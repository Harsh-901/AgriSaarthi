"""
Voice App - Views
Voice command processing endpoints
"""

import logging
from django.http import HttpResponse
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

import base64
import tempfile
import os

from .services.intent_parser import IntentParser, ResponseGenerator, Intent
from .services.voice_service import VoiceService
from schemes.services.eligibility_engine import EligibilityEngine
from applications.services.autofill_service import AutoFillService
from applications.models import Application
from schemes.models import Scheme
from documents.models import Document
from core.authentication import get_farmer_from_token


logger = logging.getLogger(__name__)


class VoiceProcessView(APIView):
    """
    POST /api/voice/process/
    
    Process voice input text and return appropriate action/response.
    This is the HERO FEATURE - main voice interaction endpoint.
    
    Accepts:
        - audio: Audio file (m4a/wav/mp3) for STT processing
        - text: Direct text input for intent parsing
    
    Returns:
        - intent, confidence, response text, audio (base64 WAV), action, data
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            farmer = get_farmer_from_token(request)
            if not farmer:
                return Response({
                    'success': False,
                    'message': 'Farmer not found. Please re-login.'
                }, status=status.HTTP_404_NOT_FOUND)
            
            language = farmer.language or 'hindi'
            
            # Get voice input (either audio or text)
            audio_file = request.FILES.get('audio')
            text = request.data.get('text', '').strip()
            
            if audio_file:
                # Validate audio file
                file_size = audio_file.size
                logger.info(f"Voice: Received audio file ({file_size} bytes) from farmer {farmer.id}")
                
                if file_size < 100:
                    return Response({
                        'success': False,
                        'message': 'Audio file too small. Please speak longer.'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if file_size > 10 * 1024 * 1024:  # 10MB limit
                    return Response({
                        'success': False,
                        'message': 'Audio file too large (max 10MB).'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Save to temp file for processing
                # Determine suffix from content type or default to .m4a
                content_type = audio_file.content_type or ''
                if 'wav' in content_type:
                    suffix = '.wav'
                elif 'mp3' in content_type or 'mpeg' in content_type:
                    suffix = '.mp3'
                else:
                    suffix = '.m4a'
                
                with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                    for chunk in audio_file.chunks():
                        tmp.write(chunk)
                    tmp_path = tmp.name
                
                try:
                    # Speech to Text
                    text, detected_lang = VoiceService.speech_to_text(tmp_path)
                    if detected_lang:
                        language = detected_lang
                    logger.info(f"Voice: STT result — lang={language}, text='{text[:100] if text else 'None'}'")
                finally:
                    # Always clean up temp file
                    try:
                        if os.path.exists(tmp_path):
                            os.unlink(tmp_path)
                    except OSError:
                        pass
                
                if not text:
                    return Response({
                        'success': False,
                        'message': 'Could not understand the audio. Please try speaking more clearly.'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            elif not text:
                return Response({
                    'success': False,
                    'message': 'No voice audio or text provided.'
                }, status=status.HTTP_400_BAD_REQUEST)
            else:
                logger.info(f"Voice: Text input from farmer {farmer.id}: '{text[:100]}'")

            # Parse intent using AI (Groq) with regex fallback
            parsed = VoiceService.map_intent(text, language)
            logger.info(f"Voice: Intent={parsed.intent.value}, confidence={parsed.confidence}")
            
            # Handle intent
            result = self._handle_intent(parsed, farmer, language)
            
            speech_text = result.get('speech_text', '')
            
            # Build JSON metadata to include in headers
            metadata = {
                'success': True,
                'intent': parsed.intent.value,
                'confidence': parsed.confidence,
                'original_text': text,
                'response': result['response'],
                'speech_text': speech_text,
                'action': result.get('action'),
                'data': result.get('data')
            }
            
            # Generate TTS audio from speech_text
            audio_content = None
            if speech_text:
                try:
                    audio_content = VoiceService.text_to_speech(speech_text, language)
                    if audio_content:
                        logger.info(f"Voice: TTS generated {len(audio_content)} bytes")
                    else:
                        logger.warning("Voice: TTS returned no audio — falling back to JSON")
                except Exception as tts_error:
                    logger.error(f"Voice: TTS failed: {tts_error}")
            
            if audio_content:
                # Return raw WAV audio with JSON metadata in headers
                import json as json_lib
                from urllib.parse import quote
                
                response = HttpResponse(audio_content, content_type='audio/wav')
                response['Content-Disposition'] = 'inline; filename="response.wav"'
                response['Content-Length'] = len(audio_content)
                
                # Expose metadata via custom headers
                response['X-Voice-Metadata'] = json_lib.dumps(metadata, ensure_ascii=False)
                response['X-Voice-Intent'] = parsed.intent.value
                response['X-Voice-Confidence'] = str(parsed.confidence)
                response['X-Voice-Response'] = quote(result['response'], safe='')
                response['X-Voice-Action'] = result.get('action') or ''
                response['X-Voice-Speech-Text'] = quote(speech_text, safe='')
                
                # Allow frontend to read custom headers (CORS)
                response['Access-Control-Expose-Headers'] = (
                    'X-Voice-Metadata, X-Voice-Intent, X-Voice-Confidence, '
                    'X-Voice-Response, X-Voice-Action, X-Voice-Speech-Text'
                )
                
                return response
            else:
                # Fallback: return JSON if TTS failed
                return Response({
                    'success': True,
                    'data': metadata
                })
        
        except Exception as e:
            logger.error(f"Voice: Unhandled error in VoiceProcessView: {type(e).__name__}: {e}", exc_info=True)
            return Response({
                'success': False,
                'message': 'An internal error occurred while processing your voice command. Please try again.'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _handle_intent(self, parsed, farmer, language):
        """Handle the parsed intent and return response"""
        intent = parsed.intent
        
        try:
            if intent == Intent.SHOW_ELIGIBLE_SCHEMES:
                return self._handle_show_schemes(farmer, language)
            
            elif intent == Intent.APPLY_SCHEME:
                scheme_mention = parsed.entities.get('scheme_mention')
                return self._handle_apply_scheme(farmer, language, scheme_mention)
            
            elif intent == Intent.CHECK_STATUS:
                return self._handle_check_status(farmer, language)
            
            elif intent == Intent.VIEW_PROFILE:
                return self._handle_view_profile(farmer, language)
            
            elif intent == Intent.LIST_APPLICATIONS:
                return self._handle_list_applications(farmer, language)
            
            elif intent == Intent.VIEW_DOCUMENTS:
                return self._handle_view_documents(farmer, language)
            
            elif intent == Intent.HELP:
                return self._handle_help(language)
            
            else:
                return self._handle_unknown(language)
        except Exception as e:
            logger.error(f"Voice: Error handling intent {intent.value}: {e}", exc_info=True)
            return self._handle_unknown(language)
    
    def _handle_show_schemes(self, farmer, language):
        """Handle SHOW_ELIGIBLE_SCHEMES intent"""
        if not farmer.is_profile_complete:
            response = ResponseGenerator.get_response(
                Intent.SHOW_ELIGIBLE_SCHEMES, language, 'incomplete_profile'
            )
            return {
                'response': response,
                'speech_text': response,
                'action': 'complete_profile'
            }
        
        eligible = EligibilityEngine.get_eligible_schemes(farmer)
        
        if not eligible:
            response = ResponseGenerator.get_response(
                Intent.SHOW_ELIGIBLE_SCHEMES, language, 'no_schemes'
            )
            return {
                'response': response,
                'speech_text': response,
                'action': None,
                'data': {'schemes': []}
            }
        
        # Build scheme list for speech
        scheme_names = [s['name_localized'] for s in eligible[:3]]
        schemes_text = ', '.join(scheme_names)
        if len(eligible) > 3:
            if language == 'marathi':
                schemes_text += f' आणि {len(eligible) - 3} अजून'
            elif language == 'hindi':
                schemes_text += f' और {len(eligible) - 3} और'
            else:
                schemes_text += f' and {len(eligible) - 3} more'
        
        response = ResponseGenerator.get_response(
            Intent.SHOW_ELIGIBLE_SCHEMES, language, 'success',
            count=len(eligible), schemes=schemes_text
        )
        
        # Strip non-serializable objects (Scheme model instances) before returning
        serializable_schemes = []
        for s in eligible:
            serializable_schemes.append({
                'scheme_id': s['scheme_id'],
                'name': s['name'],
                'name_localized': s['name_localized'],
                'description': s['description'],
                'benefit_amount': s['benefit_amount'],
                'deadline': s['deadline'],
                'can_apply': s['can_apply'],
            })
        
        return {
            'response': response,
            'speech_text': response,
            'action': 'show_schemes',
            'data': {
                'schemes': serializable_schemes,
                'count': len(eligible)
            }
        }
    
    def _handle_apply_scheme(self, farmer, language, scheme_mention=None):
        """Handle APPLY_SCHEME intent"""
        eligible = EligibilityEngine.get_eligible_schemes(farmer)
        
        if not eligible:
            response = ResponseGenerator.get_response(
                Intent.APPLY_SCHEME, language, 'not_eligible'
            )
            return {
                'response': response,
                'speech_text': response,
                'action': None
            }
        
        # Try to match scheme_mention if provided
        target_scheme_data = None
        
        if scheme_mention:
            for s in eligible:
                if scheme_mention.lower() in s.get('name', '').lower() or \
                   scheme_mention.lower() in s.get('name_localized', '').lower():
                    target_scheme_data = s
                    break
            
            if not target_scheme_data:
                # Scheme mentioned but not found in eligible list
                response = ResponseGenerator.get_response(
                    Intent.APPLY_SCHEME, language, 'scheme_not_found',
                    scheme_name=scheme_mention
                )
                return {
                    'response': response,
                    'speech_text': response,
                    'action': None
                }
        else:
            # No scheme mentioned
            # List first 3 eligible schemes and ask user to pick one
            scheme_names = [s['name_localized'] for s in eligible[:3]]
            schemes_text = ', '.join(scheme_names)
            
            response = ResponseGenerator.get_response(
                Intent.APPLY_SCHEME, language, 'specify_scheme',
                schemes=schemes_text
            )
            return {
                'response': response,
                'speech_text': response,
                'action': None
            }
        
        # Proceed with the found scheme
        scheme = target_scheme_data['scheme']
        scheme_data = target_scheme_data
        
        # Check if already applied
        existing = Application.objects.filter(farmer=farmer, scheme=scheme).first()
        if existing:
            response = ResponseGenerator.get_response(
                Intent.APPLY_SCHEME, language, 'already_applied'
            )
            return {
                'response': response,
                'speech_text': response,
                'action': 'show_application',
                'data': {
                    'application_id': str(existing.id),
                    'status': existing.status
                }
            }
        
        # Get preview data for confirmation
        preview = AutoFillService.get_form_preview(farmer, scheme)
        
        if language == 'marathi':
            response = f"तुम्हाला {scheme_data['name_localized']} साठी अर्ज करायचा आहे का?"
        elif language == 'hindi':
            response = f"क्या आप {scheme_data['name_localized']} के लिए आवेदन करना चाहते हैं?"
        else:
            response = f"Do you want to apply for {scheme_data['name_localized']}?"
        
        return {
            'response': response,
            'speech_text': response,
            'action': 'confirm_apply',
            'data': {
                'scheme_id': str(scheme.id),
                'scheme_name': scheme_data['name_localized'],
                'benefit_amount': scheme_data['benefit_amount'],
                'preview': preview
            }
        }
    
    def _handle_check_status(self, farmer, language):
        """Handle CHECK_STATUS intent"""
        applications = Application.objects.filter(farmer=farmer).select_related('scheme')
        
        if not applications:
            response = ResponseGenerator.get_response(
                Intent.CHECK_STATUS, language, 'no_applications'
            )
            return {
                'response': response,
                'speech_text': response,
                'action': None,
                'data': {'applications': []}
            }
        
        # Build status summary
        pending = applications.filter(status='PENDING').count()
        approved = applications.filter(status='APPROVED').count()
        rejected = applications.filter(status='REJECTED').count()
        
        if language == 'marathi':
            status_summary = f'{pending} प्रलंबित, {approved} मंजूर, {rejected} नाकारले'
        elif language == 'hindi':
            status_summary = f'{pending} पेंडिंग, {approved} स्वीकृत, {rejected} अस्वीकृत'
        else:
            status_summary = f'{pending} pending, {approved} approved, {rejected} rejected'
        
        response = ResponseGenerator.get_response(
            Intent.CHECK_STATUS, language, 'success',
            count=applications.count(), status_summary=status_summary
        )
        
        # Build application list
        app_list = [{
            'id': str(app.id),
            'scheme_name': app.scheme.get_localized_name(language),
            'status': app.status,
            'status_display': app.get_status_display(),
            'applied_on': app.created_at.isoformat()
        } for app in applications]
        
        return {
            'response': response,
            'speech_text': response,
            'action': 'show_applications',
            'data': {
                'applications': app_list,
                'summary': {
                    'total': applications.count(),
                    'pending': pending,
                    'approved': approved,
                    'rejected': rejected
                }
            }
        }
    
    def _handle_view_profile(self, farmer, language):
        """Handle VIEW_PROFILE intent"""
        if language == 'marathi':
            response = f'तुमचे नाव {farmer.name} आहे. तुमच्याकडे {farmer.land_size} एकर जमीन आहे आणि तुम्ही {farmer.crop_type} पिकवता.'
        elif language == 'hindi':
            response = f'आपका नाम {farmer.name} है। आपके पास {farmer.land_size} एकड़ जमीन है और आप {farmer.crop_type} उगाते हैं।'
        else:
            response = f'Your name is {farmer.name}. You have {farmer.land_size} acres of land and you grow {farmer.crop_type}.'
        
        return {
            'response': response,
            'speech_text': response,
            'action': 'show_profile',
            'data': {
                'name': farmer.name,
                'phone': farmer.phone,
                'state': farmer.state,
                'district': farmer.district,
                'village': farmer.village,
                'land_size': float(farmer.land_size),
                'crop_type': farmer.crop_type
            }
        }
    
    def _handle_view_documents(self, farmer, language):
        """Handle VIEW_DOCUMENTS intent"""
        count = Document.objects.filter(farmer=farmer).count()
        response = ResponseGenerator.get_response(
            Intent.VIEW_DOCUMENTS, language, 'success', count=count
        )
        return {
            'response': response,
            'speech_text': response,
            'action': 'show_documents'
        }
    
    def _handle_list_applications(self, farmer, language):
        """Handle LIST_APPLICATIONS intent"""
        return self._handle_check_status(farmer, language)
    
    def _handle_help(self, language):
        """Handle HELP intent"""
        response = ResponseGenerator.get_response(Intent.HELP, language)
        return {
            'response': response,
            'speech_text': response,
            'action': 'show_help'
        }
    
    def _handle_unknown(self, language):
        """Handle UNKNOWN intent"""
        response = ResponseGenerator.get_response(Intent.UNKNOWN, language)
        return {
            'response': response,
            'speech_text': response,
            'action': None
        }


class VoiceConfirmView(APIView):
    """
    POST /api/voice/confirm/
    
    Confirm an action from voice interaction (e.g., confirm application).
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            farmer = get_farmer_from_token(request)
            if not farmer:
                return Response({
                    'success': False,
                    'message': 'Farmer not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            action = request.data.get('action')
            scheme_id = request.data.get('scheme_id')
            confirmed = request.data.get('confirmed', False)
            
            if action == 'confirm_apply' and confirmed and scheme_id:
                try:
                    scheme = Scheme.objects.get(id=scheme_id)
                    application, created = AutoFillService.create_application(farmer, scheme)
                    
                    if created:
                        language = farmer.language or 'hindi'
                        response = ResponseGenerator.get_response(
                            Intent.APPLY_SCHEME, language, 'success',
                            scheme_name=scheme.get_localized_name(language)
                        )
                        logger.info(f"Voice: Application created for farmer {farmer.id}, scheme {scheme.name}")
                        return Response({
                            'success': True,
                            'data': {
                                'application_id': str(application.id),
                                'response': response,
                                'speech_text': response
                            }
                        })
                    else:
                        return Response({
                            'success': False,
                            'message': 'Already applied for this scheme'
                        }, status=status.HTTP_400_BAD_REQUEST)
                except Scheme.DoesNotExist:
                    return Response({
                        'success': False,
                        'message': 'Scheme not found'
                    }, status=status.HTTP_404_NOT_FOUND)
            
            return Response({
                'success': False,
                'message': 'Invalid confirmation request'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        except Exception as e:
            logger.error(f"Voice: Error in VoiceConfirmView: {e}", exc_info=True)
            return Response({
                'success': False,
                'message': 'An error occurred while confirming the action.'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class VoiceTTSView(APIView):
    """
    POST /api/voice/tts/
    
    Convert text to speech and return raw WAV audio file.
    Use this after voice/process to get playable audio.
    
    Accepts:
        - text: Text to convert to speech
        - language: Language (hindi, marathi, english). Defaults to farmer's language.
    
    Returns:
        - Raw WAV audio file (Content-Type: audio/wav)
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            farmer = get_farmer_from_token(request)
            if not farmer:
                return Response({
                    'success': False,
                    'message': 'Farmer not found. Please re-login.'
                }, status=status.HTTP_404_NOT_FOUND)
            
            text = request.data.get('text', '').strip()
            language = request.data.get('language', farmer.language or 'hindi')
            
            if not text:
                return Response({
                    'success': False,
                    'message': 'No text provided for speech synthesis.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            logger.info(f"TTS request: lang={language}, text='{text[:60]}...'")
            
            audio_content = VoiceService.text_to_speech(text, language)
            
            if not audio_content:
                return Response({
                    'success': False,
                    'message': 'Failed to generate audio. Please try again.'
                }, status=status.HTTP_502_BAD_GATEWAY)
            
            logger.info(f"TTS: Returning {len(audio_content)} bytes of WAV audio")
            
            response = HttpResponse(audio_content, content_type='audio/wav')
            response['Content-Disposition'] = 'inline; filename="speech.wav"'
            response['Content-Length'] = len(audio_content)
            return response
        
        except Exception as e:
            logger.error(f"Voice TTS Error: {type(e).__name__}: {e}", exc_info=True)
            return Response({
                'success': False,
                'message': 'An error occurred during speech synthesis.'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
