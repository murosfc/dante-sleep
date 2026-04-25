import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/localized_strings.dart';
import '../providers/app_provider.dart';
import '../screens/baby_onboarding_screen.dart';
import '../services/firebase_service.dart';

class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  String? _displayName;
  String? _photoBase64;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseService().currentUser;
    if (user != null) {
      final profile = await FirebaseService().getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _displayName = profile['displayName'] ?? user.displayName ?? user.email;
          _photoBase64 = profile['photoBase64'];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    final user = FirebaseService().currentUser;
    if (user != null) {
      await FirebaseService().updateUserProfile(user.uid, {'displayName': newName});
      if (mounted) {
        setState(() {
          _displayName = newName;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      
      final user = FirebaseService().currentUser;
      if (user != null) {
        await FirebaseService().updateUserProfile(user.uid, {'photoBase64': base64Str});
        if (mounted) {
          setState(() {
            _photoBase64 = base64Str;
          });
        }
      }
    }
  }

  void _showEditNameDialog(BuildContext context, LocalizedStrings strings) {
    final TextEditingController controller = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.editNameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: strings.nameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateDisplayName(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final strings = LocalizedStrings(context);
    final isDay = provider.isDay;
    final textColor = isDay ? const Color(0xFF12233F) : const Color(0xFFF2ECFF);
    final bgColor = isDay ? Colors.white : const Color(0xFF1D1130);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Profile Header
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: isDay ? Colors.grey[200] : Colors.grey[800],
                              backgroundImage: _photoBase64 != null
                                  ? MemoryImage(base64Decode(_photoBase64!))
                                  : null,
                              child: _photoBase64 == null
                                  ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2A6CE8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayName ?? strings.userDefaultName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showEditNameDialog(context, strings),
                                  icon: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: isDay
                                        ? const Color(0xFF2A6CE8)
                                        : const Color(0xFFA5C5FF),
                                  ),
                                  tooltip: strings.editName,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // Baby Profile
              ListTile(
                leading: Icon(Icons.child_care, color: textColor),
                title: Text(
                  strings.babyProfile,
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BabyOnboardingScreen(isEditing: true),
                    ),
                  );
                },
              ),

              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // Import/Export CSV
              /* 
              ListTile(
                leading: Icon(Icons.download_rounded, color: textColor),
                title: Text(strings.importCsv, style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context); // Close sheet before action
                  final result = await provider.importCsv();
                  if (context.mounted && result != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.getEntriesImportedMessage(result))),
                    );
                  } else if (context.mounted && result == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.importCancelledOrFailed)),
                    );
                  }
                },
              ),
              */
              ListTile(
                leading: Icon(Icons.upload_rounded, color: textColor),
                title: Text(strings.exportCsv, style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  final filename = await provider.exportCsv(
                    headers: strings.getCsvHeaders(),
                    dayValue: strings.dayLabel,
                    nightValue: strings.nightLabel,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.getCsvExportedMessage(filename))),
                    );
                  }
                },
              ),
              
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              
              // Language Select
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.language, color: textColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(strings.language, style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                    DropdownButton<String>(
                      value: provider.locale.languageCode,
                      dropdownColor: bgColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: textColor),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.setLanguage(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'pt',
                          child: Row(
                            children: [
                              const Text('🇧🇷', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(strings.portuguese, style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(
                            children: [
                              const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(strings.english, style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Time Format Select
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: textColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(strings.timeFormat, style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                    DropdownButton<bool>(
                      value: provider.is24Hour,
                      dropdownColor: bgColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: textColor),
                      onChanged: (bool? newValue) {
                        if (newValue != null) {
                          provider.set24Hour(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: false,
                          child: Text(strings.hourFormat12, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text(strings.hourFormat24, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              
              // Logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(strings.logout, style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  provider.clearUserData();
                  await FirebaseService().signOut();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
