import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class light2_DeviceDetailScreen extends StatefulWidget {
  @override
  _light2_DeviceDetailScreenState createState() => _light2_DeviceDetailScreenState();
}

class _light2_DeviceDetailScreenState extends State<light2_DeviceDetailScreen> {
  bool isOn = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  DocumentReference? _redLightDocRef;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      // This screen now controls the Red Light (light_01)
      _redLightDocRef = _firestore.collection('users').doc(_currentUser!.uid).collection('devices').doc('light_02');
      _listenToRedLightStatus();
    }
  }

  void _listenToRedLightStatus() {
    _redLightDocRef?.snapshots().listen((snapshot) {
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

  // Method to update Red Light status in Firestore
  Future<void> updateRedLightStatus(bool status) async {
    try {
      if (_redLightDocRef != null) {
        await _redLightDocRef!.update({'status': status});
      }
    } catch (e) {
      debugPrint('Failed to update Red Light status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Red Light")),
        body: const Center(child: Text("Please log in to control devices.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Red Light"), // Updated title
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
                        await updateRedLightStatus(val); // Updated method call
                      },
                    ),
                  ],
                ),
                Icon(Icons.lightbulb, size: 40, color: isOn ? Colors.red : Colors.grey), // Updated icon color
              ],
            ),
          ],
        ),
      ),
    );
  }
}
