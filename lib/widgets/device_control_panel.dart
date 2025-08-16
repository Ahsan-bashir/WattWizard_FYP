
// File: widgets/device_control_panel.dart
import 'package:flutter/material.dart';

class DeviceControlPanel extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Function(String deviceId, bool newState) onDeviceToggle;

  const DeviceControlPanel({
    Key? key,
    required this.devices,
    required this.onDeviceToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          const Text(
            "Quick Device Control",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E425E),
            ),
          ),
          const SizedBox(height: 16),
          ...devices.map((device) => _buildDeviceControl(device)).toList(),
        ],
      ),
    );
  }

  Widget _buildDeviceControl(Map<String, dynamic> device) {
    bool isActive = device['state'] ?? false;
    double power = (device['estimated_power'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E8) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getDeviceIcon(device['device_name']),
            color: isActive ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device['device_name'] ?? 'Unknown Device',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "${power.toStringAsFixed(1)}W • ${(device['operating_voltage'] ?? 0.0).toStringAsFixed(1)}V",
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (value) {
              onDeviceToggle(device['id'], value);
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    String name = deviceName.toLowerCase();
    if (name.contains('fan')) return Icons.air;
    if (name.contains('led') || name.contains('light')) return Icons.lightbulb_outline;
    if (name.contains('socket')) return Icons.power_outlined;
    return Icons.electrical_services;
  }
}