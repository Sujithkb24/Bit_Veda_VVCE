// lib/screens/alerts_screen.dart
// Full alerts screen — shows real-time live feed of IoT alerts
// Uses StreamBuilder so UI updates automatically when new alerts arrive

import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/firestore_service.dart';
import '../widgets/alert_card.dart';
import 'package:flutter/services.dart';

class AlertsScreen extends StatefulWidget {
  final String userId;
  const AlertsScreen({super.key, required this.userId});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
 
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  late TabController _tabController;
  String _filterSeverity = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          // Mark all as read button
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await _firestoreService.markAllAlertsAsRead(widget.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('All alerts marked as read'),
                      duration: Duration(seconds: 2)),
                );
              }
            },
          ),
          // Filter by severity
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) => setState(() => _filterSeverity = val),
            itemBuilder: (ctx) => ['ALL', 'HIGH', 'MEDIUM', 'LOW']
                .map((s) => PopupMenuItem(value: s, child: Text(s)))
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
            Tab(text: 'Critical'),
          ],
        ),
      ),

      // ── REAL-TIME STREAM ─────────────────────────────────────────────
      // StreamBuilder rebuilds this widget whenever Firestore sends new data
      body: StreamBuilder<List<AlertModel>>(
        stream: _firestoreService.getAlertsStream(widget.userId),
        builder: (context, snapshot) {
          // Waiting for first data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allAlerts = snapshot.data ?? [];

          // Apply severity filter
          List<AlertModel> filtered = _filterSeverity == 'ALL'
              ? allAlerts
              : allAlerts.where((a) => a.severity == _filterSeverity).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // All alerts
              _AlertList(
                alerts: filtered,
                onMarkRead: (id) => _firestoreService.markAlertAsRead(id),
                onDelete: (id) => _firestoreService.deleteAlert(id),
              ),
              // Unread only
              _AlertList(
                alerts: filtered.where((a) => !a.isRead).toList(),
                onMarkRead: (id) => _firestoreService.markAlertAsRead(id),
                onDelete: (id) => _firestoreService.deleteAlert(id),
              ),
              // Critical (HIGH severity) only
              _AlertList(
                alerts: filtered.where((a) => a.severity == 'HIGH').toList(),
                onMarkRead: (id) => _firestoreService.markAlertAsRead(id),
                onDelete: (id) => _firestoreService.deleteAlert(id),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── ALERT LIST ─────────────────────────────────────────────────────────────
class _AlertList extends StatelessWidget {
  final List<AlertModel> alerts;
  final Function(String) onMarkRead;
  final Function(String) onDelete;

  const _AlertList({
    required this.alerts,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No alerts here',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Your IoT device will send alerts here\nin real time',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return AlertCard(
          alert: alert,
          onMarkRead: alert.isRead ? null : () => onMarkRead(alert.id),
          onDelete: () => onDelete(alert.id),
        );
      },
    );
  }
}