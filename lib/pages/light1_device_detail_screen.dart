import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class light1_DeviceDetailScreen extends StatefulWidget {
  @override
  _light1_DeviceDetailScreenState createState() => _light1_DeviceDetailScreenState();
}

class _light1_DeviceDetailScreenState extends State<light1_DeviceDetailScreen> {
  bool isOn = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  DocumentReference? _greenLightDocRef;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      // This screen now controls the Green Light (light_02)
      _greenLightDocRef = _firestore.collection('users').doc(_currentUser!.uid).collection('devices').doc('light_01');
      _listenToGreenLightStatus();
    }
  }

  void _listenToGreenLightStatus() {
    _greenLightDocRef?.snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            isOn = data['status'] ?? false;
          });
        }
      }
    });
  }

  // Method to update Green Light status in Firestore
  Future<void> updateGreenLightStatus(bool status) async {
    try {
      if (_greenLightDocRef != null) {
        await _greenLightDocRef!.update({'status': status});
      }
    } catch (e) {
      debugPrint('Failed to update Green Light status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Green Light")),
        body: const Center(child: Text("Please log in to control devices.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Green Light"), // Updated title
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Light Control", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    FlutterSwitch(
                      width: 60,
                      height: 30,
                      value: isOn,
                      onToggle: (val) async {
                        setState(() {
                          isOn = val;
                        });
                        await updateGreenLightStatus(val); // Updated method call
                      },
                    ),
                  ],
                ),
                Icon(Icons.lightbulb, size: 40, color: isOn ? Colors.green : Colors.grey), // Updated icon color
              ],
            ),
          ],
        ),
      ),
    );
  }
}
