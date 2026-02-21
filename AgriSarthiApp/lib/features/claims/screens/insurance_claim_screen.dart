import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
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
    final result = await _claimsService.acknowledgeAlert(_alertId!, hasDamage);
    if (!mounted) return;
    if (hasDamage && result['success'] == true) {
      _goToStep(1);
    } else if (!hasDamage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('claims.crops_safe_msg'.tr()),
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
        _hoursRemaining = (result['data']['hours_remaining'] ?? 72).toDouble();
        _startDeadlineTimer();
        _goToStep(2);
      }
    });

    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'claims.failed_create_claim'.tr()),
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
        _uploadedPhotoCount =
            result['data']?['total_photos'] ?? _uploadedPhotoCount + 1;
      }
    });

    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'claims.upload_failed'.tr()),
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
        _uploadedPhotoCount =
            result['data']?['total_photos'] ?? _uploadedPhotoCount + 1;
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
    if (result == null ||
        result.files.isEmpty ||
        result.files.single.path == null) return;

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
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('claims.submit_confirm_title'.tr()),
          ],
        ),
        content: Text(
          'claims.submit_confirm_msg'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('claims.review_again'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('claims.yes_submit'.tr()),
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
          content: Text(result['message'] ?? 'claims.submission_failed'.tr()),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text(
              'claims.claim_submitted'.tr(),
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${'claims.label_claim_id'.tr()}: ${_claimReadableId ?? ''}',
              style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'claims.claim_submitted_msg'.tr(),
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
            child: Text('claims.done'.tr()),
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
        title: Text('claims.title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          // Language selector
          _buildLanguageSelector(context),
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
                      AppColors.error.withValues(
                          alpha: 0.8 + _pulseController.value * 0.2),
                      AppColors.error.withValues(alpha: 0.6),
                    ]
                  : [
                      AppColors.secondary,
                      AppColors.secondary.withValues(alpha: 0.7)
                    ],
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
                '⏰ ${_hoursRemaining.toStringAsFixed(1)} ${'claims.hours_remaining'.tr()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                urgent ? 'claims.urgent'.tr() : 'claims.deadline_72hr'.tr(),
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

  Widget _buildLanguageSelector(BuildContext context) {
    final currentLocale = context.locale;
    final languages = {
      const Locale('en'): '🇬🇧 English',
      const Locale('hi'): '🇮🇳 हिंदी',
      const Locale('mr'): '🇮🇳 मराठी',
    };
    return PopupMenuButton<Locale>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              currentLocale.languageCode.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
      onSelected: (locale) {
        context.setLocale(locale);
      },
      itemBuilder: (ctx) => languages.entries.map((e) {
        final isSelected = e.key == currentLocale;
        return PopupMenuItem<Locale>(
          value: e.key,
          child: Row(
            children: [
              Text(e.value,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
              if (isSelected) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      'claims.step_weather'.tr(),
      'claims.step_form'.tr(),
      'claims.step_photos'.tr(),
      'claims.step_docs'.tr(),
      'claims.step_submit'.tr(),
    ];
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
                      color: isCompleted ? AppColors.success : AppColors.border,
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
    final stepNames = [
      'claims.step_name_weather'.tr(),
      'claims.step_name_form'.tr(),
      'claims.step_name_photos'.tr(),
      'claims.step_name_docs'.tr(),
      'claims.step_name_submit'.tr(),
    ];
    final stepIcons = [
      Icons.cloud_done,
      Icons.description,
      Icons.camera_alt,
      Icons.folder,
      Icons.send
    ];

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
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.success),
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
        return _alertDetected
            ? '⚠️ ${'claims.weather_alert'.tr()}: ${_selectedLossType.toUpperCase()}'
            : '✅ ${'claims.weather_normal_check'.tr()}';
      case 1:
        return '✅ ${'claims.label_claim_id'.tr()} ${_claimReadableId ?? ''} ${'claims.claim_created'.tr()}';
      case 2:
        return '✅ $_uploadedPhotoCount ${'claims.photos_count'.tr()}';
      case 3:
        final complete = _docsResult?['data']?['documents_complete'] == true;
        return complete
            ? '✅ ${'claims.all_docs_attached'.tr()}'
            : '⚠️ ${'claims.some_docs_missing_summary'.tr()}';
      default:
        return '✅ ${'claims.completed'.tr()}';
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
        _summaryRow(
            'claims.label_location'.tr(), _weatherResult?['location'] ?? '-'),
        _summaryRow('claims.temp'.tr(), '${weather['temp_c'] ?? '-'}°C'),
        _summaryRow('claims.humidity'.tr(), '${weather['humidity'] ?? '-'}%'),
        _summaryRow(
            'claims.label_condition'.tr(), weather['condition_text'] ?? '-'),
        if (_alertDetected)
          _summaryRow('claims.weather_alert'.tr(),
              '${_selectedLossType.replaceAll('_', ' ').toUpperCase()} ${'claims.alert_detected'.tr()}'),
      ],
    );
  }

  Widget _buildFormSummaryContent() {
    return Column(
      children: [
        _summaryRow('claims.label_claim_id'.tr(), _claimReadableId ?? '-'),
        _summaryRow('claims.label_loss_type'.tr(),
            _selectedLossType.replaceAll('_', ' ').toUpperCase()),
        _summaryRow('claims.label_area_affected'.tr(),
            '${_areaController.text} ${'claims.acres'.tr()}'),
        _summaryRow(
            'claims.label_survey_number'.tr(),
            _surveyNumberController.text.isNotEmpty
                ? _surveyNumberController.text
                : '-'),
        if (_descriptionController.text.isNotEmpty)
          _summaryRow(
              'claims.label_description'.tr(), _descriptionController.text),
      ],
    );
  }

  Widget _buildEvidenceSummaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow(
            'claims.label_photos_uploaded'.tr(), '$_uploadedPhotoCount'),
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
        _summaryRow('claims.attached'.tr(),
            '$attached ${'claims.document_count'.tr()}'),
        if (missing.isNotEmpty)
          _summaryRow('claims.label_missing'.tr(), missing.join(', ')),
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
          title: 'claims.check_weather_title'.tr(),
          subtitle: 'claims.check_weather_desc'.tr(),
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
            label: Text(_isCheckingWeather
                ? 'claims.checking'.tr()
                : 'claims.check_weather_btn'.tr()),
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
            label: Text('claims.file_claim_manually'.tr()),
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
                    child: Text('claims.no_damage_btn'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acknowledgeAlert(true),
                    icon: const Icon(Icons.warning_amber),
                    label: Text('claims.yes_damaged_btn'.tr()),
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
              title: 'claims.weather_normal_title'.tr(),
              subtitle: _weatherResult?['message'] ??
                  'claims.extreme_weather_detected'.tr(),
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.edit_note),
              label: Text('claims.file_claim_manually_anyway'.tr()),
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
                  _weatherResult?['location'] ?? 'claims.your_location'.tr(),
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
              _weatherStat(
                  '🌡️', '${weather['temp_c'] ?? '-'}°C', 'claims.temp'.tr()),
              _weatherStat('💧', '${weather['humidity'] ?? '-'}%',
                  'claims.humidity'.tr()),
              _weatherStat('🌧️', '${weather['precip_mm'] ?? '-'}mm',
                  'claims.rain'.tr()),
              _weatherStat('💨', '${weather['wind_kph'] ?? '-'}km/h',
                  'claims.wind'.tr()),
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
                  '⚠️ ${'claims.weather_alert'.tr()}: ${(alert['type'] ?? '').toString().toUpperCase()}',
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
            alert['message'] ??
                alert['details'] ??
                'claims.extreme_weather_detected'.tr(),
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
              '${'claims.severity'.tr()}: ${alert['severity'] ?? 'High'}',
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
          title: 'claims.pmfby_form_title'.tr(),
          subtitle: 'claims.pmfby_form_desc'.tr(),
          color: AppColors.primary,
        ),
        const SizedBox(height: 20),

        // Loss Type Dropdown
        DropdownButtonFormField<String>(
          value: _selectedLossType,
          decoration: InputDecoration(
            labelText: 'claims.loss_type_label'.tr(),
            prefixIcon: const Icon(Icons.category),
          ),
          items: [
            DropdownMenuItem(
                value: 'flood', child: Text('claims.loss_flood'.tr())),
            DropdownMenuItem(
                value: 'drought', child: Text('claims.loss_drought'.tr())),
            DropdownMenuItem(
                value: 'hailstorm', child: Text('claims.loss_hailstorm'.tr())),
            DropdownMenuItem(
                value: 'heavy_rain',
                child: Text('claims.loss_heavy_rain'.tr())),
            DropdownMenuItem(
                value: 'cyclone', child: Text('claims.loss_cyclone'.tr())),
            DropdownMenuItem(
                value: 'frost', child: Text('claims.loss_frost'.tr())),
            DropdownMenuItem(
                value: 'pest_attack',
                child: Text('claims.loss_pest_attack'.tr())),
            DropdownMenuItem(
                value: 'other', child: Text('claims.loss_other'.tr())),
          ],
          onChanged: (v) => setState(() => _selectedLossType = v ?? 'flood'),
        ),
        const SizedBox(height: 16),

        // Survey Number
        TextField(
          controller: _surveyNumberController,
          decoration: InputDecoration(
            labelText: 'claims.survey_number_label'.tr(),
            prefixIcon: const Icon(Icons.pin),
            hintText: 'claims.survey_number_hint'.tr(),
          ),
        ),
        const SizedBox(height: 16),

        // Area Affected
        TextField(
          controller: _areaController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'claims.area_affected_label'.tr(),
            prefixIcon: const Icon(Icons.landscape),
            hintText: 'claims.area_affected_hint'.tr(),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'claims.damage_desc_label'.tr(),
            prefixIcon: const Icon(Icons.text_snippet),
            hintText: 'claims.damage_desc_hint'.tr(),
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
            _isCreatingClaim
                ? 'claims.creating'.tr()
                : 'claims.generate_claim_btn'.tr(),
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
          title: 'claims.upload_photos_title'.tr(),
          subtitle: 'claims.upload_photos_desc'.tr(),
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
                '$_uploadedPhotoCount ${'claims.photos_uploaded'.tr()}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _uploadedPhotoCount >= 1
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              if (_uploadedPhotoCount < 1) ...[
                const Spacer(),
                Text(
                  'claims.min_required'.tr(),
                  style: const TextStyle(
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
                label: Text('claims.camera'.tr()),
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
                label: Text('claims.gallery'.tr()),
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
            label: Text('claims.next_attach_docs'.tr()),
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
          title: 'claims.attach_docs_title'.tr(),
          subtitle: 'claims.attach_docs_desc'.tr(),
          color: AppColors.info,
        ),
        const SizedBox(height: 20),

        // Loading state
        if (_isAttachingDocs)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('claims.auto_attaching'.tr(),
                      style: const TextStyle(color: AppColors.textSecondary)),
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
                        ? 'claims.all_docs_found'.tr()
                        : 'claims.some_docs_missing'.tr(),
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
              return _buildDocRow(DocumentType.getDisplayName(name),
                  Icons.check_circle, AppColors.success, null);
            }),

          // Show missing documents with upload buttons
          if (_docsResult?['data']?['missing'] != null &&
              (_docsResult!['data']['missing'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'claims.missing_documents'.tr(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.error),
            ),
            const SizedBox(height: 8),
            ...(_docsResult!['data']['missing'] as List).map((docType) {
              final name = docType is Map
                  ? docType['document_type'] ?? docType.toString()
                  : docType.toString();
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
            onPressed: _isAttachingDocs
                ? null
                : () {
                    _autoAttachTriggered = false;
                    _attachDocuments();
                  },
            icon: const Icon(Icons.refresh),
            label: Text('claims.rescan_docs'.tr()),
          ),

          const SizedBox(height: 12),

          // Proceed button
          ElevatedButton.icon(
            onPressed: () => _goToStep(4),
            icon: const Icon(Icons.arrow_forward),
            label: Text('claims.next_review_submit'.tr()),
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
            label: Text('claims.attach_from_vault'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildDocRow(
      String name, IconData icon, Color color, VoidCallback? onUpload) {
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
              label: Text('claims.upload'.tr(),
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundColor: AppColors.primary,
              ),
            ),
          if (color == AppColors.success)
            Text('claims.attached'.tr(),
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
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
          title: 'claims.claim_preview_title'.tr(),
          subtitle: 'claims.claim_preview_desc'.tr(),
          color: AppColors.primaryDark,
        ),
        const SizedBox(height: 20),

        // ── Section 1: Weather Data ──
        _buildPreviewSection(
          'claims.section_weather_alert'.tr(),
          Icons.cloud,
          AppColors.info,
          [
            _summaryRow('claims.label_location'.tr(),
                _weatherResult?['location'] ?? '-'),
            _summaryRow('claims.label_condition'.tr(),
                _weatherResult?['weather']?['condition_text'] ?? '-'),
            _summaryRow('claims.label_temperature'.tr(),
                '${_weatherResult?['weather']?['temp_c'] ?? '-'}°C'),
            if (_alertDetected)
              _summaryRow('claims.label_alert_type'.tr(),
                  _selectedLossType.replaceAll('_', ' ').toUpperCase()),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 2: Claim Details ──
        _buildPreviewSection(
          'claims.section_claim_details'.tr(),
          Icons.description,
          AppColors.primary,
          [
            _summaryRow('claims.label_claim_id'.tr(), _claimReadableId ?? '-'),
            _summaryRow(
                'claims.label_scheme'.tr(), 'claims.pmfby_scheme_name'.tr()),
            _summaryRow('claims.label_loss_type'.tr(),
                _selectedLossType.replaceAll('_', ' ').toUpperCase()),
            _summaryRow('claims.label_area_affected'.tr(),
                '${_areaController.text} ${'claims.acres'.tr()}'),
            _summaryRow(
                'claims.label_survey_number'.tr(),
                _surveyNumberController.text.isNotEmpty
                    ? _surveyNumberController.text
                    : '-'),
            if (_descriptionController.text.isNotEmpty)
              _summaryRow(
                  'claims.label_description'.tr(), _descriptionController.text),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 3: Evidence Photos ──
        _buildPreviewSection(
          'claims.section_evidence'.tr(),
          Icons.camera_alt,
          AppColors.secondary,
          [
            _summaryRow(
                'claims.label_photos_uploaded'.tr(), '$_uploadedPhotoCount'),
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
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 12),
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
          'claims.section_documents'.tr(),
          Icons.folder,
          _docsResult?['data']?['documents_complete'] == true
              ? AppColors.success
              : AppColors.warning,
          [
            _summaryRow(
              'claims.label_status'.tr(),
              _docsResult?['data']?['documents_complete'] == true
                  ? 'claims.status_all_attached'.tr()
                  : 'claims.status_partially'.tr(),
            ),
            _summaryRow('claims.label_attached_count'.tr(),
                '${_docsResult?['data']?['attached_count'] ?? 0}'),
            if (_docsResult?['data']?['missing'] != null &&
                (_docsResult!['data']['missing'] as List).isNotEmpty)
              _summaryRow('claims.label_missing'.tr(),
                  (_docsResult!['data']['missing'] as List).join(', ')),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 5: Deadline ──
        _buildPreviewSection(
          'claims.section_deadline'.tr(),
          _hoursRemaining < 24 ? Icons.timer_off : Icons.timer,
          _hoursRemaining < 24 ? AppColors.error : AppColors.primary,
          [
            _summaryRow('claims.label_time_remaining'.tr(),
                '${_hoursRemaining.toStringAsFixed(1)} ${'claims.hours_remaining'.tr()}'),
            _summaryRow(
                'claims.label_status'.tr(),
                _hoursRemaining < 24
                    ? 'claims.status_urgent'.tr()
                    : 'claims.status_within_deadline'.tr()),
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
            _isSubmitting
                ? 'claims.submitting'.tr()
                : 'claims.submit_claim_btn'.tr(),
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
                Text(
                  'claims.pmfby_json_output'.tr(),
                  style: const TextStyle(
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

  Widget _buildPreviewSection(
      String title, IconData icon, Color color, List<Widget> children) {
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
              Text(
                title,
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
