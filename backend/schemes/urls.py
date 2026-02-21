"""
Schemes App - URL Configuration
"""

from django.urls import path
from .views import EligibleSchemesView, SchemeDetailView, AllSchemesView, CheckEligibilityView

urlpatterns = [
    path('', AllSchemesView.as_view(), name='scheme-list'),
    path('eligible/', EligibleSchemesView.as_view(), name='eligible-schemes'),
    path('<uuid:scheme_id>/', SchemeDetailView.as_view(), name='scheme-detail'),
    path('<uuid:scheme_id>/check-eligibility/', CheckEligibilityView.as_view(), name='check-eligibility'),
]
