import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/farmer_service.dart';

enum AuthState {
  initial,
  loading,
  otpSent,
  authenticated,
  unauthenticated,
  error,
}

enum UserRole {
  farmer,
  admin,
}

/// Auth Provider using Supabase Auth for OTP and Supabase DB for farmer profile
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  String? _errorMessage;
  UserRole _currentRole = UserRole.farmer;
  String? _phoneNumber;
  String? _farmerId;
  bool _isNewUser = false;
  bool _isProfileComplete = false;
  User? _supabaseUser;
  bool _isInitialized = false;
  bool _isAdminLoggedIn = false;
  String? _adminName;
  String? _adminId;
  bool _isDjangoAuthenticated = false;

  // Getters
  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  UserRole get currentRole => _currentRole;
  String? get phoneNumber => _phoneNumber;
  String? get accessToken => SupabaseConfig.currentSession?.accessToken;
  String? get farmerId => _farmerId;
  bool get isAuthenticated => _supabaseUser != null || _isAdminLoggedIn;
  bool get isAdminLoggedIn => _isAdminLoggedIn;
  String? get adminName => _adminName;
  String? get adminId => _adminId;
  bool get isNewUser => _isNewUser;
  bool get isProfileComplete => _isProfileComplete;
  User? get supabaseUser => _supabaseUser;
  bool get isInitialized => _isInitialized;
  bool get isDjangoAuthenticated => _isDjangoAuthenticated;

  final SupabaseClient _supabase = SupabaseConfig.client;
  final FarmerService _farmerService = FarmerService();
  final DocumentService _documentService = DocumentService();

  // Get display phone number (10 digits only)
  String get displayPhoneNumber {
    final phone = _phoneNumber ?? _supabaseUser?.phone;
    if (phone == null || phone.isEmpty) return '';
    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }
    if (phone.length > 10) {
      return phone.substring(phone.length - 10);
    }
    return phone;
  }

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize auth and restore session
  Future<void> _initializeAuth() async {
    try {
      debugPrint('AuthProvider: Initializing...');

      // Check for existing Supabase session
      final session = _supabase.auth.currentSession;

      if (session != null) {
        debugPrint('AuthProvider: Found existing session');
        _supabaseUser = session.user;
        _phoneNumber = _supabaseUser?.phone;

        // Load saved data from SharedPreferences
        await _loadLocalData();

        // Verify farmer profile
        await _checkFarmerProfile();

        _state = AuthState.authenticated;
        syncWithDjango();
      } else {
        debugPrint('AuthProvider: No existing session');
        _state = AuthState.unauthenticated;
      }

      // Listen for auth changes
      _listenToSupabaseAuth();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: Init error - $e');
      _state = AuthState.unauthenticated;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Listen to Supabase auth state changes
  void _listenToSupabaseAuth() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      debugPrint('AuthProvider: Auth state changed - ${data.event}');

      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _supabaseUser = data.session!.user;
        _phoneNumber = _supabaseUser?.phone;

        // Check for existing farmer profile
        await _checkFarmerProfile();

        // Create farmer bucket if farmer profile exists
        await _createFarmerBucket();

        _state = AuthState.authenticated;
        await _saveLocalData();
        
        // Sync with Django backend
        syncWithDjango();
        
        notifyListeners();
      } else if (data.event == AuthChangeEvent.signedOut) {
        debugPrint('AuthProvider: User signed out');
        _supabaseUser = null;
        _farmerId = null;
        _isProfileComplete = false;
        _state = AuthState.unauthenticated;
        await _clearLocalData();
        notifyListeners();
      } else if (data.event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('AuthProvider: Token refreshed');
        _supabaseUser = data.session?.user;
      }
    });
  }

  /// Check if farmer has profile in Supabase
  Future<void> _checkFarmerProfile() async {
    try {
      final profile = await _farmerService.getFarmerProfile();
      if (profile != null) {
        _farmerId = profile.id;
        _isProfileComplete = profile.isComplete;
        _isNewUser = false;
        debugPrint(
            'AuthProvider: Found farmer profile - id=${_farmerId}, complete=${_isProfileComplete}');
      } else {
        _isNewUser = true;
        _isProfileComplete = false;
        debugPrint('AuthProvider: No farmer profile found');
      }
    } catch (e) {
      debugPrint('AuthProvider: Error checking farmer profile - $e');
    }
  }

  /// Create a dedicated storage bucket for the farmer after login.
  /// Uses Supabase directly (no Django involved).
  Future<void> _createFarmerBucket() async {
    if (_farmerId == null) {
      debugPrint('AuthProvider: No farmer ID yet, skipping bucket creation');
      return;
    }
    try {
      debugPrint(
          'AuthProvider: Creating storage bucket for farmer $_farmerId...');
      final success = await _documentService.createFarmerBucket(_farmerId!);
      if (success) {
        debugPrint(
            'AuthProvider: Bucket created/verified for farmer $_farmerId');
      } else {
        debugPrint(
            'AuthProvider: Failed to create bucket for farmer $_farmerId');
      }
    } catch (e) {
      debugPrint('AuthProvider: Error creating farmer bucket - $e');
    }
  }

  /// Load saved data from SharedPreferences
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _farmerId = prefs.getString('farmer_id');
      _isProfileComplete = prefs.getBool('profile_complete') ?? false;
      debugPrint(
          'AuthProvider: Loaded local data - farmerId=$_farmerId, profileComplete=$_isProfileComplete');
    } catch (e) {
      debugPrint('AuthProvider: Error loading local data - $e');
    }
  }

  /// Save data to SharedPreferences
  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_farmerId != null) {
        await prefs.setString('farmer_id', _farmerId!);
      }
      if (_phoneNumber != null) {
        await prefs.setString('phone_number', _phoneNumber!);
      }
      await prefs.setBool('profile_complete', _isProfileComplete);
      debugPrint('AuthProvider: Saved local data');
    } catch (e) {
      debugPrint('AuthProvider: Error saving local data - $e');
    }
  }

  /// Clear local data
  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('farmer_id');
      await prefs.remove('phone_number');
      await prefs.remove('profile_complete');
      debugPrint('AuthProvider: Cleared local data');
    } catch (e) {
      debugPrint('AuthProvider: Error clearing local data - $e');
    }
  }

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Send OTP using Supabase Auth (Twilio)
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      // Format phone with country code
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+91$phoneNumber';
      }

      _phoneNumber = formattedPhone;

      debugPrint('AuthProvider: Sending OTP to $formattedPhone');

      // Use Supabase to send OTP via Twilio
      await _supabase.auth.signInWithOtp(
        phone: formattedPhone,
      );

      _state = AuthState.otpSent;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: Send OTP error - ${e.message}');
      _state = AuthState.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: Send OTP error - $e');
      _state = AuthState.error;
      _errorMessage = 'Failed to send OTP. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP using Supabase
  Future<bool> verifyOtp(String otp) async {
    if (_phoneNumber == null) {
      _errorMessage = 'Phone number not set';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      debugPrint('AuthProvider: Verifying OTP for $_phoneNumber');

      // Verify OTP with Supabase
      final response = await _supabase.auth.verifyOTP(
        phone: _phoneNumber!,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user == null) {
        _state = AuthState.error;
        _errorMessage = 'Invalid OTP. Please try again.';
        notifyListeners();
        return false;
      }

      debugPrint('AuthProvider: OTP verified successfully');
      _supabaseUser = response.user;

      // Check for existing farmer profile
      await _checkFarmerProfile();

      // Create farmer bucket if profile exists
      await _createFarmerBucket();

      _state = AuthState.authenticated;
      await _saveLocalData();
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: Verify OTP error - ${e.message}');
      _state = AuthState.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: Verify OTP error - $e');
      _state = AuthState.error;
      _errorMessage = 'Verification failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Update profile completion status
  void setProfileComplete(bool complete) {
    _isProfileComplete = complete;
    _saveLocalData();
    notifyListeners();
  }

  /// Set farmer ID
  void setFarmerId(String id) {
    _farmerId = id;
    _saveLocalData();
    notifyListeners();
  }

  /// Admin Login using custom admins table (RPC)
  Future<bool> adminLogin(String email, String password) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      debugPrint('AuthProvider: Admin login attempt for $email');

      // Call the verify_admin_login RPC function
      final response = await _supabase.rpc('verify_admin_login', params: {
        'p_email': email.trim(),
        'p_password': password,
      });

      debugPrint(
          'AuthProvider: Admin login raw response type: ${response.runtimeType}');
      debugPrint('AuthProvider: Admin login raw response: $response');

      // Supabase RPC can return Map or String depending on function return type
      Map<String, dynamic> result;
      if (response is Map<String, dynamic>) {
        result = response;
      } else if (response is String) {
        result = Map<String, dynamic>.from(
          json.decode(response) as Map,
        );
      } else {
        debugPrint(
            'AuthProvider: Unexpected response type: ${response.runtimeType}');
        _state = AuthState.error;
        _errorMessage = 'Unexpected server response';
        notifyListeners();
        return false;
      }

      debugPrint('AuthProvider: Parsed result: $result');

      if (result['success'] == true && result['data'] != null) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        _isAdminLoggedIn = true;
        _adminId = data['admin_id']?.toString();
        _adminName = data['name']?.toString() ?? 'Admin';
        _currentRole = UserRole.admin;
        _state = AuthState.authenticated;

        // Save admin state locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_admin_logged_in', true);
        await prefs.setString('admin_id', _adminId ?? '');
        await prefs.setString('admin_name', _adminName ?? 'Admin');
        await prefs.setString('admin_email', email.trim());

        debugPrint('AuthProvider: Admin login successful! Name: $_adminName');
        notifyListeners();
        return true;
      } else {
        _state = AuthState.error;
        _errorMessage = result['message']?.toString() ?? 'Invalid credentials';
        debugPrint('AuthProvider: Admin login failed: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('AuthProvider: Admin login error: $e');
      debugPrint('AuthProvider: Stack trace: $stackTrace');
      _state = AuthState.error;
      _errorMessage = 'Login failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Sign out - only when user explicitly requests it
  Future<void> signOut() async {
    // Only call Supabase auth signOut if user is NOT admin
    // (admins don't have Supabase auth sessions)
    if (!_isAdminLoggedIn) {
      try {
        debugPrint('AuthProvider: Signing out from Supabase...');
        await _supabase.auth.signOut();
      } catch (e) {
        debugPrint('AuthProvider: Sign out error - $e');
      }
    }

    _supabaseUser = null;
    _farmerId = null;
    _phoneNumber = null;
    _isNewUser = false;
    _isProfileComplete = false;
    _isAdminLoggedIn = false;
    _adminName = null;
    _adminId = null;
    _state = AuthState.unauthenticated;
    _currentRole = UserRole.farmer;

    await _clearLocalData();

    // Also clear admin-specific prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_admin_logged_in');
    await prefs.remove('admin_id');
    await prefs.remove('admin_name');
    await prefs.remove('admin_email');

    notifyListeners();
  }

  /// Reset state
  void resetState() {
    _state = AuthState.initial;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Manually sync Supabase auth with Django backend
  Future<void> syncWithDjango() async {
    if (_isSyncing) return;
    
    final phone = _phoneNumber ?? _supabaseUser?.phone;
    if (phone == null || phone.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    // Remove + prefix if present
    String cleanPhone = phone;
    if (phone.startsWith('+91')) {
      cleanPhone = phone.substring(3);
    } else if (phone.startsWith('+')) {
      cleanPhone = phone.substring(1);
    }

    debugPrint('AuthProvider: Syncing with Django for $cleanPhone...');
    final apiService = ApiService();
    
    // 1. Send OTP (returns demo_otp in backend for dev/hackathon)
    try {
      final sendResult = await apiService.sendDjangoOtp(cleanPhone);
      if (sendResult['success'] == true) {
        final demoOtp = sendResult['data']?['demo_otp'];
        if (demoOtp != null) {
          // 2. Automatically verify using the demo OTP
          debugPrint('AuthProvider: Auto-verifying Django with demo OTP: $demoOtp');
          final verifyResult = await apiService.verifyDjangoOtp(cleanPhone, demoOtp.toString());
          if (verifyResult['success'] == true) {
            debugPrint('AuthProvider: ✅ Django sync successful!');
            _isDjangoAuthenticated = true;
            _errorMessage = null;
          } else {
            debugPrint('AuthProvider: ❌ Django verification failed: ${verifyResult['message']}');
            _isDjangoAuthenticated = false;
            _errorMessage = 'Django Auth: ${verifyResult['message']}';
          }
        } else {
          debugPrint('AuthProvider: ⚠️ No demo OTP found in response');
          _isDjangoAuthenticated = false;
        }
      } else {
        debugPrint('AuthProvider: ❌ Django OTP send failed: ${sendResult['message']}');
        _isDjangoAuthenticated = false;
        _errorMessage = 'Backend Connection Failed';
      }
    } catch (e) {
      debugPrint('AuthProvider: ❌ Django sync error: $e');
      _isDjangoAuthenticated = false;
      _errorMessage = 'Connection Error: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
