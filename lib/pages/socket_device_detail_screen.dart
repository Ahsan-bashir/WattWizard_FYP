import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class socket_DeviceDetailScreen extends StatefulWidget {
  @override
  _socket_DeviceDetailScreenState createState() => _socket_DeviceDetailScreenState();
}

class _socket_DeviceDetailScreenState extends State<socket_DeviceDetailScreen> {
  bool isOn = false;

  // Reference to your Firestore document
  final fanDocRef = FirebaseFirestore.instance
      .collection('wattwizard')
      .doc('FRHZLgxL68UL66HdprgD');

  // Method to update fan status in Firestore
  Future<void> updateFanStatus(bool status) async {
    try {
      await fanDocRef.update({'socket_status': status});
    } catch (e) {
      debugPrint('Failed to update fan status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Socket"),
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
                    Text("Socket Control", style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                Icon(Icons.electrical_services, size: 40, color: isOn ? Colors.blue : Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
