// lib/widgets/pill_count_card.dart
//
// Drop this widget anywhere in the dashboard — it shows a live pill count
// for every container and lets the user set the initial count + threshold.
//
// HOW TO ADD TO DASHBOARD
// ───────────────────────
// In dashboard_screen.dart, inside the Column children of SliverToBoxAdapter,
// add this after the "Medication Schedules" section:
//
//   if (_deviceId.isNotEmpty) ...[
//     const Padding(
//       padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
//       child: Text('Pill Counts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//     ),
//     PillCountSection(
//       deviceId: _deviceId,
//       userId: widget.user.uid,
//       supportedContainers: _supportedContainers,
//     ),
//   ],

import 'package:flutter/material.dart';
import '../models/pill_count_model.dart';
import '../services/pill_count_service.dart';

// ── MAIN SECTION WIDGET ──────────────────────────────────────────────────────
// Listens to the Firestore stream and renders one card per container.
class PillCountSection extends StatelessWidget {
  final String deviceId;
  final String userId;
  final List<String> supportedContainers; // e.g. ['1', '2']

  const PillCountSection({
    super.key,
    required this.deviceId,
    required this.userId,
    required this.supportedContainers,
  });

  @override
  Widget build(BuildContext context) {
    final service = PillCountService();

    return StreamBuilder<List<PillCount>>(
      stream: service.getPillCountsStream(deviceId),
      builder: (context, snapshot) {
        // Build a map for quick lookup: containerId → PillCount
        final countMap = <String, PillCount>{};
        for (final pc in snapshot.data ?? []) {
          countMap[pc.containerId] = pc;
        }

        return Column(
          children: supportedContainers.map((cid) {
            return _PillCountCard(
              containerId: cid,
              deviceId: deviceId,
              userId: userId,
              pillCount: countMap[cid], // null = not configured yet
            );
          }).toList(),
        );
      },
    );
  }
}

// ── SINGLE CONTAINER CARD ────────────────────────────────────────────────────
class _PillCountCard extends StatelessWidget {
  final String containerId;
  final String deviceId;
  final String userId;
  final PillCount? pillCount;

  const _PillCountCard({
    required this.containerId,
    required this.deviceId,
    required this.userId,
    required this.pillCount,
  });

  Color get _urgencyColor {
    switch (pillCount?.urgency) {
      case 'EMPTY':    return Colors.red.shade700;
      case 'CRITICAL': return Colors.red;
      case 'LOW':      return Colors.orange;
      default:         return Colors.green;
    }
  }

  IconData get _urgencyIcon {
    switch (pillCount?.urgency) {
      case 'EMPTY':    return Icons.dangerous_outlined;
      case 'CRITICAL': return Icons.warning_amber_rounded;
      case 'LOW':      return Icons.info_outline;
      default:         return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = pillCount != null;
    final current = pillCount?.currentCount ?? 0;
    final total = pillCount?.totalCount ?? 0;
    final threshold = pillCount?.threshold ?? 0;
    final percent = pillCount?.percentFull ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isConfigured && pillCount!.isBelowThreshold
            ? BorderSide(color: _urgencyColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ROW ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _urgencyColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medication,
                    color: _urgencyColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Container $containerId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isConfigured
                            ? '$current of $total pills remaining'
                            : 'Tap Configure to set pill count',
                        style: TextStyle(
                          fontSize: 12,
                          color: isConfigured ? _urgencyColor : Colors.grey,
                          fontWeight: isConfigured && pillCount!.isBelowThreshold
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Urgency badge
                if (isConfigured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _urgencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_urgencyIcon, color: _urgencyColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          pillCount!.urgency,
                          style: TextStyle(
                            color: _urgencyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ── PROGRESS BAR ─────────────────────────────────────────────
            if (isConfigured) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_urgencyColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}% full',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Alert at ≤ $threshold pills',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── ACTION BUTTONS ───────────────────────────────────────────
            Row(
              children: [
                // Configure / Refill button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showConfigDialog(context),
                    icon: Icon(
                      isConfigured ? Icons.refresh : Icons.add,
                      size: 16,
                    ),
                    label: Text(isConfigured ? 'Refill / Edit' : 'Configure'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                    ),
                  ),
                ),
                if (isConfigured) ...[
                  const SizedBox(width: 8),
                  // Manual deduct button (for testing)
                  OutlinedButton.icon(
                    onPressed: () => _showDeductDialog(context),
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('Deduct'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── CONFIGURE DIALOG ────────────────────────────────────────────────────────
  void _showConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _PillCountConfigDialog(
        containerId: containerId,
        deviceId: deviceId,
        userId: userId,
        existingCount: pillCount,
      ),
    );
  }

  // ── MANUAL DEDUCT DIALOG (test/correction) ──────────────────────────────────
  void _showDeductDialog(BuildContext context) {
    final ctrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deduct from Container $containerId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use this to manually correct the count or test the threshold alert.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pills to deduct',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(ctrl.text) ?? 1;
              Navigator.pop(ctx);
              await PillCountService().deductDose(
                deviceId: deviceId,
                containerId: containerId,
                userId: userId,
                dosePerTime: amount,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Deducted $amount pill(s) from container $containerId'),
                  ),
                );
              }
            },
            child: const Text('Deduct'),
          ),
        ],
      ),
    );
  }
}

// ── CONFIG DIALOG ─────────────────────────────────────────────────────────────
class _PillCountConfigDialog extends StatefulWidget {
  final String containerId;
  final String deviceId;
  final String userId;
  final PillCount? existingCount;

  const _PillCountConfigDialog({
    required this.containerId,
    required this.deviceId,
    required this.userId,
    required this.existingCount,
  });

  @override
  State<_PillCountConfigDialog> createState() => _PillCountConfigDialogState();
}

class _PillCountConfigDialogState extends State<_PillCountConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _totalCtrl;
  late TextEditingController _thresholdCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing values when editing
    _totalCtrl = TextEditingController(
      text: widget.existingCount != null
          ? '${widget.existingCount!.totalCount}'
          : '',
    );
    _thresholdCtrl = TextEditingController(
      text: widget.existingCount != null
          ? '${widget.existingCount!.threshold}'
          : '10',
    );
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final total = int.parse(_totalCtrl.text.trim());
    final threshold = int.parse(_thresholdCtrl.text.trim());

    if (threshold >= total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Threshold must be less than total count'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await PillCountService().setInitialCount(
        deviceId: widget.deviceId,
        containerId: widget.containerId,
        userId: widget.userId,
        totalCount: total,
        threshold: threshold,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Container ${widget.containerId}: '
              '$total pills set, alert at ≤ $threshold',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.medication, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Text('Container ${widget.containerId}'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Helper text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Set the total pill count after refilling the container. '
                'The app will deduct pills automatically each time an alarm fires.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),

            // Total count field
            TextFormField(
              controller: _totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total pills in container',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                helperText: 'Count the pills you just filled',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter a number ≥ 1';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Threshold field
            TextFormField(
              controller: _thresholdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Alert threshold',
                prefixIcon: Icon(Icons.warning_amber_outlined),
                helperText: 'Send alert when pills drop to this number',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter a number ≥ 1';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(widget.existingCount == null ? 'Set Count' : 'Save & Refill'),
        ),
      ],
    );
  }
}