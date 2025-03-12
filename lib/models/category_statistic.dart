import 'dart:convert';
import 'package:reminder/models/reminder.dart';
import 'package:reminder/models/user.dart';

/// نموذج لإحصائيات الفئة (CategoryStatistic) يمثل بيانات الإحصائيات لفئة معينة
class CategoryStatistic {
  final int id;
  final int userId;
  final String category;
  final String complexity;
  final String domain;
  final List<String> openedStats;
  final String preferredTimes; // النص الوصفي للأوقات المفضلة
  final List<Reminder> savedPosts; // قائمة المنشورات المحفوظة

  CategoryStatistic({
    required this.id,
    required this.userId,
    required this.category,
    required this.complexity,
    required this.domain,
    required this.openedStats,
    required this.preferredTimes,
    required this.savedPosts,
  });

  /// تحليل بيانات JSON لإنشاء كائن CategoryStatistic
  factory CategoryStatistic.fromJson(Map<String, dynamic> json) {
    return CategoryStatistic(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'] ?? '',
      complexity: json['complexity'] ?? '',
      domain: json['domain'] ?? '',
      openedStats: List<String>.from(json['opened_stats'] ?? []),
      preferredTimes: json['preferred_times'] ?? '',
      savedPosts: (json['saved_posts'] as List<dynamic>?)
              ?.map((post) => Reminder.fromJson(post))
              .toList() ??
          [],
    );
  }

  /// تحويل كائن CategoryStatistic إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'complexity': complexity,
      'domain': domain,
      'opened_stats': jsonEncode(openedStats),
      'preferred_times': preferredTimes,
      'saved_posts': savedPosts.map((post) => post.toJson()).toList(),
    };
  }
}

// نموذج للمستخدم

// نموذج للفئة
class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

// نموذج للتعقيد
class Complexity {
  final int id;
  final String level;

  Complexity({required this.id, required this.level});

  factory Complexity.fromJson(Map<String, dynamic> json) {
    return Complexity(
      id: json['id'],
      level: json['level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
    };
  }
}

// نموذج للنطاق
class Domain {
  final int id;
  final String name;

  Domain({required this.id, required this.name});

  factory Domain.fromJson(Map<String, dynamic> json) {
    return Domain(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
