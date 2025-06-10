import 'package:flutter/material.dart';
import 'package:flex_reminder/models/reminder.dart';
import 'package:flex_reminder/services/api_service.dart';
import 'package:flex_reminder/services/notification_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flex_reminder/pages/edit_reminder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flex_reminder/l10n/app_localizations.dart';

class ReminderDetailScreen extends StatefulWidget {
  @override
  _ReminderDetailScreenState createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  Reminder? _reminder;
  late AppLocalizations localizations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
    if (_reminder == null) {
      _reminder = ModalRoute.of(context)!.settings.arguments as Reminder;
    }
  }

  Future<void> _setRefreshFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('needs_refresh', true);
  }

  @override
  Widget build(BuildContext context) {
    if (_reminder == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.editReminderTitle,
              style: const TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        body: Center(
            child: Text(localizations.reminderNotProvided,
                style: const TextStyle(color: Colors.black))),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, {'type': 'update', 'reminder': _reminder});
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_reminder?.title ?? localizations.noTitle,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
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
                  setState(() => _reminder = updatedReminder);
                  Navigator.pop(
                      context, {'type': 'update', 'reminder': updatedReminder});
                }
              },
            ),
            _buildDeleteButton(context),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة في الأعلى
            if (_reminder!.imageUrl != null && _reminder!.imageUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: _reminder!.imageUrl!,
                  fit: BoxFit.cover,
                  height: 200,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.lightGreen)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),

            // المحتوى الأساسي
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان
                    Text(
                      _reminder?.title ?? localizations.noTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // الوسوم
                    Wrap(
                      spacing: 8,
                      children: [
                        if (_reminder!.category != null &&
                            _reminder!.category!.isNotEmpty)
                          _buildTag(_reminder!.category!,
                              Colors.lightBlue[100]!, Colors.blue),
                        if (_reminder!.complexity != null &&
                            _reminder!.complexity!.isNotEmpty)
                          _buildTag(_reminder!.complexity!, Colors.orange[100]!,
                              Colors.orange),
                        if (_reminder!.domain != null &&
                            _reminder!.domain!.isNotEmpty)
                          _buildTag(_reminder!.domain!, Colors.green[100]!,
                              Colors.green),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // التاريخ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _reminder!.createdAt != null &&
                                _reminder!.createdAt!.isNotEmpty
                            ? _formatDate(_reminder!.createdAt!, context)
                            : localizations.noDate,
                        style: const TextStyle(
                          color: Colors.grey,
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
                              : localizations.noReminderSet,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // الأهمية
                    Text(
                        '${localizations.importancePrefix} ${_reminder!.importance}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // زر الانتقال في الأسفل بعرض كامل
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService().updateStats(_reminder!.url!, true);
                      await _setRefreshFlag();
                      if (!await launchUrlString(_reminder!.url!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localizations.unableToOpenLink),
                            backgroundColor: Color(0xfffb0a0a),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.error(e.toString())),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff050505),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    localizations.goTo,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الدوال المساعدة
  String _formatDate(String dateString, BuildContext context) {
    final date = DateTime.parse(dateString);
    return '${date.monthName(context)} ${date.day}، ${date.year}';
  }

  Widget _buildDeleteButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.black),
      onPressed: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(localizations.deleteReminder,
                style: const TextStyle(color: Colors.black)),
            content: Text(localizations.confirmDeleteReminder,
                style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations.cancel,
                    style: const TextStyle(color: Colors.lightGreen)),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    if (_reminder != null && _reminder!.id != null) {
                      await ApiService().deleteReminder(_reminder!.id!);
                      await NotificationService()
                          .cancelReminderNotifications(_reminder!.id!);

                      Navigator.pop(context);
                      Navigator.pop(
                          context, {'type': 'delete', 'id': _reminder!.id});
                    } else {
                      throw Exception('معرف التذكير مفقود أو غير صالح');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.error(e.toString())),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(localizations.delete,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }
}

extension DateTimeExtension on DateTime {
  String monthName(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    const monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    const monthsAr = [
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
    return localizations!.locale.languageCode == 'ar'
        ? monthsAr[month - 1]
        : monthsEn[month - 1];
  }
}
