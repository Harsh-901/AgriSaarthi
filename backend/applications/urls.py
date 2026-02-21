"""
Applications App - URL Configuration
"""

from django.urls import path
from .views import (
    ApplicationListView, ApplySchemeView, ApplicationPreviewView,
    ApplicationStatusView, ApplicationDetailView,
    GenerateFormView, ConfirmApplicationView, TrackApplicationView,
    RefreshDocumentsView
)

urlpatterns = [
    # List all applications
    path('', ApplicationListView.as_view(), name='application-list'),
    
    # New enhanced endpoints
    path('generate-form/', GenerateFormView.as_view(), name='generate-form'),
    path('confirm/', ConfirmApplicationView.as_view(), name='confirm-application'),
    
    # Legacy quick-apply
    path('apply/', ApplySchemeView.as_view(), name='apply-scheme'),
    path('preview/', ApplicationPreviewView.as_view(), name='application-preview'),
    
    # Application-specific endpoints
    path('<uuid:application_id>/', ApplicationDetailView.as_view(), name='application-detail'),
    path('<uuid:application_id>/status/', ApplicationStatusView.as_view(), name='application-status'),
    path('<uuid:application_id>/track/', TrackApplicationView.as_view(), name='application-track'),
    path('<uuid:application_id>/refresh-documents/', RefreshDocumentsView.as_view(), name='refresh-documents'),
]
