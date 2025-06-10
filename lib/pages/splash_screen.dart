import 'package:flutter/material.dart';
import 'package:flex_reminder/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flex_reminder/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flex_reminder/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  late AppLocalizations localizations;
  bool _hasNavigated = false; // متغير لتتبع حالة التنقل
  late AuthProvider _authProvider;

  // دالة للتحقق من الـ route الحالي
  bool _isCurrentlyOnRoute(String routeName) {
    if (!mounted) return false;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute == routeName;
  }

  void _showSnackBar(String message) {
    if (mounted && ScaffoldMessenger.of(context).mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // دالة للتحقق من الـ route الحالي والتنقل بأمان
  void _navigateToRoute(String routeName) {
    if (!mounted || _hasNavigated) {
      print(
          'Navigation blocked: mounted = $mounted, hasNavigated = $_hasNavigated');
      return;
    }

    // التحقق من الـ route الحالي
    if (_isCurrentlyOnRoute(routeName)) {
      print('Already on route: $routeName, skipping navigation');
      _hasNavigated = true; // تعيين المتغير لمنع محاولات التنقل الأخرى
      return;
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    print('Current route: $currentRoute, Target route: $routeName');

    // التحقق من أن النافذة الحالية هي SplashScreen أو null (في بداية التطبيق)
    if (currentRoute != null &&
        currentRoute != '/splash' &&
        currentRoute != '/') {
      print(
          'Not on splash screen (current: $currentRoute), skipping navigation');
      return;
    }

    // التحقق الأخير قبل التنقل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isCurrentlyOnRoute(routeName)) {
        print('Final navigation from $currentRoute to $routeName');
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed(routeName);
      } else {
        print('Final check: Already on target route or widget disposed');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateBasedOnStoredData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  // التنقل بناءً على حالة المصادقة
  Future<void> _navigateBasedOnStoredData() async {
    try {
      await Future.delayed(
          const Duration(seconds: 2)); // تأخير لعرض شاشة Splash

      // تأخير عرض الـ SnackBar حتى يتم بناء الـ widget tree
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('Checking authentication status...');
        }
      });

      String? lastCheckResult;
      String? storedToken;

      try {
        lastCheckResult = await _storage.read(key: 'last_check_result');
      } catch (e) {
        print('Error reading last_check_result: $e');
        lastCheckResult = null;
      }

      try {
        storedToken = await _storage.read(key: 'auth_token');
      } catch (e) {
        print('Error reading auth_token: $e');
        storedToken = null;
      }

      // استخدام AuthProvider للتحقق من حالة المصادقة
      await _authProvider.initializeAuthentication();
      final bool isAuthenticated = _authProvider.isAuthenticated;

      if (lastCheckResult == null ||
          !lastCheckResult.isNotEmpty ||
          storedToken == null ||
          !storedToken.isNotEmpty ||
          !isAuthenticated) {
        _navigateToRoute('/auth');
        return;
      }

      if (storedToken != null && storedToken.isNotEmpty) {
        print('token : $storedToken and lastCheckResult :$lastCheckResult');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('Performing background check...');
          }
        });

        // بدلاً من التنقل فوراً، سنقوم بالتحقق أولاً
        await _performBackgroundCheck();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('No token found, navigating to AuthScreen');
            _navigateToRoute('/auth');
          }
        });
      }
    } catch (e) {
      print('Error in _navigateBasedOnStoredData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قراءة البيانات المخزنة'),
            backgroundColor: Colors.red,
          ),
        );
        _navigateToRoute('/auth');
      }
    }
  }

  // إجراء التحقق في الخلفية
  Future<void> _performBackgroundCheck() async {
    try {
      // التحقق من صلاحية الرمز المميز باستخدام AuthProvider
      final bool isTokenValid = await _authProvider.checkTokenValidity();
      print('isTokenValid: $isTokenValid');

      if (!isTokenValid) {
        print('Token is invalid or expired');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('Token is invalid or expired');
            _navigateToRoute('/auth');
          }
        });
        await _saveCheckResult('/auth', null);
        return;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('Token is valid, checking subscription status...');
          }
        });

        final Map<String, dynamic> subscriptionResponse =
            await _apiService.checkSubscription();

        if (subscriptionResponse['subscribed'] == true) {
          if (subscriptionResponse['redirect_to_subscription'] == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print('User needs to manage subscription');
                _navigateToRoute('/subscription_management');
              }
            });
            await _saveCheckResult('/subscription_management', null);
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print('User is subscribed, navigating to RemindersScreen');
                _navigateToRoute('/reminders');
              }
            });
            await _saveCheckResult('/reminders', null);
          }
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('User is not subscribed, navigating to AuthScreen');
              _navigateToRoute('/auth');
            }
          });
          await _saveCheckResult('/auth', null);
        }
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('Background check failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.error(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
          _navigateToRoute('/auth');
        }
      });
    }
  }

  // دالة مساعدة لحفظ نتيجة الفحص
  Future<void> _saveCheckResult(String result, String? token) async {
    await _storage.write(key: 'last_check_result', value: result);
    if (token != null) {
      // استخدام AuthProvider لتخزين الرمز المميز
      await _authProvider.setToken(token);
    } else if (result == '/auth') {
      // تسجيل الخروج إذا كانت النتيجة هي التوجيه إلى شاشة المصادقة
      await _authProvider.logout();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('Saved check result: $result');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png', // تأكد من أن المسار صحيح
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
