"""
Auth App - Admin Configuration
"""

from django.contrib import admin
from .models import OTPCode


@admin.register(OTPCode)
class OTPCodeAdmin(admin.ModelAdmin):
    list_display = ['phone', 'code', 'is_used', 'expires_at', 'created_at']
    list_filter = ['is_used', 'created_at']
    search_fields = ['phone']
    readonly_fields = ['id', 'created_at']
    ordering = ['-created_at']
