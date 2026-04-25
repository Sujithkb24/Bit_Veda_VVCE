// lib/main.dart
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alarm_overlay_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Global navigator key ─────────────────────────────────────────────────
// Used by AlarmOverlayScreen to navigate from a notification tap.
// Must be passed to MaterialApp.navigatorKey below.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermissions() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

@pragma('vm:entry-point')
Future<void> _onLocalNotificationTap(NotificationResponse response) async {
  try {
    final notifId = response.id;
    if (notifId != null) {
      // Stop any repeating (insistent) system sound immediately on user action.
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // alarm_service.dart payload schema:
    // { alarmId, medicationName, doseInfo }
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final medicationName = (data['medicationName'] ?? 'Unknown').toString();
    final doseInfo = (data['doseInfo'] ?? '').toString();
    final alarmId = (data['alarmId'] as num?)?.toInt() ?? 0;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(AlarmOverlayScreen.route(
      medicationName: medicationName,
      doseInfo: doseInfo,
      alarmId: alarmId,
    ));
  } catch (_) {
    // Best-effort navigation only
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase initialized successfully');

  await AlarmService.initialize();
  print('AlarmManager initialized');

  final alarmPermission = await Permission.scheduleExactAlarm.status;
  if (alarmPermission.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: _onLocalNotificationTap,
    onDidReceiveBackgroundNotificationResponse: _onLocalNotificationTap,
  );

  await requestNotificationPermissions();

  runApp(const MedicineDispenserApp());
}

class MedicineDispenserApp extends StatelessWidget {
  const MedicineDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedDispense',
      debugShowCheckedModeBanner: false,
      // ── ADDED: wire up the global navigator key ──────────────────────
      navigatorKey: navigatorKey,
      theme: _buildTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print('Auth state changed: ${snapshot.connectionState}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Showing splash screen - checking auth state');
            return const SplashScreen();
          }

          if (snapshot.hasData && snapshot.data != null) {
            print('User logged in: ${snapshot.data!.email}');
            NotificationService().initialize(context);
            return DashboardScreen(user: snapshot.data!);
          }

          print('No user logged in, showing login screen');
          return const LoginScreen();
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFF1565C0);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.medication, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'MedDispense',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Medicine Dispenser',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 16),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white)),
          ],
        ),
      ),
    );
  }
}