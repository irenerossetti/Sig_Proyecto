"""
Google Cloud Storage service for file uploads.
Handles child photo uploads to GCS bucket.
"""
import os
import uuid
import logging
from datetime import timedelta
from typing import Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# GCS Configuration
GCS_BUCKET_NAME = os.getenv('GCS_BUCKET_NAME', 'geoguard-media')
GCS_PROJECT_ID = os.getenv('GCS_PROJECT_ID', 'geoguard-478318')
USE_GCS = os.getenv('USE_GCS', 'True').lower() == 'true'

# Singleton for storage client
_storage_client = None
_bucket = None


def get_storage_client():
    """Get or create Google Cloud Storage client."""
    global _storage_client, _bucket
    
    if not USE_GCS:
        logger.info("GCS disabled, using local storage")
        return None, None
    
    if _storage_client is None:
        try:
            from google.cloud import storage
            _storage_client = storage.Client(project=GCS_PROJECT_ID)
            _bucket = _storage_client.bucket(GCS_BUCKET_NAME)
            logger.info(f"GCS client initialized for bucket: {GCS_BUCKET_NAME}")
        except Exception as e:
            logger.error(f"Failed to initialize GCS client: {e}")
            return None, None
    
    return _storage_client, _bucket


def upload_child_photo(file, child_id: int, filename: Optional[str] = None) -> str:
    """
    Upload a child's photo to Google Cloud Storage.
    
    Args:
        file: Django UploadedFile or file-like object
        child_id: ID of the child
        filename: Optional custom filename
    
    Returns:
        URL of the uploaded file
    """
    _, bucket = get_storage_client()
    
    # Generate unique filename
    if filename:
        ext = Path(filename).suffix.lower()
    else:
        ext = '.jpg'
    
    # Validate extension
    allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
    if ext not in allowed_extensions:
        ext = '.jpg'
    
    unique_name = f"children/{child_id}/{uuid.uuid4().hex}{ext}"
    
    if bucket:
        # Upload to GCS
        try:
            blob = bucket.blob(unique_name)
            
            # Set content type
            content_type_map = {
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.png': 'image/png',
                '.gif': 'image/gif',
                '.webp': 'image/webp',
            }
            content_type = content_type_map.get(ext, 'image/jpeg')
            
            # Upload file
            if hasattr(file, 'read'):
                blob.upload_from_file(file, content_type=content_type)
            else:
                blob.upload_from_string(file, content_type=content_type)
            
            # With uniform bucket-level access, we don't use make_public()
            # The bucket already has public read access configured
            public_url = f"https://storage.googleapis.com/{GCS_BUCKET_NAME}/{unique_name}"
            
            logger.info(f"Uploaded photo to GCS: {public_url}")
            return public_url
            
        except Exception as e:
            logger.error(f"GCS upload failed: {e}")
            # Fall back to local storage
    
    # Local storage fallback
    from django.conf import settings
    from django.core.files.storage import default_storage
    
    local_path = f"children/{child_id}/{uuid.uuid4().hex}{ext}"
    saved_path = default_storage.save(local_path, file)
    
    # Return full URL for local files
    base_url = os.getenv('BACKEND_URL', 'http://localhost:8000')
    return f"{base_url}{settings.MEDIA_URL}{saved_path}"


def upload_tutor_photo(file, user_id: int, filename: Optional[str] = None) -> str:
    """Upload a tutor profile photo to Google Cloud Storage or local storage."""
    _, bucket = get_storage_client()

    ext = Path(filename).suffix.lower() if filename else '.jpg'
    allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
    if ext not in allowed_extensions:
        ext = '.jpg'

    unique_name = f"tutors/{user_id}/{uuid.uuid4().hex}{ext}"

    if bucket:
        try:
            blob = bucket.blob(unique_name)
            content_type_map = {
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.png': 'image/png',
                '.gif': 'image/gif',
                '.webp': 'image/webp',
            }
            content_type = content_type_map.get(ext, 'image/jpeg')

            if hasattr(file, 'read'):
                blob.upload_from_file(file, content_type=content_type)
            else:
                blob.upload_from_string(file, content_type=content_type)

            return f"https://storage.googleapis.com/{GCS_BUCKET_NAME}/{unique_name}"
        except Exception as e:
            logger.error(f"GCS upload failed for tutor photo: {e}")

    # Local fallback
    from django.conf import settings
    from django.core.files.storage import default_storage
    local_path = f"tutors/{user_id}/{uuid.uuid4().hex}{ext}"
    saved_path = default_storage.save(local_path, file)
    base_url = os.getenv('BACKEND_URL', 'http://localhost:8000')
    return f"{base_url}{settings.MEDIA_URL}{saved_path}"


def delete_tutor_photo(photo_url: str) -> bool:
    """Delete a tutor profile photo from storage (GCS or local)."""
    if not photo_url:
        return True

    _, bucket = get_storage_client()

    if bucket and 'storage.googleapis.com' in photo_url:
        try:
            blob_name = photo_url.split(f'{GCS_BUCKET_NAME}/')[-1]
            bucket.blob(blob_name).delete()
            logger.info(f"Deleted tutor photo from GCS: {blob_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete tutor photo from GCS: {e}")
            return False

    from django.core.files.storage import default_storage
    try:
        from django.conf import settings
        path = photo_url.replace(settings.MEDIA_URL, '')
        if default_storage.exists(path):
            default_storage.delete(path)
            logger.info(f"Deleted local tutor photo: {path}")
        return True
    except Exception as e:
        logger.error(f"Failed to delete local tutor photo: {e}")
        return False


def delete_child_photo(photo_url: str) -> bool:
    """
    Delete a child's photo from storage.
    
    Args:
        photo_url: Full URL of the photo to delete
    
    Returns:
        True if deleted successfully
    """
    if not photo_url:
        return True
    
    _, bucket = get_storage_client()
    
    if bucket and 'storage.googleapis.com' in photo_url:
        try:
            # Extract blob name from URL
            # URL format: https://storage.googleapis.com/bucket-name/path/to/file
            blob_name = photo_url.split(f'{GCS_BUCKET_NAME}/')[-1]
            blob = bucket.blob(blob_name)
            blob.delete()
            logger.info(f"Deleted photo from GCS: {blob_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete from GCS: {e}")
            return False
    else:
        # Local file
        from django.core.files.storage import default_storage
        try:
            # Extract path from URL
            from django.conf import settings
            path = photo_url.replace(settings.MEDIA_URL, '')
            if default_storage.exists(path):
                default_storage.delete(path)
                logger.info(f"Deleted local photo: {path}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete local file: {e}")
            return False


def get_signed_url(blob_name: str, expiration_minutes: int = 60) -> Optional[str]:
    """
    Generate a signed URL for private access.
    
    Args:
        blob_name: Name of the blob in GCS
        expiration_minutes: URL expiration time in minutes
    
    Returns:
        Signed URL or None
    """
    _, bucket = get_storage_client()
    
    if not bucket:
        return None
    
    try:
        blob = bucket.blob(blob_name)
        url = blob.generate_signed_url(
            expiration=timedelta(minutes=expiration_minutes),
            method='GET',
        )
        return url
    except Exception as e:
        logger.error(f"Failed to generate signed URL: {e}")
        return None
