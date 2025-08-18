import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String userName = "";
  String userEmail = "";
  String phoneNumber = "";
  String selectedAvatar = "assets/avatars/avatar1.png"; // Default avatar

  // Available built-in avatars
  final List<String> avatarOptions = [
    "assets/avatars/avatar1.png",
    "assets/avatars/avatar2.png",
    "assets/avatars/avatar3.png",
    "assets/avatars/avatar4.png",
    "assets/avatars/avatar5.png",
  ];

  // Controllers
  late TextEditingController nameController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    phoneController = TextEditingController();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userEmail = user.email ?? "";
        userName = user.displayName ?? "No Name";

        // Fetch user preferences from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();

          // Get profile data
          final profileData = data?['profile'] as Map<String, dynamic>?;
          if (profileData != null) {
            userName = profileData['name'] ?? userName;
            phoneNumber = profileData['phone'] ?? "";
            selectedAvatar = profileData['avatar'] ?? "assets/avatars/avatar1.png";
          } else {
            // Fallback to root level phone if profile doesn't exist
            phoneNumber = data?['phone'] ?? "";
          }

          nameController.text = userName;
          phoneController.text = phoneNumber;
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> saveUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update the user profile in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'profile': {
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'avatar': selectedAvatar,
            'email': userEmail,
          },
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also update Firebase Auth display name
        await user.updateDisplayName(nameController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update profile: $e")),
      );
    }
  }

  Future<void> resetAllDevices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Reset All Devices"),
            content: const Text("This will turn off all devices and reset their session times. Continue?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Reset", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Reset all devices in user's device collection with names
          final batch = FirebaseFirestore.instance.batch();
          final userDevicesRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('devices');

          // Device mapping with their names
          final devices = {
            'fan_01': 'DC Fan',
            'light_01': 'Green LED',
            'light_02': 'Red LED',
            'socket_01': '12V Socket'
          };

          for (String deviceId in devices.keys) {
            batch.set(userDevicesRef.doc(deviceId), {
              'status': false,
              'name': devices[deviceId]
            });
          }

          await batch.commit();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All devices reset successfully")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to reset devices: $e")),
      );
    }
  }

  void _showAvatarSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Avatar"),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: avatarOptions.length,
            itemBuilder: (context, index) {
              final avatar = avatarOptions[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedAvatar = avatar;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedAvatar == avatar
                          ? const Color(0xFF1E425E)
                          : Colors.grey.shade300,
                      width: selectedAvatar == avatar ? 3 : 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    child: _getAvatarIcon(index),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _getAvatarIcon(int index) {
    final icons = [
      Icons.person,
      Icons.account_circle,
      Icons.face,
      Icons.person_outline,
      Icons.supervised_user_circle,
    ];

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return Icon(
      icons[index % icons.length],
      size: 40,
      color: colors[index % colors.length],
    );
  }

  Widget _getCurrentAvatar() {
    int avatarIndex = avatarOptions.indexOf(selectedAvatar);
    if (avatarIndex == -1) avatarIndex = 0;

    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey.shade200,
      child: _getAvatarIcon(avatarIndex),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E425E),
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showAvatarSelector,
                        child: Stack(
                          children: [
                            _getCurrentAvatar(),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E425E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        nameController.text.isEmpty ? userName : nameController.text,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text("Tap avatar to change", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Profile Information
                _sectionHeader("Profile Information"),
                _buildEditableField("Full Name", nameController, TextInputType.text),
                _buildTextField("E-mail", userEmail, isEditable: false),
                _buildEditableField("Phone Number", phoneController, TextInputType.phone),

                const SizedBox(height: 30),

                // Device Management
                _sectionHeader("Device Management"),
                _buildActionButton("Reset All Devices", Icons.power_off, Colors.orange, resetAllDevices),

                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E425E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: saveUserPreferences,
                    child: const Text(
                      "SAVE SETTINGS",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E425E),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value, {bool isEditable = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        enabled: isEditable,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isEditable ? Colors.white : Colors.grey.shade100,
        ),
        controller: TextEditingController(text: value),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: color),
        label: Text(title, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}