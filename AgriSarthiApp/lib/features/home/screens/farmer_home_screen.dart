import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/farmer_service.dart';
import '../../../core/services/scheme_service.dart';
import '../../../core/services/application_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../../voice/widgets/voice_assistant_button.dart';
import '../../voice/widgets/voice_assistant_overlay.dart';

class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  int _selectedIndex = 0;
  final FarmerService _farmerService = FarmerService();
  final SchemeService _schemeService = SchemeService();
  final ApplicationService _applicationService = ApplicationService();
  String _farmerName = 'Farmer';
  bool _isLoadingName = true;
  late Future<List<SchemeModel>> _schemesFuture;
  Set<String> _appliedSchemeIds = {};

  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _loadFarmerName();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupVoiceNavigation();
    });
  }

  /// Fetch the set of scheme IDs this farmer has already applied for
  Future<Set<String>> _fetchAppliedSchemeIds() async {
    try {
      final result = await _applicationService.getApplications();
      if (result['success'] == true && result['applications'] != null) {
        final applications = result['applications'] as List<ApplicationModel>;
        // Try matching by schemeId first, fall back to schemeName
        final ids = <String>{};
        for (final app in applications) {
          if (app.schemeId != null && app.schemeId!.isNotEmpty) {
            ids.add(app.schemeId!);
          }
          // Also store scheme name for fallback matching
          ids.add(app.schemeName);
        }
        debugPrint('Applied scheme IDs loaded: $ids');
        return ids;
      }
    } catch (e) {
      debugPrint('Error loading applied scheme IDs: $e');
    }
    return {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = context.locale;
    if (_currentLocale != newLocale) {
      _currentLocale = newLocale;
      _schemesFuture = _loadSchemesWithAppliedStatus(newLocale.languageCode);
    }
  }

  void _setupVoiceNavigation() {
    if (!mounted) return;
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.onNavigate = _handleVoiceNavigation;
  }

  void _handleVoiceNavigation(String action, Map<String, dynamic>? data) {
    if (!mounted) return;
    debugPrint('FarmerHomeScreen: 🧭 Voice navigation → $action');

    switch (action) {
      case 'show_schemes':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Here are your eligible schemes'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'show_applications':
        context.push(AppRouter.applications);
        break;
      case 'show_profile':
      case 'complete_profile':
        context.push(AppRouter.farmerProfile);
        break;
      case 'show_documents':
        context.push(AppRouter.documentUpload);
        break;
      case 'show_help':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Help section coming soon!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'file_claim':
        context.push(AppRouter.insuranceClaim);
        break;
      default:
        debugPrint('FarmerHomeScreen: Unknown voice action: $action');
    }
  }

  /// Load schemes and mark which ones the farmer already applied for
  Future<List<SchemeModel>> _loadSchemesWithAppliedStatus(String languageCode) async {
    final results = await Future.wait([
      _schemeService.getEligibleSchemes(languageCode: languageCode),
      _fetchAppliedSchemeIds(),
    ]);
    final schemes = results[0] as List<SchemeModel>;
    final appliedIds = results[1] as Set<String>;

    if (mounted) {
      setState(() => _appliedSchemeIds = appliedIds);
    }

    return schemes.map((s) {
      final isApplied = appliedIds.contains(s.id) || appliedIds.contains(s.name);
      return s.copyWith(isApplied: isApplied);
    }).toList();
  }

  /// Refresh all home screen data
  Future<void> _refreshSchemes() async {
    final locale = context.locale;
    setState(() {
      _schemesFuture = _loadSchemesWithAppliedStatus(locale.languageCode);
      _isLoadingName = true;
    });
    await _loadFarmerName();
  }

  Future<void> _loadFarmerName() async {
    try {
      final profile = await _farmerService.getFarmerProfile();
      if (profile != null && mounted) {
        setState(() {
          _farmerName = profile.fullName.isNotEmpty
              ? profile.fullName.split(' ').first
              : 'Farmer';
          _isLoadingName = false;
        });
      } else {
        setState(() {
          _isLoadingName = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading farmer name: $e');
      if (mounted) {
        setState(() {
          _isLoadingName = false;
        });
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        context.push(AppRouter.applications);
        break;
      case 2:
        context.push(AppRouter.documentUpload);
        break;
      case 3:
        _showComingSoon('features.videos'.tr());
        break;
      case 4:
        context.push(AppRouter.farmerProfile);
        break;
    }
  }

  Future<void> _applyForScheme(SchemeModel scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply for ${scheme.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to apply for this scheme?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (scheme.benefit.isNotEmpty)
              Text(
                'Benefit: ${scheme.benefit}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isDjangoAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cannot connect to server. Please check your IP/Network.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Text('Submitting application...'),
          ],
        ),
        duration: Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );

    final result = await _applicationService.applyToScheme(scheme.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success'] == true) {
      final trackingId = result['data']?['tracking_id'] ?? '';
      // Refresh schemes list (will re-fetch applied IDs too)
      if (mounted) {
        setState(() {
          _schemesFuture = _loadSchemesWithAppliedStatus(
              _currentLocale?.languageCode ?? 'en');
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application submitted! Tracking ID: $trackingId',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => context.push(AppRouter.applications),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit application'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - ${'messages.coming_soon'.tr()}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Dark green header ──
              _buildHeader(),
              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // ── Weather card ──
                      _buildWeatherCard(),
                      const SizedBox(height: 20),
                      // ── Insurance claim card ──
                      _buildInsuranceClaimCard(),
                      const SizedBox(height: 20),
                      // ── Government Schemes ──
                      _buildSchemesSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Voice overlay
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HEADER – dark green gradient with greeting
  // ════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 12,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: greeting + icons
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: Color(0xFFA5D6A7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _isLoadingName
                        ? const SizedBox(
                            width: 140,
                            height: 26,
                            child: LinearProgressIndicator(
                              backgroundColor: Color(0xFF2E7D32),
                              color: Color(0xFFA5D6A7),
                            ),
                          )
                        : Text(
                            'Farmer $_farmerName!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ),
              ),
              // Notification bell
              IconButton(
                onPressed: () =>
                    _showComingSoon('features.notifications'.tr()),
                icon: const Icon(Icons.notifications_outlined),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 4),
              // Mic icon
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic_outlined),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: const CircleBorder(),
                ),
              ),
              // Connection dot
              GestureDetector(
                onTap: () {
                  authProvider.syncWithDjango();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking connection...')),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: authProvider.isDjangoAuthenticated
                        ? const Color(0xFF76FF03)
                        : AppColors.error,
                  ),
                ),
              ),
              // Overflow menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                onSelected: (value) async {
                  if (value == 'logout') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('menu.logout'.tr()),
                        content: Text('messages.logout_confirm'.tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('messages.cancel'.tr()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('menu.logout'.tr()),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await authProvider.signOut();
                      if (mounted) context.go(AppRouter.welcome);
                    }
                  } else if (value == 'language') {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('menu.change_language'.tr()),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLanguageOption(ctx, 'English', 'en'),
                              _buildLanguageOption(ctx, 'हिंदी (Hindi)', 'hi'),
                              _buildLanguageOption(
                                  ctx, 'मराठी (Marathi)', 'mr'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'language',
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('menu.change_language'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('menu.logout'.tr()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // WEATHER CARD
  // ════════════════════════════════════════════════════════════════════

  Widget _buildWeatherCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFFA726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative leaf-circle watermark
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.eco,
              size: 70,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: location + temp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.white.withOpacity(0.9), size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Pune, India',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '28°C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sunny, perfect for harvesting',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: humidity / wind
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 4),
                  _weatherDetail(Icons.water_drop, 'Humidity: 45%'),
                  const SizedBox(height: 6),
                  _weatherDetail(Icons.air, 'Wind: 12 km/h'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // INSURANCE CLAIM CARD (preserved from original)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildInsuranceClaimCard() {
    return GestureDetector(
      onTap: () => context.push(AppRouter.insuranceClaim),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE74C3C), Color(0xFFF39C12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE74C3C).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Crop Insurance Claim',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'File PMFBY claim within 72 hours',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // GOVERNMENT SCHEMES SECTION
  // ════════════════════════════════════════════════════════════════════

  Widget _buildSchemesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Text(
                'Government Schemes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _refreshSchemes,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<SchemeModel>>(
          future: _schemesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('Error loading schemes: ${snapshot.error}'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refreshSchemes,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('No schemes available at the moment.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refreshSchemes,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!
                  .map((scheme) => _buildSchemeCard(scheme))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SCHEME CARD – with left green border and status badge
  // ════════════════════════════════════════════════════════════════════

  Widget _buildSchemeCard(SchemeModel scheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left green accent bar
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            scheme.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(scheme.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Benefit
                    Text(
                      scheme.benefit,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Bottom row: click to see details + Apply
                    Row(
                      children: [
                        Text(
                          'Click to see details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _applyForScheme(scheme),
                          child: const Row(
                            children: [
                              Text(
                                'Apply',
                                style: TextStyle(
                                  color: Color(0xFFFF8F00),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward,
                                  color: Color(0xFFFF8F00), size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATUS BADGE
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStatusBadge(SchemeStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case SchemeStatus.open:
        bgColor = const Color(0xFF2E7D32);
        textColor = Colors.white;
        label = 'OPEN';
        break;
      case SchemeStatus.eligible:
        bgColor = const Color(0xFFE0E0E0);
        textColor = const Color(0xFF616161);
        label = 'ELIGIBLE';
        break;
      case SchemeStatus.closingSoon:
        bgColor = const Color(0xFFFF8F00);
        textColor = Colors.white;
        label = 'CLOSING SOON';
        break;
      case SchemeStatus.closed:
        bgColor = AppColors.error.withOpacity(0.15);
        textColor = AppColors.error;
        label = 'CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 12,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
          _buildNavItem(
              1, Icons.description_outlined, Icons.description, 'Apps'),
          const SizedBox(width: 48),
          _buildNavItem(
              2, Icons.upload_file_outlined, Icons.upload_file, 'Upload'),
          _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2E7D32).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF9E9E9E),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF9E9E9E),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LANGUAGE OPTION
  // ════════════════════════════════════════════════════════════════════

  Widget _buildLanguageOption(
      BuildContext dialogContext, String name, String code) {
    final isSelected = dialogContext.locale.languageCode == code;
    return InkWell(
      onTap: () async {
        if (isSelected) {
          Navigator.pop(dialogContext);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Changing language to $name...'),
            duration: const Duration(milliseconds: 1000),
          ),
        );

        Navigator.pop(dialogContext);
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          await context.setLocale(Locale(code));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
