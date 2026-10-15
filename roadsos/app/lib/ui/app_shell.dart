import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/emergency_handling/emergency_service.dart';
import 'package:roadsos_app/main.dart'; // globalEmergencyService
import 'package:roadsos_app/ui/screens/home_screen.dart';
import 'package:roadsos_app/ui/screens/medical_id_screen.dart';
import 'package:roadsos_app/ui/screens/volunteer_screen.dart';
import 'package:roadsos_app/ui/screens/profile_screen.dart';
import 'package:roadsos_app/ui/screens/accident_detected_screen.dart';
import 'package:roadsos_app/ui/screens/alert_sent_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  StreamSubscription<EmergencyState>? _emergencyStateSub;
  EmergencyState _currentState = EmergencyState.idle;

  // The 4 persistent screens matching bottom navigation
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const VolunteerScreen(),
      const ProfileScreen(),
    ];

    // Subscribe to global emergency state stream
    _emergencyStateSub = globalEmergencyService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
        _handleEmergencyStateTransition(state);
      }
    });
  }

  @override
  void dispose() {
    _emergencyStateSub?.cancel();
    super.dispose();
  }

  void _handleEmergencyStateTransition(EmergencyState state) {
    if (state == EmergencyState.countdown) {
      // Show accident detected screen overlay
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return const AccidentDetectedScreen();
        },
      );
    } else if (state == EmergencyState.alerting || state == EmergencyState.completed) {
      // Pop the countdown dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // Show alert sent screen overlay
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return const AlertSentScreen();
        },
      );
    } else if (state == EmergencyState.idle || state == EmergencyState.cancelled) {
      // Pop any active dialogs back to home
      while (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: RoadSoSColors.critical),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism, color: RoadSoSColors.critical),
            label: 'Volunteer',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: RoadSoSColors.critical),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
