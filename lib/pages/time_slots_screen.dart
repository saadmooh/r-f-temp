import 'package:flutter/material.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/models/user_free_time.dart';

/// شاشة عرض الفترات الزمنية (Time Slots)
class TimeSlotsScreen extends StatefulWidget {
  const TimeSlotsScreen({Key? key}) : super(key: key);

  @override
  _TimeSlotsScreenState createState() => _TimeSlotsScreenState();
}

class _TimeSlotsScreenState extends State<TimeSlotsScreen> {
  final ApiService _apiService = ApiService();
  List<UserFreeTime> _freeTimes = [];
  bool _isLoading = true;

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadFreeTimes();
  }

  /// جلب الفترات من الـ API وتحديث الواجهة
  Future<void> _loadFreeTimes() async {
    setState(() => _isLoading = true);
    try {
      final freeTimes = await _apiService.fetchFreeTimes();
      setState(() {
        _freeTimes = freeTimes;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading free times: $error')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// حذف فترة زمنية مع تأكيد المستخدم
  Future<void> _deleteFreeTime(int id) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to delete this time slot?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await _apiService.deleteFreeTime(id);
                  _loadFreeTimes();
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting time slot: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// بناء واجهة الصفحة
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Time Slots", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _daysOfWeek.map((day) {
                        return _buildDayColumn(day);
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      _showTimeSlotDialog();
                    },
                    child: Text(
                      'Add Free Time',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// بناء واجهة يوم معيَّن (مع قائمة الفترات + السويتش الخاص بالعطلة)
  Widget _buildDayColumn(String day) {
    final List<UserFreeTime> todaysFreeTimes =
        _freeTimes.where((time) => time.day == day).toList();

    // إذا كان هناك أي فترة isOffDay=true لهذا اليوم، نعدّه يوم عطلة
    bool isDayOff = todaysFreeTimes.any((time) => time.isOffDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان + السويتش
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.toUpperCase(),
                  style: TextStyle(
                    color: isDayOff ? Colors.grey[600] : Colors.green[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Switch(
                  value: isDayOff,
                  activeColor: Colors.red,
                  onChanged: (bool value) async {
                    try {
                      if (value) {
                        // حوّل اليوم إلى عطلة
                        await _apiService.createFreeTime(
                          day,
                          TimeOfDay(hour: 0, minute: 0),
                          TimeOfDay(hour: 23, minute: 59),
                          true,
                        );
                      } else {
                        // حوّل اليوم من عطلة إلى عادي (احذف كل الفترات)
                        for (var time in todaysFreeTimes) {
                          if (time.id != null) {
                            await _apiService.deleteFreeTime(time.id!);
                          }
                        }
                      }
                      _loadFreeTimes();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating day off status: $e'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // إذا كان عطلة
          if (isDayOff)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Day Off',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else ...[
            // عرض الفترات لهذا اليوم
            ...todaysFreeTimes
                .where((time) => !time.isOffDay)
                .map((freeTime) => _buildTimeSlotItem(freeTime))
                .toList(),

            // إن لم تكن هناك فترات مضافة
            if (todaysFreeTimes.where((time) => !time.isOffDay).isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'No free time slots for this day.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// نافذة إضافة/تعديل فترة زمنية
  Future<void> _showTimeSlotDialog({UserFreeTime? existingTime}) async {
    // الأيام التي ليست عطلة
    final availableDays = _daysOfWeek
        .where((day) => !_freeTimes.any(
              (time) =>
                  time.day.toLowerCase() == day.toLowerCase() && time.isOffDay,
            ))
        .toList();

    // إذا كنا في وضع تعديل، قد يكون اليوم عطلة. نضيفه مؤقتًا للقائمة
    if (existingTime != null) {
      final existingDay = existingTime.day.toLowerCase();
      if (!availableDays.any((d) => d.toLowerCase() == existingDay)) {
        availableDays.add(existingTime.day);
      }
    }

    // إذا لم توجد أيام متاحة للإضافة
    if (availableDays.isEmpty && existingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No available days to add a time slot.')),
      );
      return;
    }

    // اليوم المختار
    String _selectedDay =
        existingTime != null ? existingTime.day : availableDays.first;

    // وقت البداية والنهاية (لا يمكن أن يكونا null)
    TimeOfDay _selectedStartTime = TimeOfDay(hour: 9, minute: 0);
    TimeOfDay _selectedEndTime = TimeOfDay(hour: 17, minute: 0);

    // إذا نعدِّل فترة موجودة، حاول تفكيك التوقيت منها
    if (existingTime != null) {
      final parsedStart = _parseTimeOfDay(existingTime.startTime);
      final parsedEnd = _parseTimeOfDay(existingTime.endTime);
      if (parsedStart != null) _selectedStartTime = parsedStart;
      if (parsedEnd != null) _selectedEndTime = parsedEnd;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[800],
              title: Text(
                existingTime == null ? 'Add Free Time' : 'Edit Free Time',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedDay,
                      dropdownColor: Colors.grey[800],
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Day',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[900],
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      items: availableDays.map((day) {
                        return DropdownMenuItem(
                          value: day,
                          child:
                              Text(day, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedDay = value;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Start Time: ${_selectedStartTime.format(context)}',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Icon(Icons.access_time, color: Colors.white),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedStartTime,
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.white,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            _selectedStartTime = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'End Time: ${_selectedEndTime.format(context)}',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Icon(Icons.access_time, color: Colors.white),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedEndTime,
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.white,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            _selectedEndTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    existingTime == null ? 'Add' : 'Update',
                    style: TextStyle(color: Colors.blue),
                  ),
                  onPressed: () async {
                    // قبل الإنشاء أو التحديث، تحقق من التداخل
                    final userChoice = await _checkAndHandleOverlap(
                      selectedDay: _selectedDay,
                      startTime: _selectedStartTime,
                      endTime: _selectedEndTime,
                      existingId: existingTime?.id,
                    );

                    if (userChoice == _OverlapAction.cancel) {
                      // المستخدم اختار إلغاء العملية
                      Navigator.of(context).pop();
                      return;
                    } else if (userChoice == _OverlapAction.mergeAndSave) {
                      // تمت عملية الدمج وإنشاء الفترة المدمجة
                      _loadFreeTimes();
                      Navigator.of(context).pop();
                      return;
                    }

                    // إذا لم يوجد تداخل أو قرر المستخدم المتابعة بلا دمج
                    try {
                      if (existingTime == null) {
                        await _apiService.createFreeTime(
                          _selectedDay,
                          _selectedStartTime,
                          _selectedEndTime,
                          false,
                        );
                      } else {
                        final result = await _apiService.updateFreeTime(
                          existingTime.id!,
                          _selectedDay,
                          _selectedStartTime,
                          _selectedEndTime,
                          false,
                        );
                        if (result['success'] != true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Update failed: ${result["message"]}'),
                            ),
                          );
                          return;
                        }
                      }
                      _loadFreeTimes();
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// التحقق من التداخل والتعامل معه (دمج أو إلغاء)
  Future<_OverlapAction> _checkAndHandleOverlap({
    required String selectedDay,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int? existingId,
  }) async {
    // استخرج الفترات لنفس اليوم (باستثناء نفس العنصر إن كنا نعدِّل)
    final sameDaySlots = _freeTimes.where((slot) {
      if (slot.isOffDay) return false;
      if (slot.day.toLowerCase() != selectedDay.toLowerCase()) return false;
      if (existingId != null && slot.id == existingId) return false;
      return true;
    }).toList();

    // حوِّل الـ TimeOfDay إلى دقائق من بداية اليوم
    int newStart = startTime.hour * 60 + startTime.minute;
    int newEnd = endTime.hour * 60 + endTime.minute;

    // إذا كانت الفترة غير صحيحة
    if (newEnd <= newStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid time range (End must be after Start)')),
      );
      return _OverlapAction.cancel;
    }

    // ابحث عن أي تداخل
    List<UserFreeTime> overlappingSlots = [];
    for (var slot in sameDaySlots) {
      final st = _parseTimeOfDay(slot.startTime);
      final en = _parseTimeOfDay(slot.endTime);
      if (st == null || en == null) continue;

      int slotStart = st.hour * 60 + st.minute;
      int slotEnd = en.hour * 60 + en.minute;

      // شرط التداخل: newStart < slotEnd && newEnd > slotStart
      // إذا تريد حساب الفترات المتجاورة كتداخل فاستبدل بـ (<=) و (>=)
      if (newStart < slotEnd && newEnd > slotStart) {
        overlappingSlots.add(slot);
      }
    }

    // لا يوجد تداخل
    if (overlappingSlots.isEmpty) {
      return _OverlapAction.noOverlap;
    }

    // يوجد تداخل => اسأل المستخدم
    final action = await showDialog<_OverlapAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Overlap Detected'),
          content: Text(
            'The selected time overlaps with ${overlappingSlots.length} existing slot(s). '
            'Do you want to merge them into one slot or cancel?',
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context, _OverlapAction.cancel),
            ),
            TextButton(
              child: Text('Merge'),
              onPressed: () =>
                  Navigator.pop(context, _OverlapAction.mergeAndSave),
            ),
          ],
        );
      },
    );

    // إذا أغلق الـ Dialog أو اختار المستخدم الإلغاء
    if (action == null || action == _OverlapAction.cancel) {
      return _OverlapAction.cancel;
    }

    // إذا اختار الدمج
    if (action == _OverlapAction.mergeAndSave) {
      // احسب أدنى بداية وأعلى نهاية
      int earliest = newStart;
      int latest = newEnd;

      for (var slot in overlappingSlots) {
        final st = _parseTimeOfDay(slot.startTime)!;
        final en = _parseTimeOfDay(slot.endTime)!;
        int s = st.hour * 60 + st.minute;
        int e = en.hour * 60 + en.minute;
        if (s < earliest) earliest = s;
        if (e > latest) latest = e;
      }

      // إذا كنا في وضع تعديل، احذف الفترة القديمة قبل الدمج
      if (existingId != null) {
        await _apiService.deleteFreeTime(existingId);
      }

      // احذف الفترات المتداخلة
      for (var slot in overlappingSlots) {
        if (slot.id != null) {
          await _apiService.deleteFreeTime(slot.id!);
        }
      }

      // أنشئ فترة جديدة مدمجة
      final mergedStart =
          TimeOfDay(hour: earliest ~/ 60, minute: earliest % 60);
      final mergedEnd = TimeOfDay(hour: latest ~/ 60, minute: latest % 60);

      await _apiService.createFreeTime(
        selectedDay,
        mergedStart,
        mergedEnd,
        false,
      );

      return _OverlapAction.mergeAndSave;
    }

    return _OverlapAction.cancel; // كحالة افتراضية
  }

  /// عنصر واجهة لفترة زمنية واحدة
  Widget _buildTimeSlotItem(UserFreeTime freeTime) {
    return GestureDetector(
      onTap: () {
        _showTimeSlotDialog(existingTime: freeTime);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: freeTime.isOffDay
              ? Colors.grey[300]
              : Colors.green[100], // Light green for active, grey for off
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: freeTime.isOffDay ? Colors.grey : Colors.green[800]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${freeTime.startTime} - ${freeTime.endTime}',
              style: TextStyle(
                color: freeTime.isOffDay ? Colors.grey[700] : Colors.green[900],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (freeTime.isOffDay)
              Text(
                'Day Off',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    _showTimeSlotDialog(existingTime: freeTime);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteFreeTime(freeTime.id!);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// تحويل نص بصيغة HH:mm إلى TimeOfDay
  TimeOfDay? _parseTimeOfDay(String timeString) {
    // "09:00:00" => parts = ["09", "00", "00"]
    final parts = timeString.split(':');
    // تأكد من أن هناك على الأقل ساعتين ودقيقتين
    if (parts.length < 2) return null;

    try {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      // نتجاهل الجزء الثالث (الثواني) إن وجد
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print("Could not parse time $timeString: $e");
      return null;
    }
  }
}

/// القيم العائدة من الدالة _checkAndHandleOverlap
enum _OverlapAction {
  noOverlap, // لا يوجد تداخل
  mergeAndSave, // دمج الفترات وحفظ
  cancel, // إلغاء العملية
}
