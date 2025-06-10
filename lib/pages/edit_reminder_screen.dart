import 'package:flutter/material.dart';
import 'package:flex_reminder/models/reminder.dart';
import 'package:flex_reminder/services/api_service.dart';
import 'package:flex_reminder/services/notification_service.dart';
import 'package:flex_reminder/widgets/custom_app_bar.dart';
import 'package:flex_reminder/l10n/app_localizations.dart'; // استيراد AppLocalizations

class EditReminderScreen extends StatefulWidget {
  final Reminder reminder;

  const EditReminderScreen({Key? key, required this.reminder})
      : super(key: key);

  @override
  _EditReminderScreenState createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late String
      _importance; // ستحتوي دائمًا على القيمة الإنجليزية (day, week, month)
  DateTime? _nextReminderTime;
  bool _isImportanceChanged = false;
  bool _isNextReminderTimeChanged = false;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();
  late AppLocalizations _localizations;

  // تعريف خيارات الأهمية
  final Map<String, Map<String, String>> _importanceOptions = {
    'day': {'en': 'Day', 'ar': 'يوم'},
    'week': {'en': 'Week', 'ar': 'أسبوع'},
    'month': {'en': 'Month', 'ar': 'شهر'},
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    // تحويل قيمة importance إلى القيمة الإنجليزية المقابلة
    _importance = _normalizeImportance(widget.reminder.importance);
    if (widget.reminder.nextReminderTime != null &&
        widget.reminder.nextReminderTime!.isNotEmpty) {
      _nextReminderTime = DateTime.parse(widget.reminder.nextReminderTime!);
    }
  }

  // دالة لتحويل قيمة importance إلى القيمة الإنجليزية المقابلة
  String _normalizeImportance(String? importance) {
    if (importance == null) return 'day'; // قيمة افتراضية

    // تحقق مما إذا كانت القيمة باللغة الإنجليزية
    if (_importanceOptions.containsKey(importance)) {
      return importance; // القيمة بالفعل باللغة الإنجليزية
    }

    // تحقق مما إذا كانت القيمة باللغة العربية
    for (var entry in _importanceOptions.entries) {
      if (entry.value['ar'] == importance) {
        return entry.key; // إرجاع القيمة الإنجليزية المقابلة
      }
    }

    // إذا لم تكن القيمة معروفة، استخدم قيمة افتراضية
    return 'day';
  }

