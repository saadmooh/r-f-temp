import 'package:flutter/material.dart';
import 'package:reminder/services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white), // Set icon color
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                    context, '/time_slots'); // Navigate to TimeSlotsScreen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('Time Slots', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                    context, '/stats'); // Navigate to StatsScreen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('Stats', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                await ApiService()
                    .logout(); // Use an instance, and await logout
                Navigator.pushReplacementNamed(
                    context, '/'); // Navigate to login
              },
              child: Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
