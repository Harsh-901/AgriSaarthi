"""
Test script to debug Supabase bucket creation.
Run: python test_bucket_creation.py
"""

import os
import sys

# Add project to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Set up Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

import django
django.setup()

from django.conf import settings
from core.storage import create_farmer_bucket, get_supabase_client

def test_connection():
    print("=" * 50)
    print("SUPABASE CONNECTION TEST")
    print("=" * 50)
    
    print(f"\nSUPABASE_URL: {settings.SUPABASE_URL[:50]}..." if settings.SUPABASE_URL else "NOT SET")
    print(f"SUPABASE_KEY: {settings.SUPABASE_KEY[:20]}..." if settings.SUPABASE_KEY else "NOT SET")
    
    client = get_supabase_client()
    if not client:
        print("\n❌ ERROR: Could not create Supabase client!")
        return False
    
    print("\n✅ Supabase client created successfully")
    return True


def test_bucket_creation():
    print("\n" + "=" * 50)
    print("BUCKET CREATION TEST")
    print("=" * 50)
    
    test_farmer_id = "test-debug-12345"
    bucket_name = f"farmer-{test_farmer_id}"
    
    print(f"\nAttempting to create bucket: {bucket_name}")
    
    try:
        client = get_supabase_client()
        if not client:
            print("❌ No client available")
            return
        
        # Try to create bucket directly to see the error
        response = client.storage.create_bucket(
            bucket_name,
            options={
                "public": False,
                "file_size_limit": 10485760,
            }
        )
        print(f"\n✅ Bucket created successfully!")
        print(f"Response: {response}")
        
        # List buckets to confirm
        buckets = client.storage.list_buckets()
        print(f"\nExisting buckets:")
        for bucket in buckets:
            print(f"  - {bucket.name}")
            
    except Exception as e:
        print(f"\n❌ ERROR creating bucket: {type(e).__name__}")
        print(f"   Message: {str(e)}")
        
        if "row-level security" in str(e).lower() or "policy" in str(e).lower():
            print("\n⚠️  This looks like a PERMISSIONS issue!")
            print("   You need to use the SERVICE_ROLE key instead of ANON key")
            print("   Or configure RLS policies for storage")


def main():
    if not test_connection():
        return
    
    test_bucket_creation()
    
    print("\n" + "=" * 50)
    print("RECOMMENDATIONS")
    print("=" * 50)
    print("""
1. If you see a permissions error, you need to:
   - Add SUPABASE_SERVICE_KEY to your .env file
   - Use the service_role key from Supabase dashboard > Settings > API
   
2. The anon key can't create buckets by default.
   Service role key has admin privileges.
""")


if __name__ == "__main__":
    main()
