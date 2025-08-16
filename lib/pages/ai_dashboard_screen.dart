// Fixed AI Dashboard Screen
// File: ai_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

import '../models/ai_models.dart';
import '../models/user_preferences.dart';
import '../services/ai_service.dart';

// // PowerConsumptionModel class
// class PowerConsumptionModel {
//   static double predictNextHourConsumption(List<Map<String, dynamic>> historicalData) {
//     if (historicalData.isEmpty) return 0.0;
//
//     double totalPower = 0;
//     double weightSum = 0;
//
//     for (int i = 0; i < historicalData.length; i++) {
//       double weight = (i + 1).toDouble();
//       totalPower += (historicalData[i]['total_power_watts'] ?? 0.0) * weight;
//       weightSum += weight;
//     }
//
//     double avgPower = weightSum > 0 ? totalPower / weightSum : 0;
//
//     if (historicalData.length >= 2) {
//       double recent = historicalData.last['total_power_watts'] ?? 0.0;
//       double previous = historicalData[historicalData.length - 2]['total_power_watts'] ?? 0.0;
//       double trend = recent - previous;
//       avgPower += trend * 0.3;
//     }
//
//     return avgPower;
//   }
//
//   static bool isPeakHour() {
//     int currentHour = DateTime.now().hour;
//     return currentHour >= 18 && currentHour < 22;
//   }
//
//   static double calculateDailyCost(double kWhConsumed, double kWhLimit) {
//     double baseCostPerKWh = 0.15;
//     double totalCost = 0;
//
//     if (kWhConsumed <= kWhLimit) {
//       totalCost = kWhConsumed * baseCostPerKWh;
//     } else {
//       totalCost = (kWhLimit * baseCostPerKWh) +
//           ((kWhConsumed - kWhLimit) * baseCostPerKWh * 2);
//     }
//
//     if (isPeakHour()) {
//       totalCost *= 1.5;
//     }
//
//     return totalCost;
//   }
// }
//
// // AIAnalysisEngine class
// class AIAnalysisEngine {
//   static List<String> generateSuggestions({
//     required double currentPower,
//     required double dailyKWh,
//     required double kWhLimit,
//     required double voltage,
//     required List<Map<String, dynamic>> deviceStatus,
//     required List<Map<String, dynamic>> historicalData,
//   }) {
//     List<String> suggestions = [];
//
//     // Voltage Analysis
//     if (voltage < 11.5) {
//       suggestions.add("⚠️ Low voltage detected (${voltage.toStringAsFixed(1)}V). Consider checking your power supply or reducing load.");
//     } else if (voltage < 11.8) {
//       suggestions.add("⚡ Voltage slightly low (${voltage.toStringAsFixed(1)}V). Monitor for any power supply issues.");
//     }
//
//     // Peak Hours Analysis
//     if (PowerConsumptionModel.isPeakHour()) {
//       suggestions.add("🕕 Peak hours active! Consider turning off non-essential devices to save 33% on costs.");
//
//       List<String> nonEssentialDevices = [];
//       for (var device in deviceStatus) {
//         if (device['state'] == true &&
//             (device['device_name'].toString().contains('LED') ||
//                 device['device_name'].toString().contains('Socket'))) {
//           nonEssentialDevices.add(device['device_name']);
//         }
//       }
//
//       if (nonEssentialDevices.isNotEmpty) {
//         suggestions.add("💡 Consider turning off: ${nonEssentialDevices.join(', ')} during peak hours.");
//       }
//     }
//
//     // Daily Limit Analysis
//     double usagePercentage = (dailyKWh / kWhLimit) * 100;
//     if (usagePercentage > 90) {
//       suggestions.add("🚨 Critical: You've used ${usagePercentage.toStringAsFixed(1)}% of your daily limit! Turn off devices immediately to avoid 2x cost penalty.");
//
//       List<Map<String, dynamic>> activeDevices = deviceStatus
//           .where((device) => device['state'] == true)
//           .toList();
//       activeDevices.sort((a, b) => (b['estimated_power'] ?? 0.0)
//           .compareTo(a['estimated_power'] ?? 0.0));
//
//       if (activeDevices.isNotEmpty) {
//         suggestions.add("🔌 Turn off ${activeDevices.first['device_name']} (${activeDevices.first['estimated_power']}W) to reduce consumption.");
//       }
//     } else if (usagePercentage > 75) {
//       suggestions.add("⚠️ Warning: ${usagePercentage.toStringAsFixed(1)}% of daily limit used. Plan your remaining usage carefully.");
//     } else if (usagePercentage > 50) {
//       suggestions.add("📊 You've used ${usagePercentage.toStringAsFixed(1)}% of your daily limit. You're on track for normal usage.");
//     }
//
//     // Power Efficiency Analysis
//     double predictedNextHour = PowerConsumptionModel.predictNextHourConsumption(historicalData);
//     if (predictedNextHour > currentPower * 1.5) {
//       suggestions.add("📈 Power consumption trending upward. Expected increase of ${(predictedNextHour - currentPower).toStringAsFixed(1)}W in the next hour.");
//     }
//
//     // Device-specific suggestions
//     for (var device in deviceStatus) {
//       if (device['state'] == true) {
//         double sessionHours = device['current_session_hours'] ?? 0.0;
//         if (sessionHours > 8 && device['device_name'].toString().contains('Fan')) {
//           suggestions.add("🌀 ${device['device_name']} has been running for ${sessionHours.toStringAsFixed(1)} hours. Consider giving it a break.");
//         }
//         if (sessionHours > 12 && device['device_name'].toString().contains('LED')) {
//           suggestions.add("💡 ${device['device_name']} has been on for ${sessionHours.toStringAsFixed(1)} hours. Turn off if not needed.");
//         }
//       }
//     }
//
//     // Cost optimization suggestions
//     double currentCost = PowerConsumptionModel.calculateDailyCost(dailyKWh, kWhLimit);
//     double projectedDailyCost = currentCost * (24.0 / DateTime.now().hour.clamp(1, 24));
//
//     if (projectedDailyCost > kWhLimit * 0.15 * 1.5) {
//       suggestions.add("💰 At current usage rate, you may exceed cost-effective consumption. Consider reducing usage during non-peak hours.");
//     }
//
//     // Smart scheduling suggestions
//     if (!PowerConsumptionModel.isPeakHour() && usagePercentage < 60) {
//       suggestions.add("✅ Good time to run high-power devices! Off-peak rates are 33% cheaper than peak hours (6-10 PM).");
//     }
//
//     return suggestions.isEmpty
//         ? ["✅ All systems operating efficiently! Your power usage is within optimal range."]
//         : suggestions;
//   }
// }
//
// // UserPreferences class
// class UserPreferences {
//   final String userId;
//   final double dailyKWhLimit;
//   final bool enablePeakHourAlerts;
//   final bool enableVoltageAlerts;
//   final bool enableCostAlerts;
//   final List<String> preferredDeviceOrder;
//
//   UserPreferences({
//     required this.userId,
//     required this.dailyKWhLimit,
//     this.enablePeakHourAlerts = true,
//     this.enableVoltageAlerts = true,
//     this.enableCostAlerts = true,
//     this.preferredDeviceOrder = const [],
//   });
//
//   Map<String, dynamic> toMap() {
//     return {
//       'userId': userId,
//       'dailyKWhLimit': dailyKWhLimit,
//       'enablePeakHourAlerts': enablePeakHourAlerts,
//       'enableVoltageAlerts': enableVoltageAlerts,
//       'enableCostAlerts': enableCostAlerts,
//       'preferredDeviceOrder': preferredDeviceOrder,
//       'lastUpdated': FieldValue.serverTimestamp(),
//     };
//   }
//
//   factory UserPreferences.fromMap(Map<String, dynamic> map) {
//     return UserPreferences(
//       userId: map['userId'] ?? '',
//       dailyKWhLimit: (map['dailyKWhLimit'] ?? 5.0).toDouble(),
//       enablePeakHourAlerts: map['enablePeakHourAlerts'] ?? true,
//       enableVoltageAlerts: map['enableVoltageAlerts'] ?? true,
//       enableCostAlerts: map['enableCostAlerts'] ?? true,
//       preferredDeviceOrder: List<String>.from(map['preferredDeviceOrder'] ?? []),
//     );
//   }
// }
//
// // AIService class
// class AIService {
//   static const String userPreferencesCollection = 'user_preferences';
//   static const String powerDataCollection = 'power_data';
//
//   static Future<void> saveUserPreferences(UserPreferences preferences) async {
//     await FirebaseFirestore.instance
//         .collection(userPreferencesCollection)
//         .doc(preferences.userId)
//         .set(preferences.toMap());
//   }
//
//   static Future<UserPreferences?> getUserPreferences(String userId) async {
//     final doc = await FirebaseFirestore.instance
//         .collection(userPreferencesCollection)
//         .doc(userId)
//         .get();
//
//     if (doc.exists) {
//       return UserPreferences.fromMap(doc.data()!);
//     }
//     return null;
//   }
//
//   static Future<Map<String, dynamic>> getAIAnalysisData(String userId) async {
//     try {
//       // Get current sensor data
//       final currentDoc = await FirebaseFirestore.instance
//           .collection(powerDataCollection)
//           .doc(userId)
//           .collection('sensor_live')
//           .doc('current')
//           .get();
//
//       // Get today's historical data
//       final DateTime today = DateTime.now();
//       final DateTime startOfDay = DateTime(today.year, today.month, today.day);
//
//       final historyQuery = await FirebaseFirestore.instance
//           .collection(powerDataCollection)
//           .doc(userId)
//           .collection('sensor_history')
//           .where('timestamp', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch ~/ 1000)
//           .orderBy('timestamp', descending: true)
//           .limit(24)
//           .get();
//
//       // Get device status
//       final deviceStatusQuery = await FirebaseFirestore.instance
//           .collection(powerDataCollection)
//           .doc(userId)
//           .collection('device_status')
//           .get();
//
//       // Calculate daily kWh consumption
//       double dailyKWh = 0.0;
//       for (var doc in historyQuery.docs) {
//         double power = (doc.data()['total_power_watts'] ?? 0.0).toDouble();
//         dailyKWh += power / 1000;
//       }
//
//       return {
//         'currentData': currentDoc.exists ? currentDoc.data()! : {},
//         'historicalData': historyQuery.docs.map((doc) => doc.data()).toList(),
//         'deviceStatus': deviceStatusQuery.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
//         'dailyKWh': dailyKWh,
//       };
//     } catch (e) {
//       print('Error getting AI analysis data: $e');
//       return {
//         'currentData': {},
//         'historicalData': <Map<String, dynamic>>[],
//         'deviceStatus': <Map<String, dynamic>>[],
//         'dailyKWh': 0.0,
//       };
//     }
//   }
//
//   static Future<List<String>> generateRealTimeSuggestions(String userId) async {
//     try {
//       UserPreferences? preferences = await getUserPreferences(userId);
//       double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;
//
//       Map<String, dynamic> data = await getAIAnalysisData(userId);
//
//       Map<String, dynamic> currentData = data['currentData'];
//       double currentPower = (currentData['total_power_watts'] ?? 0.0).toDouble();
//       double voltage = (currentData['voltage'] ?? 12.0).toDouble();
//
//       List<String> suggestions = AIAnalysisEngine.generateSuggestions(
//         currentPower: currentPower,
//         dailyKWh: data['dailyKWh'],
//         kWhLimit: kWhLimit,
//         voltage: voltage,
//         deviceStatus: List<Map<String, dynamic>>.from(data['deviceStatus']),
//         historicalData: List<Map<String, dynamic>>.from(data['historicalData']),
//       );
//
//       return suggestions;
//     } catch (e) {
//       print('Error generating suggestions: $e');
//       return ["❌ Error generating suggestions: ${e.toString()}"];
//     }
//   }
// }

