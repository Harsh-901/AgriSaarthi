import os
import django
import re

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from farmers.models import Farmer

def find_duplicates():
    farmers = Farmer.objects.all()
    profiles = {}
    
    print("-" * 100)
    print(f"{'ID':<40} | {'Phone':<20} | {'Name'}")
    print("-" * 100)
    for f in farmers:
        print(f"{str(f.id):<40} | {f.phone:<20} | {f.name}")
        
        # Normalize for comparison
        phone = re.sub(r'[\s\-\(\)\+]', '', f.phone)
        if phone.startswith('91') and len(phone) == 12:
            norm_phone = phone[2:]
        elif len(phone) > 10:
            norm_phone = phone[-10:]
        else:
            norm_phone = phone
            
        if norm_phone not in profiles:
            profiles[norm_phone] = []
        profiles[norm_phone].append(f)
    
    print("\n" + "=" * 100)
    print("DUPLICATE ANALYSIS")
    print("=" * 100)
    found_duplicates = False
    for phone, list_f in profiles.items():
        if len(list_f) > 1:
            found_duplicates = True
            print(f"Phone Group: {phone} has {len(list_f)} records:")
            for f in list_f:
                print(f"  - ID: {f.id} (Bucket: farmer-{f.id}) phone: {f.phone}")
    
    if not found_duplicates:
        print("No duplicates found based on normalized 10-digit phone numbers.")
    print("=" * 100)

if __name__ == "__main__":
    find_duplicates()
