"""
Auth App - Serializers
"""

from rest_framework import serializers
import re


class PhoneLoginSerializer(serializers.Serializer):
    """Serializer for phone number login request"""
    phone = serializers.CharField(max_length=15, required=True)
    
    def validate_phone(self, value):
        """Standardize to 10-digit Indian phone number"""
        phone = re.sub(r'[\s\-\(\)\+]', '', value)
        if phone.startswith('91') and len(phone) == 12:
            phone = phone[2:]
        elif len(phone) > 10:
            phone = phone[-10:]
            
        if not phone.isdigit() or len(phone) != 10:
            raise serializers.ValidationError("Please enter a valid 10-digit phone number.")
        return phone


class OTPVerifySerializer(serializers.Serializer):
    """Serializer for OTP verification"""
    phone = serializers.CharField(max_length=15, required=True)
    otp = serializers.CharField(max_length=6, min_length=4, required=True)
    
    def validate_phone(self, value):
        """Standardize to 10-digit Indian phone number"""
        phone = re.sub(r'[\s\-\(\)\+]', '', value)
        if phone.startswith('91') and len(phone) == 12:
            phone = phone[2:]
        elif len(phone) > 10:
            phone = phone[-10:]
        return phone
    
    def validate_otp(self, value):
        """Validate OTP format"""
        if not value.isdigit():
            raise serializers.ValidationError("OTP must contain only digits.")
        return value


class TokenResponseSerializer(serializers.Serializer):
    """Serializer for token response"""
    access_token = serializers.CharField()
    refresh_token = serializers.CharField()
    farmer_id = serializers.UUIDField()
    is_new_user = serializers.BooleanField()


class FarmerRegistrationSerializer(serializers.Serializer):
    """
    Serializer for farmer registration (initial profile creation).
    Includes OTP verification and document submission.
    """
    # Auth fields
    phone = serializers.CharField(max_length=15, required=True)
    otp = serializers.CharField(max_length=6, min_length=4, required=True)
    
    # Profile fields
    name = serializers.CharField(max_length=255, required=True)
    state = serializers.CharField(max_length=100, required=True)
    district = serializers.CharField(max_length=100, required=True)
    village = serializers.CharField(max_length=100, required=False, allow_blank=True)
    land_size = serializers.DecimalField(max_digits=10, decimal_places=2, required=True)
    crop_type = serializers.CharField(max_length=255, required=True)
    language = serializers.CharField(max_length=50, required=False, default='hindi')
    
    # Documents
    documents = serializers.ListField(
        child=serializers.DictField(),
        required=False,
        allow_empty=True
    )

    def validate_phone(self, value):
        """Standardize to 10-digit Indian phone number"""
        phone = re.sub(r'[\s\-\(\)\+]', '', value)
        if phone.startswith('91') and len(phone) == 12:
            phone = phone[2:]
        elif len(phone) > 10:
            phone = phone[-10:]
        return phone

    def validate_document(self, value):
        """Validate document structure"""
        if 'document_type' not in value or 'document_url' not in value:
            raise serializers.ValidationError("Document must have 'document_type' and 'document_url'")
        return value
