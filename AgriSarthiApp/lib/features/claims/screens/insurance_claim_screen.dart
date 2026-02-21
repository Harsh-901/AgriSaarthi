import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/claims_service.dart';
import '../../../core/services/document_service.dart';
import '../../../core/theme/app_theme.dart';

/// Multi-step guided insurance claim wizard.
/// Steps: Weather Check → Auto-Fill Form → Upload Evidence → Attach Docs → Review & Submit
class InsuranceClaimScreen extends StatefulWidget {
  const InsuranceClaimScreen({super.key});

  @override
  State<InsuranceClaimScreen> createState() => _InsuranceClaimScreenState();
}

class _InsuranceClaimScreenState extends State<InsuranceClaimScreen>
    with TickerProviderStateMixin {
  final ClaimsService _claimsService = ClaimsService();
  final DocumentService _documentService = DocumentService();
  int _currentStep = 0;

  // Track which completed steps are expanded
  final Set<int> _expandedSteps = {};

  // Step 0: Weather check state
  bool _isCheckingWeather = false;
  Map<String, dynamic>? _weatherResult;
  bool _alertDetected = false;
  String? _alertId;

  // Step 1: Claim form state
  bool _isCreatingClaim = false;
  Map<String, dynamic>? _claimData;
  String? _claimId; // UUID
  String? _claimReadableId; // CLM-2026-XXXXX
  final _lossTypeController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _surveyNumberController = TextEditingController();
  String _selectedLossType = 'flood';

  // Step 2: Evidence photos
  final List<File> _evidencePhotos = [];
  bool _isUploadingPhoto = false;
  int _uploadedPhotoCount = 0;

  // Step 3: Documents
  bool _isAttachingDocs = false;
  bool _autoAttachTriggered = false;
  Map<String, dynamic>? _docsResult;
  bool _isUploadingMissingDoc = false;

  // Step 4: Submit
  bool _isSubmitting = false;
  Map<String, dynamic>? _submitResult;

  // Deadline
  double _hoursRemaining = 72;
  Timer? _deadlineTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lossTypeController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    _surveyNumberController.dispose();
    _deadlineTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startDeadlineTimer() {
    _deadlineTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _hoursRemaining > 0) {
        setState(() {
          _hoursRemaining -= 1 / 60;
        });
      }
    });
  }

  // ─── Step 0: Check Weather ─────────────────────────
  Future<void> _checkWeather() async {
    setState(() => _isCheckingWeather = true);
    final result = await _claimsService.checkWeather();
    if (!mounted) return;
    setState(() {
      _isCheckingWeather = false;
      _weatherResult = result;
      _alertDetected = result['alert_detected'] == true;
      if (_alertDetected && result['alert'] != null) {
        _alertId = result['alert']['alert_id'];
        _selectedLossType = result['alert']['type'] ?? 'flood';
      }
    });
  }

  Future<void> _acknowledgeAlert(bool hasDamage) async {
    if (_alertId == null) return;
    final result =
        await _claimsService.acknowledgeAlert(_alertId!, hasDamage);
    if (!mounted) return;
    if (hasDamage && result['success'] == true) {
      _goToStep(1);
    } else if (!hasDamage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Glad your crops are safe! 🌾'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // ─── Step 1: Create Claim ──────────────────────────
  Future<void> _createClaim() async {
    setState(() => _isCreatingClaim = true);
    final result = await _claimsService.createClaim(
      alertId: _alertId,
      lossType: _selectedLossType,
      areaAffected: double.tryParse(_areaController.text) ?? 0,
      damageDescription: _descriptionController.text,
      surveyNumber: _surveyNumberController.text,
    );
    if (!mounted) return;
    setState(() {
      _isCreatingClaim = false;
      if (result['success'] == true && result['data'] != null) {
        _claimData = result['data'];
        _claimId = result['data']['id'];
        _claimReadableId = result['data']['claim_id'];
        _hoursRemaining =
            (result['data']['hours_remaining'] ?? 72).toDouble();
        _startDeadlineTimer();
        _goToStep(2);
      }
    });

    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to create claim'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ─── Step 2: Upload Evidence ───────────────────────
  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (pickedFile == null || _claimId == null) return;

    final file = File(pickedFile.path);
    setState(() {
      _evidencePhotos.add(file);
      _isUploadingPhoto = true;
    });

    final result = await _claimsService.uploadEvidence(_claimId!, file);
    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
      if (result['success'] == true) {
        _uploadedPhotoCount = result['data']?['total_photos'] ?? _uploadedPhotoCount + 1;
      }
    });

    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Upload failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (pickedFile == null || _claimId == null) return;

    final file = File(pickedFile.path);
    setState(() {
      _evidencePhotos.add(file);
      _isUploadingPhoto = true;
    });

    final result = await _claimsService.uploadEvidence(_claimId!, file);
    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
      if (result['success'] == true) {
        _uploadedPhotoCount = result['data']?['total_photos'] ?? _uploadedPhotoCount + 1;
      }
    });
  }

  // ─── Step 3: Attach Documents ──────────────────────
  Future<void> _attachDocuments() async {
    if (_claimId == null) return;
    setState(() => _isAttachingDocs = true);

    final result = await _claimsService.attachDocuments(_claimId!);
    if (!mounted) return;

    setState(() {
      _isAttachingDocs = false;
      _docsResult = result;
      // Don't auto-advance — let user see results and upload missing docs if needed
    });
  }

  // Navigate to a step with auto-triggers
  void _goToStep(int step) {
    setState(() => _currentStep = step);
    // Auto-attach documents when reaching step 3
    if (step == 3 && !_autoAttachTriggered) {
      _autoAttachTriggered = true;
      _attachDocuments();
    }
  }

  // Upload a missing document inline
  Future<void> _uploadMissingDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() => _isUploadingMissingDoc = true);

    try {
      await _documentService.uploadSingleDocument(docType, file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${DocumentType.getDisplayName(docType)} uploaded ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      // Re-attach to refresh document status
      await _attachDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _isUploadingMissingDoc = false);
  }

  // ─── Step 4: Submit ────────────────────────────────
  Future<void> _submitClaim() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Submit Claim?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to submit this claim for verification?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Review Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_claimId == null) return;
    setState(() => _isSubmitting = true);

    final result = await _claimsService.submitClaim(_claimId!);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _submitResult = result;
    });

    if (result['success'] == true && mounted) {
      _showSuccessDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Submission failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text(
              'Claim Submitted!',
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Claim ID: ${_claimReadableId ?? ''}',
              style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your claim has been submitted for admin verification.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
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
        title: const Text('Insurance Claim'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_claimReadableId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _claimReadableId!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Deadline banner
          if (_claimId != null) _buildDeadlineBanner(),

          // Step indicator
          _buildStepIndicator(),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepsWithHistory(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineBanner() {
    final urgent = _hoursRemaining < 24;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: urgent
                  ? [
                      AppColors.error
                          .withValues(alpha: 0.8 + _pulseController.value * 0.2),
                      AppColors.error.withValues(alpha: 0.6),
                    ]
                  : [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.7)],
            ),
          ),
          child: Row(
            children: [
              Icon(
                urgent ? Icons.timer_off : Icons.timer,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '⏰ ${_hoursRemaining.toStringAsFixed(1)} hours remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                urgent ? 'URGENT!' : '72hr Deadline',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Weather', 'Form', 'Photos', 'Docs', 'Submit'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isCompleted
                            ? AppColors.success
                            : isActive
                                ? AppColors.primary
                                : AppColors.border,
                        child: isCompleted
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    flex: 0,
                    child: Container(
                      height: 2,
                      width: 20,
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Build all steps with history ──────────────────
  Widget _buildStepsWithHistory() {
    return Column(
      children: [
        // Completed steps as collapsible summaries
        for (int i = 0; i < _currentStep; i++) ...[
          _buildCompletedStepSummary(i),
          const SizedBox(height: 12),
        ],
        // Active step
        _buildActiveStep(),
      ],
    );
  }

  Widget _buildCompletedStepSummary(int step) {
    final isExpanded = _expandedSteps.contains(step);
    final stepNames = ['Weather Check', 'Claim Form', 'Evidence Photos', 'Documents', 'Submit'];
    final stepIcons = [Icons.cloud_done, Icons.description, Icons.camera_alt, Icons.folder, Icons.send];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedSteps.remove(step);
              } else {
                _expandedSteps.add(step);
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(stepIcons[step], color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${step + 1}: ${stepNames[step]}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _getCompletedStepSubtitle(step),
                          style: const TextStyle(fontSize: 12, color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildExpandedContent(step),
            ),
          ],
        ],
      ),
    );
  }

  String _getCompletedStepSubtitle(int step) {
    switch (step) {
      case 0:
        return _alertDetected ? '⚠️ Alert: ${_selectedLossType.toUpperCase()}' : '✅ Weather normal';
      case 1:
        return '✅ Claim ${_claimReadableId ?? ''} created';
      case 2:
        return '✅ $_uploadedPhotoCount photo(s) uploaded';
      case 3:
        final complete = _docsResult?['data']?['documents_complete'] == true;
        return complete ? '✅ All documents attached' : '⚠️ Some documents missing';
      default:
        return '✅ Completed';
    }
  }

  Widget _buildExpandedContent(int step) {
    switch (step) {
      case 0:
        return _buildWeatherSummaryContent();
      case 1:
        return _buildFormSummaryContent();
      case 2:
        return _buildEvidenceSummaryContent();
      case 3:
        return _buildDocsSummaryContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWeatherSummaryContent() {
    final weather = _weatherResult?['weather'] ?? {};
    return Column(
      children: [
        _summaryRow('Location', _weatherResult?['location'] ?? '-'),
        _summaryRow('Temp', '${weather['temp_c'] ?? '-'}°C'),
        _summaryRow('Humidity', '${weather['humidity'] ?? '-'}%'),
        _summaryRow('Condition', weather['condition_text'] ?? '-'),
        if (_alertDetected)
          _summaryRow('Alert', '${_selectedLossType.replaceAll('_', ' ').toUpperCase()} detected'),
      ],
    );
  }

  Widget _buildFormSummaryContent() {
    return Column(
      children: [
        _summaryRow('Claim ID', _claimReadableId ?? '-'),
        _summaryRow('Loss Type', _selectedLossType.replaceAll('_', ' ').toUpperCase()),
        _summaryRow('Area', '${_areaController.text} acres'),
        _summaryRow('Survey No.', _surveyNumberController.text.isNotEmpty ? _surveyNumberController.text : '-'),
        if (_descriptionController.text.isNotEmpty)
          _summaryRow('Description', _descriptionController.text),
      ],
    );
  }

  Widget _buildEvidenceSummaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Photos Uploaded', '$_uploadedPhotoCount'),
        if (_evidencePhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_evidencePhotos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocsSummaryContent() {
    final attached = _docsResult?['data']?['attached_count'] ?? 0;
    final missing = _docsResult?['data']?['missing'] as List? ?? [];
    return Column(
      children: [
        _summaryRow('Attached', '$attached document(s)'),
        if (missing.isNotEmpty)
          _summaryRow('Missing', missing.join(', ')),
      ],
    );
  }

  Widget _buildActiveStep() {
    switch (_currentStep) {
      case 0:
        return _buildWeatherStep();
      case 1:
        return _buildFormStep();
      case 2:
        return _buildEvidenceStep();
      case 3:
        return _buildDocsStep();
      case 4:
        return _buildSubmitStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── STEP 0: Weather Check ─────────────────────────
  Widget _buildWeatherStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info card
        _buildInfoCard(
          icon: Icons.cloud,
          title: 'Check Weather Conditions',
          subtitle:
              'We\'ll check current weather at your registered location to detect any extreme conditions that may have damaged your crops.',
          color: AppColors.info,
        ),
        const SizedBox(height: 20),

        if (_weatherResult == null) ...[
          // Check weather button
          ElevatedButton.icon(
            onPressed: _isCheckingWeather ? null : _checkWeather,
            icon: _isCheckingWeather
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.satellite_alt),
            label: Text(
                _isCheckingWeather ? 'Checking...' : 'Check Weather Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Manual claim option
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.edit_note),
            label: const Text('File Claim Manually'),
          ),
        ],

        if (_weatherResult != null) ...[
          // Weather data card
          _buildWeatherDataCard(),
          const SizedBox(height: 16),

          if (_alertDetected) ...[
            // Alert card
            _buildAlertCard(),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _acknowledgeAlert(false),
                    child: const Text('No Damage'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acknowledgeAlert(true),
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('Yes, Damaged'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildInfoCard(
              icon: Icons.check_circle,
              title: 'Weather Normal',
              subtitle:
                  _weatherResult?['message'] ?? 'No extreme weather detected.',
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.edit_note),
              label: const Text('File Claim Manually Anyway'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildWeatherDataCard() {
    final weather = _weatherResult?['weather'] ?? {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2980B9), Color(0xFF6DD5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2980B9).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _weatherResult?['location'] ?? 'Your Location',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _weatherStat('🌡️', '${weather['temp_c'] ?? '-'}°C', 'Temp'),
              _weatherStat(
                  '💧', '${weather['humidity'] ?? '-'}%', 'Humidity'),
              _weatherStat(
                  '🌧️', '${weather['precip_mm'] ?? '-'}mm', 'Rain'),
              _weatherStat(
                  '💨', '${weather['wind_kph'] ?? '-'}km/h', 'Wind'),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              weather['condition_text'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAlertCard() {
    final alert = _weatherResult?['alert'] ?? {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ Weather Alert: ${(alert['type'] ?? '').toString().toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert['message'] ?? alert['details'] ?? 'Extreme weather detected!',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Severity: ${alert['severity'] ?? 'High'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 1: Claim Form ────────────────────────────
  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.description,
          title: 'PMFBY Claim Form',
          subtitle:
              'Fill in the details below. Your personal info will be auto-filled from your profile.',
          color: AppColors.primary,
        ),
        const SizedBox(height: 20),

        // Loss Type Dropdown
        DropdownButtonFormField<String>(
          value: _selectedLossType,
          decoration: const InputDecoration(
            labelText: 'Type of Loss',
            prefixIcon: Icon(Icons.category),
          ),
          items: const [
            DropdownMenuItem(value: 'flood', child: Text('Flood')),
            DropdownMenuItem(value: 'drought', child: Text('Drought')),
            DropdownMenuItem(value: 'hailstorm', child: Text('Hailstorm')),
            DropdownMenuItem(
                value: 'heavy_rain', child: Text('Heavy Rainfall')),
            DropdownMenuItem(value: 'cyclone', child: Text('Cyclone')),
            DropdownMenuItem(value: 'frost', child: Text('Frost')),
            DropdownMenuItem(
                value: 'pest_attack', child: Text('Pest Attack')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _selectedLossType = v ?? 'flood'),
        ),
        const SizedBox(height: 16),

        // Survey Number
        TextField(
          controller: _surveyNumberController,
          decoration: const InputDecoration(
            labelText: 'Survey Number (from 7/12 Extract)',
            prefixIcon: Icon(Icons.pin),
            hintText: 'e.g., 123/4',
          ),
        ),
        const SizedBox(height: 16),

        // Area Affected
        TextField(
          controller: _areaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Area Affected (acres)',
            prefixIcon: Icon(Icons.landscape),
            hintText: 'e.g., 2.5',
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Damage Description',
            prefixIcon: Icon(Icons.text_snippet),
            hintText: 'Describe the damage to your crops...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),

        // Create button
        ElevatedButton.icon(
          onPressed: _isCreatingClaim ? null : _createClaim,
          icon: _isCreatingClaim
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_fix_high),
          label: Text(
            _isCreatingClaim ? 'Creating...' : 'Generate Claim Form',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: Upload Evidence ───────────────────────
  Widget _buildEvidenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.camera_alt,
          title: 'Upload Crop Damage Photos',
          subtitle:
              'Take photos of the damaged crops. Photos with location data help strengthen your claim.',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 20),

        // Photo count
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _uploadedPhotoCount >= 1
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _uploadedPhotoCount >= 1
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _uploadedPhotoCount >= 1
                    ? Icons.check_circle
                    : Icons.photo_library,
                color: _uploadedPhotoCount >= 1
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                '$_uploadedPhotoCount photo(s) uploaded',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _uploadedPhotoCount >= 1
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              if (_uploadedPhotoCount < 1) ...[
                const Spacer(),
                const Text(
                  'Min 1 required',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Photo previews
        if (_evidencePhotos.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_evidencePhotos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 14),
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 16),

        // Upload buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                icon: _isUploadingPhoto
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingPhoto ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Next button
        if (_uploadedPhotoCount >= 1)
          ElevatedButton.icon(
            onPressed: () => _goToStep(3),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next: Attach Documents'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }

  // ─── STEP 3: Attach Documents ──────────────────────
  Widget _buildDocsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.folder_open,
          title: 'Attach Required Documents',
          subtitle: 'We automatically pull documents from your uploaded vault.',
          color: AppColors.info,
        ),
        const SizedBox(height: 20),

        // Loading state
        if (_isAttachingDocs)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Auto-attaching documents from your vault...',
                    style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),

        // Results
        if (!_isAttachingDocs && _docsResult != null) ...[
          // Status banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _docsResult?['data']?['documents_complete'] == true
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _docsResult?['data']?['documents_complete'] == true
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _docsResult?['data']?['documents_complete'] == true
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: _docsResult?['data']?['documents_complete'] == true
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _docsResult?['data']?['documents_complete'] == true
                        ? 'All required documents found and attached!'
                        : 'Some documents are missing from your vault',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _docsResult?['data']?['documents_complete'] == true
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Show attached documents
          if (_docsResult?['data']?['attached'] != null)
            ...(_docsResult!['data']['attached'] as List).map((doc) {
              final name = doc['document_type'] ?? doc.toString();
              return _buildDocRow(DocumentType.getDisplayName(name), Icons.check_circle, AppColors.success, null);
            }),

          // Show missing documents with upload buttons
          if (_docsResult?['data']?['missing'] != null &&
              (_docsResult!['data']['missing'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Missing Documents:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            ...(_docsResult!['data']['missing'] as List).map((docType) {
              final name = docType is Map ? docType['document_type'] ?? docType.toString() : docType.toString();
              return _buildDocRow(
                DocumentType.getDisplayName(name),
                Icons.warning_amber_rounded,
                AppColors.warning,
                _isUploadingMissingDoc
                    ? null
                    : () => _uploadMissingDocument(name),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Re-attach button
          OutlinedButton.icon(
            onPressed: _isAttachingDocs ? null : () {
              _autoAttachTriggered = false;
              _attachDocuments();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-scan Documents'),
          ),

          const SizedBox(height: 12),

          // Proceed button
          ElevatedButton.icon(
            onPressed: () => _goToStep(4),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next: Review & Submit'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],

        // Initial state (before auto-attach)
        if (!_isAttachingDocs && _docsResult == null)
          ElevatedButton.icon(
            onPressed: _attachDocuments,
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Documents from Vault'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildDocRow(String name, IconData icon, Color color, VoidCallback? onUpload) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          if (onUpload != null)
            TextButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Upload', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundColor: AppColors.primary,
              ),
            ),
          if (color == AppColors.success)
            const Text('Attached', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── STEP 4: Review & Submit ───────────────────────
  Widget _buildSubmitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.rate_review,
          title: 'Claim Preview',
          subtitle: 'Review all your claim details before final submission.',
          color: AppColors.primaryDark,
        ),
        const SizedBox(height: 20),

        // ── Section 1: Weather Data ──
        _buildPreviewSection(
          'Weather & Alert',
          Icons.cloud,
          AppColors.info,
          [
            _summaryRow('Location', _weatherResult?['location'] ?? '-'),
            _summaryRow('Condition', _weatherResult?['weather']?['condition_text'] ?? '-'),
            _summaryRow('Temperature', '${_weatherResult?['weather']?['temp_c'] ?? '-'}°C'),
            if (_alertDetected)
              _summaryRow('Alert Type', _selectedLossType.replaceAll('_', ' ').toUpperCase()),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 2: Claim Details ──
        _buildPreviewSection(
          'Claim Details',
          Icons.description,
          AppColors.primary,
          [
            _summaryRow('Claim ID', _claimReadableId ?? '-'),
            _summaryRow('Scheme', 'Pradhan Mantri Fasal Bima Yojana'),
            _summaryRow('Loss Type', _selectedLossType.replaceAll('_', ' ').toUpperCase()),
            _summaryRow('Area Affected', '${_areaController.text} acres'),
            _summaryRow('Survey Number', _surveyNumberController.text.isNotEmpty ? _surveyNumberController.text : '-'),
            if (_descriptionController.text.isNotEmpty)
              _summaryRow('Description', _descriptionController.text),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 3: Evidence Photos ──
        _buildPreviewSection(
          'Evidence Photos',
          Icons.camera_alt,
          AppColors.secondary,
          [
            _summaryRow('Photos Uploaded', '$_uploadedPhotoCount'),
          ],
        ),
        if (_evidencePhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                    image: DecorationImage(
                      image: FileImage(_evidencePhotos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),

        // ── Section 4: Documents ──
        _buildPreviewSection(
          'Documents',
          Icons.folder,
          _docsResult?['data']?['documents_complete'] == true
              ? AppColors.success
              : AppColors.warning,
          [
            _summaryRow('Status',
              _docsResult?['data']?['documents_complete'] == true
                  ? 'All attached ✅'
                  : 'Partially attached ⚠️',
            ),
            _summaryRow('Attached Count', '${_docsResult?['data']?['attached_count'] ?? 0}'),
            if (_docsResult?['data']?['missing'] != null &&
                (_docsResult!['data']['missing'] as List).isNotEmpty)
              _summaryRow('Missing', (_docsResult!['data']['missing'] as List).join(', ')),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 5: Deadline ──
        _buildPreviewSection(
          'Deadline',
          _hoursRemaining < 24 ? Icons.timer_off : Icons.timer,
          _hoursRemaining < 24 ? AppColors.error : AppColors.primary,
          [
            _summaryRow('Time Remaining', '${_hoursRemaining.toStringAsFixed(1)} hours'),
            _summaryRow('Status', _hoursRemaining < 24 ? '⚠️ Urgent' : '✅ Within deadline'),
          ],
        ),
        const SizedBox(height: 24),

        // Submit button
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitClaim,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _isSubmitting ? 'Submitting...' : 'Submit Claim for Verification',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
          ),
        ),

        const SizedBox(height: 12),

        // PMFBY JSON output after submission
        if (_submitResult != null &&
            _submitResult!['data']?['claim_json'] != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PMFBY Claim JSON Output:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _submitResult!['data']['claim_json'].toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ────────────────────────────────
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
