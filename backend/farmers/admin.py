"""
Farmers App - Admin Configuration
"""

from django.contrib import admin
from .models import Farmer


@admin.register(Farmer)
class FarmerAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone', 'state', 'district', 'land_size', 'crop_type', 'language', 'is_active']
    list_filter = ['state', 'language', 'is_active', 'created_at']
    search_fields = ['name', 'phone', 'village', 'district']
    readonly_fields = ['id', 'created_at', 'updated_at']
    ordering = ['-created_at']
    
    fieldsets = (
        ('Basic Info', {
            'fields': ('id', 'phone', 'name', 'language')
        }),
        ('Location', {
            'fields': ('state', 'district', 'village')
        }),
        ('Farm Details', {
            'fields': ('land_size', 'crop_type')
        }),
        ('Status', {
            'fields': ('is_active', 'created_at', 'updated_at')
        }),
    )
