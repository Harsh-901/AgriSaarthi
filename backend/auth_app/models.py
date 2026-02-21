"""
Auth App - OTP Model for temporary code storage
Note: Main OTP table is in Supabase, this is for Django ORM access
"""

import uuid
from django.db import models
from django.utils import timezone
from datetime import timedelta


class OTPCode(models.Model):
    """
    OTP codes for phone authentication
    Table exists in Supabase - managed = False
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=15, db_index=True)
    code = models.CharField(max_length=6)
    is_used = models.BooleanField(default=False)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'otp_codes'
        managed = False  # Table exists in Supabase
        ordering = ['-created_at']
    
    def __str__(self):
        return f"OTP for {self.phone}"
    
    @property
    def is_expired(self):
        """Check if OTP has expired"""
        return timezone.now() > self.expires_at
    
    @property
    def is_valid(self):
        """Check if OTP is still valid (not used and not expired)"""
        return not self.is_used and not self.is_expired