  @override
  Widget build(BuildContext context) {
    _localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: _localizations.editReminderTitle,
        showSettings: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        child: Card(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // حقل العنوان
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: _localizations.titleLabel,
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    enabled: false,
                    validator: (value) => (value == null || value.isEmpty)
                        ? _localizations.requiredField
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // التبديل بين تعديل الأهمية أو وقت التذكير
                  _buildEditToggle(),
                  const SizedBox(height: 16),

                  // قائمة منسدلة للأهمية
                  if (_isImportanceChanged)
                    DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      value: _importance, // القيمة دائمًا باللغة الإنجليزية
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: _localizations.importanceLabel,
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      items: _importanceOptions.keys.map((String importance) {
                        return DropdownMenuItem<String>(
                          value: importance, // القيمة دائمًا باللغة الإنجليزية
                          child: Text(
                            _localizations.locale.languageCode == 'ar'
                                ? _importanceOptions[importance]!['ar']!
                                : _importanceOptions[importance]!['en']!,
                            style: const TextStyle(color: Colors.black),
                          ),
                          enabled: importance !=
                              _normalizeImportance(widget.reminder.importance),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null &&
                            value !=
                                _normalizeImportance(
                                    widget.reminder.importance)) {
                          setState(() => _importance = value);
                        }
                      },
                    ),

                  // وقت التذكير التالي
                  if (_isNextReminderTimeChanged)
                    ListTile(
                      title: Text(
                        _localizations.nextReminderTimeLabel,
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        _nextReminderTime != null
                            ? _nextReminderTime!.toLocal().toString()
                            : _localizations.notSpecified,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Builder(
                        builder: (BuildContext context) {
                          return IconButton(
                            icon: const Icon(Icons.calendar_today,
                                color: Colors.black),
                            onPressed: () {
                              print('تم الضغط على زر التقويم');
                              _selectDateTime(context);
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 32),

                  // زر الحفظ
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _localizations.saveButton,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // زر التبديل
  Widget _buildEditToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isImportanceChanged = true;
              _isNextReminderTimeChanged = false;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: Text(
            _localizations.editImportanceButton,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isImportanceChanged = false;
              _isNextReminderTimeChanged = true;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: Text(
            _localizations.editNextReminderTimeButton,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext dialogContext) async {
    print('تم استدعاء _selectDateTime');
    final now = DateTime.now();
    // إذا كان initialDate قديمًا، اجعله الوقت الحالي
    final initialDate =
        _nextReminderTime != null && _nextReminderTime!.isBefore(now)
            ? now
            : _nextReminderTime ?? now;

    final date = await showDatePicker(
      context: dialogContext,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        print('داخل builder لـ DatePicker');
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    ).catchError((e) {
      print('خطأ في showDatePicker: $e');
      return null;
    });

    if (date == null) {
      print('تم إلغاء اختيار التاريخ');
      return;
    }

    final time = await showTimePicker(
      context: dialogContext,
      initialTime: _nextReminderTime != null
          ? TimeOfDay.fromDateTime(_nextReminderTime!)
          : TimeOfDay.now(),
      builder: (context, child) {
        print('داخل builder لـ TimePicker');
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    ).catchError((e) {
      print('خطأ في showTimePicker: $e');
      return null;
    });

    if (time == null) {
      print('تم إلغاء اختيار الوقت');
      return;
    }

    setState(() {
      _nextReminderTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      print('تم تحديث _nextReminderTime إلى: $_nextReminderTime');
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedReminder = widget.reminder.copyWith(
        title: _titleController.text,
        importance:
            _isImportanceChanged ? _importance : widget.reminder.importance,
        nextReminderTime: _isNextReminderTimeChanged
            ? _nextReminderTime?.toIso8601String()
            : widget.reminder.nextReminderTime,
      );
      print('Updated Reminder: $updatedReminder');

      if (_isImportanceChanged) {
        // استدعاء reschedulePost وتمرير الاستجابة الخام
        final result = await _apiService.reschedulePost(
          updatedReminder.url!,
          updatedReminder.importance!,
        );

        // الاستجابة الآن هي Map<String, dynamic>
        final postData = result['post'] as Map<String, dynamic>;

        // تحديث الإشعارات باستخدام بيانات المنشور
        await NotificationService().updateReminderNotifications(postData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizations.reminderUpdatedSuccess),
            backgroundColor: Colors.lightGreen,
          ),
        );

        // استخراج next_reminder_time من الاستجابة
        final bestTime = DateTime.parse(postData['next_reminder_time']);
        Navigator.pop(
          context,
          updatedReminder.copyWith(
              nextReminderTime: bestTime.toIso8601String()),
        );
      } else if (_isNextReminderTimeChanged) {
        // استدعاء updateReminder وتمرير الاستجابة الخام
        final result = await _apiService.updateReminder(updatedReminder);
        if (result != null) {
          await NotificationService()
              .updateReminderNotifications(result['post']);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localizations.reminderUpdatedSuccess),
              backgroundColor: Colors.lightGreen,
            ),
          );

          // استخراج next_reminder_time من الاستجابة
          final bestTime = DateTime.parse(result['post']['next_reminder_time']);
          Navigator.pop(
            context,
            updatedReminder.copyWith(
                nextReminderTime: bestTime.toIso8601String()),
          );
        } else {
          throw Exception(_localizations.unexpectedError);
        }
      }
    } catch (e) {
      print('خطأ في _saveReminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localizations.reminderUpdateError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
