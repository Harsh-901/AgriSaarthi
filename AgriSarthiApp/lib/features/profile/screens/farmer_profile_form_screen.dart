import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/dropdown_data.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/farmer_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class FarmerProfileFormScreen extends StatefulWidget {
  const FarmerProfileFormScreen({super.key});

  @override
  State<FarmerProfileFormScreen> createState() =>
      _FarmerProfileFormScreenState();
}

class _FarmerProfileFormScreenState extends State<FarmerProfileFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FarmerService _farmerService = FarmerService();
  final DocumentService _documentService = DocumentService();

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _landSizeController = TextEditingController();

  // Selected dropdown values
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCrop;
  String? _selectedLanguage;

  // Loading state
  bool _isLoading = false;

  // Districts based on selected state
  List<String> _availableDistricts = [];

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingProfile();
    });
  }

  Future<void> _loadExistingProfile() async {
    final profile = await _farmerService.getFarmerProfile();
    if (profile != null && mounted) {
      setState(() {
        _fullNameController.text = profile.fullName;
        _villageController.text = profile.village;
        _landSizeController.text = profile.landSize.toString();
        _selectedState = profile.state.isNotEmpty ? profile.state : null;
        _selectedDistrict =
            profile.district.isNotEmpty ? profile.district : null;
        _selectedCrop =
            profile.primaryCrop.isNotEmpty ? profile.primaryCrop : null;
        _selectedLanguage = profile.preferredLanguage.isNotEmpty
            ? profile.preferredLanguage
            : null;

        if (_selectedState != null) {
          _availableDistricts =
              DropdownData.getDistrictsForState(_selectedState!);
        }
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _villageController.dispose();
    _landSizeController.dispose();
    super.dispose();
  }

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      if (state != null) {
        _availableDistricts = DropdownData.getDistrictsForState(state);
      } else {
        _availableDistricts = [];
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      _showError('Please select your state');
      return;
    }
    if (_selectedDistrict == null) {
      _showError('Please select your district');
      return;
    }
    if (_selectedCrop == null) {
      _showError('Please select your primary crop');
      return;
    }
    if (_selectedLanguage == null) {
      _showError('Please select your preferred language');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      // Use 10-digit phone number (without country code) for database
      final phoneNumber = authProvider.displayPhoneNumber;

      final profile = FarmerProfile(
        phoneNumber: phoneNumber,
        fullName: _fullNameController.text.trim(),
        state: _selectedState!,
        district: _selectedDistrict!,
        village: _villageController.text.trim(),
        landSize: double.tryParse(_landSizeController.text.trim()) ?? 0.0,
        primaryCrop: _selectedCrop!,
        preferredLanguage: _selectedLanguage!,
      );

      final savedProfile = await _farmerService.saveFarmerProfile(profile);

      // Update farmer ID in auth provider if available
      if (savedProfile?.id != null) {
        authProvider.setFarmerId(savedProfile!.id!);

        // Create Supabase storage bucket for this farmer
        debugPrint(
            'ProfileForm: Creating bucket for farmer ${savedProfile.id}');
        await _documentService.createFarmerBucket(savedProfile.id!);
      }

      // Mark profile as complete
      authProvider.setProfileComplete(true);

      if (mounted) {
        _showSuccess('Profile saved successfully!');
        // Navigate to document upload screen
        context.go(AppRouter.documentUpload);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    // Display phone (10 digits) for the UI
    final displayPhone = authProvider.displayPhoneNumber.isNotEmpty
        ? authProvider.displayPhoneNumber
        : 'Phone number not available';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Tell us about yourself',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Phone Number (read-only, verified)
                _buildLabel('Phone Number'),
                _buildReadOnlyField(displayPhone),
                const SizedBox(height: 20),

                // Full Name
                _buildLabel('Full Name'),
                _buildTextField(
                  controller: _fullNameController,
                  hintText: 'Enter your full name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // State
                _buildLabel('State'),
                _buildDropdown(
                  value: _selectedState,
                  hintText: 'Select your state',
                  items: DropdownData.states,
                  icon: Icons.location_on_outlined,
                  onChanged: _onStateChanged,
                ),
                const SizedBox(height: 20),

                // District
                _buildLabel('District'),
                _buildDropdown(
                  value: _selectedDistrict,
                  hintText: 'Select your district',
                  items: _availableDistricts,
                  icon: Icons.location_on_outlined,
                  onChanged: (value) {
                    setState(() {
                      _selectedDistrict = value;
                    });
                  },
                  enabled: _selectedState != null,
                ),
                const SizedBox(height: 20),

                // Village
                _buildLabel('Village'),
                _buildTextField(
                  controller: _villageController,
                  hintText: 'Enter your village name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your village name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Land Size
                _buildLabel('Land Size (in acres)'),
                _buildTextField(
                  controller: _landSizeController,
                  hintText: 'e.g., 5.5',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your land size';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Primary Crop Type
                _buildLabel('Primary Crop Type'),
                _buildDropdown(
                  value: _selectedCrop,
                  hintText: 'Select primary crop',
                  items: DropdownData.cropTypes,
                  icon: Icons.grass_outlined,
                  onChanged: (value) {
                    setState(() {
                      _selectedCrop = value;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Preferred Language
                _buildLabel('Preferred Language'),
                _buildLanguageDropdown(),
                const SizedBox(height: 32),

                // Continue Button
                _buildContinueButton(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hintText,
    required List<String> items,
    required IconData icon,
    required void Function(String?)? onChanged,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textHint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
          hint: Text(
            hintText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Special dropdown for language that shows display names but stores lowercase values
  Widget _buildLanguageDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedLanguage,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.language_outlined, color: AppColors.textHint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
          hint: Text(
            'Select preferred language',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
          items: DropdownData.languageValues.map((langValue) {
            return DropdownMenuItem<String>(
              value: langValue,
              child: Text(
                DropdownData.getLanguageDisplayName(langValue),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLanguage = value;
            });
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Continue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }
}
