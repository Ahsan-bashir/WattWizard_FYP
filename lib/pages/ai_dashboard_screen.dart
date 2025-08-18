// Enhanced AI Dashboard Screen with Advanced Cost Features
// File: ai_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

import '../models/ai_models.dart';
import '../models/user_preferences.dart';
import '../services/ai_service.dart';

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
  List<String> _optimizationTips = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _costBreakdown;
  double _dailyKWhLimit = 5.0;
  double _dailyUsage = 0.0;
  double _currentHourlyCost = 0.0;
  double _realTimeCostPerMinute = 0.0;
  double _projectedDailyCost = 0.0;

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
      double currentPower = analysisData['currentData']?['total_power_watts'] ?? 0.0;

      // Calculate comprehensive cost information
      Map<String, dynamic> costBreakdown = PowerConsumptionModel.getCostBreakdown(
          dailyKWh, _dailyKWhLimit, currentPower
      );

      double hourlyCost = PowerConsumptionModel.calculateCurrentHourlyCost(currentPower);
      double realTimeCost = PowerConsumptionModel.calculateRealTimeCost(currentPower);
      double projectedCost = PowerConsumptionModel.calculateProjectedDailyCost(dailyKWh, _dailyKWhLimit);

      // Generate cost optimization tips
      List<String> optimizationTips = AIAnalysisEngine.generateCostOptimizationTips(
        currentPower: currentPower,
        dailyKWh: dailyKWh,
        kWhLimit: _dailyKWhLimit,
        deviceStatus: analysisData['deviceStatus'] ?? [],
      );

      setState(() {
        _suggestions = newSuggestions;
        _optimizationTips = optimizationTips;
        _currentData = analysisData['currentData'];
        _costBreakdown = costBreakdown;
        _dailyUsage = dailyKWh;
        _currentHourlyCost = hourlyCost;
        _realTimeCostPerMinute = realTimeCost;
        _projectedDailyCost = projectedCost;
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
              _buildRealTimeCostBanner(),
              const SizedBox(height: 16),
              _buildStatusCards(),
              const SizedBox(height: 20),
              _buildCostBreakdownSection(),
              const SizedBox(height: 20),
              _buildSuggestionsSection(),
              const SizedBox(height: 20),
              _buildOptimizationTips(),
              const SizedBox(height: 20),
              _buildPowerAnalytics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealTimeCostBanner() {
    bool isPeakHour = PowerConsumptionModel.isPeakHour();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPeakHour
              ? [Colors.orange.shade400, Colors.red.shade400]
              : [Colors.blue.shade400, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPeakHour ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isPeakHour ? "PEAK HOURS ACTIVE" : "OFF-PEAK RATES",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "PKR ${_currentHourlyCost.toStringAsFixed(2)}/hour",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "PKR ${_realTimeCostPerMinute.toStringAsFixed(4)}/minute",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    double usagePercentage = (_dailyUsage / _dailyKWhLimit) * 100;
    double totalDailyCost = _costBreakdown?['total_daily_cost'] ?? 0.0;

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
                "Today's Cost",
                "PKR ${totalDailyCost.toStringAsFixed(2)}",
                "Projected: PKR ${_projectedDailyCost.toStringAsFixed(2)}",
                _projectedDailyCost > (_dailyKWhLimit * 43) ? Colors.red : Colors.blue,
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
                "Current Power",
                "${(_currentData?['total_power_watts'] ?? 0.0).toStringAsFixed(1)}W",
                "PKR ${_currentHourlyCost.toStringAsFixed(2)}/hour",
                Colors.purple,
                Icons.power,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCostBreakdownSection() {
    if (_costBreakdown == null) return const SizedBox();

    double baseCost = _costBreakdown!['base_cost'] ?? 0.0;
    double excessCost = _costBreakdown!['excess_cost'] ?? 0.0;
    double peakSurcharge = _costBreakdown!['peak_surcharge'] ?? 0.0;
    double remainingKWh = _costBreakdown!['remaining_kwh_limit'] ?? 0.0;

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
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF1E425E)),
              const SizedBox(width: 8),
              const Text(
                "Cost Breakdown",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E425E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCostRow("Base Cost", baseCost, Colors.green),
          if (excessCost > 0)
            _buildCostRow("Excess Cost (2x rate)", excessCost, Colors.red),
          if (peakSurcharge > 0)
            _buildCostRow("Peak Hour Surcharge", peakSurcharge, Colors.orange),
          const Divider(),
          _buildCostRow("Total Today", _costBreakdown!['total_daily_cost'] ?? 0.0, Color(0xFF1E425E), isTotal: true),
          const SizedBox(height: 8),
          Text(
            "Remaining budget: ${remainingKWh.toStringAsFixed(2)} kWh (PKR ${(remainingKWh * 43).toStringAsFixed(2)})",
            style: TextStyle(
              fontSize: 12,
              color: remainingKWh > 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? color : const Color(0xFF6B7280),
            ),
          ),
          Text(
            "PKR ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizationTips() {
    if (_optimizationTips.isEmpty) return const SizedBox();

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
              color: Color(0xFF059669),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  "Cost Optimization Tips",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _optimizationTips.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  _optimizationTips[index],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF065F46),
                    height: 1.4,
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                  "AI Analysis & Suggestions",
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
    double remainingBudget = (_costBreakdown?['remaining_kwh_limit'] ?? 0) * PowerConsumptionModel.baseCostPerKWh;
    bool hasExcessUsage = (_costBreakdown?['excess_kwh'] ?? 0) > 0;

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
          _buildAnalyticsRow("Current Hourly Rate", "PKR ${_currentHourlyCost.toStringAsFixed(2)}"),
          _buildAnalyticsRow("Projected Daily Cost", "PKR ${_projectedDailyCost.toStringAsFixed(2)}"),
          _buildAnalyticsRow("Daily Limit", "${_dailyKWhLimit.toStringAsFixed(1)} kWh"),
          _buildAnalyticsRow(
            "Remaining Budget",
            remainingBudget > 0 ? "PKR ${remainingBudget.toStringAsFixed(2)}" : "Exceeded",
            textColor: remainingBudget > 0 ? Colors.green : Colors.red,
          ),
          _buildAnalyticsRow("Peak Hour Status", PowerConsumptionModel.isPeakHour() ? "Active (6-10 PM)" : "Inactive"),
          if (hasExcessUsage)
            _buildAnalyticsRow(
              "Excess Usage",
              "${(_costBreakdown!['excess_kwh']).toStringAsFixed(2)} kWh",
              textColor: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value, {Color? textColor}) {
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF1E425E),
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
    if (suggestion.contains("💰") || suggestion.contains("Cost") || suggestion.contains("PKR")) return Colors.blue;
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
                    const SizedBox(height: 8),
                    Text("Estimated base cost: PKR ${(tempLimit * PowerConsumptionModel.baseCostPerKWh).toStringAsFixed(2)}/day"),
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