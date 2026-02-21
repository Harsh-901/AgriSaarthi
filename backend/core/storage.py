"""
Core - Supabase Storage Service
Handles bucket creation and document storage for farmers.
Each farmer gets their own bucket named 'farmer-{farmer_id}'.
"""

import logging
from django.conf import settings

logger = logging.getLogger(__name__)

# Lazy initialization of Supabase client
_supabase_client = None


def get_supabase_client():
    """
    Get or create Supabase client instance.
    Uses service_role key (preferred) for admin operations like bucket creation,
    falls back to anon key for regular operations.
    """
    global _supabase_client
    
    if _supabase_client is None:
        try:
            from supabase import create_client
            
            supabase_url = settings.SUPABASE_URL
            # Prefer service_role key for admin operations (bucket creation)
            supabase_key = getattr(settings, 'SUPABASE_SERVICE_KEY', '') or settings.SUPABASE_KEY
            
            if not supabase_url or not supabase_key:
                logger.warning("Supabase URL or Key not configured")
                return None
            
            _supabase_client = create_client(supabase_url, supabase_key)
            logger.info("Supabase client initialized successfully")
        except ImportError:
            logger.error("supabase package not installed. Run: pip install supabase")
            return None
        except Exception as e:
            logger.error(f"Failed to initialize Supabase client: {e}")
            return None
    
    return _supabase_client


def get_bucket_name(farmer_id: str) -> str:
    """
    Generate bucket name for a farmer.
    Format: farmer-{farmer_id}
    """
    return f"farmer-{farmer_id}"


def create_farmer_bucket(farmer_id: str) -> bool:
    """
    Create a storage bucket for a farmer.
    
    Args:
        farmer_id: UUID of the farmer
        
    Returns:
        True if bucket created successfully or already exists, False on error
    """
    client = get_supabase_client()
    if not client:
        logger.error("Cannot create bucket: Supabase client not available")
        return False
    
    bucket_name = get_bucket_name(farmer_id)
    
    try:
        # Create the bucket (private by default)
        client.storage.create_bucket(
            bucket_name,
            options={
                "public": False,
                "file_size_limit": 10485760,  # 10MB limit per file
                "allowed_mime_types": [
                    "image/jpeg",
                    "image/png", 
                    "image/webp",
                    "application/pdf"
                ]
            }
        )
        logger.info(f"Created storage bucket: {bucket_name}")
        return True
        
    except Exception as e:
        error_msg = str(e)
        # Bucket might already exist - that's okay
        if "already exists" in error_msg.lower() or "duplicate" in error_msg.lower():
            logger.info(f"Bucket already exists: {bucket_name}")
            return True
        
        logger.error(f"Failed to create bucket {bucket_name}: {e}")
        return False


def upload_document(farmer_id: str, file, filename: str) -> str:
    """
    Upload a document to farmer's bucket.
    
    Args:
        farmer_id: UUID of the farmer
        file: File object to upload
        filename: Name for the file in storage
        
    Returns:
        Public URL of the uploaded file, or empty string on error
    """
    client = get_supabase_client()
    if not client:
        logger.error("Cannot upload: Supabase client not available")
        return ""
    
    bucket_name = get_bucket_name(farmer_id)
    
    try:
        # Read file content
        file_content = file.read()
        
        # Get content type - prefer file attribute, but infer from extension as fallback
        import mimetypes
        content_type = getattr(file, 'content_type', None)
        if not content_type or content_type == 'application/octet-stream':
            guessed_type, _ = mimetypes.guess_type(filename)
            if not guessed_type:
                # Try from original file name
                guessed_type, _ = mimetypes.guess_type(getattr(file, 'name', ''))
            content_type = guessed_type or 'image/jpeg'  # Safe default for evidence photos
        
        # Upload to bucket
        response = client.storage.from_(bucket_name).upload(
            path=filename,
            file=file_content,
            file_options={"content-type": content_type}
        )
        
        # Get signed URL (valid for 1 year)
        url_response = client.storage.from_(bucket_name).create_signed_url(
            path=filename,
            expires_in=31536000  # 1 year in seconds
        )
        
        signed_url = url_response.get('signedURL', '')
        logger.info(f"Uploaded document to {bucket_name}/{filename}")
        return signed_url
        
    except Exception as e:
        logger.error(f"Failed to upload document to {bucket_name}/{filename}: {e}")
        return ""


def get_document_url(farmer_id: str, file_path: str, expires_in: int = 3600) -> str:
    """
    Get a signed URL for accessing a document.
    
    Args:
        farmer_id: UUID of the farmer
        file_path: Path to file in bucket
        expires_in: URL validity in seconds (default: 1 hour)
        
    Returns:
        Signed URL or empty string on error
    """
    client = get_supabase_client()
    if not client:
        return ""
    
    bucket_name = get_bucket_name(farmer_id)
    
    try:
        response = client.storage.from_(bucket_name).create_signed_url(
            path=file_path,
            expires_in=expires_in
        )
        return response.get('signedURL', '')
        
    except Exception as e:
        logger.error(f"Failed to get URL for {bucket_name}/{file_path}: {e}")
        return ""


def delete_document(farmer_id: str, file_path: str) -> bool:
    """
    Delete a document from farmer's bucket.
    
    Args:
        farmer_id: UUID of the farmer
        file_path: Path to file in bucket
        
    Returns:
        True if deleted successfully, False on error
    """
    client = get_supabase_client()
    if not client:
        return False
    
    bucket_name = get_bucket_name(farmer_id)
    
    try:
        client.storage.from_(bucket_name).remove([file_path])
        logger.info(f"Deleted document from {bucket_name}/{file_path}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to delete {bucket_name}/{file_path}: {e}")
        return False


def list_documents(farmer_id: str, path: str = "") -> list:
    """
    List all documents in farmer's bucket.
    
    Args:
        farmer_id: UUID of the farmer
        path: Optional subfolder path
        
    Returns:
        List of file objects in the bucket
    """
    client = get_supabase_client()
    if not client:
        return []
    
    bucket_name = get_bucket_name(farmer_id)
    
    try:
        response = client.storage.from_(bucket_name).list(path=path)
        return response
        
    except Exception as e:
        logger.error(f"Failed to list documents in {bucket_name}: {e}")
        return []
