"""
Voice App - URL Configuration
"""

from django.urls import path
from .views import VoiceProcessView, VoiceConfirmView, VoiceTTSView

urlpatterns = [
    path('process/', VoiceProcessView.as_view(), name='voice-process'),
    path('confirm/', VoiceConfirmView.as_view(), name='voice-confirm'),
    path('tts/', VoiceTTSView.as_view(), name='voice-tts'),
]
