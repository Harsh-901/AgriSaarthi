"""
Documents App - URL Configuration
"""

from django.urls import path
from .views import DocumentListView, DocumentDetailView
from .views import DocumentListView, DocumentDetailView, DocumentByFarmerView


urlpatterns = [
    path('', DocumentListView.as_view(), name='document-list'),
    path('farmer/<uuid:farmer_id>/', DocumentByFarmerView.as_view(), name='document-by-farmer'),
    path('document/<uuid:document_id>/', DocumentDetailView.as_view(), name='document-detail'),
]
