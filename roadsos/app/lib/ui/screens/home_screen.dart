import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/main.dart'; // globalDetectionEngine, globalEmergencyService
import 'package:roadsos_app/accident_detection/events/event_dispatcher.dart';
import 'package:roadsos_app/services/plus_code_service.dart';
import 'package:roadsos_app/ui/screens/medical_id_screen.dart';
import 'package:roadsos_app/helper_network/location_index_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Streams/Subscriptions handlers
  StreamSubscription<Position>? _positionSub;
  Timer? _rideTimer;

  // Real-time telemetry data
  int _rideElapsedSeconds = 0;
  double _rideSimulatedSpeed = 0.0;
  double _rideSimulatedDistance = 0.0;

  // GPS/System Info
  Position? _currentPosition;
  String _plusCode = 'Awaiting Location...';
  LocationPermission _locationPermission = LocationPermission.denied;

  // Volunteer status addition
  bool _isVolunteerAvailable = false;
  bool _updatingPresence = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
    if (globalDetectionEngine.isRunning && !globalDetectionEngine.isPaused) {
      _startRideSimulation();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _rideTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    final permission = await Geolocator.checkPermission();
    setState(() {
      _locationPermission = permission;
    });
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _plusCode = PlusCodeService.encode(position.latitude, position.longitude);
        });
      }
    });
  }

  void _toggleMonitoring() {
    if (globalDetectionEngine.isRunning && !globalDetectionEngine.isPaused) {
      globalDetectionEngine.pause();
      _stopRideSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guard Monitoring Paused. Crash sensors offline.'),
          backgroundColor: RoadSoSColors.bgElevatedDark,
        ),
      );
    } else if (globalDetectionEngine.isPaused) {
      globalDetectionEngine.resume();
      _startRideSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guard Monitoring Active. Analyzing motion vectors...'),
          backgroundColor: RoadSoSColors.critical,
        ),
      );
    } else {
      globalDetectionEngine.start();
      _startRideSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guard Monitoring Active. Crash sensors initialized.'),
          backgroundColor: RoadSoSColors.critical,
        ),
      );
    }
    setState(() {});
  }

  void _startRideSimulation() {
    _rideTimer?.cancel();
    _rideElapsedSeconds = 0;
    _rideSimulatedSpeed = 48.0;
    _rideSimulatedDistance = 0.0;

    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !globalDetectionEngine.isPaused) {
        setState(() {
          _rideElapsedSeconds++;
          final double drift = (DateTime.now().millisecond % 5) - 2.0;
          _rideSimulatedSpeed = (_rideSimulatedSpeed + drift).clamp(35.0, 75.0);
          _rideSimulatedDistance += _rideSimulatedSpeed / 3600.0;
        });
      }
    });
  }

  void _stopRideSimulation() {
    _rideTimer?.cancel();
    _rideTimer = null;
    setState(() {
      _rideSimulatedSpeed = 0.0;
    });
  }

  Future<void> _toggleVolunteerAvailability(bool val) async {
    setState(() {
      _updatingPresence = true;
    });

    Position? position = _currentPosition;
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) {
        position = Position(
          latitude: 13.0722,
          longitude: 80.1901,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    }

    final success = await LocationIndexService().updatePresence(
      'volunteer_user_global',
      position.latitude,
      position.longitude,
      val ? 'ONLINE' : 'OFFLINE',
    );

    if (mounted) {
      setState(() {
        _isVolunteerAvailable = val;
        _updatingPresence = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVolunteerAvailable
              ? 'Volunteer Status Active. Ready to assist nearby riders.'
              : 'Volunteer Status Offline.'),
          backgroundColor: _isVolunteerAvailable ? RoadSoSColors.success : RoadSoSColors.bgElevatedDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMonitoring = globalDetectionEngine.isRunning && !globalDetectionEngine.isPaused;

    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      // Screen 1 Header elements
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: Column(
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Road',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'SOS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: RoadSoSColors.critical,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: RoadSoSColors.critical,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Intelligent Accident Response System',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: RoadSoSColors.critical,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RoadSoSColors.bgDeepDark, Color(0xFF070B16)],
          ),
        ),
        child: SafeArea(
          // The home body is a fixed set of blocks; on shorter screens the
          // column used to overflow. Scroll instead of overflowing, while
          // keeping the original evenly-spaced layout when everything fits.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pulser central SOS shield component
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SosPulseShield(
                      isListening: isMonitoring,
                      onTap: _toggleMonitoring,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMonitoring ? RoadSoSColors.success : Colors.white24,
                            boxShadow: [
                              if (isMonitoring)
                                BoxShadow(
                                  color: RoadSoSColors.success.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMonitoring ? 'System Active' : 'System Inactive',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMonitoring ? 'Monitoring for accidents' : 'Tap SOS to begin monitoring',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Modules List Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GlassCard(
                  borderRadius: 24,
                  borderColor: Colors.white.withOpacity(0.06),
                  fillColor: Colors.white.withOpacity(0.02),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sensors Row
                      _buildModuleRow(
                        icon: Icons.monitor_heart_rounded,
                        iconColor: RoadSoSColors.success,
                        title: 'Sensors',
                        subtitle: isMonitoring ? 'All systems normal' : 'Sensors dormant',
                        action: Icon(
                          Icons.check_circle_rounded,
                          color: isMonitoring ? RoadSoSColors.success : Colors.white24,
                          size: 18,
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10, indent: 56),

                      // Location Row
                      _buildModuleRow(
                        icon: Icons.location_on_rounded,
                        iconColor: Colors.blue,
                        title: 'Location',
                        subtitle: _currentPosition != null ? 'Tracking active' : 'GPS Offline',
                        action: Icon(
                          Icons.check_circle_rounded,
                          color: _currentPosition != null ? RoadSoSColors.success : Colors.white24,
                          size: 18,
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10, indent: 56),

                      // Contacts Row
                      _buildModuleRow(
                        icon: Icons.people_alt_rounded,
                        iconColor: Colors.purpleAccent,
                        title: 'Contacts',
                        subtitle: '3 emergency contacts',
                        action: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MedicalIDScreen(isReadOnly: false)),
                          );
                        },
                      ),
                      const Divider(height: 1, color: Colors.white10, indent: 56),

                      // Volunteer Mode Row (New addition)
                      _buildModuleRow(
                        icon: Icons.volunteer_activism_rounded,
                        iconColor: Colors.tealAccent,
                        title: 'Volunteer Mode',
                        subtitle: 'Available to help nearby',
                        action: Switch.adaptive(
                          value: _isVolunteerAvailable,
                          activeColor: RoadSoSColors.success,
                          activeTrackColor: RoadSoSColors.success.withOpacity(0.2),
                          onChanged: _updatingPresence ? null : _toggleVolunteerAvailability,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Test SOS (Demo) Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GestureDetector(
                  onTap: () {
                    // Force trigger warning / simulation mode
                    globalDetectionEngine.simulateEvent(
                      EngineEvent.accidentDetected,
                      magnitude: 0.95,
                    );
                  },
                  child: GlassCard(
                    borderRadius: 16,
                    borderColor: RoadSoSColors.critical.withOpacity(0.2),
                    fillColor: RoadSoSColors.critical.withOpacity(0.04),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, color: RoadSoSColors.critical, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Test SOS (Demo)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: RoadSoSColors.critical,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget action,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
      trailing: action,
    );
  }
}
