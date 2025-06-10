import 'dart:convert';

/// نموذج لتذكير (Reminder) يمثل منشورًا محفوظًا ببياناته
class Reminder {
  final int id;
  final int userId;
  final String? url;
  final String title;
  final String? content;
  final String? imageUrl;
  String? importance;
  final List<String> scheduledTimes; // قائمة الأوقات المجدولة كنصوص
  String? nextReminderTime;
  final int isOpened;
  final String? createdAt;
  final String? updatedAt;
  final String? category; // الفئة الأولى
  final String? complexity; // مستوى التعقيد
  final String? domain; // النطاق (مثل youtube.com)

  Reminder({
    required this.id,
    required this.userId,
    this.url,
    required this.title,
    this.content,
    this.imageUrl,
    this.importance,
    required this.scheduledTimes,
    required this.nextReminderTime,
    required this.isOpened,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.complexity,
    this.domain,
  });

  /// إنشاء نسخة من التذكير مع تحديث بعض الحقول
  Reminder copyWith({
    String? title,
    String? importance,
    String? nextReminderTime,
  }) {
    return Reminder(
      id: id,
      userId: userId,
      url: url,
      title: title ?? this.title,
      content: content,
      imageUrl: imageUrl,
      importance: importance ?? this.importance,
      scheduledTimes: scheduledTimes, // الحفاظ على القائمة الحالية
      nextReminderTime: nextReminderTime ?? this.nextReminderTime,
      isOpened: isOpened,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      category: category,
      complexity: complexity,
      domain: domain,
    );
  }

  /// تحليل بيانات JSON لإنشاء كائن Reminder
  factory Reminder.fromJson(Map<String, dynamic> json) {
    try {
      int parseInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0; // القيمة الافتراضية إذا فشل التحليل
      }

      String? parseString(dynamic value) {
        if (value == null) return null;
        return value.toString().trim();
      }

      List<String> parseScheduledTimes(dynamic value) {
        if (value == null) return [];
        if (value is String) {
          // التعامل مع نص JSON مثل "[\"2025-02-23 17:00:00\"]"
          try {
            final List<dynamic> parsed =
                jsonDecode(value) as List<dynamic>? ?? [];
            return parsed.map((e) => e.toString().trim()).toList();
          } catch (e) {
            print('Error parsing scheduled_times: $e');
            return [value.toString().trim()]; // الرجوع إلى قيمة مفردة كـ String
          }
        }
        if (value is List) {
          return value.map((e) => e.toString().trim()).toList();
        }
        return [
          value.toString().trim()
        ]; // الرجوع إلى قيمة مفردة كـ String كبديل
      }

      return Reminder(
        id: parseInt(json['id']),
        userId: parseInt(json['user_id']),
        url: parseString(json['url']),
        title: parseString(json['title']) ?? '',
        content: parseString(json['content']),
        imageUrl: parseString(json['image_url']),
        importance: parseString(json['importance']),
        scheduledTimes: parseScheduledTimes(json['scheduled_times']),
        nextReminderTime: parseString(json['next_reminder_time']),
        isOpened: parseInt(json['is_opened']),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
        category: parseString(json['category']),
        complexity: parseString(json['complexity']),
        domain: parseString(json['domain']),
      );
    } catch (e) {
      print('Error parsing Reminder: $e');
      print('Problematic JSON: $json');
      rethrow; // إعادة إلقاء الاستثناء للسماح بمعالجة الخطأ في مكان آخر
    }
  }

  /// تحويل كائن Reminder إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'url': url,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'importance': importance,
      'scheduled_times':
          jsonEncode(scheduledTimes), // تحويل القائمة إلى نص JSON
      'next_reminder_time': nextReminderTime,
      'is_opened': isOpened,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'category': category,
      'complexity': complexity,
      'domain': domain,
    };
  }
}
