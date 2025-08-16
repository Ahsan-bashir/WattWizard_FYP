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

  // User preferences
  bool notificationsEnabled = true;
  bool autoDataSync = true;
  bool darkModeEnabled = false;
  String powerUnit = "watts"; // watts, kilowatts
  String energyUnit = "kWh"; // kWh, Wh
  int dataRetentionDays = 30;
  double powerThreshold = 50.0; // Alert threshold in watts

  // Controllers
  late TextEditingController phoneController;
  late TextEditingController powerThresholdController;
  late TextEditingController dataRetentionController;

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController();
    powerThresholdController = TextEditingController();
    dataRetentionController = TextEditingController();
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
          phoneNumber = data?['phone'] ?? "";
          notificationsEnabled = data?['notifications_enabled'] ?? true;
          autoDataSync = data?['auto_data_sync'] ?? true;
          darkModeEnabled = data?['dark_mode'] ?? false;
          powerUnit = data?['power_unit'] ?? "watts";
          energyUnit = data?['energy_unit'] ?? "kWh";
          dataRetentionDays = data?['data_retention_days'] ?? 30;
          powerThreshold = (data?['power_threshold'] ?? 50.0).toDouble();

          phoneController.text = phoneNumber;
          powerThresholdController.text = powerThreshold.toString();
          dataRetentionController.text = dataRetentionDays.toString();
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
        final updatedThreshold = double.tryParse(powerThresholdController.text) ?? powerThreshold;
        final updatedRetention = int.tryParse(dataRetentionController.text) ?? dataRetentionDays;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'phone': phoneController.text,
          'notifications_enabled': notificationsEnabled,
          'auto_data_sync': autoDataSync,
          'dark_mode': darkModeEnabled,
          'power_unit': powerUnit,
          'energy_unit': energyUnit,
          'data_retention_days': updatedRetention,
          'power_threshold': updatedThreshold,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save settings: $e")),
      );
    }
  }

  Future<void> clearDeviceHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Clear Device History"),
            content: const Text("This will permanently delete all device history data. Are you sure?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Clear", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Clear device history collection
          final batch = FirebaseFirestore.instance.batch();
          final historyQuery = await FirebaseFirestore.instance
              .collection('device_history')
              .get();

          for (var doc in historyQuery.docs) {
            batch.delete(doc.reference);
          }

          await batch.commit();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Device history cleared successfully")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to clear history: $e")),
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

  @override
  void dispose() {
    phoneController.dispose();
    powerThresholdController.dispose();
    dataRetentionController.dispose();
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
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text("Edit Profile", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Profile Information
                _sectionHeader("Profile Information"),
                _buildTextField("Full Name", userName),
                _buildTextField("E-mail", userEmail, isEditable: false),
                _buildEditableField("Phone Number", phoneController, TextInputType.phone),

                const SizedBox(height: 20),

                // Notification Settings
                _sectionHeader("Notifications"),
                _buildSwitchTile("Enable Notifications", notificationsEnabled, (value) {
                  setState(() => notificationsEnabled = value);
                }),
                _buildEditableField("Power Alert Threshold (Watts)", powerThresholdController, TextInputType.number),

                const SizedBox(height: 20),

                // Data & Sync Settings
                _sectionHeader("Data & Sync"),
                _buildSwitchTile("Auto Data Sync", autoDataSync, (value) {
                  setState(() => autoDataSync = value);
                }),
                _buildDropdownField("Power Unit", powerUnit, ["watts", "kilowatts"], (value) {
                  setState(() => powerUnit = value!);
                }),
                _buildDropdownField("Energy Unit", energyUnit, ["kWh", "Wh"], (value) {
                  setState(() => energyUnit = value!);
                }),
                _buildEditableField("Data Retention (Days)", dataRetentionController, TextInputType.number),

                const SizedBox(height: 20),

                // Appearance
                _sectionHeader("Appearance"),
                _buildSwitchTile("Dark Mode", darkModeEnabled, (value) {
                  setState(() => darkModeEnabled = value);
                }),

                const SizedBox(height: 20),

                // Device Management
                _sectionHeader("Device Management"),
                _buildActionButton("Reset All Devices", Icons.power_off, Colors.orange, resetAllDevices),
                const SizedBox(height: 10),
                _buildActionButton("Clear Device History", Icons.delete_outline, Colors.red, clearDeviceHistory),

                const SizedBox(height: 30),

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
          fillColor: Colors.white,
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

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1E425E),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: options.map((option) => DropdownMenuItem(
          value: option,
          child: Text(option),
        )).toList(),
        onChanged: onChanged,
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