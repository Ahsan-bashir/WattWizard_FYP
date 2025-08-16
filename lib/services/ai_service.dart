// File: services/ai_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ai_models.dart';
import '../models/user_preferences.dart';

class AIService {
  static const String userPreferencesCollection = 'user_preferences';
  static const String powerDataCollection = 'power_data';

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
        .limit(24) // Last 24 hours of data
        .get();

    // Get device status
    final deviceStatusQuery = await FirebaseFirestore.instance
        .collection(powerDataCollection)
        .doc(userId)
        .collection('device_status')
        .get();

    // Calculate daily kWh consumption
    double dailyKWh = 0.0;
    for (var doc in historyQuery.docs) {
      double power = (doc.data()['total_power_watts'] ?? 0.0).toDouble();
      dailyKWh += power / 1000; // Convert W to kW and assume 1-hour intervals
    }

    return {
      'currentData': currentDoc.exists ? currentDoc.data()! : {},
      'historicalData': historyQuery.docs.map((doc) => doc.data()).toList(),
      'deviceStatus': deviceStatusQuery.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
      'dailyKWh': dailyKWh,
    };
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

      // Generate AI suggestions
      List<String> suggestions = AIAnalysisEngine.generateSuggestions(
        currentPower: currentPower,
        dailyKWh: data['dailyKWh'],
        kWhLimit: kWhLimit,
        voltage: voltage,
        deviceStatus: List<Map<String, dynamic>>.from(data['deviceStatus']),
        historicalData: List<Map<String, dynamic>>.from(data['historicalData']),
      );

      return suggestions;
    } catch (e) {
      return ["❌ Error generating suggestions: ${e.toString()}"];
    }
  }
}
