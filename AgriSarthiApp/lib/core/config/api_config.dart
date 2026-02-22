/// API Configuration for the AgriSarthi Backend
class ApiConfig {
  // Base URL for the backend
  // POINTING TO PRODUCTION DEPLOYMENT
  // static const String baseUrl = 'https://agrisarthi.onrender.com'; // Production
  // static const String baseUrl = 'http://127.0.0.1:8000/'; // Local Emulator (use your IP for physical device)
  static const String baseUrl = 'http://192.168.137.216:8000'; // Physical Device

  // API Endpoints
  static const String authLogin = '$baseUrl/api/auth/login/';
  static const String authVerify = '$baseUrl/api/auth/verify/';
  static const String authRegister = '$baseUrl/api/auth/register/';
  static const String authRefresh = '$baseUrl/api/auth/refresh/';
  static const String authLogout = '$baseUrl/api/auth/logout/';


  static const String farmersProfile = '$baseUrl/api/farmers/profile/';
  static const String documents = '$baseUrl/api/documents/';

  // Helper to get farmer-specific document endpoint
  static String farmerDocuments(String farmerId) =>
      '$baseUrl/api/documents/farmer/$farmerId/';

  static String farmerProfile(String farmerId) =>
      '$baseUrl/api/farmers/profile/$farmerId/';
}
