"""
Claims App - Weather Service
Integrates with WeatherAPI.com to detect extreme weather conditions
and generate alerts for farmers.
"""

import logging
import requests
from django.conf import settings
from decimal import Decimal

logger = logging.getLogger(__name__)

# WeatherAPI.com configuration
WEATHER_API_BASE = 'http://api.weatherapi.com/v1'
WEATHER_API_KEY = None


def get_api_key():
    global WEATHER_API_KEY
    if WEATHER_API_KEY is None:
        WEATHER_API_KEY = getattr(settings, 'WEATHER_API_KEY', '')
    return WEATHER_API_KEY


# ─── Danger Thresholds ───────────────────────────────────────────────
THRESHOLDS = {
    'heavy_rain': {
        'precip_mm': 50.0,       # >50mm precipitation
        'humidity_min': 85,       # very high humidity
    },
    'flood': {
        'precip_mm': 100.0,      # >100mm extreme precipitation
    },
    'drought': {
        'temp_c_min': 40.0,      # temperature > 40°C
        'humidity_max': 20,       # very low humidity
        'precip_mm_max': 2.0,    # almost no rain
    },
    'hailstorm': {
        'condition_codes': [1237, 1261, 1264],  # Ice pellets, sleet
    },
    'cyclone': {
        'wind_kph': 90.0,        # wind > 90 km/h
    },
    'frost': {
        'temp_c_max': 2.0,       # temperature < 2°C
    },
}