// AIDashboardScreen Widget
class AIDashboardScreen extends StatefulWidget {
  final String userId;

  const AIDashboardScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<AIDashboardScreen> createState() => _AIDashboardScreenState();
}

class _AIDashboardScreenState extends State<AIDashboardScreen> {
  Timer? _suggestionTimer;
  List<String> _suggestions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentData;
  double _dailyKWhLimit = 5.0;
  double _dailyUsage = 0.0;
  double _currentCost = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startRealTimeSuggestions();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      UserPreferences? prefs = await AIService.getUserPreferences(widget.userId);
      if (prefs != null) {
        setState(() {
          _dailyKWhLimit = prefs.dailyKWhLimit;
        });
      }

      await _updateSuggestions();
    } catch (e) {
      print('Error initializing data: $e');
    }
  }

  void _startRealTimeSuggestions() {
    _suggestionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateSuggestions();
    });
  }

  Future<void> _updateSuggestions() async {
    try {
      List<String> newSuggestions = await AIService.generateRealTimeSuggestions(widget.userId);
      Map<String, dynamic> analysisData = await AIService.getAIAnalysisData(widget.userId);

      double dailyKWh = analysisData['dailyKWh'] ?? 0.0;
      double cost = PowerConsumptionModel.calculateDailyCost(dailyKWh, _dailyKWhLimit);

      setState(() {
        _suggestions = newSuggestions;
        _currentData = analysisData['currentData'];
        _dailyUsage = dailyKWh;
        _currentCost = cost;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _suggestions = ["❌ Error loading suggestions"];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "AI Power Assistant",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E425E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _updateSuggestions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCards(),
              const SizedBox(height: 20),
              _buildSuggestionsSection(),
              const SizedBox(height: 20),
              _buildPowerAnalytics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    bool isPeakHour = PowerConsumptionModel.isPeakHour();
    double usagePercentage = (_dailyUsage / _dailyKWhLimit) * 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                "Daily Usage",
                "${_dailyUsage.toStringAsFixed(2)} kWh",
                "${usagePercentage.toStringAsFixed(1)}% of limit",
                usagePercentage > 90 ? Colors.red :
                usagePercentage > 75 ? Colors.orange : Colors.green,
                Icons.bolt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatusCard(
                "Current Cost",
                "\$${_currentCost.toStringAsFixed(2)}",
                isPeakHour ? "Peak Hours (1.5x)" : "Off-Peak",
                isPeakHour ? Colors.orange : Colors.blue,
                Icons.attach_money,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                "Voltage",
                "${(_currentData?['voltage'] ?? 12.0).toStringAsFixed(1)}V",
                _getVoltageStatus(_currentData?['voltage'] ?? 12.0),
                _getVoltageColor(_currentData?['voltage'] ?? 12.0),
                Icons.electrical_services,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatusCard(
                "Power",
                "${(_currentData?['total_power_watts'] ?? 0.0).toStringAsFixed(1)}W",
                "${_currentData?['active_device_count'] ?? 0} devices active",
                Colors.purple,
                Icons.power,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E425E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  "AI Suggestions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: _getSuggestionColor(_suggestions[index]),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    _suggestions[index],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerAnalytics() {
    double projectedDailyCost = _currentCost * (24.0 / DateTime.now().hour.clamp(1, 24));
    double savingsIfOptimal = projectedDailyCost - (_dailyKWhLimit * 0.15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daily Analytics",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E425E),
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalyticsRow("Projected Daily Cost", "\$${projectedDailyCost.toStringAsFixed(2)}"),
          _buildAnalyticsRow("Daily Limit", "${_dailyKWhLimit.toStringAsFixed(1)} kWh"),
          _buildAnalyticsRow("Potential Savings", savingsIfOptimal > 0 ? "\$${savingsIfOptimal.toStringAsFixed(2)}" : "On Track"),
          _buildAnalyticsRow("Peak Hour Status", PowerConsumptionModel.isPeakHour() ? "Active (6-10 PM)" : "Inactive"),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E425E),
            ),
          ),
        ],
      ),
    );
  }

  String _getVoltageStatus(double voltage) {
    if (voltage < 11.5) return "Critical Low";
    if (voltage < 11.8) return "Low";
    if (voltage > 12.5) return "High";
    return "Normal";
  }

  Color _getVoltageColor(double voltage) {
    if (voltage < 11.5) return Colors.red;
    if (voltage < 11.8) return Colors.orange;
    if (voltage > 12.5) return Colors.blue;
    return Colors.green;
  }

  Color _getSuggestionColor(String suggestion) {
    if (suggestion.contains("🚨") || suggestion.contains("Critical")) return Colors.red;
    if (suggestion.contains("⚠️") || suggestion.contains("Warning")) return Colors.orange;
    if (suggestion.contains("✅") || suggestion.contains("Good")) return Colors.green;
    if (suggestion.contains("💰") || suggestion.contains("Cost")) return Colors.blue;
    return Colors.grey;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        double tempLimit = _dailyKWhLimit;

        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("AI Settings"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Daily kWh Limit: ${tempLimit.toStringAsFixed(1)}"),
                    Slider(
                      value: tempLimit,
                      min: 1.0,
                      max: 20.0,
                      divisions: 38,
                      label: "${tempLimit.toStringAsFixed(1)} kWh",
                      onChanged: (value) {
                        setDialogState(() {
                          tempLimit = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      UserPreferences prefs = UserPreferences(
                        userId: widget.userId,
                        dailyKWhLimit: tempLimit,
                      );
                      await AIService.saveUserPreferences(prefs);

                      setState(() {
                        _dailyKWhLimit = tempLimit;
                      });

                      Navigator.of(context).pop();
                      _updateSuggestions();
                    },
                    child: const Text("Save"),
                  ),
                ],
              );
            }
        );
      },
    );
  }
}