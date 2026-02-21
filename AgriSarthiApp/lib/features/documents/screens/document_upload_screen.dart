import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/document_service.dart';
import '../../../core/theme/app_theme.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final DocumentService _documentService = DocumentService();
  final ImagePicker _imagePicker = ImagePicker();

  // Store selected files for each document type
  final Map<String, File?> _selectedFiles = {
    DocumentType.aadhaar: null,
    DocumentType.panCard: null,
    DocumentType.landCertificate: null,
    DocumentType.sevenTwelve: null,
    DocumentType.eightA: null,
    DocumentType.bankPassbook: null,
  };

  // Status for each document
  final Map<String, String> _documentStatus = {
    DocumentType.aadhaar: 'pending',
    DocumentType.panCard: 'pending',
    DocumentType.landCertificate: 'pending',
    DocumentType.sevenTwelve: 'pending',
    DocumentType.eightA: 'pending',
    DocumentType.bankPassbook: 'pending',
  };

  // Other document
  File? _otherDocument;
  String _otherDocumentName = '';
  final TextEditingController _otherDocNameController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _otherDocNameController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // FILE PICKING LOGIC (unchanged)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _pickFromCamera(String docType) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          if (docType == DocumentType.other) {
            _otherDocument = File(image.path);
          } else {
            _selectedFiles[docType] = File(image.path);
            _documentStatus[docType] = 'selected';
          }
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickFromFile(String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (docType == DocumentType.other) {
            _otherDocument = File(result.files.single.path!);
          } else {
            _selectedFiles[docType] = File(result.files.single.path!);
            _documentStatus[docType] = 'selected';
          }
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  bool get _allDocumentsSelected {
    return _selectedFiles.values.every((file) => file != null);
  }

  int get _selectedCount {
    return _selectedFiles.values.where((file) => file != null).length;
  }

  Future<void> _uploadDocuments() async {
    if (!_allDocumentsSelected) {
      _showError('Please select all required documents before uploading');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final documentsToUpload = <String, File>{};
      _selectedFiles.forEach((key, value) {
        if (value != null) {
          documentsToUpload[key] = value;
        }
      });

      if (_otherDocument != null && _otherDocumentName.isNotEmpty) {
        documentsToUpload[DocumentType.other] = _otherDocument!;
      }

      final result = await _documentService.uploadDocuments(documentsToUpload);

      if (result['success'] == true) {
        if (mounted) {
          _showSuccess('Documents uploaded successfully!');
          context.go(AppRouter.farmerHome);
        }
      } else {
        _showError(result['message'] ?? 'Failed to upload documents');
      }
    } catch (e) {
      _showError('Failed to upload documents: $e');
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

  // ════════════════════════════════════════════════════════════════════
  // Icon color for each document type
  // ════════════════════════════════════════════════════════════════════

  Color _getDocIconColor(String docType) {
    switch (docType) {
      case 'aadhaar':
        return const Color(0xFF5C6BC0); // indigo
      case 'pan_card':
        return const Color(0xFF26A69A); // teal
      case 'land_certificate':
        return const Color(0xFFFF7043); // deep orange
      case 'seven_twelve':
        return const Color(0xFFAB47BC); // purple
      case 'eight_a':
        return const Color(0xFF42A5F5); // blue
      case 'bank_passbook':
        return const Color(0xFF66BB6A); // green
      default:
        return const Color(0xFF78909C); // blue-grey
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
          'Upload Documents',
          style: TextStyle(
            color: Color(0xFF1B1B1B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction text
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Please provide clear photos of the original documents.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            // Document list
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    ...DocumentType.compulsory
                        .map((docType) => _buildDocumentCard(docType)),

                    const SizedBox(height: 8),

                    // Other document
                    _buildOtherDocumentCard(),

                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildContinueButton(),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DOCUMENT CARD – matching the screenshot design
  // ════════════════════════════════════════════════════════════════════

  Widget _buildDocumentCard(String docType) {
    final file = _selectedFiles[docType];
    final isSelected = file != null;
    final displayName = DocumentType.getDisplayName(docType);
    final iconColor = _getDocIconColor(docType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Name + Status badge
          Row(
            children: [
              // Document icon in colored circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Name + status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSelected ? 'Uploaded successfully' : 'Required',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? const Color(0xFF43A047)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              _buildStatusBadge(isSelected ? 'uploaded' : 'pending'),
            ],
          ),

          const SizedBox(height: 14),

          // Row 2: Camera + File buttons, or selected file info
          if (isSelected) ...[
            // Show selected file
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file,
                      color: Color(0xFF43A047), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFiles[docType] = null;
                        _documentStatus[docType] = 'pending';
                      });
                    },
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Camera + File buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickFromCamera(docType),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.upload_file_outlined,
                    label: 'File',
                    onTap: () => _pickFromFile(docType),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // OTHER DOCUMENT CARD
  // ════════════════════════════════════════════════════════════════════

  Widget _buildOtherDocumentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_circle_outline,
                    color: Colors.grey.shade500, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Other Document',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Optional',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(
                  _otherDocument != null ? 'uploaded' : 'optional'),
            ],
          ),

          const SizedBox(height: 12),

          // Name input
          TextField(
            controller: _otherDocNameController,
            decoration: InputDecoration(
              hintText: 'Document Name',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.description_outlined,
                  color: Colors.grey.shade400, size: 18),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (value) {
              setState(() {
                _otherDocumentName = value;
              });
            },
          ),

          const SizedBox(height: 12),

          if (_otherDocument != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file,
                      color: Color(0xFF43A047), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _otherDocument!.path.split('/').last,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _otherDocument = null;
                      });
                    },
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickFromCamera(DocumentType.other),
                    muted: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.upload_file_outlined,
                    label: 'File',
                    onTap: () => _pickFromFile(DocumentType.other),
                    muted: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ACTION BUTTON (Camera / File)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            muted ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
        side: BorderSide(
          color: muted ? const Color(0xFFE0E0E0) : const Color(0xFFBDBDBD),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STATUS BADGE
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'uploaded':
      case 'selected':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'UPLOADED';
        break;
      case 'verified':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'VERIFIED';
        break;
      case 'rejected':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFE53935);
        label = 'REJECTED';
        break;
      case 'optional':
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF9E9E9E);
        label = 'OPTIONAL';
        break;
      default: // pending
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  // CONTINUE BUTTON
  // ════════════════════════════════════════════════════════════════════

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '$_selectedCount of 6 documents selected',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (_allDocumentsSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF43A047)),
                          SizedBox(width: 4),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: Color(0xFF43A047),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_allDocumentsSelected ? _uploadDocuments : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _allDocumentsSelected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFBDBDBD),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    : const Text(
                        'Upload Documents',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
