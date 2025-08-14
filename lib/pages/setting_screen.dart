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
  late TextEditingController unitLimitController;

  @override
  void initState() {
    super.initState();
    unitLimitController = TextEditingController(); // ✅ early init
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      // Get Firebase Auth user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userEmail = user.email ?? "";
        userName = user.displayName ?? "No Name";
      }

      // Get Firestore units_limit
      final doc = await FirebaseFirestore.instance
          .collection('wattwizard')
          .doc('FRHZLgxL68UL66HdprgD')
          .get();

      if (doc.exists) {
        final data = doc.data();
        String unitLimit = data?['units_limit'].toString() ?? "";
        unitLimitController.text = unitLimit;
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  @override
  void dispose() {
    unitLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E425E),
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
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
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Edit Profile", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),

                // Fields
                _buildTextField("Full Name", userName),
                _buildTextField("E-mail", userEmail, isEditable: false),
                _buildTextField("Phone Number", "+923074357176", isEditable: false),
                _buildEditableField("Unit Limit", unitLimitController),

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
                    onPressed: () async {
                      try {
                        final updatedLimit = int.tryParse(unitLimitController.text);
                        if (updatedLimit != null) {
                          await FirebaseFirestore.instance
                              .collection('watt-wizard')
                              .doc('HicevjsZy57Qx2Dzowzh')
                              .update({'units_limit': updatedLimit});

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Unit limit updated successfully")),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a valid number")),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to update: $e")),
                        );
                      }
                    },
                    child: const Text(
                      "SAVE",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
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
}
