"""
Applications App - Serializers
"""

from rest_framework import serializers
from .models import Application
from schemes.serializers import SchemeListSerializer


class ApplicationSerializer(serializers.ModelSerializer):
    """Full application serializer"""
    scheme_name = serializers.CharField(source='scheme.name', read_only=True)
    farmer_name = serializers.CharField(source='farmer.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Application
        fields = [
            'id', 'farmer', 'scheme', 'scheme_name', 'farmer_name',
            'auto_filled_data', 'status', 'status_display',
            'documents_submitted', 'missing_documents',
            'admin_notes', 'rejection_reason',
            'verified_by', 'verified_at',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'farmer', 'auto_filled_data', 'created_at', 'updated_at']


class ApplicationListSerializer(serializers.ModelSerializer):
    """Minimal application info for listings"""
    scheme_name = serializers.CharField(source='scheme.name', read_only=True)
    scheme_name_hindi = serializers.CharField(source='scheme.name_hindi', read_only=True)
    benefit_amount = serializers.DecimalField(
        source='scheme.benefit_amount',
        max_digits=12, decimal_places=2,
        read_only=True
    )
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Application
        fields = [
            'id', 'scheme_name', 'scheme_name_hindi',
            'benefit_amount', 'status', 'status_display',
            'created_at'
        ]


class ApplicationCreateSerializer(serializers.Serializer):
    """Serializer for creating application"""
    scheme_id = serializers.UUIDField(required=True)


class ApplicationStatusSerializer(serializers.Serializer):
    """Serializer for application status response"""
    application_id = serializers.UUIDField()
    status = serializers.CharField()
    status_display = serializers.CharField()
    scheme_name = serializers.CharField()
    applied_on = serializers.DateTimeField()
    last_updated = serializers.DateTimeField()
    rejection_reason = serializers.CharField(allow_blank=True)
