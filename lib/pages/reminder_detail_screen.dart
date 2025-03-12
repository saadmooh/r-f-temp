import 'package:flutter/material.dart';
import 'package:reminder/models/reminder.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/services/notification_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:reminder/pages/edit_reminder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // إضافة استيراد SharedPreferences
import 'package:cached_network_image/cached_network_image.dart'; // إضافة استيراد CachedNetworkImage

class ReminderDetailScreen extends StatefulWidget {
  @override
  _ReminderDetailScreenState createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  Reminder? _reminder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reminder == null) {
      _reminder = ModalRoute.of(context)!.settings.arguments as Reminder;
    }
  }

  /// تعيين علم في SharedPreferences للإشارة إلى الحاجة لتحديث شاشة التذكيرات
  Future<void> _setRefreshFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('needs_refresh', true);
  }

  @override
  Widget build(BuildContext context) {
    if (_reminder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل التذكير',
              style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
        ),
        backgroundColor: Colors.white,
        body: const Center(
            child: Text('لم يتم توفير تذكير.',
                style: TextStyle(color: Colors.black))),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context,
            {'type': 'تحديث', 'reminder': _reminder}); // إرجاع التذكير المحدث
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_reminder?.title ?? 'بدون عنوان',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0, // إزالة الظل لمظهر أنظف
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () async {
                final updatedReminder = await Navigator.push<Reminder>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditReminderScreen(
                      reminder: _reminder!,
                    ),
                  ),
                );
                if (updatedReminder != null) {
                  setState(() => _reminder =
                      updatedReminder); // استبدال التذكير المحلي بالمحدث
                  Navigator.pop(context, {
                    'type': 'تحديث',
                    'reminder': updatedReminder
                  }); // تمرير التذكير المحدث إلى شاشة التذكيرات
                }
              },
            ),
            _buildDeleteButton(context), // إضافة زر الحذف إلى شريط الأدوات
          ],
        ),
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0, // إزالة الظل لتصميم مسطح
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصورة (إن وجدت)
                  if (_reminder!.imageUrl != null &&
                      _reminder!.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: _reminder!.imageUrl!,
                        fit: BoxFit.cover,
                        height: 200, // ارتفاع الصورة، يمكن التعديل حسب الحاجة
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.lightGreen)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // العنوان
                  Text(
                    _reminder?.title ?? 'بدون عنوان',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // العلامات (الفئة، التعقيد، المجال)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (_reminder!.category != null &&
                          _reminder!.category!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _reminder!.category!,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_reminder!.complexity != null &&
                          _reminder!.complexity!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _reminder!.complexity!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_reminder!.domain != null &&
                          _reminder!.domain!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _reminder!.domain!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // التاريخ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _reminder!.createdAt != null &&
                              _reminder!.createdAt!.isNotEmpty
                          ? _formatDate(_reminder!.createdAt!)
                          : 'بدون تاريخ',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // وقت التذكير التالي
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        (_reminder?.nextReminderTime?.isNotEmpty ?? false)
                            ? _reminder!.nextReminderTime!
                            : 'لم يتم تعيين تذكير',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // زر "الذهاب" إذا كان هناك رابط
                  if (_reminder?.url != null && _reminder!.url!.isNotEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiService().updateStats(_reminder!.url!, true);
                          await _setRefreshFlag(); // تعيين العلم للإشارة إلى الحاجة لتحديث شاشة التذكيرات
                          if (!await launchUrlString(_reminder!.url!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعذر فتح ${_reminder!.url}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                      ),
                      child: const Text(
                        'الذهاب',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // الحقول الإضافية
                  if (_reminder!.url != null && _reminder!.url!.isNotEmpty)
                    Text('الرابط: ${_reminder!.url}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  if (_reminder!.importance != null &&
                      _reminder!.importance!.isNotEmpty)
                    Text('الأهمية: ${_reminder!.importance}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  if (_reminder!.scheduledTimes.isNotEmpty)
                    Text(
                        'الأوقات المجدولة: ${_reminder!.scheduledTimes.join(", ")}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  if (_reminder!.createdAt != null &&
                      _reminder!.createdAt!.isNotEmpty)
                    Text('تم الإنشاء في: ${_formatDate(_reminder!.createdAt!)}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  if (_reminder!.updatedAt != null &&
                      _reminder!.updatedAt!.isNotEmpty)
                    Text('تم التحديث في: ${_formatDate(_reminder!.updatedAt!)}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // تنسيق التاريخ ليكون مثل "مارس 15، 2024"
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.monthName} ${date.day}، ${date.year}';
  }

  Widget _buildDeleteButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.black),
      onPressed: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف التذكير',
                style: TextStyle(color: Colors.black)),
            content: const Text('هل أنت متأكد من رغبتك في حذف هذا التذكير؟',
                style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.lightGreen)),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    if (_reminder != null && _reminder!.id != null) {
                      // حذف التذكير من قاعدة البيانات باستخدام ApiService
                      await ApiService().deleteReminder(_reminder!.id!);
                      // إلغاء الإشعارات الخاصة بالتذكير
                      await NotificationService()
                          .cancelReminderNotifications(_reminder!.id!);

                      Navigator.pop(context); // إغلاق نافذة الحوار
                      Navigator.pop(context, {
                        'type': 'حذف',
                        'id': _reminder!.id
                      }); // إرجاع ID للحذف
                    } else {
                      throw Exception('معرف التذكير مفقود أو غير صالح');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ أثناء حذف التذكير: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension DateTimeExtension on DateTime {
  String get monthName {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[month - 1];
  }
}
