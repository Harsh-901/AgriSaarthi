"""
Farmers App - Serializers
"""

from rest_framework import serializers
from .models import Farmer


class FarmerSerializer(serializers.ModelSerializer):
    """Full farmer profile serializer"""
    is_profile_complete = serializers.ReadOnlyField()
    
    class Meta:
        model = Farmer
        fields = [
            'id', 'phone', 'name', 'state', 'district', 'village',
            'land_size', 'crop_type', 'language', 'is_active',
            'is_profile_complete', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'phone', 'is_active', 'created_at', 'updated_at']


class FarmerUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating farmer profile"""
    
    class Meta:
        model = Farmer
        fields = ['name', 'state', 'district', 'village', 'land_size', 'crop_type', 'language']
    
    def validate_land_size(self, value):
        if value < 0:
            raise serializers.ValidationError("Land size cannot be negative.")
        return value
    
    def validate_name(self, value):
        if value and len(value) < 2:
            raise serializers.ValidationError("Name must be at least 2 characters.")
        return value


class FarmerMinimalSerializer(serializers.ModelSerializer):
    """Minimal farmer info for listings"""
    
    class Meta:
        model = Farmer
        fields = ['id', 'name', 'phone', 'state', 'district']
