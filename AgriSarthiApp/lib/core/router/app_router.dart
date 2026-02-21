import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/farmer_login_screen.dart';
import '../../features/auth/screens/admin_login_screen.dart';
import '../../features/home/screens/farmer_home_screen.dart';
import '../../features/home/screens/admin_home_screen.dart';
import '../../features/profile/screens/farmer_profile_form_screen.dart';
import '../../features/documents/screens/document_upload_screen.dart';
import '../../features/profile/screens/farmer_profile_screen.dart';
import '../../features/applications/screens/applications_screen.dart';
import '../../features/schemes/screens/manage_schemes_screen.dart';
import '../../features/claims/screens/insurance_claim_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String farmerLogin = '/farmer-login';
  static const String adminLogin = '/admin-login';
  static const String farmerProfileForm = '/farmer-profile-form';
  static const String documentUpload = '/document-upload';
  static const String farmerHome = '/farmer-home';
  static const String adminHome = '/admin-home';
  static const String farmerProfile = '/farmer-profile';
  static const String applications = '/applications';
  static const String manageSchemes = '/manage-schemes';
  static const String insuranceClaim = '/insurance-claim';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: farmerLogin,
        name: 'farmerLogin',
        builder: (context, state) => const FarmerLoginScreen(),
      ),
      GoRoute(
        path: adminLogin,
        name: 'adminLogin',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: farmerProfileForm,
        name: 'farmerProfileForm',
        builder: (context, state) => const FarmerProfileFormScreen(),
      ),
      GoRoute(
        path: documentUpload,
        name: 'documentUpload',
        builder: (context, state) => const DocumentUploadScreen(),
      ),
      GoRoute(
        path: farmerHome,
        name: 'farmerHome',
        builder: (context, state) => const FarmerHomeScreen(),
      ),
      GoRoute(
        path: adminHome,
        name: 'adminHome',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: farmerProfile,
        name: 'farmerProfile',
        builder: (context, state) => const FarmerProfileScreen(),
      ),
      GoRoute(
        path: applications,
        name: 'applications',
        builder: (context, state) => const ApplicationsScreen(),
      ),
      GoRoute(
        path: manageSchemes,
        name: 'manageSchemes',
        builder: (context, state) => const ManageSchemesScreen(),
      ),
      GoRoute(
        path: insuranceClaim,
        name: 'insuranceClaim',
        builder: (context, state) => const InsuranceClaimScreen(),
      ),
    ],
  );
}
