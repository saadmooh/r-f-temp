import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:reminder/models/reminder.dart';
import 'package:reminder/models/reminders_response.dart';
import 'package:flutter/material.dart';
import 'package:reminder/models/user_free_time.dart';
import 'package:reminder/models/user.dart';
import 'package:reminder/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// استيراد مشروط لـ File بناءً على المنصة
import 'dart:io' as io show File if (dart.library.html) 'dart:html' show File;

class ApiService {
  static const String API_BASE_URL =
      'https://purple-zebra-199646.hostingersite.com/api';
  static const String API_PASSWORD = 'API_PASSWORD'; // استبدل بكلمة المرور الصحيحة
  final _storage = FlutterSecureStorage();
  
  final NotificationService _notificationService = NotificationService();

  ApiService() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
  }

  Future<void> register(String name, String email, String password) async {
    final url = Uri.parse('$API_BASE_URL/register');
    final response = await http.post(
      url,
      headers: {'X-API-Password': API_PASSWORD},
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Registration failed.');
    }
  }

  Future<String?> login(String email, String password) async {
    final url = Uri.parse('$API_BASE_URL/login');
    final response = await http.post(
      url,
      headers: {'X-API-Password': API_PASSWORD},
      body: {
        'email': email,
        'password': password,
        'device_name': 'mobile_app',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final token = responseData['access_token'];
      if (token != null) {
        await _storage.write(key: 'auth_token', value: token);
        print('Login Token: $token');
        return token;
      } else {
        throw Exception('Login successful, but no token received.');
      }
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Login failed.');
    }
  }

 

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<Map<String, dynamic>> user() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$API_BASE_URL/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'];
      } else {
        throw Exception('Failed to retrieve user data: ${data['message']}');
      }
    } else {
      throw Exception('Failed to retrieve user data: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> checkSubscription() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$API_BASE_URL/check-subscription'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to check subscription: ${response.body}');
    }
  }

  Future<String> getCustomerPortalUrl() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$API_BASE_URL/update-payment-info'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'];
    } else {
      throw Exception('Failed to fetch customer portal URL: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$API_BASE_URL/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch orders: ${response.body}');
    }
  }

  Future<List<int>> getRemindersIds() async {
    final url = Uri.parse('$API_BASE_URL/getRemindersIds');
    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body) as List<dynamic>;
      return decodedData.map((id) => id as int).toList();
    } else {
      try {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        throw Exception(errorData?['message'] ??
            'Failed to fetch reminder IDs: ${response.statusCode}');
      } catch (e) {
        throw Exception(
            'Failed to parse response: ${response.statusCode} - ${response.body}');
      }
    }
  }

  Future<Map<String, dynamic>> getApiConfig() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/api-credentials'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch API config: ${response.body}');
  }

  Future<String?> updateReminder(Reminder reminder) async {
    final url = Uri.parse('$API_BASE_URL/update-reminder');
    final token = await getToken();

    final response = await http.post(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "id": reminder.id,
        'next_reminder_time': reminder.nextReminderTime,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update reminder.');
    }
    return null; // أو يمكنك إرجاع قيمة إذا كان الـ API يعيد بيانات مفيدة
  }

  Future<void> deleteReminder(int id) async {
    final url = Uri.parse('$API_BASE_URL/deleteReminder/$id');
    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete reminder.');
    }
  }

  Future<RemindersResponse> fetchReminders({
    int page = 1,
    int perPage = 10,
    String searchQuery = '',
    String? category,
    String? complexity,
    String? domain,
  }) async {
    final url = Uri.parse(
      '$API_BASE_URL/reminders?page=$page&perPage=$perPage'
      '${searchQuery.isNotEmpty ? '&search=$searchQuery' : ''}'
      '${category != null && category != 'All' ? '&category=$category' : ''}'
      '${complexity != null && complexity != 'All' ? '&complexity=$complexity' : ''}'
      '${domain != null && domain != 'All' ? '&domain=$domain' : ''}',
    );
    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      return RemindersResponse.fromJson(responseData);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized. Please log in again.');
    } else {
      throw Exception('Failed to load reminders: ${response.statusCode}');
    }
  }

  Future<void> updateStats(String postUrl, bool opened) async {
    final url = Uri.parse('$API_BASE_URL/update-stats');
    final token = await getToken();
    final response = await http.post(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'url': postUrl,
        'opened': opened,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update stats.');
    }
  }

  Future<Reminder> getReminder(String postUrl) async {
    try {
      final url = Uri.parse('$API_BASE_URL/reminder?url=$postUrl');
      final token = await getToken();
      final response = await http.get(
        url,
        headers: {
          'X-API-Password': API_PASSWORD,
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received');
        }

        try {
          final decodedData = json.decode(response.body);
          return Reminder.fromJson(decodedData);
        } on FormatException catch (e) {
          print('JSON parsing error: ${response.body}');
          throw Exception('Invalid response format: ${e.message}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Reminder not found');
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? 'Failed to load reminder');
        } catch (e) {
          throw Exception('Failed to load reminder: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error in getReminder: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUser() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/user'),
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  Future<Reminder> getReminderById(int postId) async {
    try {
      final url = Uri.parse('$API_BASE_URL/reminderById?id=$postId');
      final token = await getToken();
      final response = await http.get(
        url,
        headers: {
          'X-API-Password': API_PASSWORD,
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received');
        }

        try {
          final decodedData = json.decode(response.body);
          return Reminder.fromJson(decodedData);
        } on FormatException catch (e) {
          print('JSON parsing error: ${response.body}');
          throw Exception('Invalid response format: ${e.message}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Reminder not found');
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? 'Failed to load reminder');
        } catch (e) {
          throw Exception('Failed to load reminder: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error in getReminderById: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats(String userId, String period) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/stats?user_id=$userId&period=$period'),
      headers: {'Authorization': 'Bearer ${await getToken()}'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch stats');
  }

  Future<Map<String, dynamic>> updateLanguage(String language) async {
    final url = Uri.parse('$API_BASE_URL/update-language');
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.post(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'language': language}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {'success': true, 'message': responseData['message']};
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update language.');
    }
  }

  Future<Map<String, dynamic>> fetchRemindersData(String userId, String period) async {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/remindersData?user_id=$userId&period=$period'),
      headers: {'Authorization': 'Bearer ${await getToken()}'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch reminders');
  }

  Future<Map<String, dynamic>> getApiCredentials() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/api-credentials'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch API credentials');
  }

  Future<User> getCurrentUser() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/user'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to fetch user.');
    }
  }

  Future<String> reschedulePost(String postUrl, String importance) async {
    final url = Uri.parse('$API_BASE_URL/reschedule-post');
    final token = await getToken();
    final response = await http.post(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': postUrl, 'importance': importance}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      final bestTime = responseData['best_time'];
      if (bestTime != null) {
        return bestTime;
      } else {
        throw Exception('لم يتم استلام best_time.');
      }
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'فشل في إعادة جدولة المنشور.');
    }
  }

  Future<Map<String, dynamic>> savePost(Map<String, dynamic> data) async {
    final token = await getToken();
    String endpoint = '$API_BASE_URL/save-post';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to save post: ${response.body}');
  }

  Future<UserFreeTime> createFreeTime(
    String day,
    TimeOfDay startTime,
    TimeOfDay endTime,
    bool isOffDay,
  ) async {
    final url = Uri.parse('$API_BASE_URL/free-times');
    final token = await getToken();

    final String formattedStartTime = formatTimeOfDay(startTime);
    final String formattedEndTime = formatTimeOfDay(endTime);

    final response = await http.post(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'day': day,
        'start_time': formattedStartTime,
        'end_time': formattedEndTime,
        'is_off_day': isOffDay ? 1 : 0,
      }),
    );

    if (response.statusCode == 201) {
      return UserFreeTime.fromJson(json.decode(response.body));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ??
          'Failed to create free time: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateFreeTime(
    int id,
    String day,
    TimeOfDay startTime,
    TimeOfDay endTime,
    bool isOffDay,
  ) async {
    final url = Uri.parse('$API_BASE_URL/free-times/$id');
    final token = await getToken();

    final String formattedStartTime = formatTimeOfDay(startTime);
    final String formattedEndTime = formatTimeOfDay(endTime);

    final response = await http.put(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'day': day,
        'start_time': formattedStartTime,
        'end_time': formattedEndTime,
        'is_off_day': isOffDay ? 1 : 0,
      }),
    );

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Failed to update free time.'
      };
    }
  }

  String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<List<UserFreeTime>> fetchFreeTimes() async {
    final url = Uri.parse('$API_BASE_URL/free-times');
    final token = await getToken();
    final response = await http.get(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => UserFreeTime.fromJson(item)).toList();
    } else {
      throw Exception(
          'Failed to load free times: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> deleteFreeTime(int id) async {
    final url = Uri.parse('$API_BASE_URL/free-times/$id');
    final token = await getToken();
    final response = await http.delete(
      url,
      headers: {
        'X-API-Password': API_PASSWORD,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ??
          'Failed to delete free time: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategoryStats(int userId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/category-stats?user_id=$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load category stats: ${response.statusCode}');
    }
  }

  Future<int?> getCurrentUserId() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        return payload['sub'] as int?;
      }
      return null;
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data, {dynamic image}) async {
    final url = '$API_BASE_URL/user/update';
    final token = await getToken();
    if (token == null) throw Exception('No authentication token found');

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.headers['X-API-Password'] = API_PASSWORD;

    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // التحقق من المنصة قبل التعامل مع الصورة
    if (!kIsWeb && image != null && image is io.File) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_image', image.path),
      );
    } else if (kIsWeb && image != null) {
      // للويب، يجب أن يكون image من نوع Blob أو File (من dart:html)
      // هنا نحتاج إلى معالجة خاصة للويب، ولكن هذا يعتمد على كيفية تمرير الصورة
      throw UnimplementedError('Image upload on web is not implemented yet.');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      final errorData = json.decode(responseBody) as Map<String, dynamic>?;
      throw Exception(errorData?['message'] ?? 'Failed to update profile');
    }
  }
}