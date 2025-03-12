import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:reminder/services/api_service.dart';
import 'package:reminder/models/reminder.dart';
import 'package:reminder/globals.dart'; // استيراد المفتاح العالمي للتنقل (navigatorKey)
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// كلاس لإدارة الإشعارات في التطبيق
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static bool _permissionsGranted = false; // متغير ثابت لتخزين حالة الأذونات

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// تهيئة خدمة الإشعارات
  Future<void> init() async {
    // تهيئة المناطق الزمنية
    tz.initializeTimeZones();

    // تهيئة مكتبة awesome_notifications مع قنوات الإشعارات
    await AwesomeNotifications().initialize(
      'resource://drawable/notification', // أيقونة الإشعار الافتراضية
      [
        NotificationChannel(
          channelKey: 'scheduled_channel',
          channelName: 'Scheduled Notifications',
          channelDescription: 'قناة لإشعارات التذكيرات المجدولة',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
        NotificationChannel(
          channelKey: 'check_channel',
          channelName: 'Check Notifications',
          channelDescription: 'قناة للتحقق من حالة التذكيرات',
          importance: NotificationImportance.Low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          defaultColor: Colors.transparent,
          ledColor: Colors.transparent,
        ),
      ],
    );

    // التحقق من أذونات الإشعارات مرة واحدة وتخزين الحالة
    _permissionsGranted = await AwesomeNotifications().isNotificationAllowed();
    if (!_permissionsGranted) {
      _permissionsGranted =
          await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // التحقق من تهيئة navigatorKey
    if (navigatorKey.currentState == null) {
      print('تحذير: navigatorKey لم يتم تهيئته. قد لا يعمل SnackBar.');
    }

    // إعداد مستمعي الأحداث للإشعارات
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onNotificationActionReceived,
      onNotificationCreatedMethod: onNotificationCreated,
      onNotificationDisplayedMethod: onNotificationDisplayed,
      onDismissActionReceivedMethod: onDismissActionReceived,
    );
  }

  /// مستمع: تم إنشاء إشعار
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreated(
      ReceivedNotification receivedNotification) async {
    print('تم إنشاء إشعار: ${receivedNotification.toMap()}');
    await _instance._logNotificationEvent(
      'Created',
      receivedNotification.id!,
      receivedNotification.payload
          ?.map((key, value) => MapEntry(key, value ?? '')),
    );
  }

  /// مستمع: تم عرض إشعار
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayed(
      ReceivedNotification receivedNotification) async {
    print('تم عرض إشعار: ${receivedNotification.toMap()}');
    await _instance._logNotificationEvent(
      'Displayed',
      receivedNotification.id!,
      receivedNotification.payload
          ?.map((key, value) => MapEntry(key, value ?? '')),
    );
  }

  /// مستمع: تم إلغاء إشعار
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceived(
      ReceivedAction receivedAction) async {
    print('تم إلغاء إشعار: ${receivedAction.toMap()}');
    await _instance._logNotificationEvent(
      'Dismissed',
      receivedAction.id!,
      receivedAction.payload?.map((key, value) => MapEntry(key, value ?? '')),
    );
  }

  /// مستمع: تم التفاعل مع إشعار (مثل النقر عليه أو إشعار فحص)
  @pragma("vm:entry-point")
  static Future<void> onNotificationActionReceived(
      ReceivedAction receivedAction) async {
    print('تم التفاعل مع إشعار: ${receivedAction.toMap()}');

    // التحقق مما إذا كان هذا إشعار فحص لإعادة الجدولة
    if (receivedAction.channelKey == 'check_channel') {
      await _handleCheckNotification(receivedAction);
      return;
    }

    // التعامل مع إشعار تذكير عادي (المستخدم نقر على الإشعار)
    final reminderId = receivedAction.payload?['id'] != null
        ? int.parse(receivedAction.payload!['id']!)
        : null;
    if (reminderId != null) {
      await _instance._cancelCheckNotificationsForReminder(reminderId);
    }

    // تحليل scheduledTimes من الـ payload مع معالجة أخطاء محسنة
    List<String> scheduledTimes = [];
    if (receivedAction.payload?['scheduledTimes'] != null) {
      try {
        final scheduledTimesJson = receivedAction.payload!['scheduledTimes']!;
        final decoded = jsonDecode(scheduledTimesJson);
        if (decoded is List) {
          scheduledTimes = decoded.cast<String>();
        } else {
          print(
              'تنسيق scheduledTimes غير صحيح: متوقع List، تم العثور على ${decoded.runtimeType}');
          scheduledTimes = [''];
        }
      } catch (e) {
        print('خطأ أثناء تحليل scheduledTimes: $e');
        scheduledTimes = [''];
      }
    }

    // إنشاء كائن Reminder من بيانات الإشعار
    final reminder = Reminder(
      id: receivedAction.id!,
      userId: 0,
      url: receivedAction.payload?['url'] ?? '',
      title: receivedAction.title ?? 'تذكير',
      content: receivedAction.payload?['content'] ?? '',
      imageUrl: receivedAction.payload?['imageUrl'] ?? '',
      importance: receivedAction.payload?['importance'] ?? '',
      scheduledTimes: scheduledTimes,
      nextReminderTime: receivedAction.payload?['nextReminderTime'] ?? '',
      isOpened: 1,
      createdAt: receivedAction.payload?['createdAt'] ?? '',
      updatedAt: receivedAction.payload?['updatedAt'] ?? '',
      category: receivedAction.payload?['category'] ?? '',
      complexity: receivedAction.payload?['complexity'] ?? '',
      domain: receivedAction.payload?['domain'] ?? '',
    );

    // تحديث حالة التذكير عبر API إذا كان هناك رابط متاح
    if (reminder.url?.isNotEmpty ?? false) {
      try {
        await ApiService().updateStats(reminder.url!, true);
      } catch (e) {
        print('خطأ أثناء تحديث الحالة عبر API: $e');
        _showSnackBar('فشل في تحديث حالة التذكير: $e');
      }
    }

    // التنقل إلى شاشة تفاصيل التذكير باستخدام navigatorKey
    try {
      final navigatorState = navigatorKey.currentState;
      if (navigatorState != null) {
        await navigatorState.pushNamed('/reminder', arguments: reminder);
        _showSnackBar('تم فتح التذكير بنجاح!');
      } else {
        print(
            'خطأ: حالة Navigator فارغة. لا يمكن التنقل إلى ReminderDetailScreen.');
      }
    } catch (e) {
      print('خطأ أثناء التنقل إلى ReminderDetailScreen: $e');
    }
  }

  /// التعامل مع إشعارات الفحص لإعادة جدولة التذكير إذا لم يتم فتحه بعد ساعة
  static Future<void> _handleCheckNotification(
      ReceivedAction receivedAction) async {
    print('التعامل مع إشعار فحص: ${receivedAction.toMap()}');

    final postUrl = receivedAction.payload?['url'];
    final importance = receivedAction.payload?['importance'] ?? 'day';
    final reminderId = receivedAction.payload?['id'] != null
        ? int.parse(receivedAction.payload!['id']!)
        : null;

    if (postUrl == null || reminderId == null) {
      print('خطأ: postUrl أو reminderId مفقود في بيانات إشعار الفحص.');
      return;
    }

    try {
      final fetchedReminder = await ApiService().getReminder(postUrl);
      if (fetchedReminder.isOpened == 0) {
        await ApiService().updateStats(postUrl, false);
        final String bestTimeStr =
            await ApiService().reschedulePost(postUrl, importance);
        final DateTime newScheduledDate =
            tz.TZDateTime.parse(tz.getLocation('Africa/Algiers'), bestTimeStr);

        List<String> scheduledTimes = [];
        if (receivedAction.payload?['scheduledTimes'] != null) {
          try {
            final scheduledTimesJson =
                receivedAction.payload!['scheduledTimes']!;
            final decoded = jsonDecode(scheduledTimesJson);
            if (decoded is List) {
              scheduledTimes = decoded.cast<String>();
            } else {
              print(
                  'تنسيق scheduledTimes غير صحيح في إشعار الفحص: متوقع List، تم العثور على ${decoded.runtimeType}');
              scheduledTimes = [''];
            }
          } catch (e) {
            print('خطأ أثناء تحليل scheduledTimes في إشعار الفحص: $e');
            scheduledTimes = [''];
          }
        }

        await _instance.scheduleNotification(
          title: receivedAction.payload?['title'] ?? 'تذكير',
          body: 'حان وقت تذكيرك!',
          scheduledDate: newScheduledDate,
          channelKey: 'scheduled_channel',
          summary: 'إشعار تذكير',
          payload: {
            'id': reminderId.toString(),
            'url': postUrl,
            'content': receivedAction.payload?['content'] ?? '',
            'imageUrl': receivedAction.payload?['imageUrl'] ?? '',
            'importance': importance,
            'scheduledTimes': jsonEncode(scheduledTimes),
            'nextReminderTime': newScheduledDate.toIso8601String(),
            'createdAt': receivedAction.payload?['createdAt'] ?? '',
            'updatedAt': receivedAction.payload?['updatedAt'] ?? '',
            'category': receivedAction.payload?['category'] ?? '',
            'complexity': receivedAction.payload?['complexity'] ?? '',
            'domain': receivedAction.payload?['domain'] ?? '',
          },
          isPostNotification: true,
        );
      } else {
        print('التذكير تم فتحه بالفعل، لا حاجة لإعادة الجدولة.');
      }
    } catch (e) {
      print('خطأ أثناء التحقق/إعادة جدولة الإشعار: $e');
      _showSnackBar('فشل في معالجة التذكير: $e');
    }
  }

  /// عرض رسالة SnackBar لإعلام المستخدم
  static void _showSnackBar(String message) {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      print('تحذير: لا يمكن عرض SnackBar - navigatorKey لم يتم تهيئته.');
    }
  }

  /// إلغاء إشعارات الفحص المرتبطة بتذكير معين
  Future<void> _cancelCheckNotificationsForReminder(int reminderId) async {
    final notificationMap = await _getNotificationMap();
    final checkNotificationIds = notificationMap[reminderId]
            ?.where((id) => id.toString().startsWith('check_'))
            .toList() ??
        [];

    for (final id in checkNotificationIds) {
      await AwesomeNotifications().cancel(id);
      await _logNotificationEvent('Canceled Check', id, null);
    }

    if (notificationMap.containsKey(reminderId)) {
      notificationMap[reminderId] = notificationMap[reminderId]!
          .where((id) => !id.toString().startsWith('check_'))
          .toList();
      await _saveNotificationMap(notificationMap);
    }
  }

  /// جدولة إشعار تذكير أساسي (المنطق الأساسي للجدولة)
  Future<bool> scheduleReminderNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelKey,
    String? summary,
    Map<String, String>? payload,
    bool isCheckNotification = false,
  }) async {
    try {
      final tz.TZDateTime tzScheduledDate =
          tz.TZDateTime.from(scheduledDate, tz.local);
      final int notificationId = isCheckNotification
          ? int.parse('check_${createUniqueId()}')
          : createUniqueId();
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: channelKey,
          title: isCheckNotification ? null : title,
          body: isCheckNotification ? null : body,
          summary: isCheckNotification ? null : summary,
          wakeUpScreen: !isCheckNotification,
          category: isCheckNotification
              ? NotificationCategory.Service
              : NotificationCategory.Reminder,
          notificationLayout: NotificationLayout.Default,
          payload: payload,
          displayOnForeground: !isCheckNotification,
          displayOnBackground: !isCheckNotification,
        ),
        schedule: NotificationCalendar.fromDate(
          date: tzScheduledDate,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      print('تم جدولة إشعار لـ: $tzScheduledDate (ID: $notificationId)');

      if (payload != null && payload.containsKey('id')) {
        final reminderId = int.parse(payload['id']!);
        final notificationMap = await _getNotificationMap();
        if (!notificationMap.containsKey(reminderId)) {
          notificationMap[reminderId] = [];
        }
        notificationMap[reminderId]!.add(notificationId);
        await _saveNotificationMap(notificationMap);
      }

      if (!isCheckNotification) {
        _showSnackBar(
            'تم جدولة التذكير بنجاح لـ ${tzScheduledDate.toLocal()}!');
      }

      await _logNotificationEvent('Scheduled', notificationId, payload);

      return true;
    } catch (e) {
      print('خطأ أثناء جدولة الإشعار: $e');
      _showSnackBar('فشل في جدولة الإشعار: $e');
      return false;
    }
  }

  /// جدولة إشعار مع منطق التتبع
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    DateTime? scheduledDate,
    required String channelKey,
    String? summary,
    Map<String, String>? payload,
    bool isPostNotification = false,
  }) async {
    if (!_permissionsGranted) {
      _showSnackBar('أذونات الإشعارات مرفوضة.');
      return false;
    }

    try {
      final updatedPayload = Map<String, String>.from(payload ?? {});
      if (!updatedPayload.containsKey('createdAt')) {
        updatedPayload['createdAt'] = DateTime.now().toIso8601String();
      }
      if (!updatedPayload.containsKey('updatedAt')) {
        updatedPayload['updatedAt'] = DateTime.now().toIso8601String();
      }
      if (!updatedPayload.containsKey('title')) {
        updatedPayload['title'] = title;
      }

      final DateTime finalScheduledDate =
          scheduledDate ?? DateTime.now().add(const Duration(seconds: 5));
      await scheduleReminderNotification(
        title: title,
        body: body,
        scheduledDate: finalScheduledDate,
        channelKey: channelKey,
        summary: summary,
        payload: updatedPayload,
      );

      if (isPostNotification && updatedPayload.containsKey('url')) {
        final String postUrl = updatedPayload['url']!;
        final String importance = updatedPayload['importance'] ?? 'day';

        final delayDuration = const Duration(hours: 1);
        final checkTime = finalScheduledDate.add(delayDuration);

        await scheduleReminderNotification(
          title: '',
          body: '',
          scheduledDate: checkTime,
          channelKey: 'check_channel',
          payload: updatedPayload,
          isCheckNotification: true,
        );
      }

      return true;
    } catch (e) {
      print('خطأ أثناء جدولة الإشعار: $e');
      _showSnackBar('فشل في جدولة الإشعار: $e');
      return false;
    }
  }

  /// إنشاء معرف فريد للإشعارات
  int createUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  /// إلغاء جميع الإشعارات المرتبطة بتذكير معين
  Future<void> cancelReminderNotifications(int reminderId) async {
    final notificationMap = await _getNotificationMap();
    final notificationIds = notificationMap[reminderId] ?? [];

    for (final id in notificationIds) {
      await AwesomeNotifications().cancel(id);
      await _logNotificationEvent('Canceled', id, null);
    }

    notificationMap.remove(reminderId);
    await _saveNotificationMap(notificationMap);

    _showSnackBar('تم إلغاء إشعارات التذكير ID $reminderId بنجاح!');

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: createUniqueId(),
        channelKey: 'scheduled_channel',
        title: 'تأكيد الإلغاء',
        body: 'تم إلغاء التذكير ID $reminderId.',
      ),
    );
  }

  /// تحديث أو جدولة إشعارات عند تحديث تذكير
  Future<void> updateReminderNotifications(Reminder reminder) async {
    await cancelReminderNotifications(reminder.id);

    if (reminder.nextReminderTime != null &&
        reminder.nextReminderTime!.isNotEmpty) {
      await scheduleNotification(
        title: reminder.title,
        body: 'حان وقت تذكيرك!',
        scheduledDate: DateTime.parse(reminder.nextReminderTime!),
        channelKey: 'scheduled_channel',
        summary: 'إشعار تذكير',
        payload: {
          'id': reminder.id.toString(),
          'url': reminder.url ?? '',
          'content': reminder.content ?? '',
          'imageUrl': reminder.imageUrl ?? '',
          'importance': reminder.importance ?? '',
          'scheduledTimes': jsonEncode(reminder.scheduledTimes),
          'nextReminderTime': reminder.nextReminderTime ?? '',
          'createdAt': reminder.createdAt ?? '',
          'updatedAt': reminder.updatedAt ?? '',
          'category': reminder.category ?? '',
          'complexity': reminder.complexity ?? '',
          'domain': reminder.domain ?? '',
        },
        isPostNotification: true,
      );
    } else {
      _showSnackBar('لم يتم توفير وقت تذكير تالي لتحديث الإشعارات.');
    }
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    await _logNotificationEvent('Canceled All', 0, null);
    _showSnackBar('تم إلغاء جميع الإشعارات بنجاح!');
  }

  /// التحقق من حالة أذونات الإشعارات
  Future<bool> checkPermissions() async {
    return _permissionsGranted;
  }

  /// طلب أذونات الإشعارات
  Future<bool> requestPermissions() async {
    _permissionsGranted =
        await AwesomeNotifications().requestPermissionToSendNotifications();
    return _permissionsGranted;
  }

  /// حفظ خريطة الإشعارات في SharedPreferences
  Future<void> _saveNotificationMap(Map<int, List<int>> notificationMap) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stringKeyMap = notificationMap.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('notification_map', jsonEncode(stringKeyMap));
  }

  /// استرجاع خريطة الإشعارات من SharedPreferences
  Future<Map<int, List<int>>> _getNotificationMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mapString = prefs.getString('notification_map');
    if (mapString == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(mapString);
    return decoded.map(
      (key, value) => MapEntry(int.parse(key), (value as List).cast<int>()),
    );
  }

  /// تسجيل أحداث الإشعارات في SharedPreferences لأغراض التصحيح
  Future<void> _logNotificationEvent(
      String event, int id, Map<String, String>? payload) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('notification_logs') ?? [];
    logs.add(
        '${DateTime.now().toIso8601String()}: $event - ID: $id - Payload: $payload');
    await prefs.setStringList('notification_logs', logs);
  }
}
