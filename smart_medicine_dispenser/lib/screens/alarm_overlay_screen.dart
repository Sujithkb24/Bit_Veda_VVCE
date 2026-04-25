// lib/screens/alarm_overlay_screen.dart
//
// Full-screen alarm UI with LOOPING audio.
// Sound plays from initState and stops ONLY when user taps Taken or Snooze.
//
// REQUIRES in pubspec.yaml:
//   dependencies:
//     just_audio: ^0.9.40
//   flutter:
//     assets:
//       - assets/sounds/alarm.mp3

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class AlarmOverlayScreen extends StatefulWidget {
  final String medicationName;
  final String doseInfo;
  final int alarmId;

  const AlarmOverlayScreen({
    super.key,
    required this.medicationName,
    required this.doseInfo,
    this.alarmId = 0,
  });

  // Use this to push from dashboard test button or notification tap
  static Route<void> route({
    required String medicationName,
    required String doseInfo,
    int alarmId = 0,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => AlarmOverlayScreen(
        medicationName: medicationName,
        doseInfo: doseInfo,
        alarmId: alarmId,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  State<AlarmOverlayScreen> createState() => _AlarmOverlayScreenState();
}

class _AlarmOverlayScreenState extends State<AlarmOverlayScreen>
    with TickerProviderStateMixin {

  // ── Audio player — looping until user dismisses ────────────────────────────
  AudioPlayer? _player;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ring1Anim;
  late final Animation<double>   _ring2Anim;
  late final Animation<double>   _ring3Anim;
  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initAnimations();
    _startAudio();
  }

  // ── Start looping audio ────────────────────────────────────────────────────
  Future<void> _startAudio() async {
    try {
      final player = AudioPlayer();
      _player = player;

      // LoopMode.one = repeat the same track forever until .stop() is called
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);

      // Load from Flutter assets — file must be at assets/sounds/alarm.mp3
      // and listed under flutter > assets in pubspec.yaml
      await player.setAsset('assets/sounds/alarm.mp3');

      // play() is non-blocking — audio runs independently on a platform thread
      await player.play();

      print('AlarmOverlayScreen: looping audio started');
    } catch (e) {
      // Never crash the UI if audio fails
      print('AlarmOverlayScreen: audio error — $e');
    }
  }

  // ── Stop audio and close screen ────────────────────────────────────────────
  Future<void> _stopAndDismiss() async {
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = null;
    } catch (e) {
      print('AlarmOverlayScreen: stop audio error — $e');
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      // SystemNavigator.pop() finishes the Android Activity entirely.
      // Use this when launched from AlarmActivity (lock screen).
      // If launched from within the main app Navigator, use Navigator.pop() instead.
      SystemNavigator.pop();
    }
  }

  Future<void> _onTaken()  async => _stopAndDismiss();
  Future<void> _onSnooze() async => _stopAndDismiss();

  void _initAnimations() {
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _ring1Anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut)));
    _ring2Anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _ring3Anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80))
      ..repeat(reverse: true);
    _shakeAnim = Tween<double>(begin: -3, end: 3).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    // Safety net: if screen is popped externally, stop audio
    _player?.stop();
    _player?.dispose();

    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _shakeCtrl.dispose();
    _slideCtrl.dispose();
    _waveCtrl.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      // Prevent back-button dismissal — user MUST press Taken or Snooze
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Animated wave background
            AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _WaveBgPainter(_waveCtrl.value),
              ),
            ),

            // Expanding sonar rings
            Positioned(
              top: size.height * 0.20,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(alignment: Alignment.center, children: [
                      _Ring(scale: _ring3Anim.value,
                            opacity: 1 - _ring3Anim.value),
                      _Ring(scale: _ring2Anim.value * 0.8,
                            opacity: (1 - _ring2Anim.value) * 0.7),
                      _Ring(scale: _ring1Anim.value * 0.6,
                            opacity: (1 - _ring1Anim.value) * 0.5),
                    ]),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Pulsing pill icon
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2),
                        ),
                        child: const Icon(Icons.medication_liquid,
                            size: 64, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Live clock
                  _LiveClock(),

                  const SizedBox(height: 10),

                  // Badge label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('MEDICATION REMINDER',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Info card — slides in and shakes
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                            offset: Offset(_shakeAnim.value, 0),
                            child: child),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12))
                            ],
                          ),
                          child: Column(
                            children: [
                              // Container + dose row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF0D47A1)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(
                                        Icons.inventory_2_rounded,
                                        color: Color(0xFF0D47A1),
                                        size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Container ${widget.medicationName}',
                                          style: const TextStyle(
                                              color: Color(0xFF0D47A1),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(widget.doseInfo,
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  // Pulsing red "live" dot
                                  _PulsingDot(),
                                ],
                              ),

                              const SizedBox(height: 20),
                              const Divider(height: 1),
                              const SizedBox(height: 20),

                              // Info box
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.amber.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.volume_up_rounded,
                                        color: Colors.amber.shade700,
                                        size: 18),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Alarm will keep ringing until you tap Taken or Snooze.',
                                        style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // Snooze
                        Expanded(
                          child: _ActionButton(
                            label: 'Snooze',
                            sublabel: '10 min',
                            icon: Icons.snooze_rounded,
                            isPrimary: false,
                            onTap: _onSnooze,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Taken
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            label: 'Taken',
                            sublabel: 'Stop alarm',
                            icon: Icons.check_circle_rounded,
                            isPrimary: true,
                            onTap: _onTaken,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _LiveClock extends StatefulWidget {
  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late String _time;
  @override
  void initState() {
    super.initState();
    _tick();
  }
  void _tick() {
    if (!mounted) return;
    final n = DateTime.now();
    setState(() => _time =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}');
    Future.delayed(const Duration(seconds: 10), _tick);
  }
  @override
  Widget build(BuildContext context) => Text(_time,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.w200,
          letterSpacing: -2,
          height: 1));
}

class _Ring extends StatelessWidget {
  final double scale;
  final double opacity;
  const _Ring({required this.scale, required this.opacity});
  @override
  Widget build(BuildContext context) => Transform.scale(
      scale: scale,
      child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(opacity.clamp(0.0, 0.4)),
                  width: 1.5))));
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(_a.value))));
}

