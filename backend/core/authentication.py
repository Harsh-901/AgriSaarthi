"""
Core - Authentication Utilities
Helper functions for JWT token authentication
"""

from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed
from farmers.models import Farmer


class FarmerAuthentication(JWTAuthentication):
    """
    Custom JWT Authentication for Farmers.
    Uses 'farmer_id' claim to fetch Farmer model directly, bypassing standard User lookup.
    """
    
    def get_user(self, validated_token):
        """
        Returns the Farmer instance associated with the token.
        """
        try:
            # Check for farmer_id in token claims
            # Validated token allows dict-style access
            farmer_id = validated_token.get('farmer_id')
            
            if not farmer_id:
                raise InvalidToken('Token contains no farmer_id')

            # Fetch farmer directly using UUID
            farmer = Farmer.objects.get(id=farmer_id)
            
            if not farmer.is_active:
                raise AuthenticationFailed('Farmer account is inactive')

            return farmer

        except Farmer.DoesNotExist:
            raise AuthenticationFailed('Farmer not found', code='user_not_found')
        except Exception as e:
            # Log the error for debugging
            print(f"Authentication Error: {str(e)}")
            raise AuthenticationFailed('Authentication failed', code='authentication_failed')


def get_farmer_from_token(request):
    """
    Helper to get farmer from request.user now that we use custom auth.
    Retained for backward compatibility.
    """
    if request.user and request.user.is_authenticated and isinstance(request.user, Farmer):
        return request.user
    return None

