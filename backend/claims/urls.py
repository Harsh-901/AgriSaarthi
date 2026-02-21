"""
Claims App - URL Configuration
"""

from django.urls import path
from .views import (
    CheckWeatherView, AcknowledgeAlertView, CreateClaimView,
    UploadEvidenceView, AttachDocumentsView, SubmitClaimView,
    ClaimListView, ClaimDetailView, WeatherAlertListView
)

urlpatterns = [
    # Weather & Alerts
    path('check-weather/', CheckWeatherView.as_view(), name='check-weather'),
    path('acknowledge-alert/', AcknowledgeAlertView.as_view(), name='acknowledge-alert'),
    path('alerts/', WeatherAlertListView.as_view(), name='weather-alerts'),

    # Claim CRUD
    path('', ClaimListView.as_view(), name='claim-list'),
    path('create/', CreateClaimView.as_view(), name='create-claim'),

    # Claim-specific actions
    path('<uuid:claim_id>/', ClaimDetailView.as_view(), name='claim-detail'),
    path('<uuid:claim_id>/upload-evidence/', UploadEvidenceView.as_view(), name='upload-evidence'),
    path('<uuid:claim_id>/attach-documents/', AttachDocumentsView.as_view(), name='attach-documents'),
    path('<uuid:claim_id>/submit/', SubmitClaimView.as_view(), name='submit-claim'),
]
