import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Fan_DeviceDetailScreen extends StatefulWidget {
  @override
  _Fan_DeviceDetailScreenState createState() => _Fan_DeviceDetailScreenState();
}

class _Fan_DeviceDetailScreenState extends State<Fan_DeviceDetailScreen> {
  bool isOn = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  DocumentReference? _fanDocRef;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fanDocRef = _firestore.collection('users').doc(_currentUser!.uid).collection('devices').doc('fan_01');
      _listenToFanStatus();
    }
  }

  void _listenToFanStatus() {
    _fanDocRef?.snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        // Explicitly cast snapshot.data() to Map<String, dynamic>
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            isOn = data['status'] ?? false;
          });
        }
      }
    });
  }

  // Method to update fan status in Firestore
  Future<void> updateFanStatus(bool status) async {
    try {
      if (_fanDocRef != null) {
        await _fanDocRef!.update({'status': status});
      }
    } catch (e) {
      debugPrint('Failed to update fan status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Fan")),
        body: const Center(child: Text("Please log in to control devices.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Fan"),
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
                    Text("Fan Control", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    FlutterSwitch(
                      width: 60,
                      height: 30,
                      value: isOn,
                      onToggle: (val) async {
                        setState(() {
                          isOn = val;
                        });
                        await updateFanStatus(val); // 🔄 Update Firestore here
                      },
                    ),
                  ],
                ),
                Icon(Icons.ac_unit, size: 40, color: isOn ? Colors.blue : Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
