"""
Applications App - Enhanced Auto-Fill Service
Generates unified application forms with Supabase document integration
"""

from typing import Dict, Any, List, Optional
from datetime import datetime
from decimal import Decimal


class AutoFillService:
    """
    Service for auto-filling application data from farmer profile.
    Integrates with Supabase storage for document fetching.
    """
    
    @classmethod
    def generate_unified_form(cls, farmer, scheme) -> Dict[str, Any]:
        """
        Generate a unified application form structure.
        
        This is the main form that gets auto-filled with:
        - Basic details from farmer table
        - Documents from Supabase storage bucket
        - Scheme information
        
        Args:
            farmer: Farmer model instance
            scheme: Scheme model instance
        
        Returns:
            Complete unified form structure
        """
        from .supabase_storage import SupabaseStorageService
        
        # Fetch documents from Supabase storage
        required_docs = scheme.required_documents or []
        document_result = SupabaseStorageService.fetch_required_documents(
            str(farmer.id), 
            required_docs
        )
        
        # Build unified form
        unified_form = {
            # Basic Details (auto-filled from farmer table)
            'basic_details': {
                'farmer_id': str(farmer.id),
                'name': farmer.name,
                'phone': farmer.phone,
                'state': farmer.state,
                'district': farmer.district,
                'village': farmer.village,
                'land_size': float(farmer.land_size),
                'land_size_unit': 'acres',
                'crop_type': farmer.crop_type,
            },
            
            # Scheme Information
            'scheme_info': {
                'scheme_id': str(scheme.id),
                'scheme_name': scheme.name,
                'scheme_name_localized': scheme.get_localized_name(farmer.language),
                'benefit_amount': float(scheme.benefit_amount),
                'description': scheme.get_localized_description(farmer.language),
            },
            
            # Attached Documents (from Supabase bucket)
            'attached_documents': document_result['found'],
            'missing_documents': document_result['missing'],
            'documents_complete': document_result['all_found'],
            
            # Confirmation status
            'confirmation': {
                'confirmed': False,
                'confirmed_at': None,
                'requires_confirmation': True,
            },
            
            # Metadata
            'metadata': {
                'form_generated_at': datetime.now().isoformat(),
                'language': farmer.language,
                'auto_filled': True,
                'form_version': '2.0',
            }
        }
        
        return unified_form
    
    @classmethod
    def generate_application_data(cls, farmer, scheme) -> Dict[str, Any]:
        """
        Legacy method - now wraps generate_unified_form for backward compatibility.
        """
        return cls.generate_unified_form(farmer, scheme)
    
    @classmethod
    def create_draft_application(cls, farmer, scheme) -> tuple:
        """
        Create a draft application with auto-filled data.
        Application is in DRAFT status until farmer confirms.
        
        Args:
            farmer: Farmer model instance
            scheme: Scheme model instance
        
        Returns:
            Tuple of (Application instance, created boolean)
        """
        from applications.models import Application
        from schemes.services.eligibility_engine import EligibilityEngine
        
        # Check if application already exists
        existing = Application.objects.filter(farmer=farmer, scheme=scheme).first()
        if existing:
            return existing, False
        
        # Check eligibility
        eligibility = EligibilityEngine.check_eligibility(farmer, scheme)
        if not eligibility['eligible']:
            return None, False
        
        # Generate unified form
        unified_form = cls.generate_unified_form(farmer, scheme)
        
        # Determine status based on documents
        if unified_form['documents_complete']:
            initial_status = 'PENDING_CONFIRMATION'
        else:
            initial_status = 'INCOMPLETE'
        
        # Create application
        application = Application.objects.create(
            farmer=farmer,
            scheme=scheme,
            auto_filled_data=unified_form,
            attached_documents=unified_form['attached_documents'],
            status=initial_status,
            documents_submitted=[doc['document_type'] for doc in unified_form['attached_documents']],
            missing_documents=[doc['document_type'] for doc in unified_form['missing_documents']]
        )
        
        return application, True
    
    @classmethod
    def create_application(cls, farmer, scheme):
        """
        Create and auto-submit application (legacy flow for quick apply).
        """
        application, created = cls.create_draft_application(farmer, scheme)
        
        if created and application and application.status == 'PENDING_CONFIRMATION':
            # Auto-confirm for legacy flow
            application.confirm()
        
        return application, created
    
    @classmethod
    def confirm_application(cls, application) -> Dict[str, Any]:
        """
        Farmer confirms the application - submits to government.
        
        Args:
            application: Application instance
        
        Returns:
            Confirmation result
        """
        if application.is_confirmed:
            return {
                'success': False,
                'message': 'Application already confirmed',
                'tracking_id': application.tracking_id
            }
        
        if application.status == 'INCOMPLETE':
            return {
                'success': False,
                'message': 'Cannot confirm - documents are incomplete',
                'missing_documents': application.missing_documents
            }
        
        # Confirm and submit
        application.confirm()
        
        return {
            'success': True,
            'message': 'Application confirmed and submitted to government',
            'tracking_id': application.tracking_id,
            'submitted_at': application.submitted_at.isoformat(),
            'status': application.status
        }
    
    @classmethod
    def get_form_preview(cls, farmer, scheme) -> Dict[str, Any]:
        """
        Get a preview of the unified form for confirmation screen.
        """
        unified_form = cls.generate_unified_form(farmer, scheme)
        
        # Format for display
        preview = {
            'title': f'Application for {scheme.get_localized_name(farmer.language)}',
            'benefit': f'₹{scheme.benefit_amount:,.2f}',
            
            # Form fields for display
            'fields': [
                {'label': 'Applicant Name', 'value': farmer.name, 'key': 'name', 'editable': False},
                {'label': 'Phone Number', 'value': farmer.phone, 'key': 'phone', 'editable': False},
                {'label': 'State', 'value': farmer.state, 'key': 'state', 'editable': False},
                {'label': 'District', 'value': farmer.district, 'key': 'district', 'editable': False},
                {'label': 'Village', 'value': farmer.village, 'key': 'village', 'editable': True},
                {'label': 'Land Size', 'value': f'{farmer.land_size} acres', 'key': 'land_size', 'editable': False},
                {'label': 'Crop Type', 'value': farmer.crop_type, 'key': 'crop_type', 'editable': False},
            ],
            
            # Document status
            'documents': {
                'attached': unified_form['attached_documents'],
                'missing': unified_form['missing_documents'],
                'complete': unified_form['documents_complete'],
            },
            
            # Can submit?
            'can_submit': unified_form['documents_complete'],
            'submit_message': 'All documents attached. Ready to submit!' if unified_form['documents_complete'] 
                             else f"Missing {len(unified_form['missing_documents'])} document(s)",
            
            # Full form data
            'unified_form': unified_form
        }
        
        return preview
    
    @classmethod
    def refresh_documents(cls, application) -> Dict[str, Any]:
        """
        Refresh document attachments from Supabase storage.
        Useful when farmer uploads new documents.
        """
        from .supabase_storage import SupabaseStorageService
        
        farmer = application.farmer
        scheme = application.scheme
        required_docs = scheme.required_documents or []
        
        # Re-fetch documents
        document_result = SupabaseStorageService.fetch_required_documents(
            str(farmer.id),
            required_docs
        )
        
        # Update application
        application.attached_documents = document_result['found']
        application.documents_submitted = [doc['document_type'] for doc in document_result['found']]
        application.missing_documents = [doc['document_type'] for doc in document_result['missing']]
        
        # Update status if documents are now complete
        if document_result['all_found'] and application.status == 'INCOMPLETE':
            application.status = 'PENDING_CONFIRMATION'
        
        # Update unified form
        if application.auto_filled_data:
            application.auto_filled_data['attached_documents'] = document_result['found']
            application.auto_filled_data['missing_documents'] = document_result['missing']
            application.auto_filled_data['documents_complete'] = document_result['all_found']
        
        application.save()
        
        return {
            'success': True,
            'documents_complete': document_result['all_found'],
            'attached': len(document_result['found']),
            'missing': len(document_result['missing']),
            'status': application.status
        }
