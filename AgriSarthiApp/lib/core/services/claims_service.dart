import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';

/// Service for managing insurance claims via Django backend
class ClaimsService {
  final ApiService _api = ApiService();

  /// Check weather at farmer's location
  Future<Map<String, dynamic>> checkWeather() async {
    try {
      final response = await _api.post('/api/claims/check-weather/', {});
      debugPrint('ClaimsService: checkWeather: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: checkWeather error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Acknowledge weather alert
  Future<Map<String, dynamic>> acknowledgeAlert(
      String alertId, bool hasDamage) async {
    try {
      final response = await _api.post('/api/claims/acknowledge-alert/', {
        'alert_id': alertId,
        'has_damage': hasDamage,
      });
      debugPrint('ClaimsService: acknowledgeAlert: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: acknowledgeAlert error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create a new insurance claim
  Future<Map<String, dynamic>> createClaim({
    String? alertId,
    String lossType = '',
    double areaAffected = 0,
    String damageDescription = '',
    String surveyNumber = '',
  }) async {
    try {
      final body = <String, dynamic>{
        'loss_type': lossType,
        'area_affected': areaAffected,
        'damage_description': damageDescription,
        'survey_number': surveyNumber,
      };
      if (alertId != null) body['alert_id'] = alertId;

      final response = await _api.post('/api/claims/create/', body);
      debugPrint('ClaimsService: createClaim: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: createClaim error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Upload evidence photo (multipart)
  Future<Map<String, dynamic>> uploadEvidence(
    String claimId,
    File photo, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse(
          '${ApiService.baseUrl}/api/claims/$claimId/upload-evidence/');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer ${_api.accessToken}';

      // Detect content type from file extension
      final ext = p.extension(photo.path).toLowerCase();
      final mimeTypes = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.heic': 'image/heic',
      };
      final mimeType = mimeTypes[ext] ?? 'image/jpeg';
      final parts = mimeType.split('/');

      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photo.path,
        contentType: MediaType(parts[0], parts[1]),
      ));

      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      debugPrint('ClaimsService: uploadEvidence: ${data['success']}');
      return data;
    } catch (e) {
      debugPrint('ClaimsService: uploadEvidence error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Attach documents from vault
  Future<Map<String, dynamic>> attachDocuments(String claimId) async {
    try {
      final response = await _api.post(
        '/api/claims/$claimId/attach-documents/',
        {},
      );
      debugPrint('ClaimsService: attachDocuments: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: attachDocuments error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Submit claim for verification
  Future<Map<String, dynamic>> submitClaim(String claimId) async {
    try {
      final response = await _api.post(
        '/api/claims/$claimId/submit/',
        {},
      );
      debugPrint('ClaimsService: submitClaim: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: submitClaim error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get all claims
  Future<Map<String, dynamic>> getClaims() async {
    try {
      final response = await _api.get('/api/claims/');
      debugPrint('ClaimsService: getClaims: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: getClaims error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get claim detail
  Future<Map<String, dynamic>> getClaimDetail(String claimId) async {
    try {
      final response = await _api.get('/api/claims/$claimId/');
      debugPrint('ClaimsService: getClaimDetail: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: getClaimDetail error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get weather alerts
  Future<Map<String, dynamic>> getWeatherAlerts() async {
    try {
      final response = await _api.get('/api/claims/alerts/');
      debugPrint('ClaimsService: getAlerts: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ClaimsService: getAlerts error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
