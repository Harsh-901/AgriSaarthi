"""
Schemes App - Serializers
"""

from rest_framework import serializers
from .models import Scheme


class SchemeSerializer(serializers.ModelSerializer):
    """Full scheme serializer"""
    is_expired = serializers.ReadOnlyField()
    is_available = serializers.ReadOnlyField()
    
    class Meta:
        model = Scheme
        fields = [
            'id', 'name', 'name_hindi', 'name_marathi',
            'description', 'description_hindi', 'benefit_amount',
            'eligibility_rules', 'required_documents',
            'is_active', 'is_expired', 'is_available', 'deadline',
            'created_at', 'updated_at'
        ]


class SchemeListSerializer(serializers.ModelSerializer):
    """Minimal scheme info for listings"""
    
    class Meta:
        model = Scheme
        fields = ['id', 'name', 'name_hindi', 'benefit_amount', 'deadline', 'is_active']


class EligibleSchemeSerializer(serializers.Serializer):
    """Serializer for eligible scheme response"""
    scheme_id = serializers.UUIDField()
    name = serializers.CharField()
    name_localized = serializers.CharField()
    description = serializers.CharField()
    benefit_amount = serializers.FloatField()
    deadline = serializers.CharField(allow_null=True)
    can_apply = serializers.BooleanField()
    eligibility = serializers.DictField()


class SchemeAdminSerializer(serializers.ModelSerializer):
    """Full scheme serializer for admin"""
    
    class Meta:
        model = Scheme
        fields = '__all__'
