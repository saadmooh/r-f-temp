import 'dart:io';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:reminder/services/api_service.dart';
import 'package:reminder/utils/language_manager.dart';
import 'package:reminder/l10n/app_localizations.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  File? _image;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService().getUser();
      setState(() {
        _userData = userData;
        _nameController.text = userData['name'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final data = {
        'name': _nameController.text,
      };
      await apiService.updateUserProfile(data, image: _image);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      _loadUserData(); // إعادة تحميل البيانات بعد التحديث
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final languageManager =
        Provider.of<LanguageManager>(context, listen: false);
    final isArabic = languageManager.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.userProfile,
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _userData == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GestureDetector(
                      //  onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : (_userData!['profile_image'] != null &&
                                    _userData!['profile_image'].isNotEmpty
                                ? NetworkImage(_userData!['profile_image'])
                                : null) as ImageProvider?,
                        child: _image == null &&
                                (_userData!['profile_image'] == null ||
                                    _userData!['profile_image'].isEmpty)
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      localizations.tapToChangePhoto,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24.0),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: localizations.name,
                        border: const OutlineInputBorder(),
                      ),
                      textDirection:
                          isArabic ? TextDirection.rtl : TextDirection.ltr,
                    ),
                    const SizedBox(height: 24.0),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0, vertical: 12.0),
                            ),
                            child: Text(
                              localizations.updateProfile,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
