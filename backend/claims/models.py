"""
Claims App - Models
WeatherAlert and InsuranceClaim for PMFBY proactive claims
"""

import uuid
from django.db import models
from django.utils import timezone
from datetime import timedelta


class WeatherAlert(models.Model):
    """
    Records weather events that cross danger thresholds.
    Created when system detects extreme weather at farmer's location.
    Table exists in Supabase - managed = False
    """

    ALERT_TYPE_CHOICES = [
        ('heavy_rain', 'Heavy Rainfall'),
        ('flood', 'Flood'),
        ('drought', 'Drought'),
        ('hailstorm', 'Hailstorm'),
        ('cyclone', 'Cyclone'),
        ('frost', 'Frost'),
        ('pest_attack', 'Pest Attack'),
    ]

    SEVERITY_CHOICES = [
        ('low', 'Low'),
        ('moderate', 'Moderate'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    farmer = models.ForeignKey(
        'farmers.Farmer',
        on_delete=models.CASCADE,
        related_name='weather_alerts',
        db_column='farmer_id'
    )
    alert_type = models.CharField(
        max_length=30,
        choices=ALERT_TYPE_CHOICES
    )
    severity = models.CharField(
        max_length=20,
        choices=SEVERITY_CHOICES,
        default='moderate'
    )
    weather_data = models.JSONField(
        default=dict,
        help_text="Raw weather API response snapshot"
    )
    location_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Location query used for weather check"
    )
    temp_c = models.DecimalField(
        max_digits=5, decimal_places=1, null=True, blank=True
    )
    humidity = models.IntegerField(null=True, blank=True)
    precip_mm = models.DecimalField(
        max_digits=7, decimal_places=1, null=True, blank=True
    )
    wind_kph = models.DecimalField(
        max_digits=6, decimal_places=1, null=True, blank=True
    )
    condition_text = models.CharField(max_length=100, blank=True, default='')

    triggered_at = models.DateTimeField(auto_now_add=True)
    is_acknowledged = models.BooleanField(
        default=False,
        help_text="Whether farmer has responded to the alert"
    )
    has_damage = models.BooleanField(
        default=False,
        help_text="Farmer confirmed crop damage"
    )
    acknowledged_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'weather_alerts'
        managed = False
        ordering = ['-triggered_at']
        verbose_name = 'Weather Alert'
        verbose_name_plural = 'Weather Alerts'

    def __str__(self):
        return f"{self.get_alert_type_display()} - {self.farmer.name} ({self.severity})"


class InsuranceClaim(models.Model):
    """
    PMFBY Insurance Claim form with auto-filled data,
    evidence photos, and document attachments.
    72-hour deadline enforcement from date of calamity.
    Table exists in Supabase - managed = False
    """

    LOSS_TYPE_CHOICES = [
        ('flood', 'Flood'),
        ('drought', 'Drought'),
        ('hailstorm', 'Hailstorm'),
        ('heavy_rain', 'Heavy Rainfall'),
        ('cyclone', 'Cyclone'),
        ('frost', 'Frost'),
        ('pest_attack', 'Pest Attack'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('EVIDENCE_PENDING', 'Evidence Pending'),
        ('DOCUMENTS_PENDING', 'Documents Pending'),
        ('READY_TO_SUBMIT', 'Ready to Submit'),
        ('SUBMITTED', 'Submitted for Verification'),
        ('UNDER_REVIEW', 'Under Review'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    ]

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    claim_id = models.CharField(
        max_length=20,
        unique=True,
        null=True,
        blank=True,
        db_index=True,
        help_text="Human-readable claim ID (e.g., CLM-2026-XXXXX)"
    )
    farmer = models.ForeignKey(
        'farmers.Farmer',
        on_delete=models.CASCADE,
        related_name='insurance_claims',
        db_column='farmer_id'
    )
    weather_alert = models.ForeignKey(
        WeatherAlert,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='claims',
        db_column='weather_alert_id'
    )

    # Claim Details
    loss_type = models.CharField(
        max_length=30,
        choices=LOSS_TYPE_CHOICES
    )
    date_of_calamity = models.DateField(
        help_text="Date when calamity occurred"
    )
    survey_number = models.CharField(
        max_length=50,
        blank=True,
        default='',
        help_text="Survey number from 7/12 extract"
    )
    area_affected = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        help_text="Affected area in acres"
    )
    damage_description = models.TextField(
        blank=True,
        default='',
        help_text="Description of crop damage"
    )

    # Auto-filled PMFBY form data
    claim_form_data = models.JSONField(
        default=dict,
        help_text="Complete auto-filled PMFBY claim form"
    )

    # Evidence
    evidence_photos = models.JSONField(
        default=list,
        help_text="List of geotagged photo URLs"
    )
    attached_documents = models.JSONField(
        default=list,
        help_text="Aadhaar, passbook, sowing cert URLs"
    )

    # Status & Tracking
    status = models.CharField(
        max_length=25,
        choices=STATUS_CHOICES,
        default='DRAFT',
        db_index=True
    )
    deadline = models.DateTimeField(
        null=True,
        blank=True,
        help_text="72-hour deadline for claim submission"
    )
    is_within_deadline = models.BooleanField(
        default=True,
        help_text="Whether claim was filed within 72 hours"
    )

    # Admin fields
    admin_notes = models.TextField(blank=True, default='')
    rejection_reason = models.TextField(blank=True, default='')
    verified_by = models.CharField(max_length=100, blank=True, null=True)
    verified_at = models.DateTimeField(null=True, blank=True)

    submitted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'insurance_claims'
        managed = False
        ordering = ['-created_at']
        verbose_name = 'Insurance Claim'
        verbose_name_plural = 'Insurance Claims'

    def __str__(self):
        return f"{self.claim_id or self.id} - {self.farmer.name} ({self.status})"

    def save(self, *args, **kwargs):
        if not self.claim_id:
            self.claim_id = self.generate_claim_id()
        if self.date_of_calamity and not self.deadline:
            from datetime import datetime, time
            calamity_dt = datetime.combine(self.date_of_calamity, time.min)
            calamity_dt = timezone.make_aware(calamity_dt) if timezone.is_naive(calamity_dt) else calamity_dt
            self.deadline = calamity_dt + timedelta(hours=72)
        # Auto-check deadline
        if self.deadline:
            self.is_within_deadline = timezone.now() <= self.deadline
        super().save(*args, **kwargs)

    @staticmethod
    def generate_claim_id():
        import random
        year = timezone.now().year
        random_part = ''.join([str(random.randint(0, 9)) for _ in range(5)])
        return f"CLM-{year}-{random_part}"

    @property
    def hours_remaining(self):
        """Hours remaining until 72-hour deadline"""
        if not self.deadline:
            return 0
        remaining = self.deadline - timezone.now()
        hours = remaining.total_seconds() / 3600
        return max(0, round(hours, 1))

    @property
    def is_deadline_expired(self):
        if not self.deadline:
            return False
        return timezone.now() > self.deadline

    def submit(self):
        """Submit claim for admin verification"""
        self.status = 'SUBMITTED'
        self.submitted_at = timezone.now()
        self.is_within_deadline = timezone.now() <= self.deadline if self.deadline else True
        self.save()

    def get_claim_json(self):
        """Output structured PMFBY claim JSON"""
        return {
            'loss_type': self.loss_type,
            'timestamp': self.created_at.isoformat() if self.created_at else timezone.now().isoformat(),
            'survey_number': self.survey_number,
            'damage_description': self.damage_description,
            'claim_id': self.claim_id,
            'farmer_id': str(self.farmer.id),
            'area_affected': float(self.area_affected),
            'date_of_calamity': self.date_of_calamity.isoformat() if self.date_of_calamity else None,
            'deadline': self.deadline.isoformat() if self.deadline else None,
            'hours_remaining': self.hours_remaining,
            'is_within_deadline': self.is_within_deadline,
            'status': self.status,
            'evidence_count': len(self.evidence_photos) if self.evidence_photos else 0,
            'documents_count': len(self.attached_documents) if self.attached_documents else 0,
        }