class WeatherService:
    """
    Service to check weather conditions and detect calamities
    using WeatherAPI.com
    """

    @classmethod
    def get_current_weather(cls, location_query):
        """
        Get current weather for a location.

        Args:
            location_query: City name, lat/lon, or any valid WeatherAPI query
                           e.g., "Pune", "18.52,73.85", "Mumbai"

        Returns:
            dict with weather data or None on error
        """
        api_key = get_api_key()
        if not api_key:
            logger.error("WEATHER_API_KEY not configured")
            return None

        try:
            url = f"{WEATHER_API_BASE}/current.json"
            params = {
                'key': api_key,
                'q': location_query,
                'aqi': 'no',
            }
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Weather API request failed: {e}")
            return None

    @classmethod
    def get_forecast_with_alerts(cls, location_query, days=1):
        """
        Get forecast with government weather alerts.

        Args:
            location_query: Location string
            days: Number of days (1-14)

        Returns:
            dict with forecast and alerts data
        """
        api_key = get_api_key()
        if not api_key:
            logger.error("WEATHER_API_KEY not configured")
            return None

        try:
            url = f"{WEATHER_API_BASE}/forecast.json"
            params = {
                'key': api_key,
                'q': location_query,
                'days': days,
                'alerts': 'yes',
                'aqi': 'no',
            }
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Weather Forecast API request failed: {e}")
            return None

    @classmethod
    def analyze_weather(cls, weather_data):
        """
        Analyze weather data against danger thresholds.

        Args:
            weather_data: Raw response from WeatherAPI.com

        Returns:
            dict with analysis result:
            {
                'alert': True/False,
                'alert_type': 'heavy_rain',
                'severity': 'high',
                'details': { ... },
                'current': { temp, humidity, precip, wind, condition }
            }
        """
        if not weather_data or 'current' not in weather_data:
            return {'alert': False, 'reason': 'No weather data available'}

        current = weather_data['current']

        temp_c = current.get('temp_c', 25)
        humidity = current.get('humidity', 50)
        precip_mm = current.get('precip_mm', 0)
        wind_kph = current.get('wind_kph', 0)
        condition_code = current.get('condition', {}).get('code', 1000)
        condition_text = current.get('condition', {}).get('text', 'Clear')

        current_summary = {
            'temp_c': temp_c,
            'humidity': humidity,
            'precip_mm': precip_mm,
            'wind_kph': wind_kph,
            'condition_code': condition_code,
            'condition_text': condition_text,
        }

        # Check each threshold
        alerts_detected = []

        # --- Heavy Rain ---
        if precip_mm >= THRESHOLDS['heavy_rain']['precip_mm']:
            alerts_detected.append({
                'type': 'heavy_rain',
                'severity': 'critical' if precip_mm >= 100 else 'high',
                'detail': f'Heavy rainfall: {precip_mm}mm precipitation',
            })

        # --- Flood (extreme rain) ---
        if precip_mm >= THRESHOLDS['flood']['precip_mm']:
            alerts_detected.append({
                'type': 'flood',
                'severity': 'critical',
                'detail': f'Flood risk: {precip_mm}mm extreme precipitation',
            })

        # --- Drought ---
        if (temp_c >= THRESHOLDS['drought']['temp_c_min'] and
                humidity <= THRESHOLDS['drought']['humidity_max'] and
                precip_mm <= THRESHOLDS['drought']['precip_mm_max']):
            alerts_detected.append({
                'type': 'drought',
                'severity': 'high',
                'detail': f'Drought conditions: {temp_c}°C, {humidity}% humidity, {precip_mm}mm rain',
            })

        # --- Hailstorm ---
        if condition_code in THRESHOLDS['hailstorm']['condition_codes']:
            alerts_detected.append({
                'type': 'hailstorm',
                'severity': 'high',
                'detail': f'Hailstorm detected: {condition_text}',
            })

        # --- Cyclone ---
        if wind_kph >= THRESHOLDS['cyclone']['wind_kph']:
            alerts_detected.append({
                'type': 'cyclone',
                'severity': 'critical',
                'detail': f'Cyclonic winds: {wind_kph} km/h',
            })

        # --- Frost ---
        if temp_c <= THRESHOLDS['frost']['temp_c_max']:
            alerts_detected.append({
                'type': 'frost',
                'severity': 'moderate' if temp_c > 0 else 'high',
                'detail': f'Frost conditions: {temp_c}°C',
            })

        if alerts_detected:
            # Return the most severe alert
            severity_order = {'critical': 0, 'high': 1, 'moderate': 2, 'low': 3}
            alerts_detected.sort(key=lambda a: severity_order.get(a['severity'], 99))
            top_alert = alerts_detected[0]

            return {
                'alert': True,
                'alert_type': top_alert['type'],
                'severity': top_alert['severity'],
                'details': top_alert['detail'],
                'all_alerts': alerts_detected,
                'current': current_summary,
            }

        return {
            'alert': False,
            'current': current_summary,
            'message': 'Weather conditions are normal. No extreme events detected.',
        }

    @classmethod
    def check_farmer_location(cls, farmer):
        """
        Check weather at farmer's location using their profile data.

        Args:
            farmer: Farmer model instance

        Returns:
            Analysis result dict
        """
        # Build location query from farmer profile
        location_parts = []
        if farmer.village:
            location_parts.append(farmer.village)
        if farmer.district:
            location_parts.append(farmer.district)
        if farmer.state:
            location_parts.append(farmer.state)

        if not location_parts:
            return {
                'alert': False,
                'error': 'Farmer location not available. Please update your profile.',
            }

        # Use the most specific location available
        location_query = ', '.join(location_parts)

        # Get weather data with alerts
        weather_data = cls.get_forecast_with_alerts(location_query)
        if not weather_data:
            return {
                'alert': False,
                'error': f'Could not fetch weather for: {location_query}',
            }

        # Analyze against thresholds
        analysis = cls.analyze_weather(weather_data)
        analysis['location'] = location_query
        analysis['location_info'] = weather_data.get('location', {})

        # Include any government weather alerts
        api_alerts = weather_data.get('alerts', {}).get('alert', [])
        if api_alerts:
            analysis['government_alerts'] = api_alerts
            # If gov alerts exist but no threshold alert, mark as potential
            if not analysis.get('alert'):
                analysis['alert'] = True
                analysis['alert_type'] = 'heavy_rain'  # Default type
                analysis['severity'] = 'moderate'
                analysis['details'] = api_alerts[0].get('headline', 'Government weather alert issued')

        return analysis
