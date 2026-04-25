  import 'package:medicine_dispenser/main.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';

  import '../models/alert_model.dart';
  import '../models/schedule_model.dart';
  import '../models/user_model.dart';
  import '../services/alarm_service.dart';
  import '../services/auth_service.dart';
  import '../services/firestore_service.dart';
  import '../widgets/schedule_config_dialog.dart';
  import 'alerts_screen.dart';
  import 'profile_screen.dart';
  import 'alarm_overlay_screen.dart';
  import '../widgets/pill_count_card.dart';

  class DashboardScreen extends StatefulWidget {
    final User user;

    const DashboardScreen({super.key, required this.user});

    @override
    State<DashboardScreen> createState() => _DashboardScreenState();
  }

  class _DashboardScreenState extends State<DashboardScreen> {
    int _selectedIndex = 0;
    final _firestoreService = FirestoreService();
    final _authService = AuthService();
    UserModel? _userModel;

    @override
    void initState() {
      super.initState();
      _loadUser();
    }

    Future<void> _loadUser() async {
      final user = await _authService.getUserData(widget.user.uid);
      if (mounted) {
        setState(() => _userModel = user);
      }
    }

    @override
    Widget build(BuildContext context) {
      final screens = [
        _HomeTab(user: widget.user, userModel: _userModel),
        AlertsScreen(userId: widget.user.uid),
        ProfileScreen(user: widget.user, userModel: _userModel),
      ];

      return Scaffold(
        body: screens[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: StreamBuilder<int>(
                stream: _firestoreService.getUnreadAlertCount(widget.user.uid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.notifications_outlined),
                  );
                },
              ),
              selectedIcon: const Icon(Icons.notifications),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
    }
  }

  class _HomeTab extends StatefulWidget {
    final User user;
    final UserModel? userModel;

    const _HomeTab({required this.user, required this.userModel});

    @override
    State<_HomeTab> createState() => _HomeTabState();
  }

  class _HomeTabState extends State<_HomeTab> {
    static const List<String> _supportedContainers = ['1', '2'];

    final FirestoreService _firestoreService = FirestoreService();
    final AlarmService _alarmService = AlarmService();

    String get _deviceId => widget.userModel?.dispenserDeviceId ?? '';

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF1565C0),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 70,
                      bottom: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _getGreeting(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                widget.userModel?.name.split(' ').first ??
                                    'Loading...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medication,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<DispenserStatus?>(
                      stream: _deviceId.isEmpty
                          ? const Stream.empty()
                          : _firestoreService.getDeviceStatusStream(_deviceId),
                      builder: (context, snapshot) {
                        return _DeviceStatusCard(
                          status: snapshot.data,
                          deviceId: _deviceId,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<List<AlertModel>>(
                      stream: _firestoreService.getAlertsStream(widget.user.uid),
                      builder: (context, snapshot) {
                        final alerts = snapshot.data ?? const <AlertModel>[];
                        final unread = alerts.where((item) => !item.isRead).length;
                        final critical = alerts
                            .where(
                              (item) => item.severity == 'HIGH' && !item.isRead,
                            )
                            .length;

                        return Row(
                          children: [
                            _StatCard(
                              label: 'Total',
                              value: '${alerts.length}',
                              icon: Icons.notifications,
                              color: const Color(0xFF1565C0),
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'Unread',
                              value: '$unread',
                              icon: Icons.mark_email_unread,
                              color: const Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'Critical',
                              value: '$critical',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFE53935),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (widget.userModel != null &&
                      widget.userModel!.medications.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Your Medications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...widget.userModel!.medications
                        .map((medication) => _MedCard(med: medication)),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Medication Schedules',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Containers 1 & 2',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<MedicationSchedule>>(
                    stream: _firestoreService.getSchedulesStream(widget.user.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final schedules = snapshot.data!;
                      final nextAlarm = _alarmService.getNextAlarm(schedules);
                     if (_deviceId.isNotEmpty) {
  _alarmService.fetchAndScheduleFromCloud(
    _deviceId,
    userId: widget.user.uid,
  );
}
                      return Column(
                        children: [
                          if (nextAlarm != null) _NextAlarmBanner(info: nextAlarm),
                          if (_deviceId.isEmpty)
                            Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Set the dispenser device ID in the profile before creating schedules.',
                                ),
                              ),
                            )
                          else
                            ..._supportedContainers.map((containerId) {
                              final schedule = _findSchedule(
                                schedules,
                                containerId,
                              );
                              return _ContainerScheduleCard(
                                containerId: containerId,
                                schedule: schedule,
                                onConfigure: () => _showScheduleConfig(
                                  context,
                                  containerId: containerId,
                                  schedule: schedule,
                                ),
                                onDelete: schedule == null
                                    ? null
                                    : () => _deleteSchedule(schedule),
                              );
                            }),
                        ],
                      );
                    },
                  ),
                   if (_deviceId.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pill Counts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Tap a container to configure',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PillCountSection(
                    deviceId: _deviceId,
                    userId: widget.user.uid,
                    supportedContainers: _supportedContainers, // ['1', '2']
                  ),
                ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Alarm Testing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _AlarmTestCard(alarmService: _alarmService),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Recent Alerts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  StreamBuilder<List<AlertModel>>(
                    stream: _firestoreService.getAlertsStream(widget.user.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final alerts = snapshot.data!.take(3).toList();
                      return alerts.isEmpty
                          ? const _EmptyAlerts()
                          : Column(
                              children: alerts
                                  .map((alert) => _SmallAlertTile(alert: alert))
                                  .toList(),
                            );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: () => _firestoreService.addTestAlert(
                        widget.user.uid,
                      ),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Simulate IoT Alert (Test Only)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    }

    MedicationSchedule? _findSchedule(
      List<MedicationSchedule> schedules,
      String containerId,
    ) {
      for (final schedule in schedules) {
        if (schedule.containerId == containerId) return schedule;
      }
      return null;
    }

    String _getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning,';
      if (hour < 17) return 'Good Afternoon,';
      return 'Good Evening,';
    }

    void _showScheduleConfig(
      BuildContext context, {
      required String containerId,
      MedicationSchedule? schedule,
    }) {
      showDialog(
        context: context,
        builder: (dialogContext) => ScheduleConfigDialog(
          userId: widget.user.uid,
          deviceId: _deviceId,
          existingScheduleId: schedule?.id,
          initialContainerId: schedule?.containerId ?? containerId,
          initialDosePerTime: schedule?.dosePerTime,
          initialScheduleTimes: schedule?.scheduleTimes,
          initialEndDate: schedule?.endDate,
          onScheduleSaved: (savedSchedule) async {
            await _alarmService.scheduleAlarmsForSchedule(
  savedSchedule,
  userId: widget.user.uid,
);
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  'Container ${savedSchedule.containerId} synced to ESP32.',
                ),
                backgroundColor: Colors.green.shade700,
              ),
            );
          },
        ),
      );
    }

    Future<void> _deleteSchedule(MedicationSchedule schedule) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Schedule'),
          content: Text(
            'Delete container ${schedule.containerId} schedule and cancel its alarms?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _alarmService.cancelAlarmsForSchedule(schedule.id);
      await _firestoreService.deleteMedicationSchedule(
        scheduleId: schedule.id,
        deviceId: schedule.deviceId,
        containerId: schedule.containerId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule and alarms deleted')),
      );
    }
  }

  class _AlarmTestCard extends StatefulWidget {
    final AlarmService alarmService;

    const _AlarmTestCard({required this.alarmService});

    @override
    State<_AlarmTestCard> createState() => _AlarmTestCardState();
  }

  class _AlarmTestCardState extends State<_AlarmTestCard> {
    bool _testing = false;
    String _statusMsg = '';

  Future<void> _runTest() async {
      setState(() => _testing = true);
      await widget.alarmService.fireTestAlarm();
      if (!mounted) return;
      setState(() {
        _testing = false;       _statusMsg = 'Test alarm set — fires in ~5 seconds';
      });
    }

    @override
    Widget build(BuildContext context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.orange.shade200, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alarm, color: Colors.orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Alarm',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Fires a real alarm in 5 seconds',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'This uses Android AlarmManager, so it behaves like the real schedule alarms.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testing ? null : _runTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.alarm_add),
                  label: Text(
                    _testing ? 'Setting alarm...' : 'Fire Test Alarm (5 sec)',
                  ),
                ),
              ),
              if (_statusMsg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMsg,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  class _NextAlarmBanner extends StatelessWidget {
    final AlarmInfo info;

    const _NextAlarmBanner({required this.info});

    @override
    Widget build(BuildContext context) {
      final now = DateTime.now();
      final diff = info.time.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      String timeLabel;
      if (diff.inMinutes < 1) {
        timeLabel = 'Now';
      } else if (hours > 0) {
        timeLabel = '${hours}h ${minutes}m';
      } else {
        timeLabel = '${minutes}m';
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next Alarm',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'In $timeLabel - Container ${info.containerId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('HH:mm').format(info.time),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }
  }

  class _DeviceStatusCard extends StatelessWidget {
    final DispenserStatus? status;
    final String deviceId;

    const _DeviceStatusCard({this.status, required this.deviceId});

    @override
    Widget build(BuildContext context) {
      final isOnline = status?.isOnline ?? false;
      final battery = status?.batteryLevel ?? 0;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.devices, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  const Text(
                    'Device Status',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                'Device ID: ${deviceId.isEmpty ? 'Not set' : deviceId}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatusItem(
                      icon: _batteryIcon(battery),
                      label: 'Battery',
                      value: status != null ? '$battery%' : '--',
                      color: battery < 20
                          ? Colors.red
                          : battery < 50
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _StatusItem(
                      icon: Icons.wifi,
                      label: 'Signal',
                      value: status != null ? '${status!.wifiStrength} dBm' : '--',
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  Expanded(
                    child: _StatusItem(
                      icon: Icons.medication,
                      label: 'Next Dose',
                      value: status?.nextDose != null
                          ? DateFormat('HH:mm').format(status!.nextDose!)
                          : '--',
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    IconData _batteryIcon(int level) {
      if (level > 75) return Icons.battery_full;
      if (level > 50) return Icons.battery_3_bar;
      if (level > 25) return Icons.battery_2_bar;
      if (level > 10) return Icons.battery_1_bar;
      return Icons.battery_alert;
    }
  }

  class _StatusItem extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;
    final Color color;

    const _StatusItem({
      required this.icon,
      required this.label,
      required this.value,
      required this.color,
    });

    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      );
    }
  }

  class _StatCard extends StatelessWidget {
    final String label;
    final String value;
    final IconData icon;
    final Color color;

    const _StatCard({
      required this.label,
      required this.value,
      required this.icon,
      required this.color,
    });

    @override
    Widget build(BuildContext context) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  class _MedCard extends StatelessWidget {
    final Medication med;

    const _MedCard({required this.med});

    @override
    Widget build(BuildContext context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication, color: Color(0xFF1565C0), size: 20),
          ),
          title: Text(
            med.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            med.dosage,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: med.times
                .map(
                  (time) => Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
  }

  class _SmallAlertTile extends StatelessWidget {
    final AlertModel alert;

    const _SmallAlertTile({required this.alert});

    Color get _color {
      switch (alert.severity) {
        case 'HIGH':
          return Colors.red;
        case 'MEDIUM':
          return Colors.orange;
        default:
          return Colors.green;
      }
    }

    @override
    Widget build(BuildContext context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _color.withOpacity(0.1),
            child: Icon(Icons.notifications, color: _color, size: 18),
          ),
          title: Text(
            alert.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            DateFormat('MMM d, HH:mm').format(alert.timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          trailing: !alert.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      );
    }
  }

  class _EmptyAlerts extends StatelessWidget {
    const _EmptyAlerts();

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'All clear! No alerts yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  class _ContainerScheduleCard extends StatelessWidget {
    final String containerId;
    final MedicationSchedule? schedule;
    final VoidCallback onConfigure;
    final VoidCallback? onDelete;

    const _ContainerScheduleCard({
      required this.containerId,
      required this.schedule,
      required this.onConfigure,
      required this.onDelete,
    });

    @override
    Widget build(BuildContext context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Color(0xFF1565C0),
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
                          schedule == null
                              ? 'Not configured yet'
                              : '${schedule!.dosePerTime} pill(s) per dose',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onConfigure,
                    icon: Icon(schedule == null ? Icons.add : Icons.edit, size: 18),
                    label: Text(schedule == null ? 'Set' : 'Edit'),
                  ),
                  if (schedule != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (schedule == null)
                Text(
                  'Tap Set to choose time slots, dose count, and end date.',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: schedule!.scheduleTimes
                      .map(
                        (time) => Chip(
                          avatar: const Icon(Icons.access_time, size: 16),
                          label: Text(time),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ends on ${DateFormat('dd/MM/yyyy').format(schedule!.endDate)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
