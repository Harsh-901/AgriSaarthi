import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminApplicationViewScreen extends StatefulWidget {
  final String applicationId;

  const AdminApplicationViewScreen({
    super.key,
    required this.applicationId,
  });

  @override
  State<AdminApplicationViewScreen> createState() =>
      _AdminApplicationViewScreenState();
}

class _AdminApplicationViewScreenState
    extends State<AdminApplicationViewScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _applicationData;

  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApplicationDetails();
  }

  Future<void> _loadApplicationDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _adminService
          .getApplicationForVerification(widget.applicationId);
      if (data == null) {
        setState(() {
          _errorMessage = 'Application not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _applicationData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load application details';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApprove() async {
    final success = await _adminService.updateApplicationStatus(
      widget.applicationId,
      status: 'APPROVED',
      adminNotes: _notesController.text,
      verifiedBy: 'admin',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Application approved ✅' : 'Failed to approve'),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) {
        context.pop(true); // Return true indicating success
      }
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Admin Notes (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Add notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await _adminService.updateApplicationStatus(
                widget.applicationId,
                status: 'REJECTED',
                adminNotes: _notesController.text,
                rejectionReason: _reasonController.text,
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
                if (success) {
                  context.pop(true); // Return true indicating success
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Application'),
        backgroundColor: AppColors.surface,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.error)))
              : _buildContent(),
      bottomNavigationBar: _applicationData != null &&
              (_applicationData!['status'] == 'PENDING' ||
                  _applicationData!['status'] == 'UNDER_REVIEW')
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildContent() {
    final data = _applicationData!;
    final autoFilledData =
        data['auto_filled_data'] as Map<String, dynamic>? ?? {};
    final basicDetails =
        autoFilledData['basic_details'] as Map<String, dynamic>? ?? {};
    final attachedDocs = data['attached_documents'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Details Section
          _buildSectionHeader('Farmer Details'),
          _buildInfoCard([
            _buildInfoRow(
                'Name',
                basicDetails['farmer_name'] ??
                    basicDetails['name'] ??
                    data['farmers']?['name'] ??
                    'N/A'),
            _buildInfoRow('Phone',
                basicDetails['phone'] ?? data['farmers']?['phone'] ?? 'N/A'),
            _buildInfoRow('Gender',
                basicDetails['gender']?.toString().toUpperCase() ?? 'N/A'),
            _buildInfoRow('Age', basicDetails['age']?.toString() ?? 'N/A'),
            _buildInfoRow('State',
                basicDetails['state'] ?? data['farmers']?['state'] ?? 'N/A'),
            _buildInfoRow(
                'District',
                basicDetails['district'] ??
                    data['farmers']?['district'] ??
                    'N/A'),
            _buildInfoRow(
                'Village',
                basicDetails['village'] ??
                    data['farmers']?['village'] ??
                    'N/A'),
            _buildInfoRow(
                'Social Category',
                basicDetails['social_category']?.toString().toUpperCase() ??
                    'N/A'),
            _buildInfoRow(
                'Annual Income', '₹${basicDetails['annual_income'] ?? '0'}'),
            _buildInfoRow('BPL', basicDetails['is_bpl'] == true ? 'Yes' : 'No'),
            _buildInfoRow(
                'Land Size', '${basicDetails['land_size'] ?? 'N/A'} acres'),
            _buildInfoRow('Land Type', basicDetails['land_type'] ?? 'N/A'),
            _buildInfoRow('Irrigation',
                basicDetails['has_irrigation'] == true ? 'Yes' : 'No'),
            _buildInfoRow(
                'Farming Category', basicDetails['farming_category'] ?? 'N/A'),
            _buildInfoRow(
                'Survey Number', basicDetails['survey_number'] ?? 'N/A'),
            _buildInfoRow(
                'Crops',
                (basicDetails['crops'] as List?)?.join(', ') ??
                    basicDetails['crop_type'] ??
                    'N/A'),
          ]),

          const SizedBox(height: 16),

          // Scheme Section
          _buildSectionHeader('Scheme Applied'),
          _buildInfoCard([
            _buildInfoRow('Scheme Name', data['schemes']?['name'] ?? 'N/A'),
            _buildInfoRow('Benefit Amount',
                '₹${data['schemes']?['benefit_amount'] ?? '0'}'),
            _buildInfoRow('Tracking ID', data['tracking_id'] ?? 'N/A'),
            _buildInfoRow('Status', data['status'] ?? 'N/A'),
            _buildInfoRow('Applied On', _formatDate(data['created_at'])),
          ]),

          const SizedBox(height: 16),

          // Documents Section
          _buildSectionHeader('Attached Documents'),
          if (attachedDocs.isEmpty)
            _buildInfoCard([const Text('No documents attached.')])
          else
            _buildInfoCard(
              attachedDocs.map((doc) {
                final Map<String, dynamic> docMap = doc as Map<String, dynamic>;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.description, color: AppColors.primary),
                  title: Text(docMap['document_type'] ?? 'Document'),
                  subtitle: Text(docMap['filename'] ?? ''),
                  trailing:
                      const Icon(Icons.open_in_new, color: AppColors.primary),
                  onTap: () async {
                    String? urlStr = docMap['signed_url'] ?? docMap['file_url'];

                    final farmerId = data['farmer_id'];
                    final filename = docMap['filename'];

                    if (farmerId != null && filename != null) {
                      try {
                        urlStr = await SupabaseConfig.client.storage
                            .from('farmer-$farmerId')
                            .createSignedUrl(filename, 60 * 60); // 1 hour valid
                      } catch (e) {
                        debugPrint('Failed to get signed URL: $e');
                      }
                    }

                    if (urlStr != null && urlStr.isNotEmpty) {
                      final url = Uri.tryParse(urlStr);
                      if (url != null && await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open document URL.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Document link not available.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                );
              }).toList(),
            ),

          const SizedBox(height: 16),
          _buildSectionHeader('Admin Notes'),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add notes here before approving/rejecting...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _showRejectDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Reject',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Approve',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}