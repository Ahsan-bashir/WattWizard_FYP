
// File: models/user_preferences.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  final String userId;
  final double dailyKWhLimit;
  final bool enablePeakHourAlerts;
  final bool enableVoltageAlerts;
  final bool enableCostAlerts;
  final List<String> preferredDeviceOrder;

  UserPreferences({
    required this.userId,
    required this.dailyKWhLimit,
    this.enablePeakHourAlerts = true,
    this.enableVoltageAlerts = true,
    this.enableCostAlerts = true,
    this.preferredDeviceOrder = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'dailyKWhLimit': dailyKWhLimit,
      'enablePeakHourAlerts': enablePeakHourAlerts,
      'enableVoltageAlerts': enableVoltageAlerts,
      'enableCostAlerts': enableCostAlerts,
      'preferredDeviceOrder': preferredDeviceOrder,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      userId: map['userId'] ?? '',
      dailyKWhLimit: (map['dailyKWhLimit'] ?? 5.0).toDouble(),
      enablePeakHourAlerts: map['enablePeakHourAlerts'] ?? true,
      enableVoltageAlerts: map['enableVoltageAlerts'] ?? true,
      enableCostAlerts: map['enableCostAlerts'] ?? true,
      preferredDeviceOrder: List<String>.from(map['preferredDeviceOrder'] ?? []),
    );
  }
}