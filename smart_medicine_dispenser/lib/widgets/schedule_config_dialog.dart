import 'package:flutter/material.dart';

import '../models/schedule_model.dart';
import '../services/firestore_service.dart';

class ScheduleConfigDialog extends StatefulWidget {
  final String userId;
  final String deviceId;
  final String? existingScheduleId;
  final String? initialContainerId;
  final int? initialDosePerTime;
  final List<String>? initialScheduleTimes;
  final DateTime? initialEndDate;
  final Future<void> Function(MedicationSchedule)? onScheduleSaved;

  const ScheduleConfigDialog({
    super.key,
    required this.userId,
    required this.deviceId,
    this.existingScheduleId,
    this.initialContainerId,
    this.initialDosePerTime,
    this.initialScheduleTimes,
    this.initialEndDate,
    this.onScheduleSaved,
  });

  @override
  State<ScheduleConfigDialog> createState() => _ScheduleConfigDialogState();
}

class _ScheduleConfigDialogState extends State<ScheduleConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final List<String> _containerOptions = const ['1', '2'];

  late String _selectedContainerId;
  late int _dosePerTime;
  late List<String> _selectedTimes;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedContainerId = _containerOptions.contains(widget.initialContainerId)
        ? widget.initialContainerId!
        : '1';
    _dosePerTime = widget.initialDosePerTime ?? 1;
    _selectedTimes = List<String>.from(widget.initialScheduleTimes ?? const [])
      ..sort();
    _endDate = widget.initialEndDate ??
        DateTime.now().add(const Duration(days: 30));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.deviceId.trim().isEmpty) {
      _showError('Device ID is missing in the user profile.');
      return;
    }

    if (_selectedTimes.isEmpty) {
      _showError('Add at least one time slot.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final savedSchedule = await _firestoreService.saveMedicationSchedule(
        userId: widget.userId,
        deviceId: widget.deviceId,
        containerId: _selectedContainerId,
        dosePerTime: _dosePerTime,
        scheduleTimes: _selectedTimes,
        endDate: _endDate,
      );

      await widget.onScheduleSaved?.call(savedSchedule);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Error saving schedule: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime({int? index}) async {
    final initial = index != null
        ? _parseTimeOfDay(_selectedTimes[index])
        : const TimeOfDay(hour: 8, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    final formatted = _formatTimeOfDay(picked);
    setState(() {
      if (index == null) {
        if (_selectedTimes.length >= 3) return;
        _selectedTimes.add(formatted);
      } else {
        _selectedTimes[index] = formatted;
      }
      _selectedTimes = _selectedTimes.toSet().toList()..sort();
    });
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingScheduleId != null
                        ? 'Edit Container Schedule'
                        : 'Set Container Schedule',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedContainerId,
                decoration: const InputDecoration(
                  labelText: 'Container',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: _containerOptions
                    .map(
                      (containerId) => DropdownMenuItem(
                        value: containerId,
                        child: Text('Container $containerId'),
                      ),
                    )
                    .toList(),
                onChanged: widget.existingScheduleId != null
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedContainerId = value);
                      },
              ),
              const SizedBox(height: 16),
              const Text(
                'Dose count',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _dosePerTime > 1
                        ? () => setState(() => _dosePerTime--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: const Color(0xFF1565C0),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_dosePerTime',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _dosePerTime++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Time slots',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        _selectedTimes.length >= 3 ? null : () => _pickTime(),
                    icon: const Icon(Icons.add_alarm, size: 18),
                    label: const Text('Add Time'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedTimes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'No time slots yet. Add up to 3 times for this container.',
                  ),
                )
              else
                ...List.generate(_selectedTimes.length, (index) {
                  final time = _selectedTimes[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1565C0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF1565C0)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            time,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _pickTime(index: index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => _selectedTimes.removeAt(index));
                          },
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              const Text(
                'End date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _endDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF1565C0),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save & Sync'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
