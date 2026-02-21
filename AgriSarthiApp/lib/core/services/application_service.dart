import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Application model matching Django Application model
class ApplicationModel {
  final String id;
  final String schemeName;
  final String? schemeNameHindi;
  final String status;
  final String statusDisplay;
  final String? trackingId;
  final double? benefitAmount;
  final bool isConfirmed;
  final String? rejectionReason;
  final String? governmentReference;
  final List<dynamic> missingDocuments;
  final List<dynamic> attachedDocuments;
  final Map<String, dynamic>? autoFilledData;
  final String createdAt;
  final String? confirmedAt;
  final String? submittedAt;

  ApplicationModel({
    required this.id,
    required this.schemeName,
    this.schemeNameHindi,
    required this.status,
    required this.statusDisplay,
    this.trackingId,
    this.benefitAmount,
    this.isConfirmed = false,
    this.rejectionReason,
    this.governmentReference,
    this.missingDocuments = const [],
    this.attachedDocuments = const [],
    this.autoFilledData,
    required this.createdAt,
    this.confirmedAt,
    this.submittedAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id']?.toString() ?? '',
      schemeName: json['scheme_name'] ?? 'Unknown Scheme',
      schemeNameHindi: json['scheme_name_hindi'],
      status: json['status'] ?? 'DRAFT',
      statusDisplay: json['status_display'] ?? json['status'] ?? 'Draft',
      trackingId: json['tracking_id'],
      benefitAmount: json['benefit_amount'] != null
          ? double.tryParse(json['benefit_amount'].toString())
          : null,
      isConfirmed: json['is_confirmed'] ?? false,
      rejectionReason: json['rejection_reason'],
      governmentReference: json['government_reference'],
      missingDocuments: json['missing_documents'] ?? [],
      attachedDocuments: json['attached_documents'] ?? [],
      autoFilledData: json['auto_filled_data'] is Map
          ? Map<String, dynamic>.from(json['auto_filled_data'])
          : null,
      createdAt: json['created_at'] ?? '',
      confirmedAt: json['confirmed_at'],
      submittedAt: json['submitted_at'],
    );
  }

  /// Get color-friendly status
  bool get isPending => status == 'PENDING' || status == 'PENDING_CONFIRMATION';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isUnderReview => status == 'UNDER_REVIEW';
  bool get isDraft => status == 'DRAFT';
  bool get isIncomplete => status == 'INCOMPLETE';
  bool get canConfirm => status == 'PENDING_CONFIRMATION';
}

/// Status counts from the API
class ApplicationStatusCounts {
  final int total;
  final int draft;
  final int pendingConfirmation;
  final int pending;
  final int underReview;
  final int approved;
  final int rejected;
  final int incomplete;

  ApplicationStatusCounts({
    this.total = 0,
    this.draft = 0,
    this.pendingConfirmation = 0,
    this.pending = 0,
    this.underReview = 0,
    this.approved = 0,
    this.rejected = 0,
    this.incomplete = 0,
  });

  factory ApplicationStatusCounts.fromJson(Map<String, dynamic> json) {
    return ApplicationStatusCounts(
      total: json['total'] ?? 0,
      draft: json['draft'] ?? 0,
      pendingConfirmation: json['pending_confirmation'] ?? 0,
      pending: json['pending'] ?? 0,
      underReview: json['under_review'] ?? 0,
      approved: json['approved'] ?? 0,
      rejected: json['rejected'] ?? 0,
      incomplete: json['incomplete'] ?? 0,
    );
  }
}

/// Service for managing applications via Django backend
class ApplicationService {
  final ApiService _api = ApiService();

  /// Get all applications for the authenticated farmer
  Future<Map<String, dynamic>> getApplications() async {
    try {
      final response = await _api.get('/api/applications/');
      debugPrint(
          'ApplicationService: getApplications response: ${response['success']}');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final applications = (data['applications'] as List? ?? [])
            .map((json) => ApplicationModel.fromJson(json))
            .toList();
        final statusCounts = data['status_counts'] != null
            ? ApplicationStatusCounts.fromJson(data['status_counts'])
            : ApplicationStatusCounts();

        return {
          'success': true,
          'applications': applications,
          'statusCounts': statusCounts,
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch applications',
      };
    } catch (e) {
      debugPrint('ApplicationService: Error getting applications: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Generate a pre-filled application form for a scheme
  Future<Map<String, dynamic>> generateForm(String schemeId) async {
    try {
      final response = await _api.post('/api/applications/generate-form/', {
        'scheme_id': schemeId,
      });
      debugPrint(
          'ApplicationService: generateForm response: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error generating form: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Confirm and submit an application
  Future<Map<String, dynamic>> confirmApplication(String applicationId) async {
    try {
      final response = await _api.post('/api/applications/confirm/', {
        'application_id': applicationId,
      });
      debugPrint(
          'ApplicationService: confirmApplication response: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error confirming application: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Quick apply to a scheme (generate + confirm in one step)
  Future<Map<String, dynamic>> applyToScheme(String schemeId) async {
    try {
      final response = await _api.post('/api/applications/apply/', {
        'scheme_id': schemeId,
      });
      debugPrint(
          'ApplicationService: applyToScheme response: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error applying to scheme: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get application detail
  Future<Map<String, dynamic>> getApplicationDetail(
      String applicationId) async {
    try {
      final response = await _api.get('/api/applications/$applicationId/');
      debugPrint(
          'ApplicationService: getDetail response: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error getting detail: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Track an application
  Future<Map<String, dynamic>> trackApplication(String applicationId) async {
    try {
      final response =
          await _api.get('/api/applications/$applicationId/track/');
      debugPrint(
          'ApplicationService: trackApplication response: ${response['success']}');
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error tracking application: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Refresh documents on an application
  Future<Map<String, dynamic>> refreshDocuments(String applicationId) async {
    try {
      final response = await _api.post(
        '/api/applications/$applicationId/refresh-documents/',
        {},
      );
      return response;
    } catch (e) {
      debugPrint('ApplicationService: Error refreshing docs: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
