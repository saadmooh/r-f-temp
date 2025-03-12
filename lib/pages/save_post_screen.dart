import 'package:flutter/material.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/services/notification_service.dart';
import 'package:reminder/l10n/app_localizations.dart'; // Updated import

class SavePostScreen extends StatefulWidget {
  final String? initialUrl;
  final VoidCallback? onSave;

  const SavePostScreen({Key? key, this.initialUrl, this.onSave})
      : super(key: key);

  @override
  _SavePostScreenState createState() => _SavePostScreenState();
}

class _SavePostScreenState extends State<SavePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  String? _selectedImportance;
  final List<String> _importanceOptions = [
    'day',
    'week',
    'month'
  ]; // القيم بالإنجليزية
  bool _isLoading = false;

  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) _urlController.text = widget.initialUrl!;
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
  }

  Future<void> _schedulePostNotification(
      String title, String nextReminderTime) async {
    try {
      final DateTime scheduledDate = DateTime.parse(nextReminderTime);
      await _notificationService.scheduleNotification(
        title: AppLocalizations.of(context)!.postNotificationTitle ??
            'Time for your post!',
        body: AppLocalizations.of(context)!.postNotificationBody(title) ??
            'The post "$title" is scheduled for now.',
        scheduledDate: scheduledDate,
        channelKey: 'scheduled_channel',
        summary: AppLocalizations.of(context)!.postNotificationSummary ??
            'Post Reminder',
        payload: {
          'url': _urlController.text,
          'importance': _selectedImportance ?? 'day',
          'title': title,
        },
        isPostNotification: true,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                    .errorSchedulingNotification(e.toString()) ??
                'Error scheduling post notification: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    Map<String, dynamic>? result;
    try {
      final url = _urlController.text.trim();
      if (url.isEmpty)
        throw Exception(
            AppLocalizations.of(context)!.urlRequired ?? 'URL is required');
      if (_selectedImportance == null || _selectedImportance!.isEmpty)
        throw Exception(AppLocalizations.of(context)!.importanceRequired ??
            'Importance is required');

      result = await _apiService
          .savePost({'url': url, 'importance': _selectedImportance});
      if (result['success'] == true) {
        final nextReminderTime = result['nextReminderTime'];
        final title = result['title'] ?? 'Untitled Post';
        if (nextReminderTime == null)
          throw Exception(
              AppLocalizations.of(context)!.nextReminderTimeMissing ??
                  'Next reminder time is missing in the response');
        if (title.isEmpty)
          throw Exception(AppLocalizations.of(context)!.titleMissing ??
              'Title is missing in the response');

        await _schedulePostNotification(title, nextReminderTime);

        final isPlaylist = result['is_playlist'] == true;
        final belongsToPlaylist = result['video_belongs_to_playlist'] == true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (isPlaylist || belongsToPlaylist)
                  ? AppLocalizations.of(context)!
                          .playlistSaved(nextReminderTime, title) ??
                      'Playlist saved! Notification scheduled for: $nextReminderTime with title: $title'
                  : AppLocalizations.of(context)!
                          .postSaved(nextReminderTime, title) ??
                      'Post saved! Notification scheduled for: $nextReminderTime with title: $title',
            ),
            backgroundColor: Colors.lightGreen,
          ),
        );

        widget.onSave?.call();
        Navigator.popUntil(context,
            (route) => route.isFirst || route.settings.name == '/reminders');
      } else {
        print(result['message']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null &&
                    (result['is_playlist'] == true ||
                        result['video_belongs_to_playlist'] == true)
                ? AppLocalizations.of(context)!
                        .playlistSaveError(error.toString()) ??
                    'Error saving playlist: $error'
                : AppLocalizations.of(context)!
                        .postSaveError(error.toString()) ??
                    'Error saving post: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: localizations.urlLabel,
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8.0)),
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return localizations.urlRequired;
                      final urlRegex = RegExp(
                          r'^(http(s)?:\/\/.)[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)$');
                      if (!urlRegex.hasMatch(value))
                        return localizations.invalidUrl;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.white,
                    value: _selectedImportance,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: localizations.importanceLabel,
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8.0)),
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    items: _importanceOptions.map((String importance) {
                      // عرض الخيارات بالعربية في الواجهة، مع إرسال القيم بالإنجليزية
                      final arabicImportance = _getArabicImportance(importance);
                      return DropdownMenuItem<String>(
                        value: importance, // القيمة المرسلة (إنجليزية)
                        child: Text(arabicImportance,
                            style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) =>
                        setState(() => _selectedImportance = newValue),
                    validator: (value) => value == null || value.isEmpty
                        ? localizations.importanceRequired
                        : null,
                  ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _savePost,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16.0)),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(localizations.saveButton,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // دالة لتحويل الأهمية من الإنجليزية إلى العربية لعرضها في الواجهة
  String _getArabicImportance(String englishImportance) {
    const Map<String, String> importanceMap = {
      'day': 'يوم',
      'week': 'أسبوع',
      'month': 'شهر',
    };
    return importanceMap[englishImportance.toLowerCase()] ?? englishImportance;
  }
}
