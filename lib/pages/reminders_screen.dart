import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // استيراد Provider
import 'package:reminder/models/reminder.dart';
import 'package:reminder/models/reminders_response.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/pages/save_post_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:reminder/pages/reminder_detail_screen.dart';
import 'package:reminder/pages/edit_reminder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reminder/widgets/custom_app_bar.dart';
import 'package:reminder/l10n/app_localizations.dart';
import 'package:reminder/utils/language_manager.dart'; // استيراد LanguageManager

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
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: () => close(context, query),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onQueryChanged(query);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    onQueryChanged(query);
    return Container();
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
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
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
  int _perPage = 10;
  int _totalReminders = 0;
  late AppLocalizations localizations;
  BuildContext? _screenContext;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkLoginStatus();
    _listenForShareData();
    _checkAndRefreshIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _intentSub?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await _apiService.getToken();
    if (token == null && mounted) {
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      _fetchReminders();
    }
  }

  Future<void> _fetchReminders({bool isLoadMore = false}) async {
    if (isLoadMore && _isLoadingMore) return;

    setState(() {
      if (!isLoadMore) _isLoading = true;
      _isLoadingMore = isLoadMore;
    });

    try {
      final response = await _apiService.fetchReminders(
        page: _currentPage,
        perPage: _perPage,
        searchQuery: _searchQuery,
        category: _selectedCategory,
        complexity: _selectedComplexity,
        domain: _selectedDomain,
      );
      if (mounted) {
        setState(() {
          if (!isLoadMore) {
            _reminders = response.reminders;
            _categories = ['All']..addAll(response.categories);
            _complexities = ['All']..addAll(response.complexities);
            _domains = ['All']..addAll(response.domains ?? []);
          } else {
            _reminders.addAll(response.reminders);
          }
          _totalReminders = response.total ?? 0;
          _currentPage += 1;
        });
      }
    } catch (error) {
      String errorMessage =
          localizations.unexpectedError ?? 'An unexpected error occurred';
      if (error.toString().contains('Unauthorized') ||
          error.toString().contains('403')) {
        errorMessage = localizations.unauthorizedError ??
            'Unauthorized: Your subscription does not allow this action';
        if (mounted)
          Navigator.pushReplacementNamed(context, '/subscription_management');
      } else if (error is Error) {
        errorMessage = error.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
    }
  }

  Future<void> _checkAndRefreshIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final needsRefresh = prefs.getBool('needs_refresh') ?? false;
    if (needsRefresh) {
      _currentPage = 1;
      await _fetchReminders();
      await prefs.setBool('needs_refresh', false);
    }
  }

  List<Reminder> _getFilteredReminders(bool showOpened) {
    return _reminders
        .where((reminder) => reminder.isOpened == (showOpened ? 1 : 0))
        .toList();
  }

  void _listenForShareData() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty && mounted) {
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
        setState(() {
          _sharedText = value.first.path;
          _showSavePostModal(_sharedText);
          ReceiveSharingIntent.instance.reset();
        });
      }
    });
  }

  void _showSavePostModal(String? sharedUrl) {
    showModalBottomSheet(
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
            _currentPage = 1;
            _fetchReminders();
          },
        ),
      ),
    );
  }

  void _updateReminderInList(Reminder updatedReminder) {
    if (mounted) {
      setState(() {
        final index = _reminders
            .indexWhere((reminder) => reminder.id == updatedReminder.id);
        if (index != -1) _reminders[index] = updatedReminder;
      });
    }
  }

  void _deleteReminderFromList(int id) {
    if (mounted) {
      setState(() {
        _reminders.removeWhere((reminder) => reminder.id == id);
      });
    }
  }

  void _loadMoreReminders(bool showOpened) {
    if (!_isLoadingMore && _reminders.length < _totalReminders) {
      _fetchReminders(isLoadMore: true);
    }
  }

  void _showSearch(BuildContext context, AppLocalizations loc) {
    // تم تمرير AppLocalizations هنا
    final localizations = loc; // استخدام AppLocalizations الذي تم تمريره
    showSearch(
      context: context,
      delegate: _ReminderSearchDelegate(
        _searchQuery,
        (newQuery) {
          setState(() {
            _searchQuery = newQuery;
            _currentPage = 1;
            _fetchReminders();
          });
        },
        localizations, // تم تمرير localizations هنا
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    localizations = AppLocalizations.of(context)!;
    _screenContext = context;
    return Consumer<LanguageManager>(// تغليف الشاشة بـ Consumer
        builder: (context, languageManager, child) {
      return WillPopScope(
        onWillPop: () async => false,
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            // تم حذف Directionality هنا
            appBar: CustomAppBar(
              title: localizations.remindersTitle,
              showSearch: true,
              onSearchChanged: (query) {
                setState(() {
                  _searchQuery = query;
                  _currentPage = 1;
                  _fetchReminders();
                });
              },
              showSettings: true,
              //     showFilter: true,
              showLeading: false,
              onSearchPressed: () {
                _showSearch(context, localizations); // تمرير localizations هنا
              },
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
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue,
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
              onPressed: () => _showSavePostModal(null),
              backgroundColor: Colors.lightGreen,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      );
    });
  }

  // ... بقية الكود _RemindersScreenState (بدون تغيير كبير) ...

  Widget _buildRemindersList(bool showOpened) {
    final filteredReminders = _getFilteredReminders(showOpened);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            !_isLoadingMore) {
          _loadMoreReminders(showOpened);
        }
        return false;
      },
      child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.lightGreen))
                : filteredReminders.isEmpty
                    ? Center(
                        child: Text(localizations.noUnreadReminders,
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
                                        color: Colors.lightGreen))
                                : const SizedBox.shrink();
                          }
                          return _buildReminderCard(filteredReminders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedCategory != null && _selectedCategory != 'All')
                  Chip(
                    label: Text(_selectedCategory!,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.blue,
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                        _currentPage = 1;
                        _fetchReminders();
                      });
                    },
                  ),
                if (_selectedComplexity != null && _selectedComplexity != 'All')
                  Chip(
                    label: Text(_selectedComplexity!,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.blue,
                    onDeleted: () {
                      setState(() {
                        _selectedComplexity = null;
                        _currentPage = 1;
                        _fetchReminders();
                      });
                    },
                  ),
                if (_selectedDomain != null && _selectedDomain != 'All')
                  Chip(
                    label: Text(_selectedDomain!,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.blue,
                    onDeleted: () {
                      setState(() {
                        _selectedDomain = null;
                        _currentPage = 1;
                        _fetchReminders();
                      });
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
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
                  setState(() {
                    _selectedCategory = selected ? item : null;
                    _currentPage = 1;
                  });
                  _fetchReminders();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildFilterSection(
                title: localizations.complexity,
                items: _complexities,
                selectedItem: _selectedComplexity,
                onSelected: (selected, item) {
                  setState(() {
                    _selectedComplexity = selected ? item : null;
                    _currentPage = 1;
                  });
                  _fetchReminders();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildFilterSection(
                title: localizations.domains,
                items: _domains,
                selectedItem: _selectedDomain,
                onSelected: (selected, item) {
                  setState(() {
                    _selectedDomain = selected ? item : null;
                    _currentPage = 1;
                  });
                  _fetchReminders();
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
                _currentPage = 1;
              });
              _fetchReminders();
              Navigator.pop(context);
            },
            child: Text(localizations.clearFilters,
                style: const TextStyle(color: Colors.lightGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close,
                style: const TextStyle(color: Colors.lightGreen)),
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
                backgroundColor: Colors.grey[300],
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 14),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final reminderId = reminder.id;
          if (reminderId != null) {
            final result = await Navigator.pushNamed(context, '/reminder',
                arguments: reminder) as Map<String, dynamic>?;
            if (result != null) {
              if (result['type'] == 'update') {
                final updatedReminder = result['reminder'] as Reminder;
                _updateReminderInList(updatedReminder);
              } else if (result['type'] == 'delete') {
                _deleteReminderFromList(reminderId);
              }
            }
            _currentPage = 1;
            await _fetchReminders();
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
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: reminder.imageUrl!,
                    fit: BoxFit.cover,
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
                      const Icon(Icons.notifications_none, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reminder.nextReminderTime != null &&
                      reminder.nextReminderTime!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          reminder.nextReminderTime!,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
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
    final List<Widget> tags = [];
    if (reminder.domain != null && reminder.domain!.isNotEmpty) {
      tags.add(_buildTag(reminder.domain!, Colors.green[100]!, Colors.green));
    }
    if (reminder.complexity != null && reminder.complexity!.isNotEmpty) {
      tags.add(_buildTag(reminder.complexity!, Colors.blue[100]!, Colors.blue));
    }
    if (reminder.category != null && reminder.category!.isNotEmpty) {
      tags.add(
          _buildTag(reminder.category!, Colors.purple[100]!, Colors.purple));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: tags);
  }

  Widget _buildTag(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }

  Color getComplexityColor(String complexity) {
    switch (complexity.toLowerCase()) {
      case 'beginner':
        return Colors.blue;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color getCategoryColor(String category) {
    switch (category) {
      case 'AI Basics':
      case 'Machine Learning':
      case 'Neural Networks':
      case 'Deep Learning':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color getDomainColor(String domain) {
    return Colors.green;
  }
}
