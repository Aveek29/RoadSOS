import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/main.dart'; // globalEmergencyService, globalDetectionEngine
import 'package:roadsos_app/emergency_handling/countdown_manager.dart';

class AccidentDetectedScreen extends StatefulWidget {
  const AccidentDetectedScreen({super.key});

  @override
  State<AccidentDetectedScreen> createState() => _AccidentDetectedScreenState();
}

class _AccidentDetectedScreenState extends State<AccidentDetectedScreen> {
  StreamSubscription<CountdownTick>? _countdownSub;
  int _secondsRemaining = 10;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Listen to ticks from the global emergency service
    _countdownSub = globalEmergencyService.countdownTicks.listen((tick) {
      if (mounted) {
        setState(() {
          _secondsRemaining = tick.remaining;
          _progress = tick.progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownSub?.cancel();
    super.dispose();
  }

  void _onImSafe() {
    globalEmergencyService.cancelEmergency();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: _onImSafe,
        ),
        title: const Text(
          'Accident Detected',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1020), Color(0xFF070B16)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Warning Exclamation Icon & Labels
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft glow under the icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: RoadSoSColors.critical.withOpacity(0.35),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        // Custom Triangle Painter or Icon
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: RoadSoSColors.critical,
                          size: 96,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Accident Detected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: RoadSoSColors.critical,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Are you safe?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                // Countdown Timer Ring
                CountdownRing(
                  remainingSeconds: _secondsRemaining,
                  progress: _progress,
                  color: RoadSoSColors.critical,
                ),

                // Bottom Description text & Dismiss CTA
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'If you are safe, please cancel\nthe alert',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RoadSoSColors.critical,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _onImSafe,
                        child: const Text(
                          "I'm Safe, Cancel Alert",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
