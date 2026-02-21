"""
Schemes App - Scheme Model
"""

import uuid
from django.db import models
from django.utils import timezone


class Scheme(models.Model):
    """
    Government Scheme model with eligibility rules.
    Table exists in Supabase - managed = False
    """
    
    id = models.UUIDField(
        primary_key=True, 
        default=uuid.uuid4, 
        editable=False
    )
    name = models.CharField(max_length=255, unique=True, db_index=True)
    name_hindi = models.CharField(max_length=255, blank=True, null=True)
    name_marathi = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField()
    description_hindi = models.TextField(blank=True, null=True)
    benefit_amount = models.DecimalField(max_digits=12, decimal_places=2)
    
    # Eligibility rules as JSON
    # Example: {"min_land_size": 0.5, "max_land_size": 10, "allowed_states": ["Maharashtra"]}
    eligibility_rules = models.JSONField(default=dict)
    
    # Required documents as JSON array
    # Example: ["aadhaar", "land_certificate", "bank_passbook"]
    required_documents = models.JSONField(default=list)
    
    is_active = models.BooleanField(default=True, db_index=True)
    deadline = models.DateField(null=True, blank=True)
    created_by = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'schemes'
        managed = False  # Table exists in Supabase
        ordering = ['-created_at']
        verbose_name = 'Scheme'
        verbose_name_plural = 'Schemes'
    
    def __str__(self):
        return self.name
    
    def get_localized_name(self, language='english'):
        """Get scheme name in requested language"""
        if language == 'hindi' and self.name_hindi:
            return self.name_hindi
        elif language == 'marathi' and self.name_marathi:
            return self.name_marathi
        return self.name
    
    def get_localized_description(self, language='english'):
        """Get description in requested language"""
        if language == 'hindi' and self.description_hindi:
            return self.description_hindi
        return self.description
    
    @property
    def is_expired(self):
        """Check if scheme deadline has passed"""
        if self.deadline:
            return self.deadline < timezone.now().date()
        return False
    
    @property
    def is_available(self):
        """Check if scheme is available for applications"""
        return self.is_active and not self.is_expired


class SchemeRule(models.Model):
    """
    Decision Table row — one eligibility criterion per row.
    
    Example rows for a scheme:
        field=land_size,     operator=<=,  value=2,              message=Land size must be 2 acres or less
        field=annual_income, operator=<=,  value=200000,         message=Income must be below ₹2,00,000
        field=state,         operator=IN,  value=Maharashtra,UP, message=Scheme only available in MH and UP
    
    Supported operators: <=, >=, ==, IN
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    scheme = models.ForeignKey(
        Scheme,
        on_delete=models.CASCADE,
        related_name='schemerule_set'
    )
    field = models.CharField(
        max_length=50,
        help_text="Farmer model field name, e.g. land_size, annual_income, state"
    )
    operator = models.CharField(
        max_length=10,
        help_text="Comparison operator: <=, >=, ==, IN"
    )
    value = models.CharField(
        max_length=100,
        help_text="Threshold value. For IN operator, use comma-separated values"
    )
    message = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Human-readable reason shown when rule fails"
    )
    
    class Meta:
        db_table = 'scheme_rules'
        managed = False  # Table exists in Supabase
        verbose_name = 'Scheme Rule'
        verbose_name_plural = 'Scheme Rules'
    
    def __str__(self):
        return f"{self.scheme.name}: {self.field} {self.operator} {self.value}"
