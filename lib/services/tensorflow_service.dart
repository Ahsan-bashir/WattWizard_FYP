
// File: services/tensorflow_service.dart
import 'dart:typed_data';
import 'dart:math' as math;

import '../models/ai_models.dart';

class TensorFlowService {
  // Simulated TensorFlow Lite model for power prediction
  // In a real implementation, you would load an actual TFLite model
  static Float32List _modelWeights = Float32List.fromList([
    0.8, 0.15, 0.05, // Power trend weights
    0.6, 0.25, 0.15, // Time-based weights
    0.7, 0.2, 0.1,   // Device-based weights
  ]);

  static double predictPowerConsumption({
    required List<Map<String, dynamic>> historicalData,
    required int hoursAhead,
    required List<Map<String, dynamic>> deviceStatus,
  }) {
    if (historicalData.isEmpty) return 0.0;

    // Feature extraction
    List<double> features = _extractFeatures(historicalData, deviceStatus);

    // Simple neural network simulation
    double prediction = _runInference(features);

    // Apply time-based adjustments
    prediction *= _getTimeMultiplier(hoursAhead);

    return math.max(0.0, prediction);
  }

  static List<double> _extractFeatures(
      List<Map<String, dynamic>> historicalData,
      List<Map<String, dynamic>> deviceStatus,
      ) {
    List<double> features = [];

    // Recent power trend (last 3 readings)
    for (int i = 0; i < 3 && i < historicalData.length; i++) {
      features.add((historicalData[i]['total_power_watts'] ?? 0.0).toDouble());
    }
    while (features.length < 3) features.add(0.0);

    // Time-based features
    DateTime now = DateTime.now();
    features.add(now.hour.toDouble() / 24.0); // Hour of day normalized
    features.add(now.weekday.toDouble() / 7.0); // Day of week normalized
    features.add(PowerConsumptionModel.isPeakHour() ? 1.0 : 0.0); // Peak hour flag

    // Device-based features
    int activeDevices = deviceStatus.where((d) => d['state'] == true).length;
    double totalDevicePower = deviceStatus
        .where((d) => d['state'] == true)
        .fold(0.0, (sum, d) => sum + ((d['estimated_power'] ?? 0.0).toDouble()));

    features.add(activeDevices.toDouble());
    features.add(totalDevicePower);
    features.add(deviceStatus.length.toDouble());

    return features;
  }

  static double _runInference(List<double> features) {
    if (features.length != _modelWeights.length) return 0.0;

    double output = 0.0;
    for (int i = 0; i < features.length; i++) {
      output += features[i] * _modelWeights[i];
    }

    // Apply sigmoid activation
    return 1.0 / (1.0 + math.exp(-output)) * 50.0; // Scale to reasonable watt range
  }

  static double _getTimeMultiplier(int hoursAhead) {
    // Adjust prediction based on typical usage patterns
    DateTime futureTime = DateTime.now().add(Duration(hours: hoursAhead));
    int futureHour = futureTime.hour;

    // Typical 12V DC usage patterns (adjust based on your use case)
    Map<int, double> hourlyMultipliers = {
      0: 0.3,  1: 0.2,  2: 0.2,  3: 0.2,  4: 0.3,  5: 0.5,
      6: 0.7,  7: 0.8,  8: 0.9,  9: 0.8,  10: 0.7, 11: 0.8,
      12: 0.9, 13: 0.8, 14: 0.7, 15: 0.8, 16: 0.9, 17: 1.0,
      18: 1.2, 19: 1.3, 20: 1.2, 21: 1.0, 22: 0.8, 23: 0.5,
    };

    return hourlyMultipliers[futureHour] ?? 1.0;
  }

  static Map<String, dynamic> analyzeEnergyPatterns(
      List<Map<String, dynamic>> historicalData,
      ) {
    if (historicalData.isEmpty) {
      return {
        'peakHour': 18,
        'minHour': 3,
        'averagePower': 0.0,
        'powerVariance': 0.0,
        'efficiency': 0.0,
      };
    }

    // Group data by hour
    Map<int, List<double>> hourlyData = {};
    for (var data in historicalData) {
      int hour = DateTime.fromMillisecondsSinceEpoch(
          (data['timestamp'] ?? 0) * 1000
      ).hour;
      double power = (data['total_power_watts'] ?? 0.0).toDouble();

      if (!hourlyData.containsKey(hour)) {
        hourlyData[hour] = [];
      }
      hourlyData[hour]!.add(power);
    }

    // Calculate hourly averages
    Map<int, double> hourlyAverages = {};
    hourlyData.forEach((hour, powers) {
      hourlyAverages[hour] = powers.reduce((a, b) => a + b) / powers.length;
    });

    // Find peak and minimum hours
    int peakHour = 18; // default
    int minHour = 3;   // default
    double maxPower = 0;
    double minPower = double.infinity;

    hourlyAverages.forEach((hour, avgPower) {
      if (avgPower > maxPower) {
        maxPower = avgPower;
        peakHour = hour;
      }
      if (avgPower < minPower) {
        minPower = avgPower;
        minHour = hour;
      }
    });

    // Calculate overall statistics
    List allPowers = historicalData
        .map((d) => (d['total_power_watts'] ?? 0.0).toDouble())
        .toList();

    double averagePower = allPowers.isEmpty ? 0.0 :
    allPowers.reduce((a, b) => a + b) / allPowers.length;

    double variance = 0.0;
    if (allPowers.length > 1) {
      variance = allPowers
          .map((p) => math.pow(p - averagePower, 2))
          .reduce((a, b) => a + b) / allPowers.length;
    }

    double efficiency = averagePower > 0 ?
    (minPower / averagePower) * 100 : 0.0;

    return {
      'peakHour': peakHour,
      'minHour': minHour,
      'averagePower': averagePower,
      'powerVariance': variance,
      'efficiency': efficiency,
      'hourlyPattern': hourlyAverages,
    };
  }
}
