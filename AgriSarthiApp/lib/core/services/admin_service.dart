import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Admin service for querying Supabase tables directly
/// Used by admin dashboard, scheme management, and verification screens
class AdminService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ─── Dashboard Stats ───────────────────────────────────────

  /// Get total farmers count
  Future<int> getTotalFarmers() async {
    try {
      final response =
          await _supabase.from('farmers').select('id').count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('AdminService: Error getting farmers count: $e');
      return 0;
    }
  }

  /// Get active schemes count
  Future<int> getActiveSchemesCount() async {
    try {
      final response = await _supabase
          .from('schemes')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('AdminService: Error getting schemes count: $e');
      return 0;
    }
  }

  /// Get pending verifications (applications with status PENDING or UNDER_REVIEW)
  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final response = await _supabase
          .from('applications')
          .select(
              'id, tracking_id, status, created_at, farmer_id, scheme_id, farmers(name, phone), schemes(name)')
          .inFilter('status', ['PENDING', 'UNDER_REVIEW'])
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminService: Error getting pending verifications: $e');
      return [];
    }
  }

  /// Get today's applications
  Future<List<Map<String, dynamic>>> getTodayApplications() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _supabase
          .from('applications')
          .select(
              'id, tracking_id, status, created_at, farmer_id, scheme_id, farmers(name), schemes(name)')
          .gte('created_at', startOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminService: Error getting today applications: $e');
      return [];
    }
  }

  /// Get all dashboard stats at once
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final results = await Future.wait([
        getTotalFarmers(),
        getActiveSchemesCount(),
        getPendingVerifications(),
        getTodayApplications(),
      ]);

      return {
        'totalFarmers': results[0] as int,
        'activeSchemes': results[1] as int,
        'pendingVerifications': results[2] as List<Map<String, dynamic>>,
        'todayApplications': results[3] as List<Map<String, dynamic>>,
      };
    } catch (e) {
      debugPrint('AdminService: Error getting dashboard stats: $e');
      return {
        'totalFarmers': 0,
        'activeSchemes': 0,
        'pendingVerifications': <Map<String, dynamic>>[],
        'todayApplications': <Map<String, dynamic>>[],
      };
    }
  }

  // ─── Scheme Management ─────────────────────────────────────

  /// Get all schemes (including inactive)
  Future<List<Map<String, dynamic>>> getAllSchemes() async {
    try {
      final response = await _supabase
          .from('schemes')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminService: Error getting all schemes: $e');
      return [];
    }
  }

  /// Create a new scheme
  Future<Map<String, dynamic>?> createScheme({
    required String name,
    required String description,
    String? nameHindi,
    String? descriptionHindi,
    required double benefitAmount,
    String? deadline,
    Map<String, dynamic> eligibilityRules = const {},
    List<String> requiredDocuments = const [],
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        'name_hindi': nameHindi,
        'description_hindi': descriptionHindi,
        'benefit_amount': benefitAmount,
        'deadline': deadline,
        'eligibility_rules': eligibilityRules,
        'required_documents': requiredDocuments,
        'is_active': true,
      };

      final response =
          await _supabase.from('schemes').insert(data).select().single();

      debugPrint('AdminService: Scheme created: ${response['id']}');
      return response;
    } catch (e) {
      debugPrint('AdminService: Error creating scheme: $e');
      return null;
    }
  }

  /// Update an existing scheme
  Future<Map<String, dynamic>?> updateScheme(
    String schemeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabase
          .from('schemes')
          .update(updates)
          .eq('id', schemeId)
          .select()
          .single();

      debugPrint('AdminService: Scheme updated: $schemeId');
      return response;
    } catch (e) {
      debugPrint('AdminService: Error updating scheme: $e');
      return null;
    }
  }

  /// Toggle scheme active status
  Future<bool> toggleSchemeStatus(String schemeId, bool isActive) async {
    try {
      await _supabase
          .from('schemes')
          .update({'is_active': isActive}).eq('id', schemeId);
      return true;
    } catch (e) {
      debugPrint('AdminService: Error toggling scheme status: $e');
      return false;
    }
  }

  /// Delete a scheme
  Future<bool> deleteScheme(String schemeId) async {
    try {
      await _supabase.from('schemes').delete().eq('id', schemeId);
      return true;
    } catch (e) {
      debugPrint('AdminService: Error deleting scheme: $e');
      return false;
    }
  }

  // ─── Application Verification ──────────────────────────────

  /// Update application status (approve/reject)
  Future<bool> updateApplicationStatus(
    String applicationId, {
    required String status,
    String? adminNotes,
    String? rejectionReason,
    String? verifiedBy,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'verified_at': DateTime.now().toIso8601String(),
      };
      if (adminNotes != null) updates['admin_notes'] = adminNotes;
      if (rejectionReason != null)
        updates['rejection_reason'] = rejectionReason;
      if (verifiedBy != null) updates['verified_by'] = verifiedBy;

      await _supabase
          .from('applications')
          .update(updates)
          .eq('id', applicationId);

      debugPrint('AdminService: Application $applicationId status -> $status');
      return true;
    } catch (e) {
      debugPrint('AdminService: Error updating application status: $e');
      return false;
    }
  }

  /// Get application with full details for verification
  Future<Map<String, dynamic>?> getApplicationForVerification(
    String applicationId,
  ) async {
    try {
      final response = await _supabase
          .from('applications')
          .select('*, farmers(*), schemes(*)')
          .eq('id', applicationId)
          .single();

      return response;
    } catch (e) {
      debugPrint('AdminService: Error getting application detail: $e');
      return null;
    }
  }
}
