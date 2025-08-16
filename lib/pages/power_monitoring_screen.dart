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
            Icons.power,
            color: Colors.yellow,
            size: 32,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "12V DC Power Monitoring",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Low-power device tracking & analytics",
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
        final activeDeviceCount = (data['active_device_count'] ?? 0);
        final activeDevices = data['active_devices'] ?? 'None';

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
                    "12V DC System Status",
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

              // System voltage and current
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "System Voltage",
                      "${voltage.toStringAsFixed(2)} V",
                      Icons.flash_on,
                      voltage >= 11.5 && voltage <= 12.6 ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Total Current",
                      "${(current * 1000).toStringAsFixed(0)} mA",
                      Icons.electrical_services,
                      current > 0 ? Colors.blue : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Power measurements
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Actual Power",
                      "${totalPower.toStringAsFixed(2)} W",
                      Icons.power,
                      totalPower > 0 ? Colors.red : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Estimated Power",
                      "${estimatedPower.toStringAsFixed(1)} W",
                      Icons.trending_up,
                      estimatedPower > 0 ? Colors.purple : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active devices info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeDeviceCount > 0 ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.devices_other,
                              color: activeDeviceCount > 0 ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Active Devices",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          "$activeDeviceCount/4",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: activeDeviceCount > 0 ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (activeDeviceCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        activeDevices,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // System efficiency
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: efficiency > 80 ? Colors.green.withOpacity(0.1) :
                  efficiency > 50 ? Colors.orange.withOpacity(0.1) :
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
                          color: efficiency > 80 ? Colors.green :
                          efficiency > 50 ? Colors.orange : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "System Efficiency",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      estimatedPower > 0 ? "${efficiency.toStringAsFixed(1)}%" : "N/A",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: efficiency > 80 ? Colors.green :
                        efficiency > 50 ? Colors.orange : Colors.red,
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
            textAlign: TextAlign.center,
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
                    "DC Device Status",
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
                  childAspectRatio: 1.1,
                ),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final data = device.data() as Map<String, dynamic>;

                  final deviceName = data['device_name'] ?? 'Unknown Device';
                  final isOn = data['state'] ?? false;
                  final estimatedPower = (data['estimated_power'] ?? 0.0).toDouble();
                  final operatingVoltage = (data['operating_voltage'] ?? 12.0).toDouble();
                  final totalOnTimeHours = (data['total_on_time_hours'] ?? 0.0).toDouble();
                  final currentSessionHours = (data['current_session_duration_hours'] ?? 0.0).toDouble();

                  IconData deviceIcon;
                  Color deviceColor;
                  String deviceType;

                  switch (device.id) {
                    case 'fan_01':
                      deviceIcon = Icons.air;
                      deviceColor = Colors.cyan;
                      deviceType = "DC Fan";
                      break;
                    case 'light_01':
                      deviceIcon = Icons.lightbulb;
                      deviceColor = Colors.red;
                      deviceType = "Red LED";
                      break;
                    case 'light_02':
                      deviceIcon = Icons.lightbulb;
                      deviceColor = Colors.green;
                      deviceType = "Green LED";
                      break;
                    case 'socket_01':
                      deviceIcon = Icons.power_settings_new;
                      deviceColor = Colors.purple;
                      deviceType = "12V Socket";
                      break;
                    default:
                      deviceIcon = Icons.device_unknown;
                      deviceColor = Colors.grey;
                      deviceType = "Unknown";
                  }

                  return _buildDeviceCard(
                    deviceName,
                    deviceType,
                    isOn,
                    estimatedPower,
                    operatingVoltage,
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
      String type,
      bool isOn,
      double estimatedPower,
      double operatingVoltage,
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
          Text(
            type,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${estimatedPower.toStringAsFixed(1)}W @ ${operatingVoltage.toStringAsFixed(0)}V",
            style: TextStyle(
              fontSize: 11,
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
    if (hours < 1/60) {
      return "${(hours * 3600).toStringAsFixed(0)}s";
    } else if (hours < 1) {
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
        final chartDataPower = <FlSpot>[];
        final chartDataVoltage = <FlSpot>[];

        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          final power = (data['total_power_watts'] ?? 0.0).toDouble();
          final voltage = (data['voltage'] ?? 0.0).toDouble();
          chartDataPower.add(FlSpot(i.toDouble(), power));
          chartDataVoltage.add(FlSpot(i.toDouble(), voltage));
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
                    "DC System Trends (Last 20 readings)",
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
                      horizontalInterval: chartDataPower.isNotEmpty ?
                      (chartDataPower.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 5) : 2,
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
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value < 1) {
                              return Text(
                                '${(value * 1000).toInt()}mW',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              );
                            } else {
                              return Text(
                                '${value.toStringAsFixed(1)}W',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
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
        double totalDailyEnergy = 0; // Wh (not kWh for low power)
        int activeDevices = 0;
        String mostUsedDevice = "None";
        double maxUsageHours = 0;

        for (final device in devices) {
          final data = device.data() as Map<String, dynamic>;
          final isOn = data['state'] ?? false;
          final estimatedPower = (data['estimated_power'] ?? 0.0).toDouble();
          final totalOnTimeHours = (data['total_on_time_hours'] ?? 0.0).toDouble();
          final deviceName = data['device_name'] ?? 'Unknown';

          if (isOn) {
            activeDevices++;
            totalEstimatedPower += estimatedPower;
          }

          // Calculate daily energy consumption (assuming current usage pattern)
          totalDailyEnergy += (estimatedPower * totalOnTimeHours); // Wh

          // Find most used device
          if (totalOnTimeHours > maxUsageHours) {
            maxUsageHours = totalOnTimeHours;
            mostUsedDevice = deviceName;
          }
        }

        // Estimate daily cost for low-power system (assuming $0.12 per kWh)
        final dailyCostCents = (totalDailyEnergy / 1000) * 0.12 * 100; // Convert to cents
        final monthlyCostDollars = dailyCostCents * 30 / 100; // Convert to dollars

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
                    "DC System Insights",
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
                      "$activeDevices/4",
                      Icons.devices_other,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      "Current Load",
                      "${totalEstimatedPower.toStringAsFixed(1)} W",
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
                      totalDailyEnergy < 1000 ?
                      "${totalDailyEnergy.toStringAsFixed(0)} Wh" :
                      "${(totalDailyEnergy/1000).toStringAsFixed(2)} kWh",
                      Icons.battery_charging_full,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      "Est. Monthly Cost",
                      monthlyCostDollars < 1 ?
                      "${dailyCostCents.toStringAsFixed(1)}¢/day" :
                      "\${monthlyCostDollars.toStringAsFixed(2)}",
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              if (mostUsedDevice != "None") ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Most used device: $mostUsedDevice (${_formatHours(maxUsageHours)})",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            Text("Loading DC system data..."),
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
              "No DC system data available",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              "Ensure your ESP32 is connected and devices are configured",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}