import 'package:flutter/material.dart';
import 'package:reminder/services/deep_seek_service.dart';
import 'package:reminder/models/user.dart';
import 'package:reminder/models/reminder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:reminder/services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DeepSeekService _deepSeek = DeepSeekService(apiService: ApiService());
  bool _isLoading = true;
  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _categoryDist;
  Map<String, dynamic>? _engagementTimes;
  Map<String, dynamic>? _recommendations;
  List<Map<String, dynamic>> _rawOldReminders = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final user = await _deepSeek.apiService.getCurrentUser();
      _userStats = await _deepSeek.analyzeRecentUserStats(user);
      _categoryDist = await _deepSeek.analyzeRecentCategoryDistribution(user);
      _engagementTimes = await _deepSeek.analyzeRecentEngagementTimes(user);
      _recommendations = await _deepSeek.generateRecentRecommendations(user);

      _rawOldReminders = [
        ...?_userStats?['raw_old_reminders']?.cast<Map<String, dynamic>>() ??
            [],
        ...?_categoryDist?['raw_old_reminders']?.cast<Map<String, dynamic>>() ??
            [],
        ...?_engagementTimes?['raw_old_data']
                ?.cast<String>()
                .map((e) => {'time': e})
                .toList() ??
            [],
        ...?_recommendations?['raw_old_data']?.cast<Map<String, dynamic>>() ??
            [],
      ];

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Statistics', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.lightGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Stats
                  if (_userStats != null) ...[
                    _buildStatCard(
                        'Total Reminders',
                        _userStats!['total_reminders'].toString(),
                        Colors.lightGreen),
                    _buildStatCard(
                        'Opened Reminders',
                        _userStats!['opened_reminders'].toString(),
                        Colors.lightGreen),
                    _buildStatCard(
                        'Unread Reminders',
                        _userStats!['unopened_reminders'].toString(),
                        Colors.lightGreen),
                  ],
                  const SizedBox(height: 16),

                  // Category Distribution (Pie Chart)
                  if (_categoryDist != null)
                    _buildChart('Categories Distribution',
                        _buildPieChart(_categoryDist!['categories'] ?? {})),

                  const SizedBox(height: 16),

                  // Complexity Distribution (Bar Chart)
                  if (_categoryDist != null)
                    _buildChart('Complexity Distribution',
                        _buildBarChart(_categoryDist!['complexities'] ?? {})),

                  const SizedBox(height: 16),

                  // Engagement Times and Recommendations
                  if (_engagementTimes != null && _recommendations != null) ...[
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Engagement Times (Last Week)',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Recommendations: ${_recommendations!['general_recommendations'] ?? 'No recommendations'}',
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Optimal Times:',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            ..._buildOptimalTimes(
                                _recommendations!['optimal_times'] ?? {}),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Old Data (Raw, Unanalyzed)
                  if (_rawOldReminders.isNotEmpty)
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Old Data (Not Analyzed)',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _rawOldReminders.length,
                              itemBuilder: (context, index) {
                                final reminder = _rawOldReminders[index];
                                return ListTile(
                                  title: Text(
                                      reminder['title'] ??
                                          reminder['time'] ??
                                          'Unknown',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                  subtitle: Text(
                                    'Created: ${reminder['created_at'] ?? 'Unknown'} | '
                                    'Opened: ${reminder['is_opened'] == 1 ? 'Yes' : 'No'}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchStats,
        backgroundColor: Colors.lightGreen,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(String title, Widget chart) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> categories) {
    final List<PieChartSectionData> sections = [];
    int index = 0;
    categories.forEach((category, count) {
      if (count is int) {
        sections.add(PieChartSectionData(
          value: count.toDouble(),
          title: '$category\n$count',
          color: Colors.primaries[index % Colors.primaries.length],
          radius: 80,
        ));
        index++;
      }
    });
    return PieChart(
      PieChartData(
        sections: sections.isEmpty
            ? [PieChartSectionData(value: 1, color: Colors.grey, radius: 80)]
            : sections,
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> complexities) {
    final List<BarChartGroupData> barGroups = [];
    int index = 0;
    complexities.forEach((complexity, count) {
      if (count is int) {
        barGroups.add(BarChartGroupData(
          x: index,
          barRods: [BarChartRodData(toY: count.toDouble(), color: Colors.blue)],
        ));
        index++;
      }
    });
    return BarChart(
      BarChartData(
        barGroups: barGroups.isEmpty
            ? [
                BarChartGroupData(
                    x: 0,
                    barRods: [BarChartRodData(toY: 1, color: Colors.grey)])
              ]
            : barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < complexities.length) {
                  return Text(complexities.keys.toList()[index],
                      style:
                          const TextStyle(color: Colors.black, fontSize: 12));
                }
                return const Text('');
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptimalTimes(Map<String, dynamic> times) {
    final List<Widget> timeWidgets = [];
    times.forEach((day, timesList) {
      if (timesList is List) {
        timeWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day,
                    style: const TextStyle(color: Colors.black, fontSize: 14)),
                Text(timesList.join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        );
      }
    });
    return timeWidgets.isEmpty
        ? [
            Text('No optimal times available',
                style: TextStyle(color: Colors.grey))
          ]
        : timeWidgets;
  }
}
