import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_dashboard_screen.dart';
import 'setting_screen.dart';
import 'Fan_device_detail_screen.dart';
import 'light1_device_detail_screen.dart';
import 'light2_device_detail_screen.dart';
import 'socket_device_detail_screen.dart';
import 'power_monitoring_screen.dart'; // Import the new screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tracks which tab is selected

  // List of screens to navigate between
  late final List<Widget> _screens; // Changed to late final

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeContent(), // Home Screen Content
      AIDashboardScreen(userId:'SwoC0PrmsjduTm2uoigHod8TuY92'), // AI Suggestion Screen
      PowerMonitoringScreen(), // New Power Monitoring Screen
      SettingScreen(),
    ];
  }

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
          BottomNavigationBarItem(icon: Icon(Icons.power), label: "Power"), // New Power tab
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
          // Dynamic Power Usage Chart Section
          _buildPowerUsageChart(user.uid),
          const SizedBox(height: 20),

          // Total Usage Today
          const Text(
            "All Devices",
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

  // Dynamic Power Usage Chart Widget
  Widget _buildPowerUsageChart(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('power_data')
          .doc(uid)
          .collection('sensor_history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        // Default values for loading/error states
        List<FlSpot> chartDataPower = [];
        double currentPower = 0.0;
        String powerText = "Loading...";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs.reversed.toList();

          // Get current power from the latest reading
          if (docs.isNotEmpty) {
            final latestData = docs.last.data() as Map<String, dynamic>;
            currentPower = (latestData['total_power_watts'] ?? 0.0).toDouble();
          }

          // Prepare chart data
          for (int i = 0; i < docs.length; i++) {
            final data = docs[i].data() as Map<String, dynamic>;
            final power = (data['total_power_watts'] ?? 0.0).toDouble();
            chartDataPower.add(FlSpot(i.toDouble(), power));
          }

          // Format power text
          if (currentPower < 1) {
            powerText = "${(currentPower * 1000).toStringAsFixed(0)} mW";
          } else {
            powerText = "${currentPower.toStringAsFixed(2)} W";
          }
        } else if (snapshot.hasError) {
          powerText = "Error loading data";
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          powerText = "Loading...";
        } else {
          powerText = "No data available";
        }

        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E425E),
                Color(0xFF2D5A7B),
                Color(0xFF3B6F95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E425E).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Watt Usage Insights",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Live indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Live",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current power display
              Row(
                children: [
                  Text(
                    powerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Current",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Last 20 readings from your DC system",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // Dynamic Line Chart
              SizedBox(
                height: 140,
                child: chartDataPower.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        snapshot.hasError ? Icons.error_outline : Icons.hourglass_empty,
                        color: Colors.white.withOpacity(0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.hasError
                            ? "Unable to load chart data"
                            : snapshot.connectionState == ConnectionState.waiting
                            ? "Loading chart data..."
                            : "No power data available yet",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: chartDataPower.isNotEmpty
                          ? (chartDataPower.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 4)
                          : 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, meta) {
                            if (value < 1) {
                              return Text(
                                '${(value * 1000).toInt()}mW',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 9,
                                ),
                              );
                            } else {
                              return Text(
                                '${value.toStringAsFixed(1)}W',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 9,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartDataPower,
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            Colors.amber,
                            Colors.orange,
                          ],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.amber.withOpacity(0.3),
                              Colors.orange.withOpacity(0.1),
                            ],
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 2,
                              color: Colors.white,
                              strokeWidth: 1,
                              strokeColor: Colors.amber,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        // onTap: () {
        //   // Navigate to respective device detail screen
        //   switch (deviceId) {
        //     case 'fan_01':
        //       Navigator.push(context, MaterialPageRoute(builder: (context) => Fan_DeviceDetailScreen()));
        //       break;
        //     case 'light_01': // Red Light, navigate to Light2 screen
        //       Navigator.push(context, MaterialPageRoute(builder: (context) => light1_DeviceDetailScreen()));
        //       break;
        //     case 'light_02': // Green Light, navigate to Light1 screen
        //       Navigator.push(context, MaterialPageRoute(builder: (context) => light2_DeviceDetailScreen()));
        //       break;
        //     case 'socket_01':
        //       Navigator.push(context, MaterialPageRoute(builder: (context) => socket_DeviceDetailScreen()));
        //       break;
        //   }
        // },
      ),
    );
  }
}