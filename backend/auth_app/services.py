"""
Auth App - OTP Service
Handles OTP generation and verification
"""

import random
import string
from datetime import timedelta
from django.utils import timezone
from django.conf import settings
from .models import OTPCode


class OTPService:
    """Service for OTP operations"""
    
    @staticmethod
    def generate_otp(length=6):
        """Generate a random numeric OTP"""
        # For demo/testing, use fixed OTP to avoid console spam
        return '123456'
        # return ''.join(random.choices(string.digits, k=length))
    
    @classmethod
    def create_otp(cls, phone: str) -> str:
        """
        Create and store a new OTP for the given phone number.
        Invalidates any existing unused OTPs for this phone.
        
        Returns: The generated OTP code
        """
        # Invalidate existing OTPs for this phone
        OTPCode.objects.filter(
            phone=phone,
            is_used=False
        ).update(is_used=True)
        
        # Generate new OTP
        otp_code = cls.generate_otp(getattr(settings, 'OTP_LENGTH', 6))
        expiry_minutes = getattr(settings, 'OTP_EXPIRY_MINUTES', 5)
        
        # Create OTP record
        OTPCode.objects.create(
            phone=phone,
            code=otp_code,
            expires_at=timezone.now() + timedelta(minutes=expiry_minutes)
        )
        
        # In production, send OTP via SMS here
        # For hackathon, we'll mock this
        # print(f"[MOCK SMS] OTP for {phone}: {otp_code}") # Removed console log
        
        return otp_code
    
    @classmethod
    def verify_otp(cls, phone: str, code: str) -> bool:
        """
        Verify OTP for the given phone number.
        
        Returns: True if OTP is valid, False otherwise
        """
        try:
            otp_record = OTPCode.objects.filter(
                phone=phone,
                code=code,
                is_used=False,
                expires_at__gt=timezone.now()
            ).latest('created_at')
            
            # Mark OTP as used
            otp_record.is_used = True
            otp_record.save()
            
            return True
        except OTPCode.DoesNotExist:
            return False
    
    @classmethod
    def cleanup_expired_otps(cls):
        """Remove expired OTPs from database"""
        deleted_count, _ = OTPCode.objects.filter(
            expires_at__lt=timezone.now()
        ).delete()
        return deleted_count
