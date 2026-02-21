"""
Farmers App - Views
"""

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import Farmer
from .serializers import FarmerSerializer, FarmerUpdateSerializer
from core.authentication import get_farmer_from_token


class ProfileView(APIView):
    """
    GET /api/farmers/profile/<farmer_id>/
    PUT /api/farmers/profile/<farmer_id>/

    Get or update specific farmer's profile by ID
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, farmer_id):
        try:
            farmer = Farmer.objects.get(id=farmer_id)
            serializer = FarmerSerializer(farmer)
            return Response({
                'success': True,
                'data': serializer.data
            })
        except Farmer.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

    def put(self, request, farmer_id):
        # Only allow updating own profile
        if str(request.user.id) != str(farmer_id):
            return Response({
                'success': False,
                'message': 'You can only update your own profile'
            }, status=status.HTTP_403_FORBIDDEN)

        try:
            farmer = Farmer.objects.get(id=farmer_id)
        except Farmer.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = FarmerUpdateSerializer(farmer, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Profile updated successfully',
                'data': FarmerSerializer(farmer).data
            })

        return Response({
            'success': False,
            'message': 'Invalid data',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class FarmerDetailView(APIView):
    """
    GET /api/farmers/<farmer_id>/
    
    Get specific farmer details (admin only in production)
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request, farmer_id):
        try:
            farmer = Farmer.objects.get(id=farmer_id)
            serializer = FarmerSerializer(farmer)
            return Response({
                'success': True,
                'data': serializer.data
            })
        except Farmer.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
