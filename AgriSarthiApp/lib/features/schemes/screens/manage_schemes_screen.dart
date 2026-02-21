import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

class ManageSchemesScreen extends StatefulWidget {
  const ManageSchemesScreen({super.key});

  @override
  State<ManageSchemesScreen> createState() => _ManageSchemesScreenState();
}

class _ManageSchemesScreenState extends State<ManageSchemesScreen> {
  final AdminService _adminService = AdminService();

  List<Map<String, dynamic>> _schemes = [];
  bool _isLoading = true;
  bool _showForm = false;
  bool _isEditing = false;
  String? _editingSchemeId;
  bool _isSaving = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landSizeController = TextEditingController();
  final _benefitAmountController = TextEditingController();
  final _deadlineController = TextEditingController();

  // Dropdown selections
  final List<String> _allStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  final List<String> _allCropTypes = [
    'Rice',
    'Wheat',
    'Cotton',
    'Sugarcane',
    'Soybean',
    'Maize',
    'Pulses',
    'Groundnut',
    'Jowar',
    'Bajra',
    'Vegetables',
    'Fruits',
    'Spices',
    'Other',
  ];

  List<String> _selectedStates = [];
  List<String> _selectedCropTypes = [];

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _landSizeController.dispose();
    _benefitAmountController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _loadSchemes() async {
    setState(() => _isLoading = true);

    final schemes = await _adminService.getAllSchemes();

    if (mounted) {
      setState(() {
        _schemes = schemes;
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _landSizeController.clear();
    _benefitAmountController.clear();
    _deadlineController.clear();
    _selectedStates = [];
    _selectedCropTypes = [];
    _isEditing = false;
    _editingSchemeId = null;
  }

  void _showAddForm() {
    _resetForm();
    setState(() => _showForm = true);
  }

  void _showEditForm(Map<String, dynamic> scheme) {
    _resetForm();
    _nameController.text = scheme['name'] ?? '';
    _descriptionController.text = scheme['description'] ?? '';
    _benefitAmountController.text = (scheme['benefit_amount'] ?? 0).toString();
    _deadlineController.text = scheme['deadline'] ?? '';

    final rules = scheme['eligibility_rules'] as Map<String, dynamic>? ?? {};
    if (rules['max_land_size'] != null) {
      _landSizeController.text = rules['max_land_size'].toString();
    }
    if (rules['states'] is List) {
      _selectedStates = List<String>.from(rules['states']);
    }
    if (rules['crop_types'] is List) {
      _selectedCropTypes = List<String>.from(rules['crop_types']);
    }

    _isEditing = true;
    _editingSchemeId = scheme['id'].toString();
    setState(() => _showForm = true);
  }

  Future<void> _saveScheme() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final eligibilityRules = <String, dynamic>{};
    if (_selectedStates.isNotEmpty) {
      eligibilityRules['states'] = _selectedStates;
    }
    if (_selectedCropTypes.isNotEmpty) {
      eligibilityRules['crop_types'] = _selectedCropTypes;
    }
    if (_landSizeController.text.isNotEmpty) {
      eligibilityRules['max_land_size'] =
          double.tryParse(_landSizeController.text) ?? 0;
    }

    Map<String, dynamic>? result;

    if (_isEditing && _editingSchemeId != null) {
      result = await _adminService.updateScheme(_editingSchemeId!, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'benefit_amount': double.tryParse(_benefitAmountController.text) ?? 0,
        'deadline': _deadlineController.text.isNotEmpty
            ? _deadlineController.text
            : null,
        'eligibility_rules': eligibilityRules,
      });
    } else {
      result = await _adminService.createScheme(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        benefitAmount: double.tryParse(_benefitAmountController.text) ?? 0,
        deadline: _deadlineController.text.isNotEmpty
            ? _deadlineController.text
            : null,
        eligibilityRules: eligibilityRules,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Scheme updated successfully!'
                  : 'Scheme created successfully!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _showForm = false);
        _resetForm();
        await _loadSchemes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save scheme'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      _deadlineController.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_showForm) {
              setState(() => _showForm = false);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _showForm
              ? (_isEditing ? 'Edit Scheme' : 'Manage Schemes')
              : 'Manage Schemes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: !_showForm
          ? FloatingActionButton.extended(
              onPressed: _showAddForm,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Scheme'),
            )
          : null,
      body: _showForm ? _buildSchemeForm() : _buildSchemeList(),
    );
  }

  // ─── SCHEME LIST ──────────────────────────────────────────

  Widget _buildSchemeList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_schemes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'No schemes yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Tap "+ New Scheme" to create one'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchemes,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _schemes.length,
        itemBuilder: (context, index) => _buildSchemeCard(_schemes[index]),
      ),
    );
  }

  Widget _buildSchemeCard(Map<String, dynamic> scheme) {
    final isActive = scheme['is_active'] ?? false;
    final name = scheme['name'] ?? 'Unnamed';
    final benefit = scheme['benefit_amount'] ?? 0;
    final deadline = scheme['deadline'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              if (benefit > 0) ...[
                Text(
                  '₹${_formatCurrency(benefit)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 12),
              ],
              if (deadline != null)
                Text(
                  'Deadline: $deadline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (action) async {
            switch (action) {
              case 'edit':
                _showEditForm(scheme);
                break;
              case 'toggle':
                final success = await _adminService.toggleSchemeStatus(
                  scheme['id'].toString(),
                  !isActive,
                );
                if (success) _loadSchemes();
                break;
              case 'delete':
                _confirmDelete(scheme);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18,
                    color: isActive ? AppColors.warning : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> scheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Scheme'),
        content: Text(
          'Are you sure you want to delete "${scheme['name']}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await _adminService.deleteScheme(scheme['id'].toString());
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scheme deleted'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _loadSchemes();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── SCHEME FORM ──────────────────────────────────────────

  Widget _buildSchemeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scheme Name
            _buildFieldLabel('Scheme Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: _inputDecoration(
                hint: 'e.g., Pradhan Mantri Fasal Bima Yojana',
              ),
            ),
            const SizedBox(height: 20),

            // Description
            _buildFieldLabel('Scheme Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: _inputDecoration(
                hint:
                    'Provide a brief description of the scheme\'s benefits and objectives.',
              ),
            ),
            const SizedBox(height: 20),

            // Eligible States
            _buildFieldLabel('Eligible States/Districts'),
            const SizedBox(height: 6),
            _buildMultiSelect(
              items: _allStates,
              selectedItems: _selectedStates,
              hint: 'Select States and Districts',
              onChanged: (items) => setState(() => _selectedStates = items),
            ),
            const SizedBox(height: 20),

            // Crop Types
            _buildFieldLabel('Crop Types'),
            const SizedBox(height: 6),
            _buildMultiSelect(
              items: _allCropTypes,
              selectedItems: _selectedCropTypes,
              hint: 'Select Applicable Crop Types',
              onChanged: (items) => setState(() => _selectedCropTypes = items),
            ),
            const SizedBox(height: 20),

            // Land Size
            _buildFieldLabel('Land Size Limit (in acres)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _landSizeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(hint: 'e.g., 5'),
            ),
            const SizedBox(height: 20),

            // Benefit Amount
            _buildFieldLabel('Benefit Amount (INR)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _benefitAmountController,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: _inputDecoration(
                hint: 'e.g., 120000',
                prefix: const Text('₹  '),
              ),
            ),
            const SizedBox(height: 20),

            // Deadline
            _buildFieldLabel('Application Deadline'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _deadlineController,
              readOnly: true,
              onTap: _pickDate,
              decoration: _inputDecoration(
                hint: 'YYYY-MM-DD',
                suffix: IconButton(
                  icon: const Icon(Icons.calendar_today,
                      color: AppColors.textHint, size: 20),
                  onPressed: _pickDate,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveScheme,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Scheme' : 'Save Scheme',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      prefixIcon: prefix != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12, right: 0),
              child: prefix,
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  /// Multi-select dropdown using a bottom sheet
  Widget _buildMultiSelect({
    required List<String> items,
    required List<String> selectedItems,
    required String hint,
    required ValueChanged<List<String>> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        _showMultiSelectSheet(
          items: items,
          selectedItems: List.from(selectedItems),
          title: hint,
          onConfirm: onChanged,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: selectedItems.isEmpty
                  ? Text(
                      hint,
                      style: const TextStyle(color: AppColors.textHint),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedItems
                          .map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectSheet({
    required List<String> items,
    required List<String> selectedItems,
    required String title,
    required ValueChanged<List<String>> onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title + Done
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            onConfirm(selectedItems);
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Items
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = selectedItems.contains(item);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(item),
                          activeColor: AppColors.primary,
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                selectedItems.add(item);
                              } else {
                                selectedItems.remove(item);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(dynamic amount) {
    final num = (amount is int) ? amount.toDouble() : (amount as double);
    if (num >= 100000) {
      return '${(num / 100000).toStringAsFixed(num % 100000 == 0 ? 0 : 1)}L';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(num % 1000 == 0 ? 0 : 1)}K';
    }
    return num.toStringAsFixed(0);
  }
}
