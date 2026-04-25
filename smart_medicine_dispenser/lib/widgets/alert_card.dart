// lib/widgets/alert_card.dart
// Reusable card component that displays one IoT alert

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onMarkRead;
  final VoidCallback? onDelete;

  const AlertCard({
    super.key,
    required this.alert,
    this.onMarkRead,
    this.onDelete,
  });

  // Returns color + icon based on alert type
  _AlertStyle get _style {
    switch (alert.type) {
      case 'MISSED_DOSE':
        return _AlertStyle(
            color: const Color(0xFFE53935),
            icon: Icons.medication_liquid,
            label: 'Missed Dose');
      case 'LOW_PILLS':
        return _AlertStyle(
            color: const Color(0xFFF57C00),
            icon: Icons.inventory_2_outlined,
            label: 'Low Pills');
      case 'BATTERY_LOW':
        return _AlertStyle(
            color: const Color(0xFFF9A825),
            icon: Icons.battery_alert,
            label: 'Battery Low');
      case 'DOSE_TAKEN':
        return _AlertStyle(
            color: const Color(0xFF43A047),
            icon: Icons.check_circle_outline,
            label: 'Dose Taken');
      case 'JAM_DETECTED':
        return _AlertStyle(
            color: const Color(0xFF8E24AA),
            icon: Icons.warning_amber_rounded,
            label: 'Jam Detected');
      case 'DEVICE_OFFLINE':
        return _AlertStyle(
            color: const Color(0xFF546E7A),
            icon: Icons.wifi_off,
            label: 'Device Offline');
      default:
        return _AlertStyle(
            color: const Color(0xFF1565C0),
            icon: Icons.notifications,
            label: 'Alert');
    }
  }

  Color get _severityColor {
    switch (alert.severity) {
      case 'HIGH': return const Color(0xFFE53935);
      case 'MEDIUM': return const Color(0xFFF57C00);
      default: return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: alert.isRead ? 1 : 3,
        child: InkWell(
          onTap: onMarkRead,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: alert.isRead
                  ? null
                  : Border.all(color: style.color.withOpacity(0.3), width: 1.5),
              color: alert.isRead
                  ? Colors.white
                  : style.color.withOpacity(0.04),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              style.label,
                              style: TextStyle(
                                fontWeight: alert.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 14,
                                color: style.color,
                              ),
                            ),
                          ),
                          // Severity badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _severityColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              alert.severity,
                              style: TextStyle(
                                  color: _severityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            timeago.format(alert.timestamp),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.devices,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            alert.deviceId,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          if (!alert.isRead) ...[
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: style.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _AlertStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}