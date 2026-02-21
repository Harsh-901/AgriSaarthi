"""
Auth App - URL Configuration
"""

from django.urls import path
from .views import LoginView, VerifyOTPView, RefreshTokenView, LogoutView, RegisterView

urlpatterns = [
    path('login/', LoginView.as_view(), name='auth-login'),
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('verify/', VerifyOTPView.as_view(), name='auth-verify'),
    path('refresh/', RefreshTokenView.as_view(), name='auth-refresh'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
]
