import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_suggestion_screen.dart';
import 'setting_screen.dart';
import 'Fan_device_detail_screen.dart';
import 'light1_device_detail_screen.dart';
import 'light2_device_detail_screen.dart';
import 'socket_device_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tracks which tab is selected

  // List of screens to navigate between
  final List<Widget> _screens = [
    HomeContent(), // Home Screen Content
    AISuggestionScreen(), // AI Suggestion Screen
    SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E425E),
        title: const Text("WattWizard", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      body: _screens[_selectedIndex], // Display the selected screen

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E425E),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex, // Keep track of active tab
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // Change tab on tap
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "AI Suggestion"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

// Home Screen Content Widget
class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to view devices."));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly Usage Section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E425E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Usage this Week",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "2700 watt", // This will be dynamic later
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Line Chart
                SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(days[value.toInt()], style: const TextStyle(color: Colors.white70)),
                              );
                            },
                            interval: 1,
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 200),
                            FlSpot(1, 500),
                            FlSpot(2, 900),
                            FlSpot(3, 1300),
                            FlSpot(4, 1700),
                            FlSpot(5, 2100),
                            FlSpot(6, 2500),
                          ],
                          isCurved: true,
                          color: Colors.white,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Total Usage Today
          const Text(
            "Total Today",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),

          // List of devices
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').doc(user.uid).collection('devices').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No devices found.'));
                }

                final deviceDocs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: deviceDocs.length,
                  itemBuilder: (context, index) {
                    final deviceData = deviceDocs[index].data() as Map<String, dynamic>;
                    final deviceId = deviceDocs[index].id;
                    final String title = deviceData['name'] ?? 'Unknown Device';
                    final bool status = deviceData['status'] ?? false;
                    IconData icon;
                    switch (deviceId) {
                      case 'fan_01':
                        icon = Icons.ac_unit;
                        break;
                      case 'light_01': // This is Green Light
                        icon = Icons.lightbulb;
                        break;
                      case 'light_02': // This is Red Light
                        icon = Icons.lightbulb;
                        break;
                      case 'socket_01':
                        icon = Icons.electrical_services;
                        break;
                      default:
                        icon = Icons.devices_other;
                    }
                    return _buildDeviceTile(
                      title,
                      "Location placeholder",
                      "Usage placeholder",
                      status,
                      icon,
                      context,
                      deviceId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Device List Item Widget
  Widget _buildDeviceTile(String title, String location, String usage, bool status, IconData icon, BuildContext context, String deviceId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: status ? Colors.amber : const Color(0xFF1E425E)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(location),
        trailing: Switch(
          value: status,
          onChanged: (bool newValue) async {
            // Update device status in Firebase
            User? user = _auth.currentUser;
            if (user != null) {
              await _firestore.collection('users').doc(user.uid).collection('devices').doc(deviceId).update({'status': newValue});
            }
          },
          activeColor: Colors.amber,
        ),
        onTap: () {
          // Navigate to respective device detail screen
          switch (deviceId) {
            case 'fan_01':
              Navigator.push(context, MaterialPageRoute(builder: (context) => Fan_DeviceDetailScreen()));
              break;
            case 'light_01': // Green Light, navigate to Light2 screen
              Navigator.push(context, MaterialPageRoute(builder: (context) => light1_DeviceDetailScreen()));
              break;
            case 'light_02': // Red Light, navigate to Light1 screen
              Navigator.push(context, MaterialPageRoute(builder: (context) => light2_DeviceDetailScreen()));
              break;
            case 'socket_01':
              Navigator.push(context, MaterialPageRoute(builder: (context) => socket_DeviceDetailScreen()));
              break;
          }
        },
      ),
    );
  }
}
