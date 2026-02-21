"""
Documents App - Admin Configuration
"""

from django.contrib import admin
from .models import Document


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ['farmer', 'document_type', 'is_verified', 'created_at']
    list_filter = ['document_type', 'is_verified', 'created_at']
    search_fields = ['farmer__name', 'farmer__phone']
    readonly_fields = ['id', 'created_at', 'verified_at']
    ordering = ['-created_at']
    
    raw_id_fields = ['farmer']
