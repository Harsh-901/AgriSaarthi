"""
Schemes App - Admin Configuration
"""

from django.contrib import admin
from .models import Scheme, SchemeRule


class SchemeRuleInline(admin.TabularInline):
    """Inline admin for SchemeRule — edit rules directly on the Scheme page."""
    model = SchemeRule
    extra = 1
    fields = ['field', 'operator', 'value', 'message']


@admin.register(Scheme)
class SchemeAdmin(admin.ModelAdmin):
    list_display = ['name', 'benefit_amount', 'is_active', 'deadline', 'created_at']
    list_filter = ['is_active', 'deadline', 'created_at']
    search_fields = ['name', 'name_hindi', 'description']
    readonly_fields = ['id', 'created_at', 'updated_at']
    ordering = ['-created_at']
    inlines = [SchemeRuleInline]
    
    fieldsets = (
        ('Basic Info', {
            'fields': ('id', 'name', 'name_hindi', 'name_marathi')
        }),
        ('Description', {
            'fields': ('description', 'description_hindi')
        }),
        ('Benefit', {
            'fields': ('benefit_amount', 'deadline')
        }),
        ('Eligibility (Legacy JSON)', {
            'fields': ('eligibility_rules', 'required_documents'),
            'classes': ('collapse',),
            'description': 'Legacy JSON rules. Use the Scheme Rules inline below instead.'
        }),
        ('Status', {
            'fields': ('is_active', 'created_by', 'created_at', 'updated_at')
        }),
    )
    
    def get_readonly_fields(self, request, obj=None):
        if obj:  # Editing existing object
            return self.readonly_fields
        return ['id', 'created_at', 'updated_at']


@admin.register(SchemeRule)
class SchemeRuleAdmin(admin.ModelAdmin):
    list_display = ['scheme', 'field', 'operator', 'value', 'message']
    list_filter = ['field', 'operator']
    search_fields = ['scheme__name', 'field', 'value']
    ordering = ['scheme__name', 'field']
