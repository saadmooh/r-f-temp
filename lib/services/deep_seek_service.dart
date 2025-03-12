import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:reminder/services/api_service.dart';
import 'package:reminder/models/user.dart';
import 'package:reminder/models/reminder.dart';
import 'package:reminder/models/category_statistic.dart';
import 'package:reminder/models/reminders_response.dart';

class DeepSeekService {
  late String apiKey;
  late String apiUrl;
  late String model;
  final ApiService apiService;

  DeepSeekService({required this.apiService}) {
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _initializeApiCredentials();
    await fetchApiConfig();
  }

  Future<void> _initializeApiCredentials() async {
    try {
      final credentials = await apiService.getApiCredentials();
      final Map<String, dynamic> credentialsMap = credentials is Map
          ? Map<String, dynamic>.from(credentials)
          : throw Exception('Invalid credentials format: $credentials');

      print('Credentials Map: $credentialsMap');

      apiKey = credentialsMap['apiKey'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('API Key is missing or empty');
      }
    } catch (e) {
      print('Error fetching API credentials: $e');
      throw Exception('Failed to fetch API credentials: $e');
    }
  }

  Future<Map<String, dynamic>> fetchApiConfig() async {
    try {
      final response = await apiService.getApiConfig();
      final Map<String, dynamic> responseMap = response is Map
          ? Map<String, dynamic>.from(response)
          : throw Exception('Invalid API config response format: $response');

      print('API Config Response Map: $responseMap');

      final fetchedApiUrl = responseMap['apiUrl'] as String?;
      final fetchedModel = responseMap['model'] as String?;
      final fetchedApiKey = responseMap['apiKey'] as String?;

      print('Fetched API URL: $fetchedApiUrl');
      print('Fetched Model: $fetchedModel');
      print('Fetched API Key: $fetchedApiKey');

      if (fetchedApiUrl == null || fetchedApiUrl.isEmpty) {
        throw Exception('API URL is missing or empty in the config');
      }
      if (fetchedModel == null || fetchedModel.isEmpty) {
        throw Exception('Model is missing or empty in the config');
      }
      if (fetchedApiKey == null || fetchedApiKey.isEmpty) {
        throw Exception('API Key is missing or empty in the config');
      }

      apiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/$fetchedModel:generateContent';
      model = fetchedModel;
      apiKey = fetchedApiKey;

      return {
        'apiUrl': apiUrl,
        'model': model,
        'apiKey': apiKey,
      };
    } catch (e) {
      print('Error fetching API configuration: $e');
      throw Exception('Failed to fetch API configuration: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeRecentEngagementTimes(User user) async {
    await _initializeService(); // تأكد من التهيئة
    try {
      final response = await apiService.getStats(user.id.toString(), 'week');

      print("--- Raw Response from apiService.getStats ---");
      print("Type of response: ${response.runtimeType}");
      print("Response Content: $response");
      print("--- End Raw Response ---");

      if (response is! Map<String, dynamic>) {
        throw Exception(
            "Error: apiService.getStats did NOT return a Map<String, dynamic> as expected. Returned type: ${response.runtimeType}, Content: $response");
      }

      final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
      final CategoryStatistic stat = CategoryStatistic.fromJson(responseMap);

      final now = DateTime.now();
      final engagementData = <String, List<String>>{};
      final rawOldData = <String>[];

      final openedStats = stat.openedStats ?? [];
      for (var time in openedStats) {
        try {
          final parsedTime = DateTime.parse(time);
          final dayTime =
              '${parsedTime.weekdayName} ${parsedTime.hour}:${parsedTime.minute.toString().padLeft(2, '0')}';
          final day = parsedTime.weekdayName.toLowerCase();
          if (parsedTime.isAfter(now.subtract(const Duration(days: 7)))) {
            engagementData.putIfAbsent(day, () => []).add(dayTime);
          } else {
            rawOldData.add(dayTime);
          }
        } catch (e) {
          print("Error parsing time '$time': $e - Time String: '$time'");
          continue;
        }
      }

      return {
        'engagement_times': engagementData,
        'recommendations': 'No analysis performed (direct from backend)',
        'raw_old_data': rawOldData,
      };
    } catch (e) {
      print("Error in analyzeRecentEngagementTimes: $e");
      throw Exception('Error analyzing engagement times: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeRecentUserStats(User user) async {
    await _initializeService(); // تأكد من التهيئة
    try {
      final response =
          await apiService.fetchRemindersData(user.id.toString(), 'week');
      final remindersResponse = RemindersResponse.fromJson(response);
      final reminders = remindersResponse.reminders;

      final now = DateTime.now();
      final filteredReminders = <Reminder>[];
      final rawOldReminders = <Map<String, dynamic>>[];

      for (var reminder in reminders) {
        final createdAt = DateTime.parse(reminder.createdAt ?? '');
        if (createdAt.isAfter(now.subtract(const Duration(days: 7)))) {
          filteredReminders.add(reminder);
        } else {
          rawOldReminders.add({
            'id': reminder.id,
            'title': reminder.title,
            'created_at': reminder.createdAt,
            'is_opened': reminder.isOpened,
          });
        }
      }

      if (filteredReminders.isNotEmpty) {
        final importanceDist = <String, int>{};
        for (var reminder in filteredReminders) {
          importanceDist[reminder.importance ?? 'unknown'] =
              (importanceDist[reminder.importance ?? 'unknown'] ?? 0) + 1;
        }

        return {
          'total_reminders': filteredReminders.length,
          'opened_reminders':
              filteredReminders.where((r) => r.isOpened == 1).length,
          'unopened_reminders':
              filteredReminders.where((r) => r.isOpened == 0).length,
          'importance_distribution': importanceDist,
          'raw_old_reminders': rawOldReminders,
        };
      }

      return {
        'total_reminders': 0,
        'opened_reminders': 0,
        'unopened_reminders': 0,
        'importance_distribution': {},
        'raw_old_reminders': rawOldReminders,
      };
    } catch (e) {
      throw Exception('Error analyzing user stats: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeRecentCategoryDistribution(
      User user) async {
    await _initializeService(); // تأكد من التهيئة
    try {
      final response =
          await apiService.fetchRemindersData(user.id.toString(), 'week');
      final remindersResponse = RemindersResponse.fromJson(response);
      final reminders = remindersResponse.reminders;

      final now = DateTime.now();
      final filteredReminders = <Reminder>[];
      final rawOldReminders = <Map<String, dynamic>>[];

      for (var reminder in reminders) {
        final createdAt = DateTime.parse(reminder.createdAt ?? '');
        if (createdAt.isAfter(now.subtract(const Duration(days: 7)))) {
          filteredReminders.add(reminder);
        } else {
          rawOldReminders.add({
            'id': reminder.id,
            'category': reminder.category ?? 'Unknown',
            'complexity': reminder.complexity ?? 'Unknown',
            'domain': reminder.domain ?? 'Unknown',
            'created_at': reminder.createdAt,
          });
        }
      }

      if (filteredReminders.isNotEmpty) {
        final categoryDist = <String, int>{};
        final complexityDist = <String, int>{};
        final domainDist = <String, int>{};

        for (var reminder in filteredReminders) {
          categoryDist[reminder.category ?? 'Unknown'] =
              (categoryDist[reminder.category ?? 'Unknown'] ?? 0) + 1;
          complexityDist[reminder.complexity ?? 'Unknown'] =
              (complexityDist[reminder.complexity ?? 'Unknown'] ?? 0) + 1;
          domainDist[reminder.domain ?? 'Unknown'] =
              (domainDist[reminder.domain ?? 'Unknown'] ?? 0) + 1;
        }

        return {
          'categories': categoryDist,
          'complexities': complexityDist,
          'domains': domainDist,
          'raw_old_reminders': rawOldReminders,
        };
      }

      return {
        'categories': {},
        'complexities': {},
        'domains': {},
        'raw_old_reminders': rawOldReminders,
      };
    } catch (e) {
      throw Exception('Error analyzing category distribution: $e');
    }
  }

  Future<Map<String, dynamic>> generateRecentRecommendations(User user) async {
    await _initializeService(); // تأكد من التهيئة
    try {
      final userStats = await analyzeRecentUserStats(user);
      final categoryDist = await analyzeRecentCategoryDistribution(user);
      final engagementTimes = await analyzeRecentEngagementTimes(user);

      final prompt = """
   Generate general recommendations for a user based on their recent statistics from the last week, strictly in JSON format:
   User Stats: ${jsonEncode(userStats)},
   Category Distribution: ${jsonEncode(categoryDist)},
   Engagement Times: ${jsonEncode(engagementTimes)},
   Please respond with a JSON object exactly in the following structure:
    {
        "general_recommendations": "Focus on evening posts and prioritize Neural Networks content.",
        "optimal_times": {
            "sunday": ["17:00", "19:00"],
            "monday": ["18:00", "21:00"]
        }
    }
    """;

      if (userStats['total_reminders'] > 0 ||
          categoryDist['categories'].isNotEmpty ||
          engagementTimes['engagement_times'].isNotEmpty) {
        try {
          final result = _parseGeminiResponse(await _sendToGeminiApi(prompt));
          result['raw_old_data'] = [
            ...?userStats['raw_old_reminders'],
            ...?categoryDist['raw_old_reminders'],
            ...?engagementTimes['raw_old_data'],
          ];
          return result;
        } catch (apiError) {
          print('Gemini API Error: $apiError');
          return {
            'general_recommendations':
                'Failed to fetch recommendations due to API error',
            'optimal_times': {},
            'raw_old_data': [
              ...?userStats['raw_old_reminders'],
              ...?categoryDist['raw_old_reminders'],
              ...?engagementTimes['raw_old_data'],
            ],
          };
        }
      }

      return {
        'general_recommendations': 'No recent data for analysis (last week)',
        'optimal_times': {},
        'raw_old_data': [
          ...?userStats['raw_old_reminders'],
          ...?categoryDist['raw_old_reminders'],
          ...?engagementTimes['raw_old_data'],
        ],
      };
    } catch (e) {
      print('Error in generateRecentRecommendations: $e');
      throw Exception('Error generating recommendations: $e');
    }
  }

  Future<http.Response> _sendToGeminiApi(String prompt) async {
    if (apiUrl == null || apiKey == null) {
      throw Exception('API URL or API Key is not initialized');
    }

    print('Sending request to: $apiUrl');

    final response = await http.post(
      Uri.parse('$apiUrl?key=$apiKey'),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'ar',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      return response;
    } else {
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      throw Exception(
          'Gemini API Error: ${response.statusCode} - ${response.body}');
    }
  }

  Map<String, dynamic> _parseGeminiResponse(http.Response response) {
    final body = response.body;
    String cleanedBody = body.trim();

    if (cleanedBody.startsWith('```json')) {
      cleanedBody = cleanedBody.substring(7);
    }
    if (cleanedBody.endsWith('```')) {
      cleanedBody = cleanedBody.substring(0, cleanedBody.length - 3);
    }

    cleanedBody = cleanedBody.trim();

    try {
      final decoded = jsonDecode(cleanedBody) as Map<String, dynamic>;
      if (decoded.containsKey('candidates') && decoded['candidates'] is List) {
        final candidate =
            (decoded['candidates'] as List).first as Map<String, dynamic>?;
        if (candidate != null &&
            candidate.containsKey('content') &&
            candidate['content'] is Map) {
          final content = candidate['content'] as Map<String, dynamic>;
          if (content.containsKey('parts') && content['parts'] is List) {
            final parts = content['parts'] as List;
            final textPart = parts.firstWhere((part) => part['text'] != null,
                orElse: () => {'text': ''});
            final text = textPart['text'] as String;

            String cleanedText = text.trim();
            if (cleanedText.startsWith('```json')) {
              cleanedText = cleanedText.substring(7);
            }
            if (cleanedText.endsWith('```')) {
              cleanedText = cleanedText.substring(0, cleanedText.length - 3);
            }
            cleanedText = cleanedText.trim();

            try {
              return jsonDecode(cleanedText) as Map<String, dynamic>;
            } catch (e) {
              throw Exception(
                  'Failed to parse Gemini response content as JSON: $e - Response: $cleanedText');
            }
          }
        }
      }
      throw Exception(
          'Invalid Gemini API response format: ${decoded.toString()}');
    } catch (e) {
      throw Exception(
          'Failed to parse Gemini response as JSON: $e - Response: $cleanedBody');
    }
  }

  List<List<dynamic>> _batchData(List<dynamic> data, [int batchSize = 500]) {
    final batches = <List<dynamic>>[];
    for (var i = 0; i < data.length; i += batchSize) {
      batches.add(data.sublist(
          i, i + batchSize > data.length ? data.length : i + batchSize));
    }
    return batches;
  }

  bool _checkDataSize(List<dynamic> data) {
    final size = utf8.encode(jsonEncode(data)).length;
    const maxSize = 8000000;
    return size <= maxSize;
  }

  Map<String, dynamic> _mergeBatchResults(List<Map<String, dynamic>> results) {
    final merged = {
      'engagement_times': <String, List<String>>{},
      'recommendations': '',
    } as Map<String, dynamic>;

    for (var result in results) {
      if (result['engagement_times'] != null) {
        final times = result['engagement_times'] as Map<String, dynamic>;
        times.forEach((day, timesList) {
          (merged['engagement_times'] as Map<String, List<String>>)[day] = [
            ...?(merged['engagement_times']
                    as Map<String, List<String>>)[day] ??
                [],
            ...(timesList as List).map((e) => e.toString())
          ].toSet().toList().cast<String>();
        });
      }
      if (result['recommendations'] != null &&
          result['recommendations'].isNotEmpty) {
        merged['recommendations'] = result['recommendations'] as String;
      }
    }

    return merged;
  }
}

extension DateTimeExtension on DateTime {
  String get weekdayName {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[weekday - 1];
  }
}
