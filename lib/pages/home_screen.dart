import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  // List of screens to navigate betwee
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
class HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                  "2700 watt",
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
                          spots: [
                            const FlSpot(0, 200),
                            const FlSpot(1, 500),
                            const FlSpot(2, 900),
                            const FlSpot(3, 1300),
                            const FlSpot(4, 1700),
                            const FlSpot(5, 2100),
                            const FlSpot(6, 2500),
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
            child: ListView(
              children: [
                _buildDeviceTile("Fan", "Kitchen - Bedroom", "1000 w/h", "+11.2%", Icons.ac_unit, context),
                _buildDeviceTile("Red Light", "Kitchen - Living Room", "1000 w/h", "-10.2%", Icons.lightbulb, context),
                _buildDeviceTile("Green Light", "Bedroom", "1090 w/h", "-10.3%", Icons.lightbulb, context),
                _buildDeviceTile("Socket", "Living Room", "1000 w/h", "-9.2%", Icons.electrical_services, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Device List Item Widget
  Widget _buildDeviceTile(String title, String location, String usage, String percentage, IconData icon, BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1E425E)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(location),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(usage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            Text(percentage, style: TextStyle(color: percentage.contains("+") ? Colors.green : Colors.red)),
          ],
        ),
        onTap: () {
          if (title == "Fan") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Fan_DeviceDetailScreen()),
            );
          }
          if (title == "Red Light") {
          Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => light1_DeviceDetailScreen()),
          );
          }
          if (title == "Green Light") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => light2_DeviceDetailScreen()),
            );
          }
          if (title == "Socket") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => socket_DeviceDetailScreen()),
            );
          }
        },
      ),
    );
  }
}
