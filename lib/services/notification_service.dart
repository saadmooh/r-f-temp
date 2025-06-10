import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flex_reminder/services/api_service.dart';
import 'package:flex_reminder/models/reminder.dart';
import 'package:flex_reminder/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final Map<int, Timer> _pendingTimers = {};
  final Map<int, Timer> _checkTimers = {}; // للفحص الخفي
  final Map<int, int> _attemptCounters = {}; // عداد المحاولات

  void _showSnackBar(String message, Color backgroundColor) {
    if (navigatorKey.currentContext != null) {
      final scaffoldMessenger =
          ScaffoldMessenger.of(navigatorKey.currentContext!);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      print('التطبيق غير نشط، تم تجاهل SnackBar: $message');
    }
  }

  Future<void> init() async {
    tz.initializeTimeZones();
    await AwesomeNotifications().initialize(
      'resource://drawable/notification',
      [
        NotificationChannel(
          channelKey: 'scheduled_channel',
          channelName: 'الإشعارات المجدولة',
          channelDescription: 'قناة للتذكيرات المجدولة',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          locked: true,
          playSound: true,
          soundSource: 'resource://raw/bell',
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
        // تم حذف قناة الفحص - نستخدم المؤقتات الخفية بدلاً منها
      ],
    );

    bool allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onNotificationActionReceived,
      onNotificationCreatedMethod: onNotificationCreated,
      onNotificationDisplayedMethod: onNotificationDisplayed,
      onDismissActionReceivedMethod: onDismissActionReceived,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreated(
      ReceivedNotification receivedNotification) async {
    print('📝 تم إنشاء الإشعار: ${receivedNotification.title}');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayed(
      ReceivedNotification receivedNotification) async {
    print(
        '📱 تم عرض الإشعار: ${receivedNotification.title} في ${DateTime.now()}');

    // لا نحتاج للتعامل مع إشعارات الفحص لأننا نستخدم المؤقتات الخفية
    final payload = receivedNotification.payload ?? {};
    final bool isCheckNotification = payload['isCheckNotification'] == 'true';

    if (!isCheckNotification) {
      print('🔔 إشعار تذكير رئيسي: ${receivedNotification.title}');
    } else {
      // هذا لن يحدث لأننا لا ننشئ إشعارات فحص بعد الآن
      print('⚠️ إشعار فحص غير متوقع - سيتم تجاهله');
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceived(
      ReceivedAction receivedAction) async {
    print('❌ تم تجاهل الإشعار: ${receivedAction.title}');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationActionReceived(
      ReceivedAction receivedAction) async {
    print('👆 تم النقر على الإشعار: ${receivedAction.title}');
    _instance._cancelTimerForNotification(receivedAction.id!);

    final payload = receivedAction.payload ?? {};
    final bool isCheckNotification = payload['isCheckNotification'] == 'true';

    if (!isCheckNotification) {
      final Reminder reminder = Reminder(
        id: receivedAction.id!,
        userId: 0,
        url: payload['url'] ?? '',
        title: receivedAction.title ?? 'تذكير',
        content: payload['content'] ?? '',
        imageUrl: payload['imageUrl'] ?? '',
        importance: payload['importance'] ?? '',
        scheduledTimes: (payload['scheduledTimes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        nextReminderTime: payload['nextReminderTime'] ?? '',
        isOpened: 1,
        createdAt: payload['createdAt'] ?? '',
        updatedAt: payload['updatedAt'] ?? '',
        category: payload['category'] ?? '',
        complexity: payload['complexity'] ?? '',
        domain: payload['domain'] ?? '',
      );

      try {
        final fetchedReminder =
            await ApiService().getReminderById(int.parse(payload['id']!));
        navigatorKey.currentState?.pushNamed(
          '/reminder',
          arguments: fetchedReminder,
        );
      } catch (e) {
        print('خطأ في جلب تفاصيل التذكير: $e');
        navigatorKey.currentState?.pushNamed('/reminder', arguments: reminder);
      }
    }
  }

  void _cancelTimerForNotification(int id) {
    if (_pendingTimers.containsKey(id)) {
      _pendingTimers[id]?.cancel();
      _pendingTimers.remove(id);
    }
  }

  // دالة رئيسية لجدولة التذكير مع فحص خفي
  Future<void> scheduleReminderWithHiddenCheck({
    required int reminderId,
    required String title,
    required String url,
    required DateTime scheduledDate,
    required String importance,
    Map<String, String>? additionalPayload,
  }) async {
    print('🔧 جدولة التذكير $reminderId: $title للوقت: $scheduledDate');

    // إلغاء أي تذكيرات وفحوصات سابقة
    await cancelReminderNotifications(reminderId);

    // إعداد البيانات المرفقة
    final Map<String, String> payload = {
      'id': reminderId.toString(),
      'url': url,
      'title': title,
      'importance': importance,
      'nextReminderTime': scheduledDate.toIso8601String(),
      ...?additionalPayload,
    };

    // جدولة الإشعار الرئيسي (المرئي للمستخدم)
    final bool scheduled = await scheduleReminderNotification(
      title: title,
      body: 'حان وقت التذكير!',
      scheduledDate: scheduledDate,
      channelKey: 'scheduled_channel',
      summary: 'إشعار التذكير',
      payload: payload,
    );

    if (scheduled) {
      // جدولة فحص خفي بعد 6 ساعات من الإشعار الرئيسي
      final Duration checkDelay = const Duration(hours: 6);
      _scheduleHiddenCheck(
        reminderId: reminderId,
        checkTime: scheduledDate.add(checkDelay),
        postUrl: url,
        title: title,
        importance: importance,
        additionalPayload: additionalPayload,
      );

      print(
          '✅ تم جدولة التذكير $reminderId مع فحص خفي بعد ${checkDelay.inHours} ساعات');
    } else {
      print('❌ فشل في جدولة التذكير $reminderId');
    }
  }

  // دالة الفحص الخفي (بدون إشعارات)
  void _scheduleHiddenCheck({
    required int reminderId,
    required DateTime checkTime,
    required String postUrl,
    required String title,
    required String importance,
    Map<String, String>? additionalPayload,
  }) {
    // إلغاء أي فحص خفي سابق لنفس التذكير
    _checkTimers[reminderId]?.cancel();

    final Duration delay = checkTime.difference(DateTime.now());

    if (delay.isNegative) {
      // إذا كان الوقت في الماضي، نفذ الفحص فوراً
      print('⚡ وقت الفحص في الماضي، تنفيذ فوري للتذكير $reminderId');
      _performBackgroundCheck(
          reminderId, postUrl, title, importance, additionalPayload);
      return;
    }

    // إنشاء مؤقت للفحص الخفي
    _checkTimers[reminderId] = Timer(delay, () {
      _performBackgroundCheck(
          reminderId, postUrl, title, importance, additionalPayload);
    });

    print('⏰ تم جدولة فحص خفي للتذكير $reminderId في: $checkTime');
    print(
        '⏳ المدة المتبقية: ${delay.inHours} ساعة و ${delay.inMinutes % 60} دقيقة');
  }

  // تنفيذ الفحص في الخلفية (بدون إشعارات مرئية)
  Future<void> _performBackgroundCheck(
    int reminderId,
    String postUrl,
    String title,
    String importance,
    Map<String, String>? additionalPayload,
  ) async {
    print('🔍 بدء فحص خفي للتذكير $reminderId في: ${DateTime.now()}');

    // التحقق من عدد المحاولات
    final int attempts = _attemptCounters[reminderId] ?? 0;
    print('📊 عدد المحاولات الحالي: $attempts من 5');

    if (attempts >= 5) {
      print(
          '⛔ تم تجاوز الحد الأقصى للمحاولات للتذكير $reminderId - إيقاف نهائي');
      await cancelReminderNotifications(reminderId);
      return;
    }

    try {
      // فحص حالة التذكير من الخادم
      print('🌐 جاري فحص حالة التذكير من الخادم...');
      final fetchedReminder = await ApiService().getReminder(postUrl);

      if (fetchedReminder.isOpened == 1) {
        // ✅ تم فتح التذكير - إنهاء جميع العمليات
        print('✅ تم فتح التذكير $reminderId بنجاح - إلغاء جميع العمليات');
        await cancelReminderNotifications(reminderId);

        // يمكن إضافة إشعار نجاح خفيف هنا (اختياري)
        // _showSnackBar('تم إنجاز التذكير: $title', Colors.green);
      } else {
        // ❌ لم يتم فتح التذكير - إعادة جدولة
        print(
            '❌ لم يتم فتح التذكير $reminderId بعد - المحاولة ${attempts + 1}');

        // طلب إعادة جدولة من الخادم
        print('🔄 جاري طلب إعادة جدولة من الخادم...');
        final Map<String, dynamic> resMap =
            await ApiService().reschedulePost(postUrl, importance);

        final String newScheduledTimeStr = resMap['post']['next_reminder_time'];
        final DateTime newScheduledDate = DateTime.parse(newScheduledTimeStr);

        // زيادة عداد المحاولات
        _attemptCounters[reminderId] = attempts + 1;

        print('📅 موعد جديد للتذكير: $newScheduledDate');
        print('🔢 عدد المحاولات الجديد: ${_attemptCounters[reminderId]}');

        // إعادة جدولة التذكير مع الفحص الخفي
        await scheduleReminderWithHiddenCheck(
          reminderId: reminderId,
          title: title,
          url: postUrl,
          scheduledDate: newScheduledDate,
          importance: importance,
          additionalPayload: additionalPayload,
        );

        print('🔄 تمت إعادة جدولة التذكير $reminderId بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في الفحص الخفي للتذكير $reminderId: $e');

      // في حالة الخطأ، يمكن المحاولة مرة أخرى بعد فترة قصيرة
      if (attempts < 3) {
        print('🔁 إعادة محاولة الفحص بعد 30 دقيقة بسبب الخطأ');
        _scheduleHiddenCheck(
          reminderId: reminderId,
          checkTime: DateTime.now().add(const Duration(minutes: 30)),
          postUrl: postUrl,
          title: title,
          importance: importance,
          additionalPayload: additionalPayload,
        );
      }
    }
  }

  Future<bool> scheduleReminderNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelKey,
    String? summary,
    Map<String, String>? payload,
  }) async {
    try {
      final int notificationId = createUniqueId();
      print('🆔 إنشاء إشعار بالمعرف: $notificationId');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: channelKey,
          title: title,
          body: body,
          summary: summary,
          wakeUpScreen: true,
          category: NotificationCategory.Reminder,
          notificationLayout: NotificationLayout.Default,
          payload: payload,
        ),
        schedule: NotificationCalendar.fromDate(
          date: scheduledDate,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      print('📅 تمت جدولة الإشعار لـ: $scheduledDate');

      // حفظ معرف الإشعار في الخريطة
      if (payload != null && payload.containsKey('id')) {
        final reminderId = int.parse(payload['id']!);
        final notificationMap = await _getNotificationMap();
        if (!notificationMap.containsKey(reminderId)) {
          notificationMap[reminderId] = [];
        }
        notificationMap[reminderId]!.add(notificationId);
        await _saveNotificationMap(notificationMap);
      }

      return true;
    } catch (e) {
      print('❌ خطأ في جدولة الإشعار: $e');
      return false;
    }
  }

  Future<bool> scheduleNotification({
    required String title,
    required String body,
    DateTime? scheduledDate,
    required String channelKey,
    String? summary,
    Map<String, String>? payload,
    bool isPostNotification = false,
  }) async {
    try {
      final DateTime finalScheduledDate =
          scheduledDate ?? DateTime.now().add(const Duration(seconds: 5));
      return await scheduleReminderNotification(
        title: title,
        body: body,
        scheduledDate: finalScheduledDate,
        channelKey: channelKey,
        summary: summary,
        payload: payload,
      );
    } catch (e) {
      print('❌ خطأ في جدولة الإشعار: $e');
      return false;
    }
  }

  int createUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  Future<void> cancelReminderNotifications(int reminderId) async {
    print('🗑️ إلغاء جميع العمليات للتذكير $reminderId');

    // إلغاء الإشعارات المرئية
    final notificationMap = await _getNotificationMap();
    final notificationIds = notificationMap[reminderId] ?? [];

    print('📱 إلغاء ${notificationIds.length} إشعار مرئي');
    for (final id in notificationIds) {
      await AwesomeNotifications().cancel(id);
    }

    // إلغاء المؤقتات الخفية
    if (_checkTimers.containsKey(reminderId)) {
      _checkTimers[reminderId]?.cancel();
      _checkTimers.remove(reminderId);
      print('⏰ تم إلغاء المؤقت الخفي');
    }

    // إزالة عداد المحاولات
    if (_attemptCounters.containsKey(reminderId)) {
      _attemptCounters.remove(reminderId);
      print('🔢 تم مسح عداد المحاولات');
    }

    // تنظيف خريطة الإشعارات
    notificationMap.remove(reminderId);
    await _saveNotificationMap(notificationMap);

    print('✅ تم إلغاء جميع العمليات للتذكير $reminderId بنجاح');
  }

  Future<void> updateReminderNotifications(
      Map<String, dynamic> reminderData) async {
    final reminderId = reminderData['id'] as int?;
    if (reminderId == null) {
      print('❌ لا يمكن تحديث الإشعارات: معرف التذكير مفقود');
      return;
    }

    print('🔄 تحديث إشعارات التذكير $reminderId');

    final nextReminderTimeStr = reminderData['next_reminder_time'] as String?;
    if (nextReminderTimeStr != null && nextReminderTimeStr.isNotEmpty) {
      final scheduledDate = DateTime.parse(nextReminderTimeStr);

      if (scheduledDate.isBefore(DateTime.now())) {
        print('⚠️ وقت الإشعار في الماضي، لن يتم جدولته: $nextReminderTimeStr');
        return;
      }

      final title = reminderData['title'] as String? ?? 'تذكير';
      final url = reminderData['url'] as String? ?? '';
      final importance = reminderData['importance'] as String? ?? 'day';

      // إعادة تعيين عداد المحاولات
      _attemptCounters[reminderId] = 0;

      // جدولة التذكير مع الفحص الخفي
      await scheduleReminderWithHiddenCheck(
        reminderId: reminderId,
        title: title,
        url: url,
        scheduledDate: scheduledDate,
        importance: importance,
        additionalPayload: {
          'content': reminderData['content']?.toString() ?? '',
          'imageUrl': reminderData['image_url']?.toString() ?? '',
          'createdAt': reminderData['created_at']?.toString() ?? '',
          'updatedAt': reminderData['updated_at']?.toString() ?? '',
          'category': reminderData['category']?.toString() ?? '',
          'complexity': reminderData['complexity']?.toString() ?? '',
          'domain': reminderData['domain']?.toString() ?? '',
        },
      );

      print('✅ تم تحديث التذكير $reminderId للوقت: $nextReminderTimeStr');
    } else {
      print('⚠️ لا يمكن تحديث الإشعارات: next_reminder_time مفقود');
    }
  }

  Future<List<DateTime>> getScheduledTimesForReminder(int reminderId) async {
    final notificationMap = await _getNotificationMap();
    final notificationIds = notificationMap[reminderId] ?? [];
    List<DateTime> scheduledTimes = [];

    for (final id in notificationIds) {
      final notifications =
          await AwesomeNotifications().listScheduledNotifications();
      for (final notification in notifications) {
        if (notification.content?.id == id) {
          final schedule = notification.schedule;
          if (schedule is NotificationCalendar) {
            final scheduledDate = DateTime(
              schedule.year ?? DateTime.now().year,
              schedule.month ?? DateTime.now().month,
              schedule.day ?? DateTime.now().day,
              schedule.hour ?? 0,
              schedule.minute ?? 0,
              schedule.second ?? 0,
              schedule.millisecond ?? 0,
            );
            scheduledTimes.add(scheduledDate);
          }
        }
      }
    }

    return scheduledTimes;
  }

  Future<void> cancelAllNotifications() async {
    print('🧹 إلغاء جميع الإشعارات والمؤقتات');

    await AwesomeNotifications().cancelAll();

    // إلغاء جميع المؤقتات الخفية
    for (final timer in _checkTimers.values) {
      timer.cancel();
    }
    _checkTimers.clear();

    // مسح عدادات المحاولات
    _attemptCounters.clear();

    // مسح خريطة الإشعارات
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_map');

    print('✅ تم إلغاء جميع الإشعارات والمؤقتات بنجاح');
  }

  Future<bool> checkPermissions() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  Future<bool> requestPermissions() async {
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<void> _saveNotificationMap(Map<int, List<int>> notificationMap) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stringKeyMap = notificationMap.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('notification_map', jsonEncode(stringKeyMap));
  }

  Future<Map<int, List<int>>> _getNotificationMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mapString = prefs.getString('notification_map');
    if (mapString == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(mapString);
    return decoded.map(
      (key, value) => MapEntry(int.parse(key), (value as List).cast<int>()),
    );
  }

  // معلومات إحصائية مفيدة للتطوير
  void printStatus() {
    print('📊 === حالة خدمة الإشعارات ===');
    print('🔔 إشعارات نشطة: ${_pendingTimers.length}');
    print('🔍 فحوصات خفية نشطة: ${_checkTimers.length}');
    print('🔢 عدادات المحاولات: ${_attemptCounters.length}');

    for (final entry in _attemptCounters.entries) {
      print('   - التذكير ${entry.key}: ${entry.value} محاولات');
    }

    for (final entry in _checkTimers.entries) {
      print('   - فحص خفي للتذكير ${entry.key}: نشط');
    }
    print('================================');
  }

  void dispose() {
    print('🧹 تنظيف خدمة الإشعارات...');

    // إلغاء جميع المؤقتات
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    for (final timer in _checkTimers.values) {
      timer.cancel();
    }

    _pendingTimers.clear();
    _checkTimers.clear();
    _attemptCounters.clear();

    print('✅ تم تنظيف جميع المؤقتات والموارد');
  }
}
