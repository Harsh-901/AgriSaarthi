"""
Documents App - Serializers
"""

from rest_framework import serializers
from .models import Document


class DocumentSerializer(serializers.ModelSerializer):
    """Full document serializer"""
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)
    
    class Meta:
        model = Document
        fields = [
            'id', 'farmer', 'document_type', 'document_type_display',
            'document_url', 'is_verified', 'verified_at', 'created_at'
        ]
        read_only_fields = ['id', 'is_verified', 'verified_at', 'created_at']


class DocumentCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating/uploading documents"""

    class Meta:
        model = Document
        fields = ['document_type']

    def validate_document_type(self, value):
        valid_types = [choice[0] for choice in Document.DOCUMENT_TYPES]
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid document type. Must be one of: {valid_types}")
        return value


class DocumentListSerializer(serializers.ModelSerializer):
    """Minimal document info for listings"""
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)
    
    class Meta:
        model = Document
        fields = ['id', 'document_type', 'document_type_display', 'is_verified']
