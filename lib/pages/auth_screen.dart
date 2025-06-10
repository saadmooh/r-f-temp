import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_reminder/services/api_service.dart';
import 'package:flex_reminder/utils/language_manager.dart';
import 'package:flex_reminder/l10n/app_localizations.dart';
import 'package:flex_reminder/providers/auth_provider.dart';
//import 'package:reminder/widgets/upper_app_bar.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = true;
  bool _obscurePassword = true;

  final ApiService _apiService = ApiService();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> response;
      final languageManager =
          Provider.of<LanguageManager>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final language = languageManager.locale.languageCode;

      if (_isRegistering) {
        response = await _apiService.register(
          _nameController.text,
          _emailController.text.trim().toLowerCase(),
          _passwordController.text,
          language: language,
        );

        if (response['statusCode'] == 201) {
          String message = response['data']['message'];
          if (message ==
              'messages.registered_successfullymessages.complete_payment') {
            final localizations = AppLocalizations.of(context)!;
            message = localizations.registrationSuccessful;
          }
          _showSuccessSnackBar(message);
        } else {
          _handleErrorResponse(response);
        }
      } else {
        response = await _apiService.login(
          _emailController.text.trim().toLowerCase(),
          _passwordController.text,
          language: language,
        );

        if (response['statusCode'] == 200) {
          final token = response['data']['access_token'];
          if (token != null) {
            // استخدام AuthProvider لتخزين الرمز المميز
            await authProvider.setToken(token);
            final localizations = AppLocalizations.of(context)!;
            _showSuccessSnackBar(localizations.loginSuccessful);
            Navigator.pushReplacementNamed(context, '/reminders');
          }
        } else {
          _handleErrorResponse(response);
        }
      }
    } catch (error) {
      _showErrorSnackBar('An unexpected error occurred: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleErrorResponse(Map<String, dynamic> response) {
    String errorMessage = '';

    if (response['data'] != null) {
      if (response['data']['message'] != null) {
        errorMessage = response['data']['message'];
      } else if (response['data']['errors'] != null) {
        final errors = response['data']['errors'];
        if (errors is Map) {
          errorMessage = errors.values.expand((e) => e).join('\n');
        } else {
          errorMessage = errors.toString();
        }
      } else {
        errorMessage = 'An error occurred.';
      }
    } else {
      errorMessage = 'Unexpected error occurred.';
    }

    _showErrorSnackBar(errorMessage);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final languageManager = Provider.of<LanguageManager>(context);
    final isArabic = languageManager.locale.languageCode == 'ar';
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Image.asset(
                      'assets/logo.png',
                      height: 80.0,
                    ),
                    const SizedBox(height: 40.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<String>(
                        color: Colors.white,
                        icon: const Icon(Icons.language, color: Colors.black),
                        onSelected: (value) {
                          if (value == 'en') {
                            languageManager.setLocale(const Locale('en'));
                          } else if (value == 'ar') {
                            languageManager.setLocale(const Locale('ar'));
                          } else if (value == 'zh') {
                            languageManager.setLocale(const Locale('zh'));
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            value: 'en',
                            child: Text(
                              'English',
                              style: const TextStyle(color: Colors.black),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'ar',
                            child: Text(
                              'العربية',
                              style: const TextStyle(color: Colors.black),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'zh',
                            child: Text(
                              '中文',
                              style: const TextStyle(color: Colors.black),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    if (_isRegistering)
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: localizations.name,
                          labelStyle: const TextStyle(color: Colors.black),
                          border: const UnderlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        textDirection: textDirection,
                        validator: (value) {
                          if (_isRegistering &&
                              (value == null || value.isEmpty)) {
                            return localizations.requiredField;
                          }
                          return null;
                        },
                      ),
                    if (_isRegistering) const SizedBox(height: 20.0),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: localizations.email,
                        labelStyle: const TextStyle(color: Colors.black),
                        border: const UnderlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      textDirection: textDirection,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value == null || value.isEmpty || !value.contains('@')
                              ? localizations.invalidEmail
                              : null,
                    ),
                    const SizedBox(height: 20.0),
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: localizations.password,
                        labelStyle: const TextStyle(color: Colors.black),
                        border: const UnderlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.visibility, color: Colors.black),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      textDirection: textDirection,
                      obscureText: _obscurePassword,
                      validator: (value) => value == null || value.length < 6
                          ? localizations.requiredField
                          : null,
                    ),
                    const SizedBox(height: 30.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isRegistering
                                  ? localizations.signUp
                                  : localizations.login,
                              style: const TextStyle(
                                  fontSize: 16.0, color: Colors.white),
                            ),
                    ),
                    const SizedBox(height: 20.0),
                    if (!_isRegistering)
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushNamed(context, '/reset-password');
                              },
                        child: Text(
                          localizations.forgotPassword,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegistering
                              ? localizations.alreadyHaveAccount
                              : localizations.dontHaveAccount,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegistering = !_isRegistering;
                            });
                          },
                          child: Text(
                            _isRegistering
                                ? localizations.login
                                : localizations.signUp,
                            style: const TextStyle(color: Color(0xFF6200EE)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
