import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class light1_DeviceDetailScreen extends StatefulWidget {
  @override
  _light1_DeviceDetailScreenState createState() => _light1_DeviceDetailScreenState();
}

class _light1_DeviceDetailScreenState extends State<light1_DeviceDetailScreen> {
  bool isOn = false;

  // Reference to your Firestore document
  final fanDocRef = FirebaseFirestore.instance
      .collection('wattwizard')
      .doc('FRHZLgxL68UL66HdprgD');

  // Method to update fan status in Firestore
  Future<void> updateFanStatus(bool status) async {
    try {
      await fanDocRef.update({'light1_status': status});
    } catch (e) {
      debugPrint('Failed to update fan status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Red Light"),
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
                        await updateFanStatus(val); // 🔄 Update Firestore here
                      },
                    ),
                  ],
                ),
                Icon(Icons.lightbulb, size: 40, color: isOn ? Colors.red : Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
