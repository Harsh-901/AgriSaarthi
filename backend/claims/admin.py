"""
Claims App - Admin Configuration
"""

from django.contrib import admin
from .models import WeatherAlert, InsuranceClaim


@admin.register(WeatherAlert)
class WeatherAlertAdmin(admin.ModelAdmin):
    list_display = ['id', 'farmer', 'alert_type', 'severity', 'location_name',
                    'is_acknowledged', 'has_damage', 'triggered_at']
    list_filter = ['alert_type', 'severity', 'is_acknowledged', 'has_damage']
    search_fields = ['farmer__name', 'farmer__phone', 'location_name']
    ordering = ['-triggered_at']
    readonly_fields = ['id', 'triggered_at']


@admin.register(InsuranceClaim)
class InsuranceClaimAdmin(admin.ModelAdmin):
    list_display = ['claim_id', 'farmer', 'loss_type', 'status',
                    'date_of_calamity', 'area_affected', 'is_within_deadline',
                    'submitted_at', 'created_at']
    list_filter = ['status', 'loss_type', 'is_within_deadline']
    search_fields = ['claim_id', 'farmer__name', 'farmer__phone']
    ordering = ['-created_at']
    readonly_fields = ['id', 'claim_id', 'created_at', 'updated_at']

    fieldsets = (
        ('Claim Info', {
            'fields': ('id', 'claim_id', 'farmer', 'weather_alert', 'status')
        }),
        ('Loss Details', {
            'fields': ('loss_type', 'date_of_calamity', 'survey_number',
                      'area_affected', 'damage_description')
        }),
        ('Evidence & Documents', {
            'fields': ('evidence_photos', 'attached_documents', 'claim_form_data')
        }),
        ('Deadline', {
            'fields': ('deadline', 'is_within_deadline')
        }),
        ('Admin Review', {
            'fields': ('admin_notes', 'rejection_reason', 'verified_by', 'verified_at')
        }),
        ('Timestamps', {
            'fields': ('submitted_at', 'created_at', 'updated_at')
        }),
    )
