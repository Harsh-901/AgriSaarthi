import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'farmer_service.dart';

/// Document types for farmer verification
class DocumentType {
  static const String aadhaar = 'aadhaar';
  static const String panCard = 'pan_card';
  static const String landCertificate = 'land_certificate';
  static const String sevenTwelve = 'seven_twelve';
  static const String eightA = 'eight_a';
  static const String bankPassbook = 'bank_passbook';
  static const String other = 'other';

  static const List<String> compulsory = [
    aadhaar,
    panCard,
    landCertificate,
    sevenTwelve,
    eightA,
    bankPassbook,
  ];

  static String getDisplayName(String type) {
    switch (type) {
      case aadhaar:
        return 'Aadhaar Card';
      case panCard:
        return 'PAN Card';
      case landCertificate:
        return 'Land Certificate';
      case sevenTwelve:
        return '7/12 Extract';
      case eightA:
        return '8A Document';
      case bankPassbook:
        return 'Bank Passbook';
      case other:
        return 'Other Document';
      default:
        return type;
    }
  }
}

/// Model for document upload status
class DocumentModel {
  final String type;
  final String displayName;
  final File? file;
  final String? url;
  final String status; // pending, selected, uploading, uploaded, error

  DocumentModel({
    required this.type,
    required this.displayName,
    this.file,
    this.url,
    this.status = 'pending',
  });
}

