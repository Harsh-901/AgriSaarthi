
import os
import django
import sys

# Setup Django environment
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'applications.settings') # Assuming 'applications' or similar is the main app
# Wait, I need to check where settings.py is. list_dir showed 'applications' folder.
# 'manage.py' is in root.
# Let's check manage.py to see settings module.

if __name__ == "__main__":
    from django.core.management import execute_from_command_line
    # This is just to setup.
    
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'applications.settings')
    try:
        from django.conf import settings
        if not settings.configured:
            django.setup()
            
        from documents.models import Document
        
        print("Existing Document Types:")
        types = Document.objects.values_list('document_type', flat=True).distinct()
        for t in types:
            print(f"- {t}")
            
    except Exception as e:
        print(f"Error: {e}")
