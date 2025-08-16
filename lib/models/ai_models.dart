// AI Power Monitoring System
// File: models/ai_models.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class PowerConsumptionModel {
  static double predictNextHourConsumption(List<Map<String, dynamic>> historicalData) {
    if (historicalData.isEmpty) return 0.0;

    // Simple moving average with trend analysis
    double totalPower = 0;
    double weightSum = 0;

    for (int i = 0; i < historicalData.length; i++) {
      double weight = (i + 1).toDouble(); // More recent data has higher weight
      totalPower += (historicalData[i]['total_power_watts'] ?? 0.0) * weight;
      weightSum += weight;
    }

    double avgPower = weightSum > 0 ? totalPower / weightSum : 0;

    // Add trend factor
    if (historicalData.length >= 2) {
      double recent = historicalData.last['total_power_watts'] ?? 0.0;
      double previous = historicalData[historicalData.length - 2]['total_power_watts'] ?? 0.0;
      double trend = recent - previous;
      avgPower += trend * 0.3; // 30% trend influence
    }

    return avgPower;
  }

  static bool isPeakHour() {
    int currentHour = DateTime.now().hour;
    return currentHour >= 18 && currentHour < 22; // 6PM to 10PM
  }

  static double calculateDailyCost(double kWhConsumed, double kWhLimit) {
    double baseCostPerKWh = 43.0; // Base cost per kWh in PKR (Pakistani Rupees)
    double totalCost = 0;

    if (kWhConsumed <= kWhLimit) {
      totalCost = kWhConsumed * baseCostPerKWh;
    } else {
      // Normal rate for limit, 2x rate for excess
      totalCost = (kWhLimit * baseCostPerKWh) +
          ((kWhConsumed - kWhLimit) * baseCostPerKWh * 2);
    }

    // Apply peak hour multiplier if current time is peak
    if (isPeakHour()) {
      totalCost *= 1.5;
    }

    return totalCost;
  }
}

class AIAnalysisEngine {
  static List<String> generateSuggestions({
    required double currentPower,
    required double dailyKWh,
    required double kWhLimit,
    required double voltage,
    required List<Map<String, dynamic>> deviceStatus,
    required List<Map<String, dynamic>> historicalData,
  }) {
    List<String> suggestions = [];

    // Voltage Analysis
    if (voltage < 11.5) {
      suggestions.add("⚠️ Low voltage detected (${voltage.toStringAsFixed(1)}V). Consider checking your power supply or reducing load.");
    } else if (voltage < 11.8) {
      suggestions.add("⚡ Voltage slightly low (${voltage.toStringAsFixed(1)}V). Monitor for any power supply issues.");
    }

    // Peak Hours Analysis
    if (PowerConsumptionModel.isPeakHour()) {
      suggestions.add("🕕 Peak hours active! Consider turning off non-essential devices to save 33% on costs.");

      // Suggest specific devices to turn off during peak hours
      List<String> nonEssentialDevices = [];
      for (var device in deviceStatus) {
        if (device['state'] == true &&
            (device['device_name'].toString().contains('LED') ||
                device['device_name'].toString().contains('Socket'))) {
          nonEssentialDevices.add(device['device_name']);
        }
      }

      if (nonEssentialDevices.isNotEmpty) {
        suggestions.add("💡 Consider turning off: ${nonEssentialDevices.join(', ')} during peak hours.");
      }
    }

    // Daily Limit Analysis
    double usagePercentage = (dailyKWh / kWhLimit) * 100;
    if (usagePercentage > 90) {
      suggestions.add("🚨 Critical: You've used ${usagePercentage.toStringAsFixed(1)}% of your daily limit! Turn off devices immediately to avoid 2x cost penalty.");

      // Suggest highest power consuming active devices
      List<Map<String, dynamic>> activeDevices = deviceStatus
          .where((device) => device['state'] == true)
          .toList();
      activeDevices.sort((a, b) => (b['estimated_power'] ?? 0.0)
          .compareTo(a['estimated_power'] ?? 0.0));

      if (activeDevices.isNotEmpty) {
        suggestions.add("🔌 Turn off ${activeDevices.first['device_name']} (${activeDevices.first['estimated_power']}W) to reduce consumption.");
      }
    } else if (usagePercentage > 75) {
      suggestions.add("⚠️ Warning: ${usagePercentage.toStringAsFixed(1)}% of daily limit used. Plan your remaining usage carefully.");
    } else if (usagePercentage > 50) {
      suggestions.add("📊 You've used ${usagePercentage.toStringAsFixed(1)}% of your daily limit. You're on track for normal usage.");
    }

    // Power Efficiency Analysis
    double predictedNextHour = PowerConsumptionModel.predictNextHourConsumption(historicalData);
    if (predictedNextHour > currentPower * 1.5) {
      suggestions.add("📈 Power consumption trending upward. Expected increase of ${(predictedNextHour - currentPower).toStringAsFixed(1)}W in the next hour.");
    }

    // Device-specific suggestions
    for (var device in deviceStatus) {
      if (device['state'] == true) {
        double sessionHours = device['current_session_hours'] ?? 0.0;
        if (sessionHours > 8 && device['device_name'].toString().contains('Fan')) {
          suggestions.add("🌀 ${device['device_name']} has been running for ${sessionHours.toStringAsFixed(1)} hours. Consider giving it a break.");
        }
        if (sessionHours > 12 && device['device_name'].toString().contains('LED')) {
          suggestions.add("💡 ${device['device_name']} has been on for ${sessionHours.toStringAsFixed(1)} hours. Turn off if not needed.");
        }
      }
    }

    // Cost optimization suggestions
    double currentCost = PowerConsumptionModel.calculateDailyCost(dailyKWh, kWhLimit);
    double projectedDailyCost = currentCost * (24.0 / DateTime.now().hour.clamp(1, 24));

    if (projectedDailyCost > kWhLimit * 0.15 * 1.5) {
      suggestions.add("💰 At current usage rate, you may exceed cost-effective consumption. Consider reducing usage during non-peak hours.");
    }

    // Smart scheduling suggestions
    if (!PowerConsumptionModel.isPeakHour() && usagePercentage < 60) {
      suggestions.add("✅ Good time to run high-power devices! Off-peak rates are 33% cheaper than peak hours (6-10 PM).");
    }

    return suggestions.isEmpty
        ? ["✅ All systems operating efficiently! Your power usage is within optimal range."]
        : suggestions;
  }
}