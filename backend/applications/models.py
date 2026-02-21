"""
Applications App - Application Model
Enhanced with tracking and confirmation fields
"""

import uuid
from django.db import models
from django.utils import timezone


class Application(models.Model):
    """
    Farmer scheme application with auto-filled data.
    Includes tracking, confirmation, and document attachment.
    """
    
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('PENDING_CONFIRMATION', 'Pending Farmer Confirmation'),
        ('PENDING', 'Pending Review'),
        ('UNDER_REVIEW', 'Under Review'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
        ('INCOMPLETE', 'Incomplete Documents'),
    ]
    
    id = models.UUIDField(
        primary_key=True, 
        default=uuid.uuid4, 
        editable=False
    )
    
    # Tracking ID for government reference (human readable)
    tracking_id = models.CharField(
        max_length=20,
        unique=True,
        null=True,
        blank=True,
        db_index=True,
        help_text="Human-readable tracking ID (e.g., APP-2024-XXXXX)"
    )
    
    farmer = models.ForeignKey(
        'farmers.Farmer',
        on_delete=models.CASCADE,
        related_name='applications',
        db_column='farmer_id'
    )
    scheme = models.ForeignKey(
        'schemes.Scheme',
        on_delete=models.CASCADE,
        related_name='applications',
        db_column='scheme_id'
    )
    
    # Unified form with auto-filled data
    auto_filled_data = models.JSONField(
        default=dict,
        help_text="Unified form with basic_details, attached_documents, scheme_info"
    )
    
    # Attached documents from Supabase storage
    attached_documents = models.JSONField(
        default=list,
        help_text="Documents attached from farmer's storage bucket with signed URLs"
    )
    
    status = models.CharField(
        max_length=25,
        choices=STATUS_CHOICES,
        default='DRAFT',
        db_index=True
    )
    
    documents_submitted = models.JSONField(default=list)
    missing_documents = models.JSONField(default=list)
    
    # Confirmation tracking
    is_confirmed = models.BooleanField(
        default=False,
        help_text="Whether farmer has confirmed the application"
    )
    confirmed_at = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="When farmer confirmed the application"
    )
    
    # Submission tracking
    submitted_at = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="When application was submitted to government"
    )
    government_reference = models.CharField(
        max_length=100, 
        blank=True, 
        null=True,
        help_text="Reference ID from government system"
    )
    
    # Admin/verification fields
    admin_notes = models.TextField(blank=True, default='')
    rejection_reason = models.TextField(blank=True, default='')
    verified_by = models.CharField(max_length=100, blank=True, null=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'applications'
        managed = False  # Table exists in Supabase
        ordering = ['-created_at']
        unique_together = [['farmer', 'scheme']]
        verbose_name = 'Application'
        verbose_name_plural = 'Applications'
    
    def __str__(self):
        return f"{self.tracking_id or self.id} - {self.farmer.name} ({self.status})"
    
    def save(self, *args, **kwargs):
        # Generate tracking ID if not exists
        if not self.tracking_id:
            self.tracking_id = self.generate_tracking_id()
        super().save(*args, **kwargs)
    
    @staticmethod
    def generate_tracking_id():
        """Generate human-readable tracking ID"""
        import random
        year = timezone.now().year
        random_part = ''.join([str(random.randint(0, 9)) for _ in range(5)])
        return f"APP-{year}-{random_part}"
    
    def confirm(self):
        """Farmer confirms the application - ready for submission"""
        self.is_confirmed = True
        self.confirmed_at = timezone.now()
        self.status = 'PENDING'
        self.submitted_at = timezone.now()
        self.save()
    
    def approve(self, verified_by=None, government_reference=None):
        """Approve the application"""
        self.status = 'APPROVED'
        self.verified_at = timezone.now()
        if verified_by:
            self.verified_by = verified_by
        if government_reference:
            self.government_reference = government_reference
        self.save()
    
    def reject(self, reason, verified_by=None):
        """Reject the application"""
        self.status = 'REJECTED'
        self.rejection_reason = reason
        self.verified_at = timezone.now()
        if verified_by:
            self.verified_by = verified_by
        self.save()
    
    def get_tracking_info(self):
        """Get tracking information for the application"""
        return {
            'tracking_id': self.tracking_id,
            'application_id': str(self.id),
            'scheme_name': self.scheme.name,
            'status': self.status,
            'status_display': self.get_status_display(),
            'is_confirmed': self.is_confirmed,
            'confirmed_at': self.confirmed_at.isoformat() if self.confirmed_at else None,
            'submitted_at': self.submitted_at.isoformat() if self.submitted_at else None,
            'government_reference': self.government_reference,
            'verified_at': self.verified_at.isoformat() if self.verified_at else None,
            'rejection_reason': self.rejection_reason if self.status == 'REJECTED' else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
        }
