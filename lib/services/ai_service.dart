// // File: services/ai_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// import '../models/ai_models.dart';
// import '../models/user_preferences.dart';
//
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
//     // Get current sensor data
//     final currentDoc = await FirebaseFirestore.instance
//         .collection(powerDataCollection)
//         .doc(userId)
//         .collection('sensor_live')
//         .doc('current')
//         .get();
//
//     // Get today's historical data
//     final DateTime today = DateTime.now();
//     final DateTime startOfDay = DateTime(today.year, today.month, today.day);
//
//     final historyQuery = await FirebaseFirestore.instance
//         .collection(powerDataCollection)
//         .doc(userId)
//         .collection('sensor_history')
//         .where('timestamp', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch ~/ 1000)
//         .orderBy('timestamp', descending: true)
//         .limit(24) // Last 24 hours of data
//         .get();
//
//     // Get device status
//     final deviceStatusQuery = await FirebaseFirestore.instance
//         .collection(powerDataCollection)
//         .doc(userId)
//         .collection('device_status')
//         .get();
//
//     // Calculate daily kWh consumption
//     double dailyKWh = 0.0;
//     for (var doc in historyQuery.docs) {
//       double power = (doc.data()['total_power_watts'] ?? 0.0).toDouble();
//       dailyKWh += power / 1000; // Convert W to kW and assume 1-hour intervals
//     }
//
//     return {
//       'currentData': currentDoc.exists ? currentDoc.data()! : {},
//       'historicalData': historyQuery.docs.map((doc) => doc.data()).toList(),
//       'deviceStatus': deviceStatusQuery.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
//       'dailyKWh': dailyKWh,
//     };
//   }
//
//   static Future<List<String>> generateRealTimeSuggestions(String userId) async {
//     try {
//       // Get user preferences
//       UserPreferences? preferences = await getUserPreferences(userId);
//       double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;
//
//       // Get analysis data
//       Map<String, dynamic> data = await getAIAnalysisData(userId);
//
//       // Extract current data
//       Map<String, dynamic> currentData = data['currentData'];
//       double currentPower = (currentData['total_power_watts'] ?? 0.0).toDouble();
//       double voltage = (currentData['voltage'] ?? 12.0).toDouble();
//
//       // Generate AI suggestions
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
//       return ["❌ Error generating suggestions: ${e.toString()}"];
//     }
//   }
// }
















// File: services/ai_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;

import '../models/ai_models.dart';
import '../models/user_preferences.dart';

class AIService {
  static const String userPreferencesCollection = 'user_preferences';
  static const String powerDataCollection = 'power_data';
  static const String costHistoryCollection = 'cost_history';

  // Real-time cost tracking
  static Timer? _costUpdateTimer;
  static StreamController<Map<String, dynamic>>? _costStreamController;

  static Future<void> saveUserPreferences(UserPreferences preferences) async {
    await FirebaseFirestore.instance
        .collection(userPreferencesCollection)
        .doc(preferences.userId)
        .set(preferences.toMap());
  }

  static Future<UserPreferences?> getUserPreferences(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection(userPreferencesCollection)
        .doc(userId)
        .get();

    if (doc.exists) {
      return UserPreferences.fromMap(doc.data()!);
    }
    return null;
  }

  static Future<Map<String, dynamic>> getAIAnalysisData(String userId) async {
    // Get current sensor data
    final currentDoc = await FirebaseFirestore.instance
        .collection(powerDataCollection)
        .doc(userId)
        .collection('sensor_live')
        .doc('current')
        .get();

    // Get today's historical data
    final DateTime today = DateTime.now();
    final DateTime startOfDay = DateTime(today.year, today.month, today.day);

    final historyQuery = await FirebaseFirestore.instance
        .collection(powerDataCollection)
        .doc(userId)
        .collection('sensor_history')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch ~/ 1000)
        .orderBy('timestamp', descending: true)
        .limit(144) // Every 10 minutes for 24 hours
        .get();

    // Get device status
    final deviceStatusQuery = await FirebaseFirestore.instance
        .collection(powerDataCollection)
        .doc(userId)
        .collection('device_status')
        .get();

    // Calculate daily kWh consumption with proper time intervals
    double dailyKWh = _calculateDailyKWh(historyQuery.docs);

    // Get cost breakdown
    UserPreferences? preferences = await getUserPreferences(userId);
    double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;
    double currentPower = (currentDoc.exists ? currentDoc.data()!['total_power_watts'] ?? 0.0 : 0.0).toDouble();

