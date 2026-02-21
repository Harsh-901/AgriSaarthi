"""
Claims App - Views
PMFBY Insurance Claims endpoints for weather check, claim creation,
evidence upload, document attachment, and submission.
"""

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.utils import timezone

from .models import WeatherAlert, InsuranceClaim
from .serializers import (
    WeatherAlertSerializer, InsuranceClaimListSerializer,
    InsuranceClaimDetailSerializer, AcknowledgeAlertSerializer,
    CreateClaimSerializer
)
from .services.weather_service import WeatherService
from .services.claims_service import ClaimsService
from core.authentication import get_farmer_from_token


class CheckWeatherView(APIView):
    """
    POST /api/claims/check-weather/

    Check weather conditions at farmer's location.
    If dangerous conditions detected, create a WeatherAlert.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        # Check weather at farmer's location
        analysis = WeatherService.check_farmer_location(farmer)

        if analysis.get('error'):
            return Response({
                'success': False,
                'message': analysis['error']
            }, status=status.HTTP_400_BAD_REQUEST)

        response_data = {
            'success': True,
            'weather': analysis.get('current', {}),
            'location': analysis.get('location', ''),
            'location_info': analysis.get('location_info', {}),
            'alert_detected': analysis.get('alert', False),
        }

        # Always create alert record (TEST MODE: simulates alert even for normal weather)
        # TODO: Remove test mode for production — restore the if/else check below
        real_alert = analysis.get('alert', False)
        alert_type = analysis.get('alert_type', 'flood') if real_alert else 'flood'
        severity = analysis.get('severity', 'moderate') if real_alert else 'high'
        details = analysis.get('details', '') if real_alert else (
            f"⚠️ TEST MODE: Simulated flood alert at {analysis.get('location', 'your location')}. "
            f"Current conditions: {analysis.get('current', {}).get('condition_text', 'Unknown')}."
        )

        weather_alert = WeatherAlert.objects.create(
            farmer=farmer,
            alert_type=alert_type,
            severity=severity,
            weather_data=analysis,
            location_name=analysis.get('location', ''),
            temp_c=analysis.get('current', {}).get('temp_c'),
            humidity=analysis.get('current', {}).get('humidity'),
            precip_mm=analysis.get('current', {}).get('precip_mm'),
            wind_kph=analysis.get('current', {}).get('wind_kph'),
            condition_text=analysis.get('current', {}).get('condition_text', ''),
        )

        response_data['alert_detected'] = True  # Always true in test mode
        response_data['alert'] = {
            'alert_id': str(weather_alert.id),
            'type': alert_type,
            'severity': severity,
            'details': details,
            'is_simulated': not real_alert,  # Flag so you know it's test data
            'message': f"⚠️ {details} "
                      f"If your crops are damaged, you can file an insurance claim "
                      f"within 72 hours.",
        }

        if analysis.get('government_alerts'):
            response_data['government_alerts'] = analysis['government_alerts']

        if not real_alert:
            response_data['message'] = (
                'Weather is normal but a TEST alert has been generated for testing.'
            )

        return Response(response_data)


class AcknowledgeAlertView(APIView):
    """
    POST /api/claims/acknowledge-alert/

    Farmer acknowledges weather alert and reports damage.
    If has_damage=true, system prepares for claim creation.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = AcknowledgeAlertSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid input',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        alert_id = serializer.validated_data['alert_id']
        has_damage = serializer.validated_data['has_damage']

        try:
            alert = WeatherAlert.objects.get(id=alert_id, farmer=farmer)
        except WeatherAlert.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Weather alert not found'
            }, status=status.HTTP_404_NOT_FOUND)

        # Update alert
        alert.is_acknowledged = True
        alert.has_damage = has_damage
        alert.acknowledged_at = timezone.now()
        alert.save()

        if has_damage:
            return Response({
                'success': True,
                'message': 'Crop damage reported. Preparing insurance claim form...',
                'alert_id': str(alert.id),
                'has_damage': True,
                'next_step': 'create_claim',
                'deadline_hours': 72,
            })
        else:
            return Response({
                'success': True,
                'message': 'Thank you for responding. We are glad your crops are safe!',
                'alert_id': str(alert.id),
                'has_damage': False,
            })


