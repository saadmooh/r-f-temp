import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // النصوص المتوفرة بناءً على اللغة مع إضافة ترجمات لمعلومات المستخدم
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Reminder App',
      'searchPosts': 'Search posts...',
      'navigationFailed': 'Navigation failed: {message}',
      'filterPressed': 'Filter pressed',
      'timeSlots': 'Time Slots',
      'subscriptionManagement': 'Subscription Management',
      'stats': 'Stats',
      'logout': 'Logout',
      'searchReminders': 'Search Reminders...',
      'unexpectedError': 'An unexpected error occurred',
      'unauthorizedError': 'Unauthorized access',
      'remindersTitle': 'Reminders',
      'unreadReminders': 'Unread Reminders',
      'readReminders': 'Read Reminders',
      'noUnreadReminders': 'No unread reminders',
      'filters': 'Filters',
      'categories': 'Categories',
      'complexity': 'Complexity',
      'domains': 'Domains',
      'clearFilters': 'Clear Filters',
      'close': 'Close',
      'postNotificationTitle': 'Post Saved',
      'postNotificationSummary': 'Post Saved Summary',
      'urlRequired': 'URL is required',
      'importanceRequired': 'Importance is required',
      'nextReminderTimeMissing': 'Next reminder time is missing',
      'titleMissing': 'Title is required',
      'urlLabel': 'URL',
      'invalidUrl': 'Invalid URL',
      'importanceLabel': 'Importance',
      'saveButton': 'Save',
      // ترجمات جديدة لمعلومات المستخدم
      'profileUpdate': 'Update Profile',
      'profileUpdateSuccess': 'Profile updated successfully',
      'profileUpdateFailed': 'Failed to update profile',
      'uploadPhoto': 'Upload Photo',
      'changeLanguage': 'Change Language',
      'languageUpdated': 'Language updated successfully',
      'languageUpdateFailed': 'Failed to update language',
      'currentLanguage': 'Current Language',
      'selectLanguage': 'Select Language',
      'profileSettings': 'Profile Settings',
      'editProfile': 'Edit Profile',
      'saveChanges': 'Save Changes',
      'cancel': 'Cancel',
      // ترجمات جديدة بناءً على الأخطاء
      'userProfile': 'User Profile',
      'tapToChangePhoto': 'Tap to change photo',
      'name': 'Name',
    },
    'ar': {
      'appTitle': 'تطبيق التذكير',
      'searchPosts': 'ابحث في المنشورات...',
      'navigationFailed': 'فشل التنقل: {message}',
      'filterPressed': 'تم الضغط على الفلتر',
      'timeSlots': 'فترات الوقت',
      'subscriptionManagement': 'إدارة الاشتراك',
      'stats': 'الإحصائيات',
      'logout': 'تسجيل الخروج',
      'searchReminders': 'ابحث في التذكيرات...',
      'unexpectedError': 'حدث خطأ غير متوقع',
      'unauthorizedError': 'وصول غير مخول',
      'remindersTitle': 'التذكيرات',
      'unreadReminders': 'التذكيرات غير المقروءة',
      'readReminders': 'التذكيرات المقروءة',
      'noUnreadReminders': 'لا توجد تذكيرات غير مقروءة',
      'filters': 'المرشحات',
      'categories': 'الفئات',
      'complexity': 'التعقيد',
      'domains': 'النطاقات',
      'clearFilters': 'مسح المرشحات',
      'close': 'إغلاق',
      'postNotificationTitle': 'تم حفظ المنشور',
      'postNotificationSummary': 'ملخص حفظ المنشور',
      'urlRequired': 'الرابط مطلوب',
      'importanceRequired': 'الأهمية مطلوبة',
      'nextReminderTimeMissing': 'وقت التذكير التالي مفقود',
      'titleMissing': 'العنوان مطلوب',
      'urlLabel': 'الرابط',
      'invalidUrl': 'رابط غير صحيح',
      'importanceLabel': 'الأهمية',
      'saveButton': 'حفظ',
      // ترجمات جديدة لمعلومات المستخدم
      'profileUpdate': 'تحديث الملف الشخصي',
      'profileUpdateSuccess': 'تم تحديث الملف الشخصي بنجاح',
      'profileUpdateFailed': 'فشل تحديث الملف الشخصي',
      'uploadPhoto': 'رفع صورة',
      'changeLanguage': 'تغيير اللغة',
      'languageUpdated': 'تم تحديث اللغة بنجاح',
      'languageUpdateFailed': 'فشل تحديث اللغة',
      'currentLanguage': 'اللغة الحالية',
      'selectLanguage': 'اختر اللغة',
      'profileSettings': 'إعدادات الملف الشخصي',
      'editProfile': 'تعديل الملف الشخصي',
      'saveChanges': 'حفظ التغييرات',
      'cancel': 'إلغاء',
      // ترجمات جديدة بناءً على الأخطاء
      'userProfile': 'الملف الشخصي',
      'tapToChangePhoto': 'اضغط لتغيير الصورة',
      'name': 'الاسم',
    },
  };

  // دوال الوصول إلى النصوص
  String get appTitle =>
      _localizedValues[locale.languageCode]?['appTitle'] ?? 'Reminder App';
  String get searchPosts =>
      _localizedValues[locale.languageCode]?['searchPosts'] ??
      'Search posts...';
  String navigationFailed(String message) =>
      _localizedValues[locale.languageCode]?['navigationFailed']
          ?.replaceFirst('{message}', message) ??
      'Navigation failed: $message';
  String get filterPressed =>
      _localizedValues[locale.languageCode]?['filterPressed'] ??
      'Filter pressed';
  String get timeSlots =>
      _localizedValues[locale.languageCode]?['timeSlots'] ?? 'Time Slots';
  String get subscriptionManagement =>
      _localizedValues[locale.languageCode]?['subscriptionManagement'] ??
      'Subscription Management';
  String get stats =>
      _localizedValues[locale.languageCode]?['stats'] ?? 'Stats';
  String get logout =>
      _localizedValues[locale.languageCode]?['logout'] ?? 'Logout';
  String get searchReminders =>
      _localizedValues[locale.languageCode]?['searchReminders'] ??
      'Search Reminders...';
  String get unexpectedError =>
      _localizedValues[locale.languageCode]?['unexpectedError'] ??
      'An unexpected error occurred';
  String get unauthorizedError =>
      _localizedValues[locale.languageCode]?['unauthorizedError'] ??
      'Unauthorized access';
  String get remindersTitle =>
      _localizedValues[locale.languageCode]?['remindersTitle'] ?? 'Reminders';
  String get unreadReminders =>
      _localizedValues[locale.languageCode]?['unreadReminders'] ??
      'Unread Reminders';
  String get readReminders =>
      _localizedValues[locale.languageCode]?['readReminders'] ??
      'Read Reminders';
  String get noUnreadReminders =>
      _localizedValues[locale.languageCode]?['noUnreadReminders'] ??
      'No unread reminders';
  String get filters =>
      _localizedValues[locale.languageCode]?['filters'] ?? 'Filters';
  String get categories =>
      _localizedValues[locale.languageCode]?['categories'] ?? 'Categories';
  String get complexity =>
      _localizedValues[locale.languageCode]?['complexity'] ?? 'Complexity';
  String get domains =>
      _localizedValues[locale.languageCode]?['domains'] ?? 'Domains';
  String get clearFilters =>
      _localizedValues[locale.languageCode]?['clearFilters'] ?? 'Clear Filters';
  String get close =>
      _localizedValues[locale.languageCode]?['close'] ?? 'Close';
  String get postNotificationTitle =>
      _localizedValues[locale.languageCode]?['postNotificationTitle'] ??
      'Post Saved';
  String get postNotificationSummary =>
      _localizedValues[locale.languageCode]?['postNotificationSummary'] ??
      'Post Saved Summary';
  String get urlRequired =>
      _localizedValues[locale.languageCode]?['urlRequired'] ??
      'URL is required';
  String get importanceRequired =>
      _localizedValues[locale.languageCode]?['importanceRequired'] ??
      'Importance is required';
  String get nextReminderTimeMissing =>
      _localizedValues[locale.languageCode]?['nextReminderTimeMissing'] ??
      'Next reminder time is missing';
  String get titleMissing =>
      _localizedValues[locale.languageCode]?['titleMissing'] ??
      'Title is required';
  String get urlLabel =>
      _localizedValues[locale.languageCode]?['urlLabel'] ?? 'URL';
  String get invalidUrl =>
      _localizedValues[locale.languageCode]?['invalidUrl'] ?? 'Invalid URL';
  String get importanceLabel =>
      _localizedValues[locale.languageCode]?['importanceLabel'] ?? 'Importance';
  String get saveButton =>
      _localizedValues[locale.languageCode]?['saveButton'] ?? 'Save';
  // دوال جديدة لمعلومات المستخدم
  String get profileUpdate =>
      _localizedValues[locale.languageCode]?['profileUpdate'] ??
      'Update Profile';
  String get profileUpdateSuccess =>
      _localizedValues[locale.languageCode]?['profileUpdateSuccess'] ??
      'Profile updated successfully';
  String get profileUpdateFailed =>
      _localizedValues[locale.languageCode]?['profileUpdateFailed'] ??
      'Failed to update profile';
  String get uploadPhoto =>
      _localizedValues[locale.languageCode]?['uploadPhoto'] ?? 'Upload Photo';
  String get changeLanguage =>
      _localizedValues[locale.languageCode]?['changeLanguage'] ??
      'Change Language';
  String get languageUpdated =>
      _localizedValues[locale.languageCode]?['languageUpdated'] ??
      'Language updated successfully';
  String get languageUpdateFailed =>
      _localizedValues[locale.languageCode]?['languageUpdateFailed'] ??
      'Failed to update language';
  String get currentLanguage =>
      _localizedValues[locale.languageCode]?['currentLanguage'] ??
      'Current Language';
  String get selectLanguage =>
      _localizedValues[locale.languageCode]?['selectLanguage'] ??
      'Select Language';
  String get profileSettings =>
      _localizedValues[locale.languageCode]?['profileSettings'] ??
      'Profile Settings';
  String get editProfile =>
      _localizedValues[locale.languageCode]?['editProfile'] ?? 'Edit Profile';
  String get saveChanges =>
      _localizedValues[locale.languageCode]?['saveChanges'] ?? 'Save Changes';
  String get cancel =>
      _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  // ترجمات جديدة بناءً على الأخطاء
  String get userProfile =>
      _localizedValues[locale.languageCode]?['userProfile'] ?? 'User Profile';
  String get tapToChangePhoto =>
      _localizedValues[locale.languageCode]?['tapToChangePhoto'] ??
      'Tap to change photo';
  String get name => _localizedValues[locale.languageCode]?['name'] ?? 'Name';
  String get updateProfile =>
      _localizedValues[locale.languageCode]?['updateProfile'] ??
      'Update Profile';

  // دوال ديناميكية مع معاملات
  String postNotificationBody(String title) =>
      _localizedValues[locale.languageCode]?['postNotificationBody']
          ?.replaceFirst('{title}', title) ??
      'Your post {title} has been saved successfully';
  String errorSchedulingNotification(String error) =>
      _localizedValues[locale.languageCode]?['errorSchedulingNotification']
          ?.replaceFirst('{error}', error) ??
      'Error scheduling notification: {error}';
  String playlistSaved(DateTime nextReminderTime, String title) =>
      _localizedValues[locale.languageCode]?['playlistSaved']
          ?.replaceFirst('{time}', nextReminderTime.toString())
          .replaceFirst('{title}', title) ??
      'Playlist {title} saved successfully at {time}';
  String postSaved(DateTime nextReminderTime, String title) =>
      _localizedValues[locale.languageCode]?['postSaved']
          ?.replaceFirst('{time}', nextReminderTime.toString())
          .replaceFirst('{title}', title) ??
      'Post {title} saved successfully at {time}';
  String playlistSaveFailed(String error) =>
      _localizedValues[locale.languageCode]?['playlistSaveFailed']
          ?.replaceFirst('{error}', error) ??
      'Failed to save playlist: {error}';
  String postSaveFailed(String error) =>
      _localizedValues[locale.languageCode]?['postSaveFailed']
          ?.replaceFirst('{error}', error) ??
      'Failed to save post: {error}';
  String playlistSaveError(String error) =>
      _localizedValues[locale.languageCode]?['playlistSaveError']
          ?.replaceFirst('{error}', error) ??
      'Error saving playlist: {error}';
  String postSaveError(String error) =>
      _localizedValues[locale.languageCode]?['postSaveError']
          ?.replaceFirst('{error}', error) ??
      'Error saving post: {error}';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
