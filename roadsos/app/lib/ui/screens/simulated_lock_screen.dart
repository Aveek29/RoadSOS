import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'medical_id_screen.dart';

class SimulatedLockScreen extends StatelessWidget {
  const SimulatedLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Blurred background image simulation
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1A2C),
                  Color(0xFF050A14),
                ],
              ),
            ),
          ),

          // Central lock indicator
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white54, size: 28),
                  const SizedBox(height: 12),
                  const Text(
                    '09:41',
                    style: TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'Saturday, May 30',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),

                  // Mock lock screen notifications
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: Colors.white10,
                    fillColor: Colors.white.withOpacity(0.04),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: RoadSoSColors.redDim,
                          child: Icon(Icons.emergency_rounded, color: RoadSoSColors.critical, size: 18),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RoadSOS Sentinel Active',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Impact monitoring running in background.',
                                style: TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Swipe/tap prompt text
                  const Text(
                    'Swipe up to unlock',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),

                  const Spacer(),

                  // Lock Screen Footer Access Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Emergency Dialer / Medical ID Trigger
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        icon: const Icon(Icons.medical_services_rounded, color: RoadSoSColors.critical, size: 18),
                        label: const Text(
                          'EMERGENCY',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        onPressed: () {
                          // Paramedic Shortcut: bypasses phone lock directly into Read-only Medical ID
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MedicalIDScreen(isReadOnly: true),
                            ),
                          );
                        },
                      ),
                      
                      // Lock status action
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
