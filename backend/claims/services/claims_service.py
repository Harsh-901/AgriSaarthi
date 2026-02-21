"""
Claims App - Claims Service
Auto-fills PMFBY claim forms, handles evidence upload, document attachment,
and claim submission with 72-hour deadline enforcement.
"""

import logging
from typing import Dict, Any
from datetime import datetime, date
from django.utils import timezone

logger = logging.getLogger(__name__)


class ClaimsService:
    """
    Service for managing insurance claims lifecycle:
    1. Auto-fill PMFBY form from farmer profile + weather alert
    2. Upload geotagged evidence photos
    3. Attach existing documents (Aadhaar, passbook)
    4. Submit for admin verification
    """

    @classmethod
    def auto_fill_claim_form(cls, farmer, weather_alert=None) -> Dict[str, Any]:
        """
        Generate a pre-filled PMFBY claim form using farmer profile data
        and weather alert information.

        Args:
            farmer: Farmer model instance
            weather_alert: Optional WeatherAlert instance

        Returns:
            Complete PMFBY claim form structure
        """
        form = {
            # Farmer / Policy Details (from profile)
            'farmer_details': {
                'farmer_id': str(farmer.id),
                'name': farmer.name,
                'phone': farmer.phone,
                'state': farmer.state,
                'district': farmer.district,
                'village': farmer.village,
                'land_size': float(farmer.land_size),
                'land_size_unit': 'acres',
                'crop_type': farmer.crop_type,
                'land_type': farmer.land_type,
                'farming_category': farmer.farming_category,
                'social_category': farmer.social_category,
                'gender': farmer.gender,
                'age': farmer.age,
                'annual_income': float(farmer.annual_income),
            },

            # Nature of Loss (from weather alert)
            'loss_details': {
                'loss_type': weather_alert.alert_type if weather_alert else '',
                'severity': weather_alert.severity if weather_alert else '',
                'date_of_calamity': (
                    weather_alert.triggered_at.date().isoformat()
                    if weather_alert and weather_alert.triggered_at
                    else date.today().isoformat()
                ),
                'weather_condition': weather_alert.condition_text if weather_alert else '',
                'temperature': float(weather_alert.temp_c) if weather_alert and weather_alert.temp_c else None,
                'precipitation': float(weather_alert.precip_mm) if weather_alert and weather_alert.precip_mm else None,
                'humidity': weather_alert.humidity if weather_alert else None,
                'wind_speed': float(weather_alert.wind_kph) if weather_alert and weather_alert.wind_kph else None,
            },

            # Scheme Information
            'scheme_info': {
                'scheme_name': 'Pradhan Mantri Fasal Bima Yojana',
                'scheme_name_hindi': 'प्रधानमंत्री फसल बीमा योजना',
                'scheme_type': 'Crop Insurance',
            },

            # Required docs checklist
            'required_documents': [
                {'type': 'aadhaar', 'label': 'Aadhaar Card', 'required': True},
                {'type': 'bank_passbook', 'label': 'Bank Passbook', 'required': True},
                {'type': 'land_certificate', 'label': 'Land Certificate / 7/12 Extract', 'required': True},
                {'type': 'seven_twelve', 'label': '7/12 Extract (Satbara)', 'required': True},
                {'type': 'sowing_certificate', 'label': 'Sowing Certificate', 'required': False},
            ],

            # Metadata
            'metadata': {
                'form_generated_at': datetime.now().isoformat(),
                'auto_filled': True,
                'form_type': 'PMFBY_CLAIM',
                'form_version': '1.0',
                'language': farmer.language,
                'deadline_hours': 72,
            },
        }

        return form

    @classmethod
    def create_claim(cls, farmer, weather_alert=None, loss_type=None,
                     area_affected=0, damage_description='', survey_number=''):
        """
        Create a draft insurance claim with auto-filled data.

        Args:
            farmer: Farmer model instance
            weather_alert: Optional WeatherAlert instance
            loss_type: Type of loss (if not from weather alert)
            area_affected: Affected area in acres
            damage_description: Description of damage
            survey_number: Survey number from 7/12

        Returns:
            InsuranceClaim instance
        """
        from claims.models import InsuranceClaim

        # Determine loss type
        effective_loss_type = loss_type or (weather_alert.alert_type if weather_alert else 'other')

        # Determine date of calamity
        if weather_alert and weather_alert.triggered_at:
            date_of_calamity = weather_alert.triggered_at.date()
        else:
            date_of_calamity = date.today()

        # Generate auto-filled form
        claim_form = cls.auto_fill_claim_form(farmer, weather_alert)

        # Create claim
        claim = InsuranceClaim.objects.create(
            farmer=farmer,
            weather_alert=weather_alert,
            loss_type=effective_loss_type,
            date_of_calamity=date_of_calamity,
            survey_number=survey_number,
            area_affected=area_affected,
            damage_description=damage_description,
            claim_form_data=claim_form,
            status='EVIDENCE_PENDING',
        )

        return claim

    @classmethod
    def upload_evidence_photo(cls, claim, file, metadata=None):
        """
        Upload a geotagged crop damage photo to Supabase storage.

        Args:
            claim: InsuranceClaim instance
            file: Uploaded file object
            metadata: Optional dict with lat, lon, timestamp

        Returns:
            dict with upload result
        """
        from core.storage import upload_document, get_bucket_name, create_farmer_bucket

        farmer_id = str(claim.farmer.id)

        # Ensure bucket exists
        create_farmer_bucket(farmer_id)

        # Generate filename
        photo_count = len(claim.evidence_photos) if claim.evidence_photos else 0
        file_ext = file.name.split('.')[-1] if '.' in file.name else 'jpg'
        filename = f"claims/{claim.claim_id}/evidence_{photo_count + 1}.{file_ext}"

        # Upload to Supabase
        document_url = upload_document(farmer_id, file, filename)

        if not document_url:
            return {'success': False, 'message': 'Failed to upload photo'}

        # Build photo record
        photo_record = {
            'url': document_url,
            'filename': filename,
            'uploaded_at': datetime.now().isoformat(),
            'photo_number': photo_count + 1,
        }

        if metadata:
            photo_record['latitude'] = metadata.get('latitude')
            photo_record['longitude'] = metadata.get('longitude')
            photo_record['capture_timestamp'] = metadata.get('timestamp')

        # Update claim
        photos = claim.evidence_photos or []
        photos.append(photo_record)
        claim.evidence_photos = photos
        claim.save()

        return {
            'success': True,
            'photo': photo_record,
            'total_photos': len(photos),
        }

    @classmethod
    def attach_documents(cls, claim):
        """
        Attach existing documents from farmer's document vault.
        Pulls Aadhaar, passbook, land certificates from Supabase storage.

        Args:
            claim: InsuranceClaim instance

        Returns:
            dict with attachment result
        """
        from applications.services.supabase_storage import SupabaseStorageService

        farmer_id = str(claim.farmer.id)
        required_doc_types = ['aadhaar', 'bank_passbook', 'land_certificate', 'seven_twelve']

        # Fetch documents from Supabase
        doc_result = SupabaseStorageService.fetch_required_documents(
            farmer_id, required_doc_types
        )

        # Update claim
        claim.attached_documents = doc_result.get('found', [])
        missing = doc_result.get('missing', [])

        # Update status based on completeness
        has_evidence = len(claim.evidence_photos or []) >= 1
        has_docs = len(missing) == 0

        if has_evidence and has_docs:
            claim.status = 'READY_TO_SUBMIT'
        elif has_evidence:
            claim.status = 'DOCUMENTS_PENDING'
        else:
            claim.status = 'EVIDENCE_PENDING'

        claim.save()

        return {
            'success': True,
            'attached': doc_result.get('found', []),
            'missing': [doc.get('document_type', doc) for doc in missing],
            'documents_complete': has_docs,
            'status': claim.status,
        }

    @classmethod
    def submit_claim(cls, claim):
        """
        Submit the claim for admin verification.
        Validates completeness and checks 72-hour deadline.

        Args:
            claim: InsuranceClaim instance

        Returns:
            dict with submission result
        """
        # Validate evidence
        if not claim.evidence_photos or len(claim.evidence_photos) < 1:
            return {
                'success': False,
                'message': 'At least 1 evidence photo is required',
                'step': 'evidence',
            }

        # Validate documents
        if not claim.attached_documents or len(claim.attached_documents) < 1:
            return {
                'success': False,
                'message': 'Required documents must be attached',
                'step': 'documents',
            }

        # Check deadline
        is_within_deadline = True
        if claim.deadline:
            is_within_deadline = timezone.now() <= claim.deadline

        # Submit
        claim.submit()

        return {
            'success': True,
            'message': 'Claim submitted for verification' + (
                '' if is_within_deadline else ' (Note: submitted after 72-hour deadline)'
            ),
            'claim_id': claim.claim_id,
            'submitted_at': claim.submitted_at.isoformat(),
            'is_within_deadline': is_within_deadline,
            'hours_remaining': claim.hours_remaining,
            'status': claim.status,
            'claim_json': claim.get_claim_json(),
        }
