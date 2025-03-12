import 'package:flutter/material.dart';
import 'package:reminder/models/reminder.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/services/notification_service.dart';
import 'package:reminder/widgets/custom_app_bar.dart'; // إضافة استيراد CustomAppBar

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
  late String _importance;
  DateTime? _nextReminderTime;
  bool _isImportanceChanged = false; // لتتبع تغيير الأهمية
  bool _isNextReminderTimeChanged = false; // لتتبع تغيير وقت التذكير

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _importance = widget.reminder.importance ?? '';
    if (widget.reminder.nextReminderTime != null &&
        widget.reminder.nextReminderTime!.isNotEmpty) {
      _nextReminderTime = DateTime.parse(widget.reminder.nextReminderTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Edit Reminder',
        showSettings: true, // تفعيل زر الإعدادات
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title field (read-only since not mentioned for editing)
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    enabled: false, // جعل العنوان غير قابل للتعديل
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Toggle between editing Importance or Next Reminder Time
                  _buildEditToggle(),
                  const SizedBox(height: 16),

                  // Importance dropdown (visible only if editing importance)
                  if (_isImportanceChanged)
                    DropdownButtonFormField<String>(
                      value: _importance.isNotEmpty ? _importance : null,
                      decoration: const InputDecoration(
                        labelText: 'Importance',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      items: ['day', 'week', 'month']
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style:
                                        const TextStyle(color: Colors.black)),
                                enabled: e !=
                                    widget.reminder
                                        .importance, // تعطيل القيمة الحالية
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null &&
                            value != widget.reminder.importance) {
                          setState(() => _importance = value);
                        }
                      },
                    ),
                  const SizedBox(height: 16),

                  // Next reminder time (visible only if editing next reminder time)
                  if (_isNextReminderTimeChanged)
                    ListTile(
                      title: const Text('Next Reminder Time',
                          style: TextStyle(color: Colors.black)),
                      subtitle: Text(
                        _nextReminderTime != null
                            ? _nextReminderTime!.toLocal().toString()
                            : 'Not set',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today,
                            color: Colors.lightGreen),
                        onPressed: _selectDateTime,
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

  // Toggle button to switch between editing Importance or Next Reminder Time
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
            backgroundColor:
                _isImportanceChanged ? Colors.lightGreen : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: const Text(
            'Edit Importance',
            style: TextStyle(color: Colors.white, fontSize: 14),
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
            backgroundColor:
                _isNextReminderTimeChanged ? Colors.lightGreen : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: const Text(
            'Edit Next Reminder Time',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextReminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.lightGreen),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _nextReminderTime != null
          ? TimeOfDay.fromDateTime(_nextReminderTime!)
          : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.lightGreen),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _nextReminderTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final updatedReminder = widget.reminder.copyWith(
        title: _titleController.text,
        importance:
            _isImportanceChanged ? _importance : widget.reminder.importance,
        nextReminderTime: _isNextReminderTimeChanged
            ? _nextReminderTime?.toIso8601String()
            : widget.reminder.nextReminderTime,
      );

      // تحديث الإشعارات باستخدام الوقت الجديد
      await NotificationService().updateReminderNotifications(updatedReminder);

      // تمرير التذكير المحدث إلى ReminderDetailScreen
      Navigator.pop(context, updatedReminder);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
