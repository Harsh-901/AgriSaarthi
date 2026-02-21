
import os
import django
import sys
from django.db import connection

# Setup Django environment
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

if __name__ == "__main__":
    try:
        from django.conf import settings
        if not settings.configured:
            django.setup()
            
        print("Updating documents_document_type_check constraint...")
        
        with connection.cursor() as cursor:
            # Drop existing constraint
            cursor.execute("ALTER TABLE documents DROP CONSTRAINT IF EXISTS documents_document_type_check;")
            
            # Add new constraint
            # Note: We include both original values (from migration) and new values
            allowed_types = [
                'aadhaar', 'pan_card', 'land_certificate', 
                'seven_twelve', 'eight_a', 'bank_passbook', 
                'income_certificate', 'caste_certificate', 'other'
            ]
            
            # Helper to format array string for SQL
            # ARRAY['a', 'b']::text[]
            array_elements = ", ".join([f"'{t}'::text" for t in allowed_types])
            sql = f"""
                ALTER TABLE documents ADD CONSTRAINT documents_document_type_check 
                CHECK (document_type::text = ANY (ARRAY[{array_elements}]::text[]));
            """
            
            cursor.execute(sql)
            
        print("Constraint updated successfully.")
            
    except Exception as e:
        print(f"Error: {e}")
