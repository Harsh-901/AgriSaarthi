import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/application_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  final ApplicationService _applicationService = ApplicationService();
  final ApiService _apiService = ApiService();

  List<ApplicationModel> _applications = [];
  ApplicationStatusCounts _statusCounts = ApplicationStatusCounts();
  bool _isLoading = true;
  bool _isAuthenticating = false;
  String? _errorMessage;
  String _selectedFilter = 'all';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // DATA LOGIC (unchanged)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _initAndLoad() async {
    await _apiService.init();
    if (!_apiService.isAuthenticated) {
      await _authenticateWithDjango();
    } else {
      await _loadApplications();
    }
  }

  Future<void> _authenticateWithDjango() async {
    if (!mounted) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final phone = authProvider.displayPhoneNumber;

      if (phone.isEmpty) {
        setState(() {
          _errorMessage = 'Phone number not available. Please login again.';
          _isAuthenticating = false;
          _isLoading = false;
        });
        return;
      }

      debugPrint(
          'ApplicationsScreen: Authenticating with Django for phone: $phone');

      final otpResponse = await _apiService.sendDjangoOtp(phone);
      if (otpResponse['success'] != true) {
        setState(() {
          _errorMessage =
              otpResponse['message'] ?? 'Failed to connect to server';
          _isAuthenticating = false;
          _isLoading = false;
        });
        return;
      }

      final demoOtp = otpResponse['data']?['demo_otp']?.toString();

      if (demoOtp != null) {
        final verifyResponse =
            await _apiService.verifyDjangoOtp(phone, demoOtp);
        if (verifyResponse['success'] == true) {
          debugPrint('ApplicationsScreen: Django auth successful!');
          setState(() => _isAuthenticating = false);
          await _loadApplications();
          return;
        }
      }

      if (mounted) {
        _showOtpDialog(phone);
      }
    } catch (e) {
      debugPrint('ApplicationsScreen: Django auth error: $e');
      setState(() {
        _errorMessage = 'Server connection failed. Please try again later.';
        _isAuthenticating = false;
        _isLoading = false;
      });
    }
  }

  void _showOtpDialog(String phone) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Server Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the OTP sent to $phone for server access',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Enter OTP',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isAuthenticating = false;
                _isLoading = false;
                _errorMessage = 'Authentication cancelled';
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final response =
                  await _apiService.verifyDjangoOtp(phone, otpController.text);
              if (response['success'] == true) {
                setState(() => _isAuthenticating = false);
                await _loadApplications();
              } else {
                setState(() {
                  _isAuthenticating = false;
                  _isLoading = false;
                  _errorMessage = 'Invalid OTP';
                });
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _applicationService.getApplications();

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _applications = result['applications'] as List<ApplicationModel>;
        _statusCounts = result['statusCounts'] as ApplicationStatusCounts;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to load applications';
        _isLoading = false;
      });
    }
  }

  List<ApplicationModel> get _filteredApplications {
    if (_selectedFilter == 'all') return _applications;
    return _applications.where((app) {
      switch (_selectedFilter) {
        case 'pending':
          return app.isPending;
        case 'approved':
          return app.isApproved;
        case 'rejected':
          return app.isRejected;
        default:
          return true;
      }
    }).toList();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B1B1B)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'My Applications',
          style: TextStyle(
            color: Color(0xFF1B1B1B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadApplications,
            icon: const Icon(Icons.refresh, color: Color(0xFF1B1B1B)),
          ),
        ],
      ),
      body: _isAuthenticating
          ? _buildAuthenticatingView()
          : _isLoading
              ? _buildLoadingView()
              : _errorMessage != null
                  ? _buildErrorView()
                  : _buildContent(),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // CONTENT
  // ════════════════════════════════════════════════════════════════════

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 14),
        // ── Status summary counters ──
        _buildStatusSummary(),
        const SizedBox(height: 14),
        // ── Filter chips ──
        _buildFilterChips(),
        const SizedBox(height: 8),
        // ── Applications list ──
        Expanded(
          child: _filteredApplications.isEmpty
              ? _buildEmptyView()
              : RefreshIndicator(
                  onRefresh: _loadApplications,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredApplications.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _filteredApplications.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Tap on an application to view details',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }
                      return _buildApplicationCard(
                          _filteredApplications[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATUS SUMMARY – pill counters
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStatusSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCounterPill(
            _statusCounts.total,
            'Total',
            const Color(0xFF2E7D32),
            const Color(0xFFE8F5E9),
          ),
          const SizedBox(width: 10),
          _buildCounterPill(
            _statusCounts.pending + _statusCounts.pendingConfirmation,
            'Pending',
            const Color(0xFFFF8F00),
            const Color(0xFFFFF3E0),
          ),
          const SizedBox(width: 10),
          _buildCounterPill(
            _statusCounts.approved,
            'Approved',
            const Color(0xFF00897B),
            const Color(0xFFE0F2F1),
          ),
          const SizedBox(width: 10),
          _buildCounterPill(
            _statusCounts.rejected,
            'Rejected',
            const Color(0xFFE53935),
            const Color(0xFFFFEBEE),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterPill(int count, String label, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // FILTER CHIPS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('All', 'all'),
            const SizedBox(width: 8),
            _buildChip('Pending', 'pending'),
            const SizedBox(width: 8),
            _buildChip('Approved', 'approved'),
            const SizedBox(width: 8),
            _buildChip('Rejected', 'rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE0E0E0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF616161),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // APPLICATION CARD – matching the screenshot design
  // ════════════════════════════════════════════════════════════════════

  Widget _buildApplicationCard(ApplicationModel application) {
    final statusColor = _getStatusColor(application.status);
    final statusIcon = _getStatusIcon(application.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showApplicationDetail(application),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Icon + Name + Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status icon circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    // Scheme name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.schemeName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1B1B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    _buildStatusBadge(
                        application.status, application.statusDisplay),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 2: Amount + Date
                Row(
                  children: [
                    if (application.benefitAmount != null) ...[
                      const Text(
                        '₹ ',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${application.benefitAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Icon(Icons.calendar_today,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(application.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                // Rejection reason
                if (application.isRejected &&
                    application.rejectionReason != null &&
                    application.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            application.rejectionReason!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Confirm button for pending confirmation
                if (application.canConfirm) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _confirmApplication(application),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirm & Submit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATUS BADGE
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStatusBadge(String status, String displayText) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF00897B);
      case 'REJECTED':
        return const Color(0xFFE53935);
      case 'PENDING':
      case 'PENDING_CONFIRMATION':
        return const Color(0xFFFF8F00);
      case 'UNDER_REVIEW':
        return AppColors.info;
      case 'INCOMPLETE':
        return Colors.orange;
      case 'DRAFT':
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'PENDING':
      case 'PENDING_CONFIRMATION':
        return Icons.hourglass_empty;
      case 'UNDER_REVIEW':
        return Icons.visibility_outlined;
      case 'INCOMPLETE':
        return Icons.warning_amber_outlined;
      case 'DRAFT':
      default:
        return Icons.edit_note_outlined;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // LOADING / AUTH / ERROR / EMPTY VIEWS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildAuthenticatingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF2E7D32),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to server...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Authenticating your account',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 56,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'all'
                  ? 'No Applications Yet'
                  : 'No ${_selectedFilter[0].toUpperCase()}${_selectedFilter.substring(1)} Applications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'all'
                  ? 'Apply for government schemes from the home screen to see them here.'
                  : 'No applications with this status.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (_selectedFilter == 'all') ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Browse Schemes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // APPLICATION DETAIL BOTTOM SHEET
  // ════════════════════════════════════════════════════════════════════

  void _showApplicationDetail(ApplicationModel application) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: _buildStatusBadge(
                          application.status, application.statusDisplay),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        application.schemeName,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                        'Tracking ID', application.trackingId ?? 'N/A'),
                    _buildDetailRow('Application ID',
                        application.id.substring(0, 8).toUpperCase()),
                    if (application.benefitAmount != null)
                      _buildDetailRow('Benefit Amount',
                          '₹${application.benefitAmount!.toStringAsFixed(2)}'),
                    _buildDetailRow(
                        'Applied On', _formatDate(application.createdAt)),
                    if (application.confirmedAt != null)
                      _buildDetailRow(
                          'Confirmed', _formatDate(application.confirmedAt!)),
                    if (application.submittedAt != null)
                      _buildDetailRow(
                          'Submitted', _formatDate(application.submittedAt!)),
                    if (application.governmentReference != null)
                      _buildDetailRow(
                          'Govt. Ref', application.governmentReference!),
                    if (application.missingDocuments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Missing Documents',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                      ),
                      const SizedBox(height: 8),
                      ...application.missingDocuments.map((doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text(doc.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium),
                              ],
                            ),
                          )),
                    ],
                    if (application.isRejected &&
                        application.rejectionReason != null &&
                        application.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rejection Reason',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              application.rejectionReason!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (application.canConfirm) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmApplication(application);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirm & Submit Application',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // CONFIRM APPLICATION
  // ════════════════════════════════════════════════════════════════════

  Future<void> _confirmApplication(ApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Application'),
        content: Text(
          'Are you sure you want to submit your application for "${application.schemeName}"?\n\nOnce confirmed, it will be sent for government verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      final result =
          await _applicationService.confirmApplication(application.id);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Application submitted!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _loadApplications();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to submit'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
