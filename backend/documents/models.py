"""
Documents App - Document Model
"""
import uuid
from django.db import models


class Document(models.Model):
    """
    Farmer document storage reference.
    Table exists in Supabase - managed = False
    """
    
    DOCUMENT_TYPES = [
        ('aadhaar', 'Aadhaar Card'),
        ('pan_card', 'PAN Card'),
        ('land_certificate', 'Land Certificate'),
        ('seven_twelve', '7/12 Extract'),
        ('eight_a', '8A Document'),
        ('bank_passbook', 'Bank Passbook'),
        ('other', 'Other'),
    ]
    
    id = models.UUIDField(
        primary_key=True, 
        default=uuid.uuid4, 
        editable=False
    )
    farmer = models.ForeignKey(
        'farmers.Farmer',
        on_delete=models.CASCADE,
        related_name='documents',
        db_column='farmer_id'
    )
    document_type = models.CharField(
        max_length=50,
        choices=DOCUMENT_TYPES
    )
    document_url = models.URLField(max_length=500)
    is_verified = models.BooleanField(default=False)
    verified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'documents'
        managed = False  # Table exists in Supabase
        ordering = ['-created_at']
        verbose_name = 'Document'
        verbose_name_plural = 'Documents'
    
    def __str__(self):
        return f"{self.get_document_type_display()} - {self.farmer.name}"
    
    @classmethod
    def get_farmer_document_types(cls, farmer):
        """Get list of document types a farmer has"""
        return list(cls.objects.filter(farmer=farmer).values_list('document_type', flat=True))