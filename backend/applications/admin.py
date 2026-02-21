"""
Applications App - Admin Configuration
"""

from django.contrib import admin
from .models import Application


@admin.register(Application)
class ApplicationAdmin(admin.ModelAdmin):
    list_display = ['farmer', 'scheme', 'status', 'created_at', 'verified_at']
    list_filter = ['status', 'created_at', 'verified_at']
    search_fields = ['farmer__name', 'farmer__phone', 'scheme__name']
    readonly_fields = ['id', 'auto_filled_data', 'created_at', 'updated_at']
    ordering = ['-created_at']
    
    raw_id_fields = ['farmer', 'scheme']
    
    fieldsets = (
        ('Application Info', {
            'fields': ('id', 'farmer', 'scheme', 'status')
        }),
        ('Auto-Filled Data', {
            'fields': ('auto_filled_data',),
            'classes': ('collapse',)
        }),
        ('Documents', {
            'fields': ('documents_submitted', 'missing_documents')
        }),
        ('Verification', {
            'fields': ('verified_by', 'verified_at', 'admin_notes', 'rejection_reason')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )
    
    actions = ['approve_applications', 'reject_applications']
    
    def approve_applications(self, request, queryset):
        count = 0
        for app in queryset:
            app.approve(verified_by=request.user.username)
            count += 1
        self.message_user(request, f'{count} applications approved.')
    approve_applications.short_description = 'Approve selected applications'
    
    def reject_applications(self, request, queryset):
        count = queryset.update(status='REJECTED')
        self.message_user(request, f'{count} applications rejected.')
    reject_applications.short_description = 'Reject selected applications'
