import 'package:flutter/material.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/pages/offers_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    print('SplashScreen initState called');
    _checkTokenAndSubscription();
  }

  Future<void> _checkTokenAndSubscription() async {
    try {
      print('Checking token...');
      final token = await _apiService.getToken();
      if (token == null || token.isEmpty) {
        print('No token found, redirecting to AuthScreen');
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      } else {
        print(await _apiService.getToken());
      }

      print('Checking subscription...');
      final data = await _apiService.checkSubscription();
      print('Subscription data: $data');

      if (data['subscribed'] == false) {
        print('User is not subscribed');
        final plans = List<Map<String, dynamic>>.from(data['plans'] ?? []);
        if (plans.isEmpty) {
          print('No plans available, redirecting to NoPlansAvailableScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const NoPlansAvailableScreen(),
            ),
          );
        } else {
          print('Plans available, redirecting to OffersScreen');
          Navigator.pushNamed(context, '/subscription_management');
        }
      } else {
        print('User is subscribed, redirecting to RemindersScreen');
        Navigator.of(context).pushReplacementNamed('/reminders');
      }
    } catch (e) {
      print('Error occurred: $e, redirecting to AuthScreen');
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('SplashScreen build called');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          '/assets/logo.png', // تم تغييره من 'assets/logo.png' إلى 'logo.png'
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}

class NoPlansAvailableScreen extends StatelessWidget {
  const NoPlansAvailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('No Plans Available'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sorry, no subscription plans are available at the moment.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