class _ActionButton extends StatefulWidget {
  final String label, sublabel;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label, required this.sublabel,
    required this.icon, required this.isPrimary, required this.onTap,
  });
  @override State<_ActionButton> createState() => _ActionButtonState();
}
class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.93, upperBound: 1.0, value: 1.0);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp:   (_) { _c.forward(); widget.onTap(); },
      onTapCancel: () => _c.forward(),
      child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: _c.value, child: child),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: widget.isPrimary
                    ? Colors.green.shade500
                    : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: widget.isPrimary
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.35)),
                boxShadow: widget.isPrimary
                    ? [BoxShadow(
                        color: Colors.green.shade700.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8))]
                    : null,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(widget.label, style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w700)),
                Text(widget.sublabel, style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ]))));
}

// ── Animated wave background painter ──────────────────────────────────────────
class _WaveBgPainter extends CustomPainter {
  final double t;
  _WaveBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // Solid gradient base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1F6B), Color(0xFF0D47A1), Color(0xFF1565C0)])
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // Animated wave bands
    for (int i = 0; i < 3; i++) {
      final phase = t * 2 * math.pi + i * (math.pi / 1.5);
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x++) {
        path.lineTo(x,
            size.height * 0.72 +
                math.sin((x / size.width * 2 * math.pi) + phase) *
                    (30 - i * 8.0) +
                math.cos((x / size.width * math.pi) + phase * 0.7) * 12);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path,
          Paint()
            ..color = Colors.white.withOpacity(0.04 - i * 0.01)
            ..style = PaintingStyle.fill);
    }
    // Radial glow
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.30),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(
            colors: [Colors.white.withOpacity(0.08), Colors.transparent])
            .createShader(Rect.fromCircle(
                center: Offset(size.width / 2, size.height * 0.30),
                radius: size.width * 0.6)),
    );
  }
  @override
  bool shouldRepaint(_WaveBgPainter old) => old.t != t;
}