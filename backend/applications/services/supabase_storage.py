"""
Supabase Storage Service
Handles document fetching from farmer storage buckets
With proper document type normalization and alias mapping
"""

import os
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from decouple import config

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None


class SupabaseStorageService:
    """
    Service to interact with Supabase Storage.
    Each farmer has their own bucket: farmer-{farmer_id}
    Documents are stored with standard naming: {document_type}.pdf/jpg
    """
    
    _client: Optional[Client] = None
    
    # Standard document types matching scheme requirements
    DOCUMENT_TYPES = {
        'aadhaar': ['aadhaar.pdf', 'aadhaar.jpg', 'aadhaar.png'],
        'land_certificate': ['land_certificate.pdf', 'land_record.pdf', 'land_certificate.png', 'land_certificate.jpg'],
        'bank_passbook': ['bank_passbook.pdf', 'bank_passbook.jpg', 'bank_passbook.png', 'passbook.pdf'],
        'caste_certificate': ['caste_certificate.pdf', 'caste_cert.pdf', 'caste_certificate.png'],
        'income_certificate': ['income_certificate.pdf', 'income_cert.pdf', 'income_certificate.png'],
        'pan_card': ['pan_card.pdf', 'pan_card.jpg', 'pan_card.png', 'pan.pdf'],
        'voter_id': ['voter_id.pdf', 'voter_id.jpg', 'voter_id.png', 'voter.pdf'],
        'ration_card': ['ration_card.pdf', 'ration_card.jpg', 'ration_card.png'],
        'photo': ['photo.jpg', 'photo.png', 'passport_photo.jpg'],
        'soil_health_card': ['soil_health_card.pdf', 'soil_health.pdf', 'soil_health_card.png'],
        'kisan_credit_card': ['kcc.pdf', 'kisan_credit_card.pdf', 'kcc.png'],
        'seven_twelve': ['seven_twelve.pdf', 'seven_twelve.png', '7_12.pdf', '7_12_extract.pdf'],
        'eight_a': ['eight_a.pdf', 'eight_a.png', '8a.pdf', '8_a.pdf'],
    }
    
    # Alias mapping: Maps human-readable scheme requirement names to internal document types
    # This handles the mismatch between scheme.required_documents and actual filenames
    DOCUMENT_ALIASES = {
        # Aadhaar variants
        'aadhaar': 'aadhaar',
        'aadhar': 'aadhaar',
        'aadhar card': 'aadhaar',
        'aadhaar card': 'aadhaar',
        
        # Bank related
        'bank passbook': 'bank_passbook',
        'bank account details': 'bank_passbook',
        'bank details': 'bank_passbook',
        'bank account linked to aadhaar': 'bank_passbook',
        'bank documents': 'bank_passbook',
        
        # Land records - 7/12 Extract
        '7/12 extract': 'seven_twelve',
        '7/12 land record': 'seven_twelve',
        '7-12 extract': 'seven_twelve',
        'seven twelve': 'seven_twelve',
        'seven_twelve': 'seven_twelve',
        
        # Land records - 8A
        '8-a extract': 'eight_a',
        '8a extract': 'eight_a',
        'eight_a': 'eight_a',
        '8-a': 'eight_a',
        
        # Land records - general
        'land certificate': 'land_certificate',
        'land records': 'land_certificate',
        'land ror': 'land_certificate',
        'land details': 'land_certificate',
        'land ownership proof': 'land_certificate',
        
        # Certificates
        'caste certificate': 'caste_certificate',
        'income certificate': 'income_certificate',
        
        # ID Cards
        'pan card': 'pan_card',
        'voter id': 'voter_id',
        'ration card': 'ration_card',
        
        # Other
        'photo': 'photo',
        'passport photo': 'photo',
        'farmer id': 'aadhaar',  # Often Aadhaar is used as farmer ID
        'farmer/fisher id': 'aadhaar',
        
        # Special schemes
        'sowing certificate': 'sowing_certificate',
        'crop details proof': 'land_certificate',
        'project report': 'project_report',
        'project proposal': 'project_report',
        'pm-kisan registration': 'pm_kisan_registration',
        'fisheries registration certificate': 'fisheries_certificate',
        'training certificate (if applicable)': 'training_certificate',
    }
    
    @classmethod
    def normalize_document_type(cls, doc_type: str) -> str:
        """
        Normalize document type from scheme requirement to internal type.
        Handles case-insensitive matching and aliases.
        """
        if not doc_type:
            return doc_type
            
        # Lowercase for matching
        doc_lower = doc_type.lower().strip()
        
        # Check if already normalized
        if doc_lower in cls.DOCUMENT_TYPES:
            return doc_lower
        
        # Check aliases
        if doc_lower in cls.DOCUMENT_ALIASES:
            return cls.DOCUMENT_ALIASES[doc_lower]
        
        # Default: convert to snake_case
        return doc_lower.replace(' ', '_').replace('-', '_').replace('/', '_')
    
    @classmethod
    def get_client(cls) -> Optional[Client]:
        """Get or create Supabase client"""
        if cls._client is None:
            supabase_url = config('SUPABASE_URL', default='')
            supabase_key = config('SUPABASE_SERVICE_KEY', default='') or config('SUPABASE_KEY', default='')
            
            if supabase_url and supabase_key and create_client:
                cls._client = create_client(supabase_url, supabase_key)
        
        return cls._client
    
    @classmethod
    def get_farmer_bucket_name(cls, farmer_id: str) -> str:
        """Generate bucket name for a farmer"""
        return f"farmer-{farmer_id}"
    
    @classmethod
    def list_farmer_documents(cls, farmer_id: str) -> List[Dict[str, Any]]:
        """
        List all documents in a farmer's bucket.
        
        Returns:
            List of document info dicts with type, filename, and size
        """
        client = cls.get_client()
        if not client:
            print(f"No Supabase client available")
            return []
        
        bucket_name = cls.get_farmer_bucket_name(farmer_id)
        
        try:
            # List all files in the bucket
            files = client.storage.from_(bucket_name).list()
            
            # Debug: show raw response type and first item
            print(f"[DEBUG] Bucket {bucket_name}: got {len(files) if files else 0} items, type={type(files)}")
            if files and len(files) > 0:
                first = files[0]
                print(f"[DEBUG] First item type: {type(first)}, value: {first}")
            
            documents = []
            for file in files:
                if file is None:
                    continue
                
                # Handle both dict-like and object-like responses
                if isinstance(file, dict):
                    name = file.get('name')
                    metadata = file.get('metadata') or {}
                    size = metadata.get('size', 0) if isinstance(metadata, dict) else 0
                    created_at = file.get('created_at')
                    updated_at = file.get('updated_at')
                else:
                    # Object with attributes (newer Supabase Python client)
                    name = getattr(file, 'name', None)
                    metadata = getattr(file, 'metadata', {}) or {}
                    size = metadata.get('size', 0) if isinstance(metadata, dict) else getattr(metadata, 'size', 0) if metadata else 0
                    created_at = getattr(file, 'created_at', None)
                    updated_at = getattr(file, 'updated_at', None)
                
                if not name or name.startswith('.'):
                    # Skip empty names and hidden files like .emptyFolderPlaceholder
                    continue
                
                doc_type = cls._identify_document_type(str(name))
                documents.append({
                    'filename': name,
                    'document_type': doc_type,
                    'size': size,
                    'created_at': created_at,
                    'updated_at': updated_at,
                })
            
            print(f"Found {len(documents)} documents in bucket {bucket_name}: {[d['document_type'] for d in documents]}")
            return documents
        except Exception as e:
            print(f"Error listing documents for farmer {farmer_id}: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    @classmethod
    def _identify_document_type(cls, filename: str) -> str:
        """Identify document type from filename"""
        filename_lower = filename.lower()
        
        # Check against known patterns
        for doc_type, patterns in cls.DOCUMENT_TYPES.items():
            for pattern in patterns:
                if pattern.lower() in filename_lower or filename_lower.startswith(doc_type):
                    return doc_type
        
        # Default: use filename without extension as type
        base_name = filename.rsplit('.', 1)[0] if '.' in filename else filename
        return base_name.lower().replace(' ', '_')
    
    @classmethod
    def get_document_signed_url(cls, farmer_id: str, filename: str, expires_in: int = 3600) -> Optional[str]:
        """
        Get a signed URL for a document.
        """
        client = cls.get_client()
        if not client:
            return None
        
        bucket_name = cls.get_farmer_bucket_name(farmer_id)
        
        try:
            response = client.storage.from_(bucket_name).create_signed_url(
                filename, 
                expires_in
            )
            return response.get('signedURL') or response.get('signedUrl')
        except Exception as e:
            print(f"Error getting signed URL for {filename}: {e}")
            return None
    
    @classmethod
    def fetch_required_documents(cls, farmer_id: str, required_docs: List[str]) -> Dict[str, Any]:
        """
        Fetch required documents from farmer's bucket.
        Matches scheme requirements with available documents using aliases.
        
        Args:
            farmer_id: The farmer's UUID
            required_docs: List of required document types (can be human-readable)
        
        Returns:
            Dict with found documents, missing documents, and signed URLs
        """
        # Get all documents in farmer's bucket
        available_docs = cls.list_farmer_documents(farmer_id)
        
        # Create lookup by normalized document type
        docs_by_type = {}
        for doc in available_docs:
            doc_type = doc['document_type']
            if doc_type not in docs_by_type:
                docs_by_type[doc_type] = doc
        
        print(f"Available doc types in bucket: {list(docs_by_type.keys())}")
        
        # Match required documents (with normalization)
        found_documents = []
        missing_documents = []
        
        for required_doc in required_docs:
            # Normalize the required document type
            normalized_type = cls.normalize_document_type(required_doc)
            
            print(f"Looking for '{required_doc}' -> normalized to '{normalized_type}'")
            
            if normalized_type in docs_by_type:
                doc = docs_by_type[normalized_type]
                # Get signed URL
                signed_url = cls.get_document_signed_url(farmer_id, doc['filename'])
                
                found_documents.append({
                    'document_type': required_doc,  # Keep original name for display
                    'internal_type': normalized_type,
                    'filename': doc['filename'],
                    'signed_url': signed_url,
                    'verified': True,
                    'status': 'attached'
                })
            else:
                missing_documents.append({
                    'document_type': required_doc,
                    'internal_type': normalized_type,
                    'status': 'missing',
                    'message': f'{required_doc} not found in your documents'
                })
        
        print(f"Found: {len(found_documents)}, Missing: {len(missing_documents)}")
        
        return {
            'found': found_documents,
            'missing': missing_documents,
            'all_found': len(missing_documents) == 0,
            'total_required': len(required_docs),
            'total_found': len(found_documents)
        }
    
    @classmethod
    def ensure_farmer_bucket_exists(cls, farmer_id: str) -> bool:
        """
        Ensure a farmer's storage bucket exists.
        Creates it if it doesn't exist.
        """
        client = cls.get_client()
        if not client:
            return False
        
        bucket_name = cls.get_farmer_bucket_name(farmer_id)
        
        try:
            client.storage.get_bucket(bucket_name)
            return True
        except Exception:
            try:
                client.storage.create_bucket(bucket_name, {'public': False})
                return True
            except Exception as e:
                print(f"Error creating bucket for farmer {farmer_id}: {e}")
                return False