class CreateClaimView(APIView):
    """
    POST /api/claims/create/

    Create a draft insurance claim with auto-filled PMFBY form.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = CreateClaimSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid input',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get weather alert if provided
        weather_alert = None
        alert_id = serializer.validated_data.get('alert_id')
        if alert_id:
            try:
                weather_alert = WeatherAlert.objects.get(id=alert_id, farmer=farmer)
            except WeatherAlert.DoesNotExist:
                pass

        # Create claim
        claim = ClaimsService.create_claim(
            farmer=farmer,
            weather_alert=weather_alert,
            loss_type=serializer.validated_data.get('loss_type', ''),
            area_affected=serializer.validated_data.get('area_affected', 0),
            damage_description=serializer.validated_data.get('damage_description', ''),
            survey_number=serializer.validated_data.get('survey_number', ''),
        )

        return Response({
            'success': True,
            'message': 'Insurance claim created. Please upload crop damage photos.',
            'data': {
                'claim_id': claim.claim_id,
                'id': str(claim.id),
                'status': claim.status,
                'loss_type': claim.loss_type,
                'date_of_calamity': claim.date_of_calamity.isoformat(),
                'deadline': claim.deadline.isoformat() if claim.deadline else None,
                'hours_remaining': claim.hours_remaining,
                'claim_form': claim.claim_form_data,
                'next_step': 'upload_evidence',
                'steps_remaining': [
                    {'step': 'upload_evidence', 'label': 'Upload crop damage photos', 'required': True},
                    {'step': 'attach_documents', 'label': 'Attach Aadhaar & Passbook', 'required': True},
                    {'step': 'submit', 'label': 'Review & Submit', 'required': True},
                ],
            }
        }, status=status.HTTP_201_CREATED)


class UploadEvidenceView(APIView):
    """
    POST /api/claims/<claim_id>/upload-evidence/

    Upload geotagged crop damage photo as evidence.
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, claim_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            claim = InsuranceClaim.objects.get(id=claim_id, farmer=farmer)
        except InsuranceClaim.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Claim not found'
            }, status=status.HTTP_404_NOT_FOUND)

        file = request.FILES.get('photo') or request.FILES.get('file')
        if not file:
            return Response({
                'success': False,
                'message': 'No photo file provided. Send as "photo" or "file" field.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get geotag metadata
        metadata = {
            'latitude': request.data.get('latitude'),
            'longitude': request.data.get('longitude'),
            'timestamp': request.data.get('timestamp'),
        }

        result = ClaimsService.upload_evidence_photo(claim, file, metadata)

        if result['success']:
            return Response({
                'success': True,
                'message': f"Photo uploaded ({result['total_photos']} total)",
                'data': {
                    'photo': result['photo'],
                    'total_photos': result['total_photos'],
                    'claim_id': claim.claim_id,
                    'next_step': 'attach_documents' if result['total_photos'] >= 1 else 'upload_evidence',
                }
            })
        else:
            return Response({
                'success': False,
                'message': result['message']
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AttachDocumentsView(APIView):
    """
    POST /api/claims/<claim_id>/attach-documents/

    Attach existing documents (Aadhaar, passbook, land cert) from farmer's vault.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, claim_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            claim = InsuranceClaim.objects.get(id=claim_id, farmer=farmer)
        except InsuranceClaim.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Claim not found'
            }, status=status.HTTP_404_NOT_FOUND)

        result = ClaimsService.attach_documents(claim)

        return Response({
            'success': True,
            'message': 'Documents attached' if result['documents_complete']
                      else f"Some documents missing: {', '.join(result['missing'])}",
            'data': {
                'attached_count': len(result['attached']),
                'attached': result['attached'],
                'missing': result['missing'],
                'documents_complete': result['documents_complete'],
                'status': result['status'],
                'claim_id': claim.claim_id,
                'next_step': 'submit' if result['status'] == 'READY_TO_SUBMIT' else 'attach_documents',
            }
        })


class SubmitClaimView(APIView):
    """
    POST /api/claims/<claim_id>/submit/

    Final submission of claim for admin verification.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, claim_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            claim = InsuranceClaim.objects.get(id=claim_id, farmer=farmer)
        except InsuranceClaim.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Claim not found'
            }, status=status.HTTP_404_NOT_FOUND)

        result = ClaimsService.submit_claim(claim)

        if result['success']:
            return Response({
                'success': True,
                'message': result['message'],
                'data': {
                    'claim_id': result['claim_id'],
                    'submitted_at': result['submitted_at'],
                    'is_within_deadline': result['is_within_deadline'],
                    'hours_remaining': result['hours_remaining'],
                    'status': result['status'],
                    'claim_json': result['claim_json'],
                }
            })
        else:
            return Response({
                'success': False,
                'message': result['message'],
                'data': {'step': result.get('step')}
            }, status=status.HTTP_400_BAD_REQUEST)


class ClaimListView(APIView):
    """
    GET /api/claims/

    List all insurance claims for the authenticated farmer.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        claims = InsuranceClaim.objects.filter(farmer=farmer)
        serializer = InsuranceClaimListSerializer(claims, many=True)

        # Status counts
        status_counts = {
            'total': claims.count(),
            'draft': claims.filter(status='DRAFT').count(),
            'evidence_pending': claims.filter(status='EVIDENCE_PENDING').count(),
            'submitted': claims.filter(status='SUBMITTED').count(),
            'under_review': claims.filter(status='UNDER_REVIEW').count(),
            'approved': claims.filter(status='APPROVED').count(),
            'rejected': claims.filter(status='REJECTED').count(),
        }

        return Response({
            'success': True,
            'data': {
                'claims': serializer.data,
                'status_counts': status_counts,
            }
        })


class ClaimDetailView(APIView):
    """
    GET /api/claims/<claim_id>/

    Get detailed claim information with deadline countdown.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, claim_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            claim = InsuranceClaim.objects.get(id=claim_id, farmer=farmer)
        except InsuranceClaim.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Claim not found'
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = InsuranceClaimDetailSerializer(claim)

        return Response({
            'success': True,
            'data': serializer.data
        })


class WeatherAlertListView(APIView):
    """
    GET /api/claims/alerts/

    List recent weather alerts for the farmer.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        alerts = WeatherAlert.objects.filter(farmer=farmer).order_by('-triggered_at')[:20]
        serializer = WeatherAlertSerializer(alerts, many=True)

        return Response({
            'success': True,
            'data': {
                'alerts': serializer.data,
                'count': len(serializer.data),
            }
        })
