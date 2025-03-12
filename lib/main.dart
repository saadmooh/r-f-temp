import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:reminder/pages/auth_screen.dart';
import 'package:reminder/pages/reminders_screen.dart';
import 'package:reminder/pages/reminder_detail_screen.dart';
import 'package:reminder/pages/settings_screen.dart';
import 'package:reminder/pages/time_slots_screen.dart';
import 'package:reminder/pages/save_post_screen.dart';
import 'package:reminder/pages/stats_screen.dart';
import 'package:reminder/pages/splash_screen.dart';
import 'package:reminder/pages/user_profile_screen.dart';
import 'package:reminder/pages/subscription_management_screen.dart';
import 'package:reminder/globals.dart';
import 'package:reminder/utils/language_manager.dart';
import 'package:reminder/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('MyApp build called');
    return Consumer<LanguageManager>(
      builder: (context, languageManager, child) {
        return MaterialApp(
          title: AppLocalizations.of(context)?.appTitle ?? 'Reminder App',
          navigatorKey: navigatorKey,
          theme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            fontFamily: 'arial',
            scaffoldBackgroundColor: Colors.black,
            cardColor: Colors.grey[900],
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              displayLarge:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white70),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff727475),
                padding: const EdgeInsets.symmetric(
                    horizontal: 48.0, vertical: 16.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffcbced0)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ar', ''),
          ],
          locale: languageManager.locale,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) {
              return supportedLocales.first;
            }
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode) {
                return supportedLocale;
              }
            }
            return supportedLocales.first;
          },
          routes: {
            '/': (context) => const SplashScreen(),
            '/auth': (context) => AuthScreen(),
            '/reminders': (context) => RemindersScreen(),
            '/reminder': (context) => ReminderDetailScreen(),
            '/settings': (context) => SettingsScreen(),
            '/time_slots': (context) => const TimeSlotsScreen(),
            '/save-post': (context) => const SavePostScreen(),
            '/stats': (context) => const StatsScreen(),
            '/user_profile': (context) => const UserProfileScreen(),
            '/subscription_management': (context) =>
                const SubscriptionManagementScreen(),
          },
          onUnknownRoute: (settings) {
            print('Unknown route accessed: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: Center(child: Text('Route not found: ${settings.name}')),
              ),
            );
          },
        );
      },
    );
  }
}
