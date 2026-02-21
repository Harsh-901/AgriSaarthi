
import requests
import json
import sys

BASE_URL = "http://127.0.0.1:8000"

def test_registration_flow():
    print("Starting Registration Flow Verification...")
    
    # 1. Request OTP (Login)
    import random
    phone = f"9{random.randint(100000000, 999999999)}"
    print(f"\n1. Requesting OTP for {phone}...")
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login/", json={"phone": phone})
        if login_response.status_code != 200:
            print(f"FAILED: Login request failed. Status: {login_response.status_code}")
            print(login_response.text)
            return

        login_data = login_response.json()
        if not login_data['success']:
            print("FAILED: Login reported failure.")
            print(login_data)
            return
            
        otp = login_data['data'].get('demo_otp')
        if not otp:
            print("FAILED: Could not retrieve demo_otp from response.")
            print(login_data)
            return
            
        print(f"SUCCESS: OTP Received: {otp}")

    except Exception as e:
        print(f"EXCEPTION during Login: {e}")
        return

    # 2. Register
    print(f"\n2. Registering Farmer...")
    payload = {
        "phone": phone,
        "otp": otp,
        "name": "Verif Farmer",
        "state": "Maharashtra",
        "district": "Nasik",
        "village": "Deolali",
        "land_size": 5.5,
        "crop_type": "Grapes, Onion",
        "language": "marathi",
        "documents": [
            {"document_type": "aadhaar", "document_url": "https://example.com/aadhaar.jpg"},
            {"document_type": "seven_twelve", "document_url": "https://example.com/712.pdf"}
        ]
    }
    
    try:
        reg_response = requests.post(f"{BASE_URL}/api/auth/register/", json=payload)
        
        print(f"Registration Status: {reg_response.status_code}")
        
        if reg_response.status_code != 200 and reg_response.status_code != 201:
            print("Response Text (Error) saved to error.html")
            with open("error.html", "w", encoding="utf-8") as f:
                f.write(reg_response.text)

        print("Response Body:")
        try:
            print(json.dumps(reg_response.json(), indent=2))
        except:
            print("Could not parse JSON response.")
        
        if reg_response.status_code == 201:
            print("\nSUCCESS: Registration Verified!")
        elif reg_response.status_code == 400 and "Already registered" in reg_response.text:
            print("\nINFO: User already registered, which is valid if run multiple times.")
        else:
            print("\nFAILED: Registration failed.")

    except Exception as e:
        print(f"EXCEPTION during Registration: {e}")

if __name__ == "__main__":
    test_registration_flow()
