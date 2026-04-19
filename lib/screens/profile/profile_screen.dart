import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/auth_service.dart';
import 'package:split/services/user_service.dart';
import 'package:split/services/expense_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: use_build_context_synchronously
// jj

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: SafeArea(
        child: user == null
            ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Not Logged In',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      child: const Text('Login'),
                      onPressed: () => context.push('/login'),
                    ),
                  ],
                ),
              )
            : StreamBuilder<UserModel?>(
                stream: context.read<UserService>().getUserStream(user.uid),
                builder: (context, snapshot) {
                  final userModelFromStream = snapshot.data;
                  final currentUser = userModelFromStream ?? UserModel(
                    id: user.uid,
                    email: user.email ?? '',
                    displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
                    avatarUrl: user.photoURL,
                  );
                  return ListView(
                    children: [
                      const SizedBox(height: 32),
                      // Profile Picture Section
                      Center(
        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showImagePicker(context, currentUser),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200]!,
                                      image: _profileImage != null
                                        ? DecorationImage(
                                            image: FileImage(_profileImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : currentUser.avatarUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(currentUser.avatarUrl!),
                                                fit: BoxFit.cover,
                                                onError: (error, _) {},
                                              )
                                            : null,
                                    ),
                                    child: _profileImage == null &&
                                            currentUser.avatarUrl == null
                                        ? const Icon(
                                            Icons.account_circle,
                                            size: 120,
                                            color: Colors.indigo,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentUser.displayName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser.email,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            if (currentUser.bio != null && currentUser.bio!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  currentUser.bio!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (_isLoading) const LinearProgressIndicator(),
                      const SizedBox(height: 12),

                      // User Statistics
                      _UserStatisticsSection(userId: user.uid),

                      // Profile Options
                      Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Edit Profile'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showEditProfileDialog(context, currentUser),
                          ),
                          ListTile(
                            leading: const Icon(Icons.text_fields),
                            title: const Text('Change Username'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showEditUsernameDialog(context, currentUser),
                          ),
                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('About Me'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showEditBioDialog(context, currentUser),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text('Settings'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showSettings(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.info),
                            title: const Text('About App'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showAboutApp(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextButton(
                          child: const Text('Logout'),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text('Are you sure you want to logout?'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.pop(context, false),
                                  ),
                                  TextButton(
                                    child: const Text('Logout'),
                                    onPressed: () => Navigator.pop(context, true),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && context.mounted) {
                              await context.read<AuthService>().signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showImagePicker(BuildContext context, UserModel user) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Change Profile Picture',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.camera);
                if (image != null && mounted) {
                  setState(() {
                    _profileImage = File(image.path);
                  });
                  await _uploadProfileImage(context, user);
                }
              },
            ),
            ListTile(
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null && mounted) {
                  setState(() {
                    _profileImage = File(image.path);
                  });
                  await _uploadProfileImage(context, user);
                }
              },
            ),
            if (user.avatarUrl != null)
              ListTile(
                title: const Text('Remove Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeProfileImage(context, user);
                },
              ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadProfileImage(BuildContext context, UserModel user) async {
    if (_profileImage == null) return;

    setState(() => _isLoading = true);

    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('profile_images/${user.id}_${const Uuid().v4()}.jpg');
      await ref.putFile(_profileImage!);
      final downloadUrl = await ref.getDownloadURL();

      if (!mounted) return;
      final updatedUser = user.copyWith(avatarUrl: downloadUrl);
      await context.read<UserService>().updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _profileImage = null;
          _isLoading = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Profile picture updated successfully!'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to upload profile picture: ${e.toString()}'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _removeProfileImage(BuildContext context, UserModel user) async {
    setState(() => _isLoading = true);

    try {
      final updatedUser = user.copyWith(avatarUrl: null);
      if (!mounted) return;
      await context.read<UserService>().updateUser(updatedUser);

      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Profile picture removed successfully!'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to remove profile picture: ${e.toString()}'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, UserModel user) async {
    final usernameController = TextEditingController(text: user.displayName);
    final bioController = TextEditingController(text: user.bio ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  hintText: 'Bio (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              final newName = usernameController.text.trim();
              if (newName.isEmpty) {
                Navigator.pop(context);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Error'),
                      content: const Text('Username cannot be empty'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }

              Navigator.pop(context);
              await _updateUserProfile(
                context,
                user,
                newName,
                bioController.text.trim(),
              );
            },
          ),
        ],
      ),
    );

  }

  Future<void> _showEditUsernameDialog(BuildContext context, UserModel user) async {
    final controller = TextEditingController(text: user.displayName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Username',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                Navigator.pop(context);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Error'),
                      content: const Text('Username cannot be empty'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }

              Navigator.pop(context);
              await _updateUserProfile(context, user, newName, user.bio);
            },
          ),
        ],
      ),
    );

  }

  Future<void> _showEditBioDialog(BuildContext context, UserModel user) async {
    final controller = TextEditingController(text: user.bio ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Me'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Write a short bio about yourself...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              Navigator.pop(context);
              await _updateUserProfile(
                context,
                user,
                user.displayName,
                controller.text.trim(),
              );
            },
          ),
        ],
      ),
    );

  }

  Future<void> _updateUserProfile(
    BuildContext context,
    UserModel user,
    String displayName,
    String? bio,
  ) async {
    try {
      final updatedUser = user.copyWith(
        displayName: displayName,
        bio: bio?.isEmpty == true ? null : bio,
      );
      await context.read<UserService>().updateUser(updatedUser);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Profile updated successfully!'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update profile: ${e.toString()}'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text('• Notifications'),
              SizedBox(height: 4),
              Text('• Currency Preferences'),
              SizedBox(height: 4),
              Text('• Language Settings'),
              SizedBox(height: 4),
              Text('• Privacy & Security'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Splitter'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Splitter App',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(height: 16),
              Text(
                'Splitter is a comprehensive expense splitting and meal tracking application designed for groups, trips, and bachelor mess management.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Split expenses equally, unequally, or by shares'),
              Text('• Track meals and calculate meal rates'),
              Text('• Generate detailed PDF reports'),
              Text('• Manage multiple groups'),
              Text('• Real-time expense tracking'),
              SizedBox(height: 12),
              Text(
                '© 2024 Splitter App. All rights reserved.',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _UserStatisticsSection extends StatelessWidget {
  final String userId;

  const _UserStatisticsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: _getUserStatistics(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final totalGroups = stats[0] as int;
        final totalExpenses = stats[1] as int;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Groups',
                  value: totalGroups.toString(),
                  icon: Icons.group,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Expenses',
                  value: totalExpenses.toString(),
                  icon: Icons.attach_money,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<List<dynamic>> _getUserStatistics(BuildContext context) async* {
    final expenseService = context.read<ExpenseService>();

    // Get all groups where user is a member
    final allGroups = await FirebaseFirestore.instance
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .get();

    int totalExpenses = 0;
    for (final groupDoc in allGroups.docs) {
      final expenses = await expenseService
          .getGroupExpenses(groupDoc.id)
          .first
          .timeout(const Duration(seconds: 5));
      totalExpenses += expenses.length;
    }

    yield [allGroups.docs.length, totalExpenses];
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