/// Service for uploading documents to Supabase Storage
/// Uses Option 2: Per-farmer buckets (farmer-{uuid})
class DocumentService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FarmerService _farmerService = FarmerService();

  static const String _farmerBucketPrefix = 'farmer-';

  /// Get farmer ID from the farmers table
  Future<String?> _getFarmerId() async {
    final profile = await _farmerService.getFarmerProfile();
    return profile?.id;
  }

  /// Get bucket name for a farmer
  static String getBucketName(String farmerId) {
    return '$_farmerBucketPrefix$farmerId';
  }

  /// Create a dedicated storage bucket for a farmer.
  /// This should be called right after the farmer account is created
  /// (after Supabase OTP login + profile save).
  ///
  /// Uses Supabase RPC function 'create_farmer_bucket' which runs with
  /// SECURITY DEFINER privileges (service-role level) to create the bucket.
  Future<bool> createFarmerBucket(String farmerId) async {
    final bucketName = getBucketName(farmerId);

    debugPrint('========== BUCKET CREATION START ==========');
    debugPrint(
        'DocumentService: Creating bucket "$bucketName" for farmer "$farmerId"');

    // Step 1: Check if bucket already exists
    try {
      await _supabase.storage.from(bucketName).list();
      debugPrint('DocumentService: ✅ Bucket $bucketName already exists!');
      return true;
    } catch (e) {
      debugPrint(
          'DocumentService: Bucket does not exist yet (expected). Error: $e');
    }

    // Step 2: Try RPC function (most reliable - uses SECURITY DEFINER)
    try {
      debugPrint('DocumentService: Calling RPC create_farmer_bucket...');
      final result = await _supabase.rpc('create_farmer_bucket', params: {
        'farmer_id': farmerId,
      });
      debugPrint('DocumentService: ✅ RPC returned: $result');
      return true;
    } catch (e) {
      debugPrint('DocumentService: ❌ RPC failed: $e');
    }

    // Step 3: Fallback - Try direct bucket creation
    try {
      debugPrint('DocumentService: Trying direct createBucket...');
      await _supabase.storage.createBucket(
        bucketName,
        const BucketOptions(
          public: true,
          fileSizeLimit: '10485760', // 10MB
          allowedMimeTypes: ['image/*', 'application/pdf'],
        ),
      );
      debugPrint('DocumentService: ✅ Direct bucket creation succeeded!');
      return true;
    } catch (e) {
      debugPrint('DocumentService: ❌ Direct bucket creation also failed: $e');
    }

    debugPrint('========== BUCKET CREATION FAILED ==========');
    return false;
  }

  /// Ensure the per-farmer bucket exists.
  /// Tries to create it if it doesn't exist.
  Future<String> _ensureBucketExists(String farmerId) async {
    final bucketName = getBucketName(farmerId);

    try {
      // 1. Try to list files to see if bucket exists and is accessible
      await _supabase.storage.from(bucketName).list();
      debugPrint(
          'DocumentService: Bucket $bucketName exists and is accessible.');
      return bucketName;
    } catch (e) {
      debugPrint(
          'DocumentService: Bucket $bucketName missing. Attempting to create...');

      // 2. Try to create via RPC first
      final created = await createFarmerBucket(farmerId);
      if (created) {
        return bucketName;
      }

      // 3. If all fails, throw clear error
      throw Exception(
          'Bucket "$bucketName" not found and could not be created automatically.\n'
          'Please ensure the create_farmer_bucket RPC function exists in your Supabase project.');
    }
  }

  /// Upload all documents to the farmer's specific bucket
  Future<Map<String, dynamic>> uploadDocuments(
    Map<String, File> documents, {
    String? otherDocumentName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final farmerId = await _getFarmerId();
    if (farmerId == null) {
      throw Exception(
          'Farmer profile not found. Please complete your profile first.');
    }

    // Validate compulsory documents
    for (final docType in DocumentType.compulsory) {
      if (!documents.containsKey(docType)) {
        throw Exception(
            'Missing required document: ${DocumentType.getDisplayName(docType)}');
      }
    }

    // Ensure bucket exists
    final bucketName = await _ensureBucketExists(farmerId);
    debugPrint('DocumentService: Uploading to bucket: $bucketName');

    final uploadedDocs = <String, String>{};
    final errors = <String>[];

    // Upload each document
    for (final entry in documents.entries) {
      try {
        final docType = entry.key;
        final file = entry.value;

        // Determine file extension
        final ext = file.path.split('.').last.toLowerCase();
        final fileName = '$docType.$ext';

        // In per-farmer bucket, file is at root
        final storagePath = fileName;

        debugPrint(
            'DocumentService: Uploading $docType to $bucketName/$storagePath');

        // Read file bytes
        final fileBytes = await file.readAsBytes();

        // Upload to Supabase Storage
        await _supabase.storage.from(bucketName).uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: _getContentType(ext),
                upsert: true, // Overwrite if exists
              ),
            );

        // Get public URL
        final url =
            _supabase.storage.from(bucketName).getPublicUrl(storagePath);

        uploadedDocs[docType] = url;
        debugPrint('DocumentService: Uploaded $docType successfully');
      } catch (e) {
        debugPrint('DocumentService: Error uploading ${entry.key} - $e');
        errors.add(
            'Failed to upload ${DocumentType.getDisplayName(entry.key)}: $e');
      }
    }

    if (errors.isNotEmpty && uploadedDocs.isEmpty) {
      throw Exception(errors.join('\n'));
    }

    return {
      'success': uploadedDocs.isNotEmpty,
      'uploaded': uploadedDocs.length,
      'total': documents.length,
      'urls': uploadedDocs,
      if (errors.isNotEmpty) 'errors': errors,
    };
  }

  /// Get content type for file extension
  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload a single document to the farmer's bucket (no compulsory validation).
  /// Used for uploading missing documents from the claims flow.
  Future<void> uploadSingleDocument(String docType, File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final farmerId = await _getFarmerId();
    if (farmerId == null) {
      throw Exception('Farmer profile not found. Complete your profile first.');
    }

    final bucketName = await _ensureBucketExists(farmerId);
    final ext = file.path.split('.').last.toLowerCase();
    final storagePath = '$docType.$ext';
    final fileBytes = await file.readAsBytes();

    debugPrint('DocumentService: Uploading single doc $docType to $bucketName/$storagePath');

    await _supabase.storage.from(bucketName).uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: FileOptions(
        contentType: _getContentType(ext),
        upsert: true,
      ),
    );

    debugPrint('DocumentService: Single doc $docType uploaded successfully');
  }

  /// Get list of uploaded documents for the current farmer
  Future<List<DocumentModel>> getDocuments() async {
    final farmerId = await _getFarmerId();
    if (farmerId == null) {
      return [];
    }

    final bucketName = '$_farmerBucketPrefix$farmerId';
    final documents = <DocumentModel>[];

    try {
      // List files in the farmer's bucket
      final files = await _supabase.storage.from(bucketName).list();

      for (final file in files) {
        final docType = file.name.split('.').first;
        final url = _supabase.storage.from(bucketName).getPublicUrl(file.name);

        documents.add(DocumentModel(
          type: docType,
          displayName: DocumentType.getDisplayName(docType),
          url: url,
          status: 'uploaded',
        ));
      }
    } catch (e) {
      debugPrint(
          'DocumentService: Error listing documents (Bucket likely missing) - $e');
    }

    return documents;
  }
}
