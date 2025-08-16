// Fixed AI Dashboard Screen with PKR Currency
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
                "PKR ${_currentCost.toStringAsFixed(2)}",
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
    double savingsIfOptimal = projectedDailyCost - (_dailyKWhLimit * 42.5); // Using PKR rate

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
          _buildAnalyticsRow("Projected Daily Cost", "PKR ${projectedDailyCost.toStringAsFixed(2)}"),
          _buildAnalyticsRow("Daily Limit", "${_dailyKWhLimit.toStringAsFixed(1)} kWh"),
          _buildAnalyticsRow("Potential Savings", savingsIfOptimal > 0 ? "PKR ${savingsIfOptimal.toStringAsFixed(2)}" : "On Track"),
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