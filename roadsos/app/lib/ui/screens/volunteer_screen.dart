
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/helper_network/location_index_service.dart';


class VolunteerScreen extends StatefulWidget {
  const VolunteerScreen({super.key});

  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen>
    with TickerProviderStateMixin {
  bool _isAvailable = false;
  bool _updatingPresence = false;
  bool _hasActiveMission = false;
  String _missionStatus = 'ASSIGNED';

  // Collapse states
  bool _howItWorksExpanded = false;
  bool _historyExpanded = true;

  // Simulated metrics
  final double _rating = 4.98;
  final int _livesAssisted = 12;
  final int _nearbyHelpers = 4;
  final int _totalDispatches = 37;

  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _fadeInController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );
    _fadeInController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(bool val) async {
    setState(() => _updatingPresence = true);

    Position? position;
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

    await LocationIndexService().updatePresence(
      'volunteer_user_global',
      position.latitude,
      position.longitude,
      val ? 'ONLINE' : 'OFFLINE',
    );

    if (mounted) {
      setState(() {
        _isAvailable = val;
        _updatingPresence = false;
        if (_isAvailable) {
          _pulseController.repeat();
          _rippleController.repeat();
        } else {
          _pulseController.stop();
          _pulseController.reset();
          _rippleController.stop();
          _rippleController.reset();
          _hasActiveMission = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAvailable
              ? '🟢  Volunteer Network Active. Monitoring nearby crash triggers.'
              : '⚫  Volunteer Mode Off Duty.'),
          backgroundColor: _isAvailable
              ? RoadSoSColors.success.withValues(alpha: 0.85)
              : RoadSoSColors.bgElevatedDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: AnimatedBuilder(
        animation: _fadeIn,
        builder: (context, child) => Opacity(
          opacity: _fadeIn.value,
          child: Transform.translate(
            offset: Offset(0, _slideUp.value),
            child: child,
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Collapsible App Bar ──────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: const Color(0xFF080D1A),
              elevation: 0,
              title: const Text(
                'Volunteer Network',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _OnlineBadge(isOnline: _isAvailable),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Status Card ─────────────────────
                    _buildHeroStatusCard(),
                    const SizedBox(height: 20),

                    // ── Active Mission (conditional) ──────────
                    if (_hasActiveMission) ...[
                      _buildActiveMissionLayout(),
                      const SizedBox(height: 20),
                    ],

                    // ── Stats Row ────────────────────────────
                    _buildStatsRow(),
                    const SizedBox(height: 20),

                    // ── How it Works ─────────────────────────
                    _buildHowItWorksCard(),
                    const SizedBox(height: 20),

                    // ── Recent Activity ───────────────────────
                    _buildRecentActivity(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Hero Status Card
  // ─────────────────────────────────────────────────────────
  Widget _buildHeroStatusCard() {
    final color = _isAvailable ? RoadSoSColors.success : const Color(0xFF4A5568);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isAvailable
              ? [
                  const Color(0xFF0A2A1A),
                  const Color(0xFF0D1F2D),
                ]
              : [
                  const Color(0xFF131929),
                  const Color(0xFF0D1120),
                ],
        ),
        border: Border.all(
          color: color.withValues(alpha: _isAvailable ? 0.35 : 0.12),
          width: 1.5,
        ),
        boxShadow: _isAvailable
            ? [
                BoxShadow(
                  color: RoadSoSColors.success.withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            // Top row: Avatar + Text
            Row(
              children: [
                // Animated pulse ring + icon
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ripple
                      if (_isAvailable)
                        AnimatedBuilder(
                          animation: _rippleController,
                          builder: (_, __) => Opacity(
                            opacity: (1.0 - _rippleController.value) * 0.4,
                            child: Transform.scale(
                              scale: 0.6 + _rippleController.value * 0.7,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: RoadSoSColors.success,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Inner pulse ring
                      if (_isAvailable)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Opacity(
                            opacity: (1.0 - _pulseController.value) * 0.6,
                            child: Transform.scale(
                              scale: 0.75 + _pulseController.value * 0.3,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: RoadSoSColors.success.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Core icon circle
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _isAvailable
                                ? [
                                    RoadSoSColors.success.withValues(alpha: 0.3),
                                    RoadSoSColors.success.withValues(alpha: 0.1),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.03),
                                  ],
                          ),
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _isAvailable
                              ? Icons.verified_user_rounded
                              : Icons.shield_outlined,
                          color: color,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status pill chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: _isAvailable
                                    ? [BoxShadow(color: RoadSoSColors.success, blurRadius: 4)]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isAvailable ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isAvailable ? 'Available to Help' : 'Off Duty',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isAvailable
                            ? 'Actively monitoring for nearby crash alerts'
                            : 'Enable to join the RoadSoS responder loop',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Divider
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),

            const SizedBox(height: 18),

            // Responder toggle row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Responder Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAvailable
                            ? 'You will receive real-time crash alerts'
                            : 'Toggle to start accepting dispatches',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                _updatingPresence
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: color,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _toggleAvailability(!_isAvailable),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 56,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: _isAvailable
                                ? RoadSoSColors.success
                                : Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: _isAvailable
                                  ? RoadSoSColors.success
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                left: _isAvailable ? 28 : 2,
                                top: 2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Stats Row
  // ─────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'YOUR IMPACT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Lives\nAssisted',
                value: '$_livesAssisted',
                icon: Icons.favorite_rounded,
                color: RoadSoSColors.critical,
                glow: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Response\nRating',
                value: '$_rating',
                suffix: '★',
                icon: Icons.star_rounded,
                color: RoadSoSColors.warning,
                glow: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Total\nDispatches',
                value: '$_totalDispatches',
                icon: Icons.bolt_rounded,
                color: RoadSoSColors.volunteerPurple,
                glow: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Wide helpers card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                RoadSoSColors.success.withValues(alpha: 0.12),
                RoadSoSColors.success.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: RoadSoSColors.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RoadSoSColors.success.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.people_alt_rounded, color: RoadSoSColors.success, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HELPERS ONLINE NEARBY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: RoadSoSColors.success.withValues(alpha: 0.7),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_nearbyHelpers responders active in your area',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: RoadSoSColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_nearbyHelpers',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: RoadSoSColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String suffix = '',
    required IconData icon,
    required Color color,
    required bool glow,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111827),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 0)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              children: [
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  How it Works Card (collapsible)
  // ─────────────────────────────────────────────────────────
  Widget _buildHowItWorksCard() {
    const steps = [
      _Step(Icons.toggle_on_rounded, 'Go Online', 'Enable responder status', Color(0xFF22C55E)),
      _Step(Icons.notifications_active_rounded, 'Receive Alert', 'Get crash location instantly', Color(0xFFF59E0B)),
      _Step(Icons.navigation_rounded, 'Navigate & Help', 'Arrive and assist the victim', Color(0xFF8B5CF6)),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0E1526),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header tap to toggle ──
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _howItWorksExpanded = !_howItWorksExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  const Text(
                    'HOW IT WORKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _howItWorksExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // ── Collapsible content ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  const SizedBox(height: 14),
                  ...steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: step.color.withValues(alpha: 0.12),
                                border: Border.all(color: step.color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(step.icon, color: step.color, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    step.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: step.color.withValues(alpha: 0.15),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: step.color,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (i < steps.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6),
                            child: Container(
                              width: 1,
                              height: 16,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _howItWorksExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Incident History (collapsible)
  // ─────────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    final incidents = [
      _Incident(
        title: 'Accident Detected - NH-48 Expressway',
        time: 'May 28, 2026 • 18:42',
        location: 'NH-48, Koyambedu, Chennai',
        response: 'Ambulance + 2 Volunteers dispatched.',
        severity: 'Critical Impact',
        status: 'Resolved',
        isCritical: true,
      ),
      _Incident(
        title: 'Accident Nearby - IIT Madras Campus',
        time: 'May 24, 2026 • 09:15',
        location: 'IIT Madras Adyar Gate, Chennai',
        response: 'You responded and provided CPR support.',
        severity: 'High Severity',
        status: 'Assisted & Resolved',
        isCritical: false,
      ),
      _Incident(
        title: 'Calibration Trigger - Test Event',
        time: 'May 15, 2026 • 14:02',
        location: 'Velachery Main Road, Chennai',
        response: 'Auto-cancelled within 10s countdown.',
        severity: 'Minor Impact',
        status: 'Cancelled by User',
        isCritical: false,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0E1526),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  const Text(
                    'INCIDENT HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: RoadSoSColors.critical.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${incidents.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: RoadSoSColors.critical,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _historyExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // ── Collapsible timeline ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  const SizedBox(height: 12),
                  ...incidents.asMap().entries.map((entry) {
                    final i = entry.key;
                    final inc = entry.value;
                    final isResolved = inc.status == 'Resolved' || inc.status == 'Assisted & Resolved';
                    final dotColor = inc.isCritical ? RoadSoSColors.critical : RoadSoSColors.warning;
                    final statusColor = isResolved ? RoadSoSColors.success : Colors.grey;
                    final severityColor = inc.isCritical ? RoadSoSColors.critical : RoadSoSColors.warning;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Timeline column
                          SizedBox(
                            width: 24,
                            child: Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dotColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: dotColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < incidents.length - 1)
                                  Expanded(
                                    child: Container(
                                      width: 1.5,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: const Color(0xFF131929),
                                  border: Border.all(
                                    color: dotColor.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            inc.title,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            inc.status,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: statusColor,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      inc.time,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            inc.location,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            inc.response,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          inc.isCritical ? Icons.report_problem_rounded : Icons.info_rounded,
                                          size: 12,
                                          color: severityColor,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          inc.severity,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: severityColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _historyExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 350),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Active Mission Layout
  // ─────────────────────────────────────────────────────────
  Widget _buildActiveMissionLayout() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RoadSoSColors.critical.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            RoadSoSColors.critical.withValues(alpha: 0.08),
            const Color(0xFF0D1120),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: RoadSoSColors.critical.withValues(alpha: 0.15),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _BlinkingDot(color: RoadSoSColors.critical),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE DISPATCH  ·  $_missionStatus',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: RoadSoSColors.critical,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _hasActiveMission = false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white38, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const LiveMapPreview(height: 180, showDirections: true),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _missionChip(Icons.timer_outlined, 'ETA: 2 mins', RoadSoSColors.warning),
                const SizedBox(width: 8),
                _missionChip(Icons.place_outlined, '120 m away', RoadSoSColors.volunteerPurple),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => setState(() => _missionStatus = 'ON_SCENE'),
                    child: const Text('Mark On Scene', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RoadSoSColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() => _hasActiveMission = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mission completed. Thank you for saving a life! 💚'),
                          backgroundColor: RoadSoSColors.success,
                        ),
                      );
                    },
                    child: const Text('Complete Mission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _missionChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Helper Widgets
// ─────────────────────────────────────────────────────────

class _OnlineBadge extends StatelessWidget {
  final bool isOnline;
  const _OnlineBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline
            ? RoadSoSColors.success.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? RoadSoSColors.success.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        isOnline ? 'LIVE' : 'OFF',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isOnline ? RoadSoSColors.success : Colors.white38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.4 + _ctrl.value * 0.6,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Step(this.icon, this.title, this.subtitle, this.color);
}

class _Incident {
  final String title;
  final String time;
  final String location;
  final String response;
  final String severity;
  final String status;
  final bool isCritical;
  const _Incident({
    required this.title,
    required this.time,
    required this.location,
    required this.response,
    required this.severity,
    required this.status,
    required this.isCritical,
  });
}