    Map<String, dynamic> costBreakdown = PowerConsumptionModel.getCostBreakdown(
        dailyKWh, kWhLimit, currentPower
    );

    return {
      'currentData': currentDoc.exists ? currentDoc.data()! : {},
      'historicalData': historyQuery.docs.map((doc) => doc.data()).toList(),
      'deviceStatus': deviceStatusQuery.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
      'dailyKWh': dailyKWh,
      'costBreakdown': costBreakdown,
    };
  }

  // Enhanced method to calculate daily kWh with proper time intervals
  static double _calculateDailyKWh(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0.0;

    double totalKWh = 0.0;

    for (int i = 0; i < docs.length - 1; i++) {
      var currentDoc = docs[i].data() as Map<String, dynamic>;
      var nextDoc = docs[i + 1].data() as Map<String, dynamic>;

      double currentPower = (currentDoc['total_power_watts'] ?? 0.0).toDouble();
      int currentTimestamp = currentDoc['timestamp'] ?? 0;
      int nextTimestamp = nextDoc['timestamp'] ?? 0;

      // Calculate time difference in hours
      double timeDiffHours = (currentTimestamp - nextTimestamp).abs() / 3600.0;

      // Limit time difference to reasonable values (max 1 hour)
      timeDiffHours = math.min(timeDiffHours, 1.0);

      // Calculate kWh for this interval
      totalKWh += (currentPower / 1000.0) * timeDiffHours;
    }

    return totalKWh;
  }

  static Future<List<String>> generateRealTimeSuggestions(String userId) async {
    try {
      // Get user preferences
      UserPreferences? preferences = await getUserPreferences(userId);
      double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;

      // Get analysis data
      Map<String, dynamic> data = await getAIAnalysisData(userId);

      // Extract current data
      Map<String, dynamic> currentData = data['currentData'];
      double currentPower = (currentData['total_power_watts'] ?? 0.0).toDouble();
      double voltage = (currentData['voltage'] ?? 12.0).toDouble();

      // Generate AI suggestions with cost awareness
      List<String> suggestions = AIAnalysisEngine.generateSuggestions(
        currentPower: currentPower,
        dailyKWh: data['dailyKWh'],
        kWhLimit: kWhLimit,
        voltage: voltage,
        deviceStatus: List<Map<String, dynamic>>.from(data['deviceStatus']),
        historicalData: List<Map<String, dynamic>>.from(data['historicalData']),
      );

      // Add cost-specific suggestions
      suggestions.addAll(_generateCostSuggestions(data, kWhLimit));

      return suggestions;
    } catch (e) {
      return ["❌ Error generating suggestions: ${e.toString()}"];
    }
  }

  // New method: Generate cost-specific suggestions
  static List<String> _generateCostSuggestions(Map<String, dynamic> data, double kWhLimit) {
    List<String> costSuggestions = [];
    Map<String, dynamic> costBreakdown = data['costBreakdown'];
    double dailyKWh = data['dailyKWh'];
    double currentPower = (data['currentData']['total_power_watts'] ?? 0.0).toDouble();

    // Check if approaching or exceeding limit
    double usagePercentage = (dailyKWh / kWhLimit) * 100;

    // if (usagePercentage > 95) {
    //   costSuggestions.add("🚨 Critical: You've exceeded your daily limit! Every additional kWh costs 2x rate (PKR ${PowerConsumptionModel.excessCostPerKWh}/kWh)");
    // } else if (usagePercentage > 85) {
    //   costSuggestions.add("⚠️ Warning: Approaching daily limit (${usagePercentage.toStringAsFixed(1)}%). Consider reducing non-essential loads.");
    // }

    // Peak hour suggestions
    if (PowerConsumptionModel.isPeakHour()) {
      double peakSavings = currentPower * 0.15 / 1000 * PowerConsumptionModel.baseCostPerKWh;
      costSuggestions.add("💰 Peak hours active! Reduce load to save PKR ${peakSavings.toStringAsFixed(2)}/hour");
    }

    // High power consumption alert
    if (currentPower > 800) {
      double hourlyCost = PowerConsumptionModel.calculateCurrentHourlyCost(currentPower);
      costSuggestions.add("💡 High power usage detected (${currentPower.toStringAsFixed(0)}W). Current cost: PKR ${hourlyCost.toStringAsFixed(2)}/hour");
    }

    // Excess cost warning
    double excessKWh = costBreakdown['excess_kwh'] ?? 0.0;
    if (excessKWh > 0) {
      double excessCost = costBreakdown['excess_cost'] ?? 0.0;
      costSuggestions.add("📊 Excess usage: ${excessKWh.toStringAsFixed(2)} kWh at 2x rate = PKR ${excessCost.toStringAsFixed(2)} extra cost");
    }

    return costSuggestions;
  }

  // New method: Get comprehensive cost breakdown
  static Future<Map<String, dynamic>> getCostBreakdown(String userId) async {
    try {
      Map<String, dynamic> data = await getAIAnalysisData(userId);
      UserPreferences? preferences = await getUserPreferences(userId);
      double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;
      double currentPower = (data['currentData']['total_power_watts'] ?? 0.0).toDouble();

      return PowerConsumptionModel.getCostBreakdown(
          data['dailyKWh'], kWhLimit, currentPower
      );
    } catch (e) {
      return {
        'error': 'Failed to calculate cost breakdown: ${e.toString()}',
        'total_daily_cost': 0.0,
        'base_cost': 0.0,
        'excess_cost': 0.0,
        'peak_surcharge': 0.0,
      };
    }
  }

  // New method: Generate optimization tips
  static Future<List<String>> generateOptimizationTips(String userId) async {
    try {
      Map<String, dynamic> data = await getAIAnalysisData(userId);
      UserPreferences? preferences = await getUserPreferences(userId);
      double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;
      double currentPower = (data['currentData']['total_power_watts'] ?? 0.0).toDouble();

      return AIAnalysisEngine.generateCostOptimizationTips(
        currentPower: currentPower,
        dailyKWh: data['dailyKWh'],
        kWhLimit: kWhLimit,
        deviceStatus: List<Map<String, dynamic>>.from(data['deviceStatus']),
      );
    } catch (e) {
      return ["❌ Error generating optimization tips: ${e.toString()}"];
    }
  }

  // New method: Get real-time cost updates
  static Stream<Map<String, dynamic>> getRealTimeCostUpdates(String userId) {
    _costStreamController ??= StreamController<Map<String, dynamic>>.broadcast();

    // Cancel existing timer
    _costUpdateTimer?.cancel();

    // Start real-time updates every 30 seconds
    _costUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Map<String, dynamic> data = await getAIAnalysisData(userId);
        double currentPower = (data['currentData']['total_power_watts'] ?? 0.0).toDouble();

        // Calculate real-time costs
        double hourlyCost = PowerConsumptionModel.calculateCurrentHourlyCost(currentPower);
        double realTimeCost = PowerConsumptionModel.calculateRealTimeCost(currentPower);
        double projectedCost = PowerConsumptionModel.calculateProjectedDailyCost(
            data['dailyKWh'],
            (await getUserPreferences(userId))?.dailyKWhLimit ?? 5.0
        );

        Map<String, dynamic> costUpdate = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'current_hourly_cost': hourlyCost,
          'real_time_cost_per_minute': realTimeCost,
          'projected_daily_cost': projectedCost,
          'current_power': currentPower,
          'daily_kwh': data['dailyKWh'],
          'is_peak_hour': PowerConsumptionModel.isPeakHour(),
          'cost_breakdown': data['costBreakdown'],
        };

        _costStreamController!.add(costUpdate);
      } catch (e) {
        _costStreamController!.addError('Error updating real-time costs: ${e.toString()}');
      }
    });

    return _costStreamController!.stream;
  }

  // New method: Save cost history for analytics
  static Future<void> saveCostSnapshot(String userId) async {
    try {
      Map<String, dynamic> data = await getAIAnalysisData(userId);
      double currentPower = (data['currentData']['total_power_watts'] ?? 0.0).toDouble();
      UserPreferences? preferences = await getUserPreferences(userId);
      double kWhLimit = preferences?.dailyKWhLimit ?? 5.0;

      Map<String, dynamic> costSnapshot = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'daily_kwh': data['dailyKWh'],
        'current_power': currentPower,
        'hourly_cost': PowerConsumptionModel.calculateCurrentHourlyCost(currentPower),
        'projected_daily_cost': PowerConsumptionModel.calculateProjectedDailyCost(data['dailyKWh'], kWhLimit),
        'is_peak_hour': PowerConsumptionModel.isPeakHour(),
        'cost_breakdown': data['costBreakdown'],
        'kwh_limit': kWhLimit,
      };

      await FirebaseFirestore.instance
          .collection(costHistoryCollection)
          .doc(userId)
          .collection('daily_snapshots')
          .add(costSnapshot);
    } catch (e) {
      print('Error saving cost snapshot: $e');
    }
  }

  // New method: Get cost trends and analytics
  static Future<Map<String, dynamic>> getCostAnalytics(String userId, {int days = 7}) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startDate = now.subtract(Duration(days: days));

      final costHistoryQuery = await FirebaseFirestore.instance
          .collection(costHistoryCollection)
          .doc(userId)
          .collection('daily_snapshots')
          .where('timestamp', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> costHistory = costHistoryQuery.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // Calculate analytics
      double avgDailyCost = 0.0;
      double maxDailyCost = 0.0;
      double totalKWh = 0.0;
      int peakHourUsageCount = 0;

      for (var snapshot in costHistory) {
        double dailyCost = snapshot['projected_daily_cost'] ?? 0.0;
        avgDailyCost += dailyCost;
        maxDailyCost = math.max(maxDailyCost, dailyCost);
        totalKWh += snapshot['daily_kwh'] ?? 0.0;
        if (snapshot['is_peak_hour'] == true) peakHourUsageCount++;
      }

      if (costHistory.isNotEmpty) {
        avgDailyCost /= costHistory.length;
      }

      return {
        'cost_history': costHistory,
        'average_daily_cost': avgDailyCost,
        'max_daily_cost': maxDailyCost,
        'total_kwh_period': totalKWh,
        'peak_hour_usage_percentage': costHistory.isNotEmpty ? (peakHourUsageCount / costHistory.length) * 100 : 0,
        'cost_trend': _calculateCostTrend(costHistory),
        'savings_opportunities': _identifySavingsOpportunities(costHistory),
      };
    } catch (e) {
      return {
        'error': 'Failed to get cost analytics: ${e.toString()}',
        'cost_history': [],
        'average_daily_cost': 0.0,
      };
    }
  }

  // Helper method: Calculate cost trend
  static String _calculateCostTrend(List<Map<String, dynamic>> costHistory) {
    if (costHistory.length < 2) return 'insufficient_data';

    double recentAvg = 0.0;
    double olderAvg = 0.0;
    int recentCount = math.min(3, costHistory.length ~/ 2);

    // Calculate recent average (last few days)
    for (int i = 0; i < recentCount; i++) {
      recentAvg += costHistory[i]['projected_daily_cost'] ?? 0.0;
    }
    recentAvg /= recentCount;

    // Calculate older average
    for (int i = recentCount; i < costHistory.length; i++) {
      olderAvg += costHistory[i]['projected_daily_cost'] ?? 0.0;
    }
    olderAvg /= (costHistory.length - recentCount);

    double difference = ((recentAvg - olderAvg) / olderAvg) * 100;

    if (difference > 10) return 'increasing';
    if (difference < -10) return 'decreasing';
    return 'stable';
  }

  // Helper method: Identify savings opportunities
  static List<String> _identifySavingsOpportunities(List<Map<String, dynamic>> costHistory) {
    List<String> opportunities = [];

    int highPeakUsage = 0;
    int excessUsageCount = 0;

    for (var snapshot in costHistory) {
      if (snapshot['is_peak_hour'] == true) highPeakUsage++;

      Map<String, dynamic> breakdown = snapshot['cost_breakdown'] ?? {};
      if ((breakdown['excess_kwh'] ?? 0.0) > 0) excessUsageCount++;
    }

    double peakUsagePercentage = costHistory.isNotEmpty ? (highPeakUsage / costHistory.length) * 100 : 0;
    double excessUsagePercentage = costHistory.isNotEmpty ? (excessUsageCount / costHistory.length) * 100 : 0;

    if (peakUsagePercentage > 30) {
      opportunities.add("Reduce peak hour usage (6-10 PM) to save 15% on electricity costs");
    }

    if (excessUsagePercentage > 20) {
      opportunities.add("Consider increasing daily kWh limit or reducing overall consumption to avoid 2x excess charges");
    }

    if (opportunities.isEmpty) {
      opportunities.add("Great job! Your power usage patterns are already cost-optimized");
    }

    return opportunities;
  }

  // Cleanup method
  static void dispose() {
    _costUpdateTimer?.cancel();
    _costStreamController?.close();
    _costUpdateTimer = null;
    _costStreamController = null;
  }
}