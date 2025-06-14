import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_reminder/models/reminder.dart';
import 'package:flex_reminder/models/reminders_response.dart';
import 'package:flex_reminder/services/api_service.dart';
import 'package:flex_reminder/services/notification_service.dart';
import 'package:flex_reminder/pages/save_post_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flex_reminder/pages/reminder_detail_screen.dart';
import 'package:flex_reminder/pages/edit_reminder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_reminder/widgets/upper_app_bar.dart';
import 'package:flex_reminder/widgets/lower_navigation_bar.dart';
import 'package:flex_reminder/l10n/app_localizations.dart';
import 'package:flex_reminder/utils/language_manager.dart';
import 'package:flex_reminder/providers/auth_provider.dart';

class _ReminderSearchDelegate extends SearchDelegate<String> {
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;
  final AppLocalizations appLocalizations;

  _ReminderSearchDelegate(
      this.initialQuery, this.onQueryChanged, this.appLocalizations);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.black),
        onPressed: () {
          query = '';
          onQueryChanged('');
          close(context, '');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final isArabic = Provider.of<LanguageManager>(context, listen: false)
            .locale
            .languageCode ==
        'ar';
    return IconButton(
      icon: Icon(
        isArabic ? Icons.chevron_right : Icons.chevron_left,
        color: Colors.black,
      ),
      onPressed: () => close(context, query),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onQueryChanged(query);
    return Container(color: Colors.white);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    onQueryChanged(query);
    return Container(color: Colors.white);
  }

  @override
  String get searchFieldLabel =>
      appLocalizations.searchReminders ?? 'Search reminders...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
    );
  }
}

class RemindersScreen extends StatefulWidget {
  final int initialIndex;

  const RemindersScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  List<Reminder> _reminders = [];
  List<String> _categories = [];
  List<String> _complexities = [];
  List<String> _domains = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  StreamSubscription? _intentSub;
  String? _sharedText;

  String? _selectedCategory;
  String? _selectedComplexity;
  String? _selectedDomain;

  late TabController _tabController;
  int _currentPage = 1;
  int _perPage = 4;
  int _totalReminders = 0;
  late AppLocalizations localizations;

  int _currentNavIndex = 0;

  // مفاتيح التخزين المحلي
  static const String _remindersKey = 'cached_reminders';
  static const String _categoriesKey = 'cached_categories';
  static const String _complexitiesKey = 'cached_complexities';
  static const String _domainsKey = 'cached_domains';
  static const String _totalKey = 'cached_total';
  static const String _lastUpdateKey = 'last_update_time';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentNavIndex = widget.initialIndex;
    _listenForShareData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _intentSub?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    print('Checking login status...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await Future.delayed(const Duration(milliseconds: 300));

    if (authProvider.status == AuthStatus.loading) {
      await authProvider.initializeAuthentication();
      await authProvider.checkTokenValidity();
    }

    if (!authProvider.isAuthenticated && mounted) {
      print('Not authenticated, redirecting to auth screen.');
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      print('Authenticated, loading cached data first then fetching new data.');
      await _loadCachedData();
      _fetchReminders();
    }
  }

  // تحميل البيانات المخزنة محلياً
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedRemindersJson = prefs.getString(_remindersKey);
      final cachedCategoriesJson = prefs.getString(_categoriesKey);
      final cachedComplexitiesJson = prefs.getString(_complexitiesKey);
      final cachedDomainsJson = prefs.getString(_domainsKey);
      final cachedTotal = prefs.getInt(_totalKey) ?? 0;

