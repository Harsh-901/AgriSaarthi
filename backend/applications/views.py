"""
Applications App - Enhanced Views
Full application flow with form generation, confirmation, and tracking
"""

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import Application
from .serializers import (
    ApplicationSerializer, ApplicationListSerializer,
    ApplicationCreateSerializer
)
from .services.autofill_service import AutoFillService
from schemes.models import Scheme
from schemes.services.eligibility_engine import EligibilityEngine
from core.authentication import get_farmer_from_token


class ApplicationListView(APIView):
    """
    GET /api/applications/
    
    List all applications for the authenticated farmer.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        applications = Application.objects.filter(farmer=farmer).select_related('scheme')
        serializer = ApplicationListSerializer(applications, many=True)
        
        # Group by status
        status_counts = {
            'total': applications.count(),
            'draft': applications.filter(status='DRAFT').count(),
            'pending_confirmation': applications.filter(status='PENDING_CONFIRMATION').count(),
            'pending': applications.filter(status='PENDING').count(),
            'under_review': applications.filter(status='UNDER_REVIEW').count(),
            'approved': applications.filter(status='APPROVED').count(),
            'rejected': applications.filter(status='REJECTED').count(),
            'incomplete': applications.filter(status='INCOMPLETE').count(),
        }
        
        return Response({
            'success': True,
            'data': {
                'applications': serializer.data,
                'status_counts': status_counts
            }
        })


class GenerateFormView(APIView):
    """
    POST /api/applications/generate-form/
    
    Generate a pre-filled application form with documents attached.
    Creates a draft application ready for farmer confirmation.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        scheme_id = request.data.get('scheme_id')
        if not scheme_id:
            return Response({
                'success': False,
                'message': 'scheme_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            scheme = Scheme.objects.get(id=scheme_id)
        except Scheme.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Scheme not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check eligibility
        eligibility = EligibilityEngine.check_eligibility(farmer, scheme)
        if not eligibility['eligible']:
            return Response({
                'success': False,
                'message': 'You are not eligible for this scheme',
                'data': {'failed_rules': eligibility['failed_rules']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create draft application with auto-filled form
        application, created = AutoFillService.create_draft_application(farmer, scheme)
        
        if not created and application:
            # Application exists - refresh documents and return updated state
            AutoFillService.refresh_documents(application)
            application.refresh_from_db()  # Reload from database
            
            return Response({
                'success': True,
                'message': 'Application already exists',
                'data': {
                    'application_id': str(application.id),
                    'tracking_id': application.tracking_id,
                    'status': application.status,
                    'is_confirmed': application.is_confirmed,
                    'unified_form': application.auto_filled_data,
                    'attached_documents': application.attached_documents,
                    'missing_documents': application.missing_documents,
                    'can_confirm': application.status == 'PENDING_CONFIRMATION'
                }
            })
        
        if not application:
            return Response({
                'success': False,
                'message': 'Could not create application'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response({
            'success': True,
            'message': 'Application form generated successfully',
            'data': {
                'application_id': str(application.id),
                'tracking_id': application.tracking_id,
                'status': application.status,
                'unified_form': application.auto_filled_data,
                'attached_documents': application.attached_documents,
                'missing_documents': application.missing_documents,
                'documents_complete': len(application.missing_documents) == 0,
                'can_confirm': application.status == 'PENDING_CONFIRMATION',
                'confirmation_message': 'Please review and confirm to submit' if application.status == 'PENDING_CONFIRMATION'
                                       else f'Missing documents: {", ".join(application.missing_documents)}'
            }
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class ConfirmApplicationView(APIView):
    """
    POST /api/applications/confirm/
    
    Farmer confirms the application - submits to government for verification.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        application_id = request.data.get('application_id')
        if not application_id:
            return Response({
                'success': False,
                'message': 'application_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            application = Application.objects.get(id=application_id, farmer=farmer)
        except Application.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Application not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Confirm the application
        result = AutoFillService.confirm_application(application)
        
        if result['success']:
            return Response({
                'success': True,
                'message': result['message'],
                'data': {
                    'tracking_id': result['tracking_id'],
                    'submitted_at': result['submitted_at'],
                    'status': result['status'],
                    'next_steps': 'Your application is now with the government for verification. Track using your tracking ID.'
                }
            })
        else:
            return Response({
                'success': False,
                'message': result['message'],
                'data': result
            }, status=status.HTTP_400_BAD_REQUEST)


class TrackApplicationView(APIView):
    """
    GET /api/applications/<application_id>/track/
    
    Get detailed tracking information for an application.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request, application_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            application = Application.objects.select_related('scheme', 'farmer').get(
                id=application_id,
                farmer=farmer
            )
        except Application.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Application not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        tracking_info = application.get_tracking_info()
        tracking_info['scheme_details'] = {
            'name': application.scheme.name,
            'name_localized': application.scheme.get_localized_name(farmer.language),
            'benefit_amount': float(application.scheme.benefit_amount),
        }
        tracking_info['attached_documents'] = application.attached_documents
        tracking_info['missing_documents'] = application.missing_documents
        
        return Response({
            'success': True,
            'data': tracking_info
        })


class RefreshDocumentsView(APIView):
    """
    POST /api/applications/<application_id>/refresh-documents/
    
    Refresh document attachments from Supabase storage.
    Useful when farmer uploads new documents.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, application_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            application = Application.objects.get(id=application_id, farmer=farmer)
        except Application.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Application not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        result = AutoFillService.refresh_documents(application)
        
        return Response({
            'success': True,
            'message': 'Documents refreshed',
            'data': {
                'documents_complete': result['documents_complete'],
                'attached_count': result['attached'],
                'missing_count': result['missing'],
                'status': result['status'],
                'can_confirm': result['status'] == 'PENDING_CONFIRMATION'
            }
        })


# Legacy endpoints for backward compatibility

class ApplySchemeView(APIView):
    """
    POST /api/applications/apply/
    
    Quick apply - generates form and confirms in one step.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = ApplicationCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid input',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        scheme_id = serializer.validated_data['scheme_id']
        
        try:
            scheme = Scheme.objects.get(id=scheme_id)
        except Scheme.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Scheme not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        eligibility = EligibilityEngine.check_eligibility(farmer, scheme)
        if not eligibility['eligible']:
            return Response({
                'success': False,
                'message': 'You are not eligible for this scheme',
                'data': {'failed_rules': eligibility['failed_rules']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        application, created = AutoFillService.create_application(farmer, scheme)
        
        if not created and application:
            return Response({
                'success': False,
                'message': 'You have already applied for this scheme',
                'data': {
                    'application_id': str(application.id),
                    'tracking_id': application.tracking_id,
                    'status': application.status
                }
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if not application:
            return Response({
                'success': False,
                'message': 'Could not create application'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response({
            'success': True,
            'message': 'Application submitted successfully',
            'data': {
                'application_id': str(application.id),
                'tracking_id': application.tracking_id,
                'scheme_name': scheme.name,
                'scheme_name_localized': scheme.get_localized_name(farmer.language),
                'status': application.status,
                'unified_form': application.auto_filled_data,
                'attached_documents': application.attached_documents,
                'missing_documents': application.missing_documents
            }
        }, status=status.HTTP_201_CREATED)


class ApplicationPreviewView(APIView):
    """
    POST /api/applications/preview/
    
    Get a preview of the auto-filled form before submitting.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        scheme_id = request.data.get('scheme_id')
        if not scheme_id:
            return Response({
                'success': False,
                'message': 'scheme_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            scheme = Scheme.objects.get(id=scheme_id)
        except Scheme.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Scheme not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        preview = AutoFillService.get_form_preview(farmer, scheme)
        
        return Response({
            'success': True,
            'data': preview
        })


class ApplicationStatusView(APIView):
    """
    GET /api/applications/<application_id>/status/
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request, application_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            application = Application.objects.select_related('scheme').get(
                id=application_id,
                farmer=farmer
            )
        except Application.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Application not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        return Response({
            'success': True,
            'data': application.get_tracking_info()
        })


class ApplicationDetailView(APIView):
    """
    GET /api/applications/<application_id>/
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request, application_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            application = Application.objects.select_related('scheme', 'farmer').get(
                id=application_id,
                farmer=farmer
            )
        except Application.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Application not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = ApplicationSerializer(application)
        
        return Response({
            'success': True,
            'data': serializer.data
        })
