import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class FarmerProfile {
  final String? id;
  final String phoneNumber;
  final String fullName;
  final String state;
  final String district;
  final String village;
  final double landSize;
  final String primaryCrop;
  final String preferredLanguage;

  FarmerProfile({
    this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.state,
    required this.district,
    required this.village,
    required this.landSize,
    required this.primaryCrop,
    required this.preferredLanguage,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phoneNumber,
      'name': fullName,
      'state': state,
      'district': district,
      'village': village,
      'land_size': landSize,
      'crop_type': primaryCrop,
      'language': preferredLanguage,
    };
  }

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    return FarmerProfile(
      id: json['id']?.toString(),
      phoneNumber: json['phone'] ?? '',
      fullName: json['name'] ?? '',
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      village: json['village'] ?? '',
      landSize: (json['land_size'] ?? 0).toDouble(),
      primaryCrop: json['crop_type'] ?? '',
      preferredLanguage: json['language'] ?? '',
    );
  }

  bool get isComplete =>
      fullName.isNotEmpty && state.isNotEmpty && village.isNotEmpty;
}

/// FarmerService that uses Supabase directly for profile management
/// Uses phone number as the unique identifier
class FarmerService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Get 10-digit phone number from Supabase user
  String? _getPhoneFromUser() {
    final user = _supabase.auth.currentUser;
    if (user == null || user.phone == null) return null;

    String phone = user.phone!.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    // Standardize Indian numbers: 10 digits
    if (phone.startsWith('91') && phone.length == 12) {
      phone = phone.substring(2);
    } else if (phone.length > 10) {
      // Fallback: take last 10 digits
      phone = phone.substring(phone.length - 10);
    }
    
    return phone;
  }

  /// Get current user's farmer profile from Supabase
  Future<FarmerProfile?> getFarmerProfile() async {
    try {
      final phone = _getPhoneFromUser();
      if (phone == null) {
        debugPrint('FarmerService: No phone number for current user');
        return null;
      }

      debugPrint('FarmerService: Looking for farmer with phone=$phone');

      final response = await _supabase
          .from('farmers')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (response != null) {
        debugPrint('FarmerService: Found existing profile');
        return FarmerProfile.fromJson(response);
      }

      debugPrint('FarmerService: No existing profile found');
      return null;
    } on PostgrestException catch (e) {
      debugPrint('FarmerService: PostgrestException - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('FarmerService: Error getting profile - $e');
      return null;
    }
  }

  /// Save or update farmer profile in Supabase
  /// Uses phone as the unique identifier
  Future<FarmerProfile?> saveFarmerProfile(FarmerProfile profile) async {
    try {
      final phone = _getPhoneFromUser();
      if (phone == null) {
        throw Exception('User not authenticated or no phone number');
      }

      debugPrint('FarmerService: Saving profile for phone $phone');

      // Check if profile exists
      final existing = await getFarmerProfile();

      // Ensure the phone in profile matches the authenticated user's phone
      final data = profile.toJson();
      data['phone'] = phone; // Always use the authenticated user's phone

      debugPrint('FarmerService: Profile data to save: $data');

      if (existing != null && existing.id != null) {
        // Update existing profile
        debugPrint(
            'FarmerService: Updating existing profile id=${existing.id}');

        final response = await _supabase
            .from('farmers')
            .update(data)
            .eq('id', existing.id!)
            .select()
            .single();

        debugPrint('FarmerService: Update successful');
        return FarmerProfile.fromJson(response);
      } else {
        // Insert new profile
        debugPrint('FarmerService: Inserting new profile');

        final response =
            await _supabase.from('farmers').insert(data).select().single();

        debugPrint('FarmerService: Insert successful');
        return FarmerProfile.fromJson(response);
      }
    } on PostgrestException catch (e) {
      debugPrint('FarmerService: PostgrestException - ${e.message}');
      debugPrint('FarmerService: Details - ${e.details}');
      debugPrint('FarmerService: Hint - ${e.hint}');
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      debugPrint('FarmerService: Error saving profile - $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  /// Check if farmer has completed profile
  Future<bool> hasCompletedProfile() async {
    final profile = await getFarmerProfile();
    return profile != null && profile.isComplete;
  }

  /// Get farmer ID for the current user
  Future<String?> getFarmerId() async {
    final profile = await getFarmerProfile();
    return profile?.id;
  }
}
