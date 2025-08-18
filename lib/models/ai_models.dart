// AI Power Monitoring System
// File: models/ai_models.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class PowerConsumptionModel {
  static const double baseCostPerKWh = 43.0; // Base cost per kWh in PKR
  static const double peakHourMultiplier = 1.5; // 50% surcharge during peak hours
  static const double excessRateMultiplier = 2.0; // 2x rate for excess consumption

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

  // Calculate cost for total daily consumption
  static double calculateDailyCost(double kWhConsumed, double kWhLimit) {
    double totalCost = 0;

    if (kWhConsumed <= kWhLimit) {
      totalCost = kWhConsumed * baseCostPerKWh;
    } else {
      // Normal rate for limit, 2x rate for excess
      totalCost = (kWhLimit * baseCostPerKWh) +
          ((kWhConsumed - kWhLimit) * baseCostPerKWh * excessRateMultiplier);
    }

    // Apply peak hour multiplier if current time is peak
    if (isPeakHour()) {
      totalCost *= peakHourMultiplier;
    }

    return totalCost;
  }

  // Calculate current hourly cost based on current power consumption
  static double calculateCurrentHourlyCost(double currentWatts) {
    double kWhPerHour = currentWatts / 1000.0;
    double hourlyCost = kWhPerHour * baseCostPerKWh;

    // Apply peak hour multiplier if current time is peak
    if (isPeakHour()) {
      hourlyCost *= peakHourMultiplier;
    }

    return hourlyCost;
  }

  // Calculate real-time cost per minute
  static double calculateRealTimeCost(double currentWatts) {
    double hourlyRate = calculateCurrentHourlyCost(currentWatts);
    return hourlyRate / 60.0; // Cost per minute
  }

  // Calculate projected daily cost based on current consumption pattern
  static double calculateProjectedDailyCost(double currentKWh, double kWhLimit) {
    int currentHour = DateTime.now().hour;
    if (currentHour == 0) currentHour = 1; // Avoid division by zero

    double projectedTotalKWh = (currentKWh / currentHour) * 24;
    return calculateDailyCost(projectedTotalKWh, kWhLimit);
  }

  // Calculate accumulated cost so far today
  static double calculateAccumulatedCost(double kWhConsumedToday, double kWhLimit) {
    return calculateDailyCost(kWhConsumedToday, kWhLimit);
  }

  // Calculate potential savings by turning off specific devices
  static double calculateSavings(List<Map<String, dynamic>> devicesToTurnOff) {
    double totalWatts = 0;
    for (var device in devicesToTurnOff) {
      totalWatts += device['estimated_power'] ?? 0.0;
    }

    return calculateCurrentHourlyCost(totalWatts);
  }

  // Get cost breakdown information
  static Map<String, dynamic> getCostBreakdown(double kWhConsumed, double kWhLimit, double currentWatts) {
    double baseCost = min(kWhConsumed, kWhLimit) * baseCostPerKWh;
    double excessCost = kWhConsumed > kWhLimit
        ? (kWhConsumed - kWhLimit) * baseCostPerKWh * excessRateMultiplier
        : 0.0;

    double totalDailyCost = baseCost + excessCost;
    double peakSurcharge = isPeakHour() ? totalDailyCost * (peakHourMultiplier - 1) : 0.0;

    return {
      'base_cost': baseCost,
      'excess_cost': excessCost,
      'peak_surcharge': peakSurcharge,
      'total_daily_cost': totalDailyCost + peakSurcharge,
      'current_hourly_rate': calculateCurrentHourlyCost(currentWatts),
      'is_peak_hour': isPeakHour(),
      'excess_kwh': max(0.0, kWhConsumed - kWhLimit),
      'remaining_kwh_limit': max(0.0, kWhLimit - kWhConsumed),
    };
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

    // Get comprehensive cost information
    Map<String, dynamic> costBreakdown = PowerConsumptionModel.getCostBreakdown(
        dailyKWh, kWhLimit, currentPower
    );

    // Voltage Analysis
    if (voltage < 11.5) {
      suggestions.add("⚠️ Low voltage detected (${voltage.toStringAsFixed(1)}V). Consider checking your power supply or reducing load.");
    } else if (voltage < 11.8) {
      suggestions.add("⚡ Voltage slightly low (${voltage.toStringAsFixed(1)}V). Monitor for any power supply issues.");
    }

    // Peak Hours Analysis with detailed cost impact
    if (PowerConsumptionModel.isPeakHour()) {
      double hourlyRate = costBreakdown['current_hourly_rate'];
      double offPeakRate = hourlyRate / PowerConsumptionModel.peakHourMultiplier;
      double potentialSavings = hourlyRate - offPeakRate;

      suggestions.add("🕕 Peak hours active! Current rate: ${hourlyRate.toStringAsFixed(2)} PKR/hour vs ${offPeakRate.toStringAsFixed(2)} PKR/hour off-peak.");

      if (potentialSavings > 10) {
        suggestions.add("💰 You could save ${potentialSavings.toStringAsFixed(2)} PKR/hour by waiting until 10 PM for non-essential usage.");
      }

      // Suggest specific devices to turn off during peak hours
      List<Map<String, dynamic>> nonEssentialDevices = deviceStatus
          .where((device) =>
      device['state'] == true &&
          (device['device_name'].toString().contains('LED') ||
              device['device_name'].toString().contains('Socket')))
          .toList();

      if (nonEssentialDevices.isNotEmpty) {
        double savings = PowerConsumptionModel.calculateSavings(nonEssentialDevices);
        suggestions.add("💡 Turn off ${nonEssentialDevices.map((d) => d['device_name']).join(', ')} to save ${savings.toStringAsFixed(2)} PKR/hour during peak.");
      }
    }

    // Daily Limit Analysis with cost implications
    double usagePercentage = (dailyKWh / kWhLimit) * 100;
    double remainingKWh = costBreakdown['remaining_kwh_limit'];

    if (usagePercentage > 90) {
      double excessCost = costBreakdown['excess_cost'];
      suggestions.add("🚨 Critical: ${usagePercentage.toStringAsFixed(1)}% of daily limit used! Only ${remainingKWh.toStringAsFixed(2)} kWh remaining.");

      if (excessCost > 0) {
        suggestions.add("💸 You're already paying excess charges: ${excessCost.toStringAsFixed(2)} PKR extra today.");
      }

      // Suggest highest power consuming active devices
      List<Map<String, dynamic>> activeDevices = deviceStatus
          .where((device) => device['state'] == true)
          .toList();
      activeDevices.sort((a, b) => (b['estimated_power'] ?? 0.0)
          .compareTo(a['estimated_power'] ?? 0.0));

      if (activeDevices.isNotEmpty) {
        double deviceSavings = PowerConsumptionModel.calculateSavings([activeDevices.first]);
        suggestions.add("🔌 Turn off ${activeDevices.first['device_name']} (${activeDevices.first['estimated_power']}W) to save ${deviceSavings.toStringAsFixed(2)} PKR/hour.");
      }
    } else if (usagePercentage > 75) {
      double projectedCost = PowerConsumptionModel.calculateProjectedDailyCost(dailyKWh, kWhLimit);
      suggestions.add("⚠️ Warning: ${usagePercentage.toStringAsFixed(1)}% of daily limit used. Projected daily cost: ${projectedCost.toStringAsFixed(2)} PKR.");
    } else if (usagePercentage > 50) {
      suggestions.add("📊 You've used ${usagePercentage.toStringAsFixed(1)}% of daily limit. Remaining: ${remainingKWh.toStringAsFixed(2)} kWh.");
    }

    // Current cost display
    double currentHourlyCost = PowerConsumptionModel.calculateCurrentHourlyCost(currentPower);
    double dailyCost = costBreakdown['total_daily_cost'];

    suggestions.add("💵 Current rate: ${currentHourlyCost.toStringAsFixed(2)} PKR/hour | Today's cost: ${dailyCost.toStringAsFixed(2)} PKR");

    // Power Efficiency Analysis
    double predictedNextHour = PowerConsumptionModel.predictNextHourConsumption(historicalData);
    if (predictedNextHour > currentPower * 1.5) {
      double predictedCost = PowerConsumptionModel.calculateCurrentHourlyCost(predictedNextHour);
      suggestions.add("📈 Power trending up. Expected: ${predictedNextHour.toStringAsFixed(1)}W (${predictedCost.toStringAsFixed(2)} PKR/hour) next hour.");
    }

    // Device-specific suggestions with cost impact
    for (var device in deviceStatus) {
      if (device['state'] == true) {
        double sessionHours = device['current_session_hours'] ?? 0.0;
        double devicePower = device['estimated_power'] ?? 0.0;
        double deviceHourlyCost = PowerConsumptionModel.calculateCurrentHourlyCost(devicePower);

        if (sessionHours > 8 && device['device_name'].toString().contains('Fan')) {
          double sessionCost = deviceHourlyCost * sessionHours;
          suggestions.add("🌀 ${device['device_name']} running ${sessionHours.toStringAsFixed(1)}h (${sessionCost.toStringAsFixed(2)} PKR so far). Consider a break.");
        }
        if (sessionHours > 12 && device['device_name'].toString().contains('LED')) {
          double sessionCost = deviceHourlyCost * sessionHours;
          suggestions.add("💡 ${device['device_name']} on ${sessionHours.toStringAsFixed(1)}h (${sessionCost.toStringAsFixed(2)} PKR cost). Turn off if not needed.");
        }
      }
    }

    // Smart scheduling suggestions
    if (!PowerConsumptionModel.isPeakHour() && usagePercentage < 60) {
      suggestions.add("✅ Optimal time for high-power devices! Off-peak rates are ${((PowerConsumptionModel.peakHourMultiplier - 1) * 100).toInt()}% cheaper than peak hours.");
    }

    // Excess usage warning
    if (costBreakdown['excess_kwh'] > 0) {
      suggestions.add("⚠️ Excess usage: ${costBreakdown['excess_kwh'].toStringAsFixed(2)} kWh at 2x rate (${(costBreakdown['excess_cost']).toStringAsFixed(2)} PKR extra).");
    }

    return suggestions.isEmpty
        ? ["✅ All systems efficient! Current: ${currentHourlyCost.toStringAsFixed(2)} PKR/hour | Today: ${dailyCost.toStringAsFixed(2)} PKR"]
        : suggestions;
  }

  // Generate cost optimization recommendations
  static List<String> generateCostOptimizationTips({
    required double currentPower,
    required double dailyKWh,
    required double kWhLimit,
    required List<Map<String, dynamic>> deviceStatus,
  }) {
    List<String> tips = [];

    Map<String, dynamic> costBreakdown = PowerConsumptionModel.getCostBreakdown(
        dailyKWh, kWhLimit, currentPower
    );

    // Peak hour optimization
    if (PowerConsumptionModel.isPeakHour()) {
      tips.add("⏰ Wait 2-4 hours for 33% cheaper rates (peak ends at 10 PM)");
    } else {
      tips.add("💡 Great time for energy-intensive tasks - off-peak rates active!");
    }

    // Device scheduling tips
    List<Map<String, dynamic>> activeDevices = deviceStatus
        .where((device) => device['state'] == true)
        .toList();

    if (activeDevices.isNotEmpty) {
      activeDevices.sort((a, b) => (b['estimated_power'] ?? 0.0)
          .compareTo(a['estimated_power'] ?? 0.0));

      double highestDeviceCost = PowerConsumptionModel.calculateCurrentHourlyCost(
          activeDevices.first['estimated_power'] ?? 0.0);

      tips.add("🔋 Highest cost device: ${activeDevices.first['device_name']} (${highestDeviceCost.toStringAsFixed(2)} PKR/hour)");
    }

    // Limit management
    double remainingBudget = costBreakdown['remaining_kwh_limit'] * PowerConsumptionModel.baseCostPerKWh;
    if (remainingBudget > 0) {
      tips.add("💰 Remaining budget: ${remainingBudget.toStringAsFixed(2)} PKR before excess charges kick in");
    }

    return tips;
  }
}