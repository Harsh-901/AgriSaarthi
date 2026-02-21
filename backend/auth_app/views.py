"""
Auth App - Views
Phone OTP-based authentication endpoints
"""

import logging
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import PhoneLoginSerializer, OTPVerifySerializer, FarmerRegistrationSerializer
from .services import OTPService
from farmers.models import Farmer
from documents.models import Document
from core.storage import create_farmer_bucket

logger = logging.getLogger(__name__)


class LoginView(APIView):
    """
    POST /api/auth/login/
    Send OTP to phone number for login
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = PhoneLoginSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid phone number',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        phone = serializer.validated_data['phone']
        
        # Generate and send OTP
        otp_code = OTPService.create_otp(phone)
        
        # Check if farmer exists
        farmer_exists = Farmer.objects.filter(phone=phone).exists()
        
        return Response({
            'success': True,
            'message': f'OTP sent to {phone}',
            'data': {
                'phone': phone,
                'is_existing_user': farmer_exists,
                'otp_expiry_minutes': 5,
                # FOR DEMO ONLY - Remove in production!
                'demo_otp': otp_code
            }
        }, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    """
    POST /api/auth/verify/
    Verify OTP and return JWT tokens
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid input',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        phone = serializer.validated_data['phone']
        otp = serializer.validated_data['otp']
        
        # Verify OTP
        if not OTPService.verify_otp(phone, otp):
            return Response({
                'success': False,
                'message': 'Invalid or expired OTP'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        # Get or create farmer
        farmer, is_new = Farmer.objects.get_or_create(
            phone=phone,
            defaults={
                'name': '',
                'state': '',
                'district': '',
                'village': '',
                'land_size': 0,
                'crop_type': '',
                'language': 'hindi'
            }
        )
        
        # Create storage bucket for new farmers
        if is_new:
            bucket_created = create_farmer_bucket(str(farmer.id))
            if not bucket_created:
                logger.warning(f"Failed to create storage bucket for farmer {farmer.id}")
        
        # Generate JWT tokens
        tokens = self._generate_tokens(farmer)
        
        return Response({
            'success': True,
            'message': 'Login successful',
            'data': {
                'access_token': tokens['access'],
                'refresh_token': tokens['refresh'],
                'farmer_id': str(farmer.id),
                'is_new_user': is_new,
                'profile_complete': bool(farmer.name and farmer.state)
            }
        }, status=status.HTTP_200_OK)
    
    def _generate_tokens(self, farmer):
        """Generate JWT tokens for farmer"""
        refresh = RefreshToken()
        refresh['farmer_id'] = str(farmer.id)
        refresh['phone'] = farmer.phone
        
        return {
            'access': str(refresh.access_token),
            'refresh': str(refresh)
        }


class RegisterView(APIView):
    """
    POST /api/auth/register/
    Register a new farmer or update existing one with full profile
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = FarmerRegistrationSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid input',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        data = serializer.validated_data
        phone = data['phone']
        otp = data['otp']
        
        # Verify OTP
        if not OTPService.verify_otp(phone, otp):
            return Response({
                'success': False,
                'message': 'Invalid or expired OTP'
            }, status=status.HTTP_401_UNAUTHORIZED)
            
        # Check if farmer exists
        farmer = Farmer.objects.filter(phone=phone).first()
        
        if farmer and farmer.is_profile_complete:
            # If farmer exists and profile is complete, return error
            # They should use login instead
            return Response({
                'success': False,
                'message': 'User already registered. Please login instead.'
            }, status=status.HTTP_400_BAD_REQUEST)
            
        if not farmer:
            farmer = Farmer(phone=phone)
            
        # Update/Set profile details
        farmer.name = data['name']
        farmer.state = data['state']
        farmer.district = data['district']
        farmer.village = data.get('village', '')
        farmer.land_size = data['land_size']
        farmer.crop_type = data['crop_type']
        farmer.language = data.get('language', 'hindi')
        
        is_new_farmer = farmer.pk is None or not Farmer.objects.filter(pk=farmer.pk).exists()
        farmer.save()
        
        # Create storage bucket for new farmers
        if is_new_farmer:
            bucket_created = create_farmer_bucket(str(farmer.id))
            if not bucket_created:
                logger.warning(f"Failed to create storage bucket for farmer {farmer.id}")
        
        # Handle Documents
        documents_data = data.get('documents', [])
        if documents_data:
            # Delete existing documents if updating (optional strategy)
            # Document.objects.filter(farmer=farmer).delete() 
            
            new_docs = []
            for doc in documents_data:
                new_docs.append(Document(
                    farmer=farmer,
                    document_type=doc['document_type'],
                    document_url=doc['document_url']
                ))
            
            if new_docs:
                Document.objects.bulk_create(new_docs)
        
        # Generate tokens
        # We can reuse the Logic from VerifyOTPView if we move it to a helper or mixin
        # For now, duplicating the simple logic or calling helper if available methods
        tokens = self._generate_tokens(farmer)
        
        return Response({
            'success': True,
            'message': 'Registration successful',
            'data': {
                'access_token': tokens['access'],
                'refresh_token': tokens['refresh'],
                'farmer_id': str(farmer.id),
                'profile': {
                    'name': farmer.name,
                    'phone': farmer.phone
                }
            }
        }, status=status.HTTP_201_CREATED)

    def _generate_tokens(self, farmer):
        """Generate JWT tokens for farmer"""
        refresh = RefreshToken()
        refresh['farmer_id'] = str(farmer.id)
        refresh['phone'] = farmer.phone
        
        return {
            'access': str(refresh.access_token),
            'refresh': str(refresh)
        }


class RefreshTokenView(APIView):
    """
    POST /api/auth/refresh/
    Refresh access token using refresh token
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        refresh_token = request.data.get('refresh_token')
        
        if not refresh_token:
            return Response({
                'success': False,
                'message': 'Refresh token is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            refresh = RefreshToken(refresh_token)
            
            return Response({
                'success': True,
                'message': 'Token refreshed',
                'data': {
                    'access_token': str(refresh.access_token),
                    'refresh_token': str(refresh)
                }
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'success': False,
                'message': 'Invalid or expired refresh token'
            }, status=status.HTTP_401_UNAUTHORIZED)


class LogoutView(APIView):
    """
    POST /api/auth/logout/
    Logout user (client should discard tokens)
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        # In a production app, you might want to blacklist the token
        return Response({
            'success': True,
            'message': 'Logged out successfully'
        }, status=status.HTTP_200_OK)
