  import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminService _adminService = AdminService();

  int _totalFarmers = 0;
  int _activeSchemes = 0;
  List<Map<String, dynamic>> _pendingVerifications = [];
  List<Map<String, dynamic>> _todayApplications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ════════════════════════════════════════════════════════════════════
  // DATA LOGIC (unchanged)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _adminService.getDashboardStats();
      if (mounted) {
        setState(() {
          _totalFarmers = stats['totalFarmers'] ?? 0;
          _activeSchemes = stats['activeSchemes'] ?? 0;
          _pendingVerifications =
              stats['pendingVerifications'] as List<Map<String, dynamic>>;
          _todayApplications =
              stats['todayApplications'] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminHome: Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard data';
          _isLoading = false;
        });
      }
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}K';
    }
    return number.toString();
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return '';
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: const Color(0xFF1A237E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Dark blue gradient header ──
                        _buildHeader(authProvider),

                        // ── Stat cards ──
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: _buildStatsRow(),
                        ),

                        // ── Pending Verifications ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildPendingVerifications(),
                        ),

                        // ── Applications Today ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildTodayApplications(),
                        ),

                        // ── Quick Actions ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: _buildQuickActions(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DARK BLUE GRADIENT HEADER
  // ════════════════════════════════════════════════════════════════════

  Widget _buildHeader(AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 48,
        left: 20,
        right: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1B4A),
            Color(0xFF1A3068),
            Color(0xFF2541A8),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Refresh
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
          ),
          // Settings / Logout
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white70, size: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await authProvider.signOut();
                if (mounted) {
                  context.go(AppRouter.welcome);
                }
              } else if (value == 'manage_schemes') {
                context.push(AppRouter.manageSchemes);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_schemes',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Color(0xFF1A237E)),
                    SizedBox(width: 8),
                    Text('Manage Schemes'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAT CARDS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.people_outline,
              iconBg: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF1A237E),
              value: _formatNumber(_totalFarmers),
              label: 'TOTAL FARMERS',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _buildStatCard(
              icon: Icons.article_outlined,
              iconBg: const Color(0xFFE0F2F1),
              iconColor: const Color(0xFF00897B),
              value: _activeSchemes.toString(),
              label: 'ACTIVE SCHEMES',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // PENDING VERIFICATIONS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildPendingVerifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Text(
              'Pending Verifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const Spacer(),
            if (_pendingVerifications.length > 3)
              GestureDetector(
                onTap: () {
                  // TODO: navigate to all verifications
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF1A237E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _pendingVerifications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No pending verifications 🎉',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    ..._pendingVerifications
                        .take(5)
                        .map((v) => _buildVerificationItem(v)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildVerificationItem(Map<String, dynamic> verification) {
    final farmerName = verification['farmers']?['name'] ?? 'Unknown Farmer';
    final schemeName = verification['schemes']?['name'] ?? 'Unknown Scheme';
    final applicationId = verification['id']?.toString() ?? '';

    // Avatar colors
    final colors = [
      const Color(0xFFE8EAF6), // indigo light
      const Color(0xFFE0F2F1), // teal light
      const Color(0xFFFCE4EC), // pink light
      const Color(0xFFFFF3E0), // orange light
      const Color(0xFFEDE7F6), // purple light
    ];
    final textColors = [
      const Color(0xFF283593),
      const Color(0xFF00695C),
      const Color(0xFFC2185B),
      const Color(0xFFE65100),
      const Color(0xFF4527A0),
    ];
    final idx = farmerName.hashCode.abs() % colors.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Letter avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: colors[idx],
            child: Text(
              farmerName.isNotEmpty ? farmerName[0].toUpperCase() : '?',
              style: TextStyle(
                color: textColors[idx],
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + Scheme
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schemeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Verify button
          OutlinedButton(
            onPressed: () => _navigateToApplicationView(applicationId),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 34),
            ),
            child: const Text(
              'Verify',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // APPLICATIONS TODAY
  // ════════════════════════════════════════════════════════════════════

  Widget _buildTodayApplications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Text(
              'Applications Today',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const Spacer(),
            if (_todayApplications.length > 5)
              GestureDetector(
                onTap: () {
                  // TODO: navigate to all applications
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF1A237E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _todayApplications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No applications today',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Column(
                  children:
                      _todayApplications.map((a) => _buildAppItem(a)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAppItem(Map<String, dynamic> app) {
    final farmerName = app['farmers']?['name'] ?? 'Unknown';
    final schemeName = app['schemes']?['name'] ?? 'Unknown Scheme';
    final createdAt = app['created_at'] ?? '';
    final time = _formatTime(createdAt);

    // Status dot color
    final status = (app['status'] ?? '').toString().toUpperCase();
    Color dotColor;
    switch (status) {
      case 'APPROVED':
        dotColor = const Color(0xFF43A047);
        break;
      case 'REJECTED':
        dotColor = const Color(0xFFE53935);
        break;
      default:
        dotColor = const Color(0xFFFF8F00);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Name + scheme
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schemeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Time
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          // Status dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B1B1B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Add Scheme
            Expanded(
              child: _buildActionBtn(
                icon: Icons.add_circle_outline,
                label: 'Add Scheme',
                color: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap: () => context.push(AppRouter.manageSchemes),
              ),
            ),
            const SizedBox(width: 12),
            // Verify Docs
            Expanded(
              child: _buildActionBtn(
                icon: Icons.verified_outlined,
                label: 'Verify Docs',
                color: const Color(0xFFE65100),
                bgColor: const Color(0xFFFFF3E0),
                onTap: () {
                  if (_pendingVerifications.isNotEmpty) {
                    _navigateToApplicationView(
                      _pendingVerifications.first['id'].toString(),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No pending verifications!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Manage Schemes – full width
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => context.push(AppRouter.manageSchemes),
            icon: const Icon(Icons.description_outlined, size: 20),
            label: const Text(
              'Manage Schemes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ERROR VIEW
  // ════════════════════════════════════════════════════════════════════

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // NAVIGATE TO APPLICATION VIEW
  // ════════════════════════════════════════════════════════════════════

  /// Navigate to application view screen
  Future<void> _navigateToApplicationView(String applicationId) async {
    final result = await context.push<bool>(
      '${AppRouter.adminApplicationView}/$applicationId',
    );
    if (result == true && mounted) {
      _loadDashboardData();
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // VERIFY / REJECT DIALOG (unchanged logic)
  // ════════════════════════════════════════════════════════════════════

  void _showVerifyDialog(String applicationId, String farmerName) {
    final notesController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Verify: $farmerName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Notes (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add notes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Rejection Reason (if rejecting):'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Reason for rejection...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _adminService.updateApplicationStatus(
                applicationId,
                status: 'REJECTED',
                adminNotes: notesController.text,
                rejectionReason: reasonController.text,
                verifiedBy: 'admin',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Application rejected' : 'Failed'),
                    backgroundColor:
                        success ? AppColors.warning : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _adminService.updateApplicationStatus(
                applicationId,
                status: 'APPROVED',
                adminNotes: notesController.text,
                verifiedBy: 'admin',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(success ? 'Application approved ✅' : 'Failed'),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}
