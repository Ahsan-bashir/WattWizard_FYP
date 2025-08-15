import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class PowerMonitoringScreen extends StatefulWidget {
  const PowerMonitoringScreen({super.key});

  @override
  _PowerMonitoringScreenState createState() => _PowerMonitoringScreenState();
}

class _PowerMonitoringScreenState extends State<PowerMonitoringScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          "Please log in to view power data.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // Deep blue
            Color(0xFF3B82F6), // Blue
            Color(0xFF06B6D4), // Cyan
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildRealTimePowerCard(user.uid),
                    const SizedBox(height: 20),
                    _buildDeviceStatusGrid(user.uid),
                    const SizedBox(height: 20),
                    _buildPowerChart(user.uid),
                    const SizedBox(height: 20),
                    _buildEnergyInsights(user.uid),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.bolt,
            color: Colors.yellow,
            size: 32,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Power Monitoring",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Real-time energy tracking & analytics",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimePowerCard(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('power_data')
          .doc(uid)
          .collection('sensor_live')
          .doc('current')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard("Error loading real-time data: ${snapshot.error}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildNoDataCard();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final voltage = (data['voltage'] ?? 0.0).toDouble();
        final current = (data['current_a'] ?? 0.0).toDouble();
        final totalPower = (data['total_power_watts'] ?? 0.0).toDouble();
        final estimatedPower = (data['estimated_total_power'] ?? 0.0).toDouble();
        final efficiency = (data['power_efficiency'] ?? 0.0).toDouble();

        final timestamp = data['timestamp'];
        String lastUpdate = 'Unknown';
        if (timestamp != null) {
          try {
            final time = DateTime.fromMillisecondsSinceEpoch(
              int.parse(timestamp.toString()) * 1000,
            );
            lastUpdate = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
          } catch (e) {
            lastUpdate = 'Invalid timestamp';
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Real-Time Power",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Live",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Voltage",
                      "${voltage.toStringAsFixed(1)} V",
                      Icons.flash_on,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Current",
                      "${current.toStringAsFixed(2)} A",
                      Icons.electrical_services,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Actual Power",
                      "${totalPower.toStringAsFixed(1)} W",
                      Icons.power,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Estimated",
                      "${estimatedPower.toStringAsFixed(1)} W",
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: efficiency > 95 ? Colors.green.withOpacity(0.1) :
                  efficiency > 80 ? Colors.orange.withOpacity(0.1) :
                  Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: efficiency > 95 ? Colors.green :
                          efficiency > 80 ? Colors.orange : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Power Efficiency",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      "${efficiency.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: efficiency > 95 ? Colors.green :
                        efficiency > 80 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Last updated: $lastUpdate",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusGrid(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('power_data')
          .doc(uid)
          .collection('device_status')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard("Error loading device data: ${snapshot.error}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoDataCard();
        }

        final devices = snapshot.data!.docs;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.devices,
                    color: Color(0xFF1E3A8A),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Device Status",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final data = device.data() as Map<String, dynamic>;

                  final deviceName = data['device_name'] ?? 'Unknown Device';
                  final isOn = data['state'] ?? false;
                  final estimatedPower = (data['estimated_power'] ?? 0.0).toDouble();
                  final totalOnTimeHours = (data['total_on_time_hours'] ?? 0.0).toDouble();
                  final currentSessionHours = (data['current_session_duration_hours'] ?? 0.0).toDouble();

                  IconData deviceIcon;
                  Color deviceColor;

                  switch (device.id) {
                    case 'fan_01':
                      deviceIcon = Icons.air;
                      deviceColor = Colors.cyan;
                      break;
                    case 'light_01':
                    case 'light_02':
                      deviceIcon = Icons.lightbulb;
                      deviceColor = Colors.amber;
                      break;
                    case 'socket_01':
                      deviceIcon = Icons.power_settings_new;
                      deviceColor = Colors.green;
                      break;
                    default:
                      deviceIcon = Icons.device_unknown;
                      deviceColor = Colors.grey;
                  }

                  return _buildDeviceCard(
                    deviceName,
                    isOn,
                    estimatedPower,
                    totalOnTimeHours,
                    currentSessionHours,
                    deviceIcon,
                    deviceColor,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard(
      String name,
      bool isOn,
      double estimatedPower,
      double totalOnTimeHours,
      double currentSessionHours,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOn ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn ? color : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: isOn ? color : Colors.grey,
                size: 24,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOn ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOn ? "ON" : "OFF",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isOn ? color : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${estimatedPower.toStringAsFixed(0)} W",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          if (isOn && currentSessionHours > 0)
            Text(
              "Session: ${_formatHours(currentSessionHours)}",
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          Text(
            "Total: ${_formatHours(totalOnTimeHours)}",
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours < 1) {
      return "${(hours * 60).toStringAsFixed(0)}m";
    } else if (hours < 24) {
      return "${hours.toStringAsFixed(1)}h";
    } else {
      final days = (hours / 24).floor();
      final remainingHours = hours % 24;
      return "${days}d ${remainingHours.toStringAsFixed(0)}h";
    }
  }

  Widget _buildPowerChart(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('power_data')
          .doc(uid)
          .collection('sensor_history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard("Error loading chart data: ${snapshot.error}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: Color(0xFF1E3A8A),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Power Trends",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 60),
                Text(
                  "No historical data available yet",
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 60),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.reversed.toList();
        final chartData = <FlSpot>[];

        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          final power = (data['total_power_watts'] ?? 0.0).toDouble();
          chartData.add(FlSpot(i.toDouble(), power));
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    color: Color(0xFF1E3A8A),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Power Trends (Last 20 readings)",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 50,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.3),
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
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}W',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF06B6D4),
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
                              const Color(0xFF3B82F6).withOpacity(0.3),
                              const Color(0xFF06B6D4).withOpacity(0.1),
                            ],
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFF3B82F6),
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

  Widget _buildEnergyInsights(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('power_data')
          .doc(uid)
          .collection('device_status')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final devices = snapshot.data!.docs;
        double totalEstimatedPower = 0;
        double totalDailyEnergy = 0; // kWh
        int activeDevices = 0;

        for (final device in devices) {
          final data = device.data() as Map<String, dynamic>;
          final isOn = data['state'] ?? false;
          final estimatedPower = (data['estimated_power'] ?? 0.0).toDouble();
          final totalOnTimeHours = (data['total_on_time_hours'] ?? 0.0).toDouble();

          if (isOn) {
            activeDevices++;
            totalEstimatedPower += estimatedPower;
          }

          // Calculate daily energy consumption (assuming today's usage pattern)
          totalDailyEnergy += (estimatedPower * totalOnTimeHours) / 1000; // Convert to kWh
        }

        // Estimate daily cost (assuming $0.12 per kWh)
        final dailyCost = totalDailyEnergy * 0.12;
        final monthlyCost = dailyCost * 30;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: Color(0xFF1E3A8A),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Energy Insights",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      "Active Devices",
                      "$activeDevices",
                      Icons.devices_other,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      "Current Load",
                      "${totalEstimatedPower.toStringAsFixed(0)} W",
                      Icons.speed,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      "Today's Energy",
                      "${totalDailyEnergy.toStringAsFixed(2)} kWh",
                      Icons.battery_charging_full,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      "Est. Monthly Cost",
                      "\${monthlyCost.toStringAsFixed(2)}",
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading power data..."),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.data_usage_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              "No power data available",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              "Ensure your ESP32 is connected and sending data",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}