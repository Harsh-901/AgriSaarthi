import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'translation_service.dart';
import 'api_service.dart';

enum SchemeStatus { open, eligible, closingSoon, closed }

class SchemeModel {
  final String id;
  final String name;
  final String benefit;
  final String deadline;
  final SchemeStatus status;
  final String? description;
  final bool isApplied;

  SchemeModel({
    required this.id,
    required this.name,
    required this.benefit,
    required this.deadline,
    required this.status,
    this.description,
    this.isApplied = false,
  });

  factory SchemeModel.fromJson(Map<String, dynamic> json) {
    // Map status string from DB to Enum
    SchemeStatus status = SchemeStatus.open;
    String statusStr = (json['status'] ?? 'open').toString().toLowerCase();

    if (statusStr.contains('eligible')) {
      status = SchemeStatus.eligible;
    } else if (statusStr.contains('closing')) {
      status = SchemeStatus.closingSoon;
    } else if (statusStr.contains('closed')) {
      status = SchemeStatus.closed;
    }

    return SchemeModel(
      id: json['id']?.toString() ?? json['scheme_id']?.toString() ?? '',
      name: json['name'] ?? json['name_localized'] ?? 'Unknown Scheme',
      // Map 'benefit' or 'description' from DB
      benefit: json['benefit'] ??
          json['benefit_display'] ??
          json['description'] ??
          'View details',
      deadline: json['deadline'] ?? 'Ongoing',
      status: status,
      description: json['description'],
    );
  }

  SchemeModel copyWith({
    String? id,
    String? name,
    String? benefit,
    String? deadline,
    SchemeStatus? status,
    String? description,
    bool? isApplied,
  }) {
    return SchemeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      benefit: benefit ?? this.benefit,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      description: description ?? this.description,
      isApplied: isApplied ?? this.isApplied,
    );
  }
}

class SchemeService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final ApiService _apiService = ApiService();

  /// Fetch ONLY eligible schemes for the farmer from Django API
  /// Uses the Decision Table engine on the backend
  Future<List<SchemeModel>> getEligibleSchemes({String? languageCode}) async {
    try {
      final response = await _apiService.get('/api/schemes/eligible/');

      if (response['success'] == true && response['data'] != null) {
        final schemesJson = response['data']['schemes'] as List<dynamic>? ?? [];
        final schemes = schemesJson.map((json) {
          final model = SchemeModel.fromJson(json);
          // If we're getting it from the eligible endpoint, mark it as eligible status
          return model.copyWith(status: SchemeStatus.eligible);
        }).toList();

        // Translate if needed
        if (languageCode != null &&
            languageCode.isNotEmpty &&
            languageCode != 'en') {
          try {
            return await Future.wait(
              schemes.map((scheme) async {
                final tName = await TranslationService.translate(
                    scheme.name, languageCode);
                final tBenefit = await TranslationService.translate(
                    scheme.benefit, languageCode);
                String? tDesc;
                if (scheme.description != null &&
                    scheme.description!.isNotEmpty) {
                  tDesc = await TranslationService.translate(
                      scheme.description!, languageCode);
                }
                return scheme.copyWith(
                    name: tName, benefit: tBenefit, description: tDesc);
              }),
            );
          } catch (e) {
            debugPrint('Translation error: $e');
            return schemes;
          }
        }
        return schemes;
      }

      // If API call didn't succeed, fall back to Supabase
      debugPrint(
          'SchemeService: Eligible API failed, falling back to Supabase');
      return getSchemes(languageCode: languageCode);
    } catch (e) {
      debugPrint('SchemeService: Error fetching eligible schemes - $e');
      // Fall back to Supabase
      return getSchemes(languageCode: languageCode);
    }
  }

  /// Fetch all schemes from the 'schemes' table
  Future<List<SchemeModel>> getSchemes({String? languageCode}) async {
    try {
      final response = await _supabase
          .from('schemes')
          .select()
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      final schemes = data.map((json) => SchemeModel.fromJson(json)).toList();

      // If language is provided and not English, translate dynamic content
      if (languageCode != null &&
          languageCode.isNotEmpty &&
          languageCode != 'en') {
        try {
          final translatedSchemes = await Future.wait(
            schemes.map((scheme) async {
              // Translate visible fields
              final tName =
                  await TranslationService.translate(scheme.name, languageCode);
              final tBenefit = await TranslationService.translate(
                  scheme.benefit, languageCode);

              String? tDesc;
              if (scheme.description != null &&
                  scheme.description!.isNotEmpty) {
                tDesc = await TranslationService.translate(
                    scheme.description!, languageCode);
              }

              return scheme.copyWith(
                name: tName,
                benefit: tBenefit,
                description: tDesc,
              );
            }),
          );
          return translatedSchemes;
        } catch (e) {
          debugPrint('Translation error: $e');
          // Return original schemes if translation fails
          return schemes;
        }
      }

      return schemes;
    } catch (e) {
      debugPrint('SchemeService: Error fetching schemes - $e');
      return [];
    }
  }
}