      if (cachedRemindersJson != null) {
        final List<dynamic> remindersList = json.decode(cachedRemindersJson);
        final List<Reminder> cachedReminders =
            remindersList.map((json) => Reminder.fromJson(json)).toList();

        if (mounted) {
          final isArabic = Provider.of<LanguageManager>(context, listen: false)
                  .locale
                  .languageCode ==
              'ar';
          final allLabel = isArabic ? 'الكل' : 'All';

          setState(() {
            _reminders = cachedReminders;
            _categories = cachedCategoriesJson != null
                ? [
                    allLabel,
                    ...List<String>.from(json.decode(cachedCategoriesJson))
                  ]
                : [allLabel];
            _complexities = cachedComplexitiesJson != null
                ? [
                    allLabel,
                    ...List<String>.from(json.decode(cachedComplexitiesJson))
                  ]
                : [allLabel];
            _domains = cachedDomainsJson != null
                ? [
                    allLabel,
                    ...List<String>.from(json.decode(cachedDomainsJson))
                  ]
                : [allLabel];
            _totalReminders = cachedTotal;
            _isLoading = false;
          });

          print('Loaded ${cachedReminders.length} cached reminders');
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  // حفظ البيانات محلياً
  Future<void> _saveCachedData(RemindersResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تحويل التذكيرات إلى JSON
      final remindersJson = json.encode(
          response.reminders.map((reminder) => reminder.toJson()).toList());

      await prefs.setString(_remindersKey, remindersJson);
      await prefs.setString(_categoriesKey, json.encode(response.categories));
      await prefs.setString(
          _complexitiesKey, json.encode(response.complexities));
      if (response.domains != null) {
        await prefs.setString(_domainsKey, json.encode(response.domains!));
      }
      await prefs.setInt(_totalKey, response.total ?? 0);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print('Data cached successfully');
    } catch (e) {
      print('Error caching data: $e');
    }
  }

  // مسح البيانات المخزنة
  Future<void> _clearCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_remindersKey);
      await prefs.remove(_categoriesKey);
      await prefs.remove(_complexitiesKey);
      await prefs.remove(_domainsKey);
      await prefs.remove(_totalKey);
      await prefs.remove(_lastUpdateKey);
      print('Cached data cleared');
    } catch (e) {
      print('Error clearing cached data: $e');
    }
  }

  Future<void> _fetchReminders({bool isLoadMore = false}) async {
    if (isLoadMore && _isLoadingMore) {
      print('Load more already in progress, skipping.');
      return;
    }

    print('Fetching reminders: isLoadMore = $isLoadMore, page = $_currentPage');
    setState(() {
      if (!isLoadMore) _isLoading = true;
      _isLoadingMore = isLoadMore;
    });

    try {
      final response = await _apiService.fetchReminders(
        page: _currentPage,
        perPage: _perPage,
        searchQuery: "",
        category: _selectedCategory,
        complexity: _selectedComplexity,
        domain: _selectedDomain,
      );

      // التحقق من وجود تحديثات
      final hasUpdates = response.hasUpdates ?? true;
      final isSuccess = response.success ?? true;

      if (!isSuccess || !hasUpdates) {
        print('No updates available or request failed, using cached data');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      print(
          'Reminders fetched successfully: ${response.reminders.length} items');

      if (mounted) {
        final isArabic = Provider.of<LanguageManager>(context, listen: false)
                .locale
                .languageCode ==
            'ar';
        final allLabel = isArabic ? 'الكل' : 'All';

        if (!isLoadMore) {
          // حفظ البيانات الجديدة والاستبدال الكامل
          await _saveCachedData(response);

          setState(() {
            _reminders = response.reminders;
            _categories = [allLabel]..addAll(response.categories);
            _complexities = [allLabel]..addAll(response.complexities);
            _domains = [allLabel]..addAll(response.domains ?? []);
            _totalReminders = response.total ?? 0;
            _currentPage = 2; // الصفحة التالية
            print('Initial load: ${_reminders.length} reminders loaded');
          });
        } else {
          // إضافة المزيد من البيانات
          setState(() {
            _reminders.addAll(response.reminders);
            _totalReminders = response.total ?? 0;
            _currentPage += 1;
            print(
                'Load more: ${_reminders.length} total reminders after adding ${response.reminders.length}');
          });

          // تحديث البيانات المخزنة
          await _saveCachedData(RemindersResponse(
            reminders: _reminders,
            categories: _categories.where((c) => c != allLabel).toList(),
            complexities: _complexities.where((c) => c != allLabel).toList(),
            domains: _domains.where((d) => d != allLabel).toList(),
            total: _totalReminders,
            hasUpdates: true,
            success: true,
          ));
        }

        print('Processing current batch of reminders...');
        await _processRemindersInBatches(response.reminders);
      }
    } catch (error) {
      print('Error fetching reminders: $error');

      // في حالة الخطأ، نعرض البيانات المخزنة إذا كانت متوفرة
      if (_reminders.isEmpty) {
        await _loadCachedData();
      }

      String errorMessage =
          localizations.unexpectedError ?? 'An unexpected error occurred';
      if (error.toString().contains('Unauthorized') ||
          error.toString().contains('403')) {
        errorMessage = localizations.unauthorizedError ??
            'Unauthorized: Please log in again';
        print('Unauthorized error, redirecting to auth screen.');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      } else if (error is Error) {
        errorMessage = error.toString();
      }

      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          print('Fetching complete: Loading states reset');
        });
      }
    }
  }

  Future<void> _processRemindersInBatches(List<Reminder> batch) async {
    final now = DateTime.now();
    print('Processing batch of ${batch.length} reminders');

    await _syncBatchWithNotifications(batch, now);
    print('Batch processing completed');
  }

  Future<void> _syncBatchWithNotifications(
      List<Reminder> batch, DateTime now) async {
    for (final reminder in batch) {
      if (reminder.id == null || reminder.nextReminderTime == null) {
        print(
            'Skipping reminder with missing ID or nextReminderTime: ${reminder.title}');
        continue;
      }

      print('Checking notifications for reminder ${reminder.id}');
      final scheduledTimes =
          await _notificationService.getScheduledTimesForReminder(reminder.id!);
      final nextReminderDateTime = DateTime.parse(reminder.nextReminderTime!);

      bool hasNotification = scheduledTimes.any((scheduledTime) =>
          scheduledTime.toIso8601String() ==
          nextReminderDateTime.toIso8601String());

      if (!hasNotification) {
        print(
            'No matching notification found for reminder ${reminder.id}, scheduling new one');
        final reminderData = {
          'id': reminder.id,
          'title': reminder.title,
          'url': reminder.url ?? '',
          'importance': reminder.importance ?? 'day',
          'next_reminder_time': reminder.nextReminderTime,
        };
        try {
          await _notificationService.updateReminderNotifications(reminderData);
          print('New notification scheduled for reminder ${reminder.id}');
        } catch (e) {
          print(
              'Error scheduling notification for reminder ${reminder.id}: $e');
          _showErrorSnackBar('Failed to schedule notification: $e');
        }
      } else {
        print('Reminder ${reminder.id} already has a matching notification');
      }

      if (nextReminderDateTime.isBefore(now)) {
        print(
            'Reminder ${reminder.id} next time (${reminder.nextReminderTime}) is before now, rescheduling');
        try {
          final rescheduleResult = await _apiService.reschedulePost(
            reminder.url ?? '',
            reminder.importance ?? 'day',
          );
          print('Raw rescheduleResult: $rescheduleResult');

          if (rescheduleResult.containsKey('post')) {
            final newScheduledTimeStr =
                rescheduleResult['post']['next_reminder_time'] as String;
            final newScheduledTime = DateTime.parse(newScheduledTimeStr);

            setState(() {
              reminder.nextReminderTime = newScheduledTimeStr;
              print(
                  'Reminder ${reminder.id} rescheduled to $newScheduledTimeStr');
            });

            try {
              await _notificationService
                  .updateReminderNotifications(rescheduleResult['post']);
              print(
                  'Notification updated for rescheduled reminder ${reminder.id}');
            } catch (e) {
              print(
                  'Error updating notification for rescheduled reminder ${reminder.id}: $e');
              _showErrorSnackBar('Failed to update notification: $e');
            }
          } else {
            print(
                'No valid data in reschedule response for reminder ${reminder.id}');
            throw Exception('Invalid reschedule response: missing post data');
          }
        } catch (e) {
          print('Error rescheduling reminder ${reminder.id}: $e');
          _showErrorSnackBar('Failed to reschedule reminder: $e');
        }
      } else {
        print('Reminder ${reminder.id} not rescheduled (not past due)');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    print('Showing error snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<Reminder> _getFilteredReminders(bool showOpened) {
    print(
        'Filtering reminders: showOpened = $showOpened, searchQuery = $_searchQuery');
    List<Reminder> filtered = _reminders
        .where((reminder) => reminder.isOpened == (showOpened ? 1 : 0))
        .toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((reminder) =>
              reminder.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
      print('Applied search filter, filtered count: ${filtered.length}');
    }
    if (_selectedCategory != null &&
        _selectedCategory != 'All' &&
        _selectedCategory != 'الكل') {
      filtered = filtered
          .where((reminder) => reminder.category == _selectedCategory)
          .toList();
      print(
          'Applied category filter ($_selectedCategory), filtered count: ${filtered.length}');
    }
    if (_selectedComplexity != null &&
        _selectedComplexity != 'All' &&
        _selectedComplexity != 'الكل') {
      filtered = filtered
          .where((reminder) => reminder.complexity == _selectedComplexity)
          .toList();
      print(
          'Applied complexity filter ($_selectedComplexity), filtered count: ${filtered.length}');
    }
    if (_selectedDomain != null &&
        _selectedDomain != 'All' &&
        _selectedDomain != 'الكل') {
      filtered = filtered
          .where((reminder) => reminder.domain == _selectedDomain)
          .toList();
      print(
          'Applied domain filter ($_selectedDomain), filtered count: ${filtered.length}');
    }

    print('Filtering complete, returning ${filtered.length} reminders');
    return filtered;
  }

  void _listenForShareData() {
    print('Listening for share data...');
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty && mounted) {
          print('Received shared data: ${value.first.path}');
          setState(() {
            _sharedText = value.first.path;
            _showSavePostModal(_sharedText);
          });
        }
      },
      onError: (err) => print("getMediaStream error: $err"),
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty && mounted) {
        print('Received initial shared data: ${value.first.path}');
        setState(() {
          _sharedText = value.first.path;
          _showSavePostModal(_sharedText);
          ReceiveSharingIntent.instance.reset();
        });
      }
    });
  }

  Future<void> _showSavePostModal(String? sharedUrl) async {
    print('Showing save post modal with URL: $sharedUrl');
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SavePostScreen(
          initialUrl: sharedUrl,
          onSave: () {
            print('Post saved, triggering refresh');
            setState(() {
              _currentPage = 1;
              _reminders.clear();
            });
            _fetchReminders();
          },
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _currentPage = 1;
        _reminders.clear();
      });
      await _fetchReminders();
    }
  }

  void _updateReminderInList(Reminder updatedReminder) {
    if (mounted) {
      setState(() {
        final index = _reminders
            .indexWhere((reminder) => reminder.id == updatedReminder.id);
        if (index != -1) {
          _reminders[index] = updatedReminder;
          print('Reminder ${updatedReminder.id} updated in list');
        } else {
          print('Reminder ${updatedReminder.id} not found in list');
        }
      });

      // تحديث البيانات المخزنة
      _updateCachedReminder(updatedReminder);
    }
  }

  void _deleteReminderFromList(int id) {
    if (mounted) {
      setState(() {
        _reminders.removeWhere((reminder) => reminder.id == id);
        print('Reminder $id deleted from list');
      });

      // تحديث البيانات المخزنة
      _deleteCachedReminder(id);
    }
  }

  // تحديث تذكير في البيانات المخزنة
  Future<void> _updateCachedReminder(Reminder updatedReminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRemindersJson = prefs.getString(_remindersKey);

      if (cachedRemindersJson != null) {
        final List<dynamic> remindersList = json.decode(cachedRemindersJson);
        final List<Reminder> cachedReminders =
            remindersList.map((json) => Reminder.fromJson(json)).toList();

        final index =
            cachedReminders.indexWhere((r) => r.id == updatedReminder.id);
        if (index != -1) {
          cachedReminders[index] = updatedReminder;

          final updatedJson = json.encode(
              cachedReminders.map((reminder) => reminder.toJson()).toList());
          await prefs.setString(_remindersKey, updatedJson);
          print('Cached reminder ${updatedReminder.id} updated');
        }
      }
    } catch (e) {
      print('Error updating cached reminder: $e');
    }
  }

  // حذف تذكير من البيانات المخزنة
  Future<void> _deleteCachedReminder(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRemindersJson = prefs.getString(_remindersKey);

      if (cachedRemindersJson != null) {
        final List<dynamic> remindersList = json.decode(cachedRemindersJson);
        final List<Reminder> cachedReminders =
            remindersList.map((json) => Reminder.fromJson(json)).toList();

        cachedReminders.removeWhere((r) => r.id == id);

        final updatedJson = json.encode(
            cachedReminders.map((reminder) => reminder.toJson()).toList());
        await prefs.setString(_remindersKey, updatedJson);
        print('Cached reminder $id deleted');
      }
    } catch (e) {
      print('Error deleting cached reminder: $e');
    }
  }

  void _loadMoreReminders(bool showOpened) {
    if (!_isLoadingMore && _reminders.length < _totalReminders) {
      print('Loading more reminders for tab showOpened = $showOpened');
      _fetchReminders(isLoadMore: true);
    } else {
      print('No more reminders to load or already loading');
    }
  }

  void _showSearch(BuildContext context, AppLocalizations loc) {
    print('Showing search dialog');
    showSearch(
      context: context,
      delegate: _ReminderSearchDelegate(
        _searchQuery,
        (newQuery) {
          setState(() {
            _searchQuery = newQuery;
            print('Search query updated to: $_searchQuery');
          });
        },
        loc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    localizations = AppLocalizations.of(context)!;
    print('Building RemindersScreen');
    return Consumer<LanguageManager>(
      builder: (context, languageManager, child) {
        return WillPopScope(
          onWillPop: () async => false,
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: UpperAppBar(
                showSearch: true,
                onSearchChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                    print('Search query changed via app bar: $_searchQuery');
                  });
                },
                showSettings: true,
                showLeading: false,
              ),
              backgroundColor: Colors.white,
              body: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: localizations.unreadReminders),
                      Tab(text: localizations.readReminders),
                    ],
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: Colors.black,
                    labelStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRemindersList(false),
                        _buildRemindersList(true),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  print('Floating action button pressed');
                  _showSavePostModal(null);
                },
                backgroundColor: Colors.black,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              bottomNavigationBar: LowerNavigationBar(
                currentIndex: _currentNavIndex,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemindersList(bool showOpened) {
    final filteredReminders = _getFilteredReminders(showOpened);
    print(
        'Building reminders list for showOpened = $showOpened, filtered count: ${filteredReminders.length}');

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            !_isLoadingMore) {
          print('Scroll reached near end, triggering load more');
          _loadMoreReminders(showOpened);
        }
        return false;
      },
      child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading && filteredReminders.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black))
                : filteredReminders.isEmpty
                    ? Center(
                        child: Text(
                            showOpened
                                ? localizations.noReadReminders
                                : localizations.noUnreadReminders,
                            style: const TextStyle(color: Colors.black)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: filteredReminders.length +
                            (filteredReminders.length < _totalReminders
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredReminders.length &&
                              filteredReminders.length < _totalReminders) {
                            return _isLoadingMore
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.black))
                                : const SizedBox.shrink();
                          }
                          print(
                              'Building card for reminder ${filteredReminders[index].id}');
                          return _buildReminderCard(filteredReminders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isArabic = Provider.of<LanguageManager>(context, listen: false)
            .locale
            .languageCode ==
        'ar';
    final allLabel = isArabic ? 'الكل' : 'All';
    print('Building filter bar');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedCategory != null && _selectedCategory != allLabel)
                  Chip(
                    label: Text(_selectedCategory!,
                        style: const TextStyle(color: Colors.black)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                        print('Category filter cleared');
                      });
                    },
                  ),
                if (_selectedComplexity != null &&
                    _selectedComplexity != allLabel)
                  Chip(
                    label: Text(_selectedComplexity!,
                        style: const TextStyle(color: Colors.black)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onDeleted: () {
                      setState(() {
                        _selectedComplexity = null;
                        print('Complexity filter cleared');
                      });
                    },
                  ),
                if (_selectedDomain != null && _selectedDomain != allLabel)
                  Chip(
                    label: Text(_selectedDomain!,
                        style: const TextStyle(color: Colors.black)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onDeleted: () {
                      setState(() {
                        _selectedDomain = null;
                        print('Domain filter cleared');
                      });
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {
              print('Filter button pressed');
              _showFilterDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    print('Showing filter dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.filters,
            style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterSection(
                title: localizations.categories,
                items: _categories,
                selectedItem: _selectedCategory,
                onSelected: (selected, item) {
                  final isArabic =
                      Provider.of<LanguageManager>(context, listen: false)
                              .locale
                              .languageCode ==
                          'ar';
                  final allLabel = isArabic ? 'الكل' : 'All';
                  setState(() {
                    _selectedCategory =
                        (selected && item != allLabel) ? item : null;
                    print('Category filter set to: $_selectedCategory');
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildFilterSection(
                title: localizations.complexity,
                items: _complexities,
                selectedItem: _selectedComplexity,
                onSelected: (selected, item) {
                  final isArabic =
                      Provider.of<LanguageManager>(context, listen: false)
                              .locale
                              .languageCode ==
                          'ar';
                  final allLabel = isArabic ? 'الكل' : 'All';
                  setState(() {
                    _selectedComplexity =
                        (selected && item != allLabel) ? item : null;
                    print('Complexity filter set to: $_selectedComplexity');
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildFilterSection(
                title: localizations.domains,
                items: _domains,
                selectedItem: _selectedDomain,
                onSelected: (selected, item) {
                  final isArabic =
                      Provider.of<LanguageManager>(context, listen: false)
                              .locale
                              .languageCode ==
                          'ar';
                  final allLabel = isArabic ? 'الكل' : 'All';
                  setState(() {
                    _selectedDomain =
                        (selected && item != allLabel) ? item : null;
                    print('Domain filter set to: $_selectedDomain');
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedComplexity = null;
                _selectedDomain = null;
                print('All filters cleared');
              });
              Navigator.pop(context);
            },
            child: Text(localizations.clearFilters,
                style: const TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              print('Closing filter dialog');
              Navigator.pop(context);
            },
            child: Text(localizations.close,
                style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<String> items,
    required String? selectedItem,
    required Function(bool, String) onSelected,
  }) {
    print('Building filter section: $title');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = (selectedItem == item);
              return FilterChip(
                label: Text(item, style: const TextStyle(color: Colors.black)),
                selected: isSelected,
                onSelected: (selected) => onSelected(selected, item),
                backgroundColor: Colors.white,
                selectedColor: Colors.black,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 14),
                side: const BorderSide(color: Colors.black),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    print('Building reminder card for ID: ${reminder.id}');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          print('Reminder card tapped: ${reminder.id}');
          final reminderId = reminder.id;
          if (reminderId != null) {
            final result = await Navigator.pushNamed(context, '/reminder',
                arguments: reminder) as Map<String, dynamic>?;
            if (result != null) {
              if (result['type'] == 'update') {
                final updatedReminder = result['reminder'] as Reminder;
                _updateReminderInList(updatedReminder);
                setState(() {
                  _currentPage = 1;
                  _reminders.clear();
                });
                await _fetchReminders();
              } else if (result['type'] == 'delete') {
                _deleteReminderFromList(reminderId);
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder.imageUrl != null && reminder.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: reminder.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white,
                      child: const Center(
                          child:
                              CircularProgressIndicator(color: Colors.black)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.white,
                      child: const Icon(Icons.error, color: Colors.black),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.black),
                        ),
                      ),
                      const Icon(Icons.notifications_none, color: Colors.black),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reminder.nextReminderTime != null &&
                      reminder.nextReminderTime!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          reminder.nextReminderTime!,
                          style: const TextStyle(
                              color: Colors.black, fontSize: 12),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  _buildTags(reminder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(Reminder reminder) {
    print('Building tags for reminder ${reminder.id}');
    final List<Widget> tags = [];
    if (reminder.domain != null && reminder.domain!.isNotEmpty) {
      tags.add(_buildTag(reminder.domain!, Colors.white, Colors.black));
    }
    if (reminder.complexity != null && reminder.complexity!.isNotEmpty) {
      tags.add(_buildTag(reminder.complexity!, Colors.white, Colors.black));
    }
    if (reminder.category != null && reminder.category!.isNotEmpty) {
      tags.add(_buildTag(reminder.category!, Colors.white, Colors.black));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: tags);
  }

  Widget _buildTag(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }
}
