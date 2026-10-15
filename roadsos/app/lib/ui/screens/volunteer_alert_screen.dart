import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';

class VolunteerAlertScreen extends StatefulWidget {
  final VoidCallback onAccept;

  const VolunteerAlertScreen({
    super.key,
    required this.onAccept,
  });

  @override
  State<VolunteerAlertScreen> createState() => _VolunteerAlertScreenState();
}

class _VolunteerAlertScreenState extends State<VolunteerAlertScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: GlassCard(
            borderRadius: 28,
            borderColor: RoadSoSColors.critical.withOpacity(0.3),
            fillColor: RoadSoSColors.bgDeepDark.withOpacity(0.95),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing alert header icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: RoadSoSColors.critical.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: RoadSoSColors.critical,
                      ),
                      child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Alert details
                const Text(
                  'Accident Nearby',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Urgent response requested within your zone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),

                // Grid stats
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailsItem('DISTANCE', '120m away', Icons.directions_run_rounded, RoadSoSColors.critical),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailsItem('EST. ARRIVAL', '2 mins', Icons.timer_rounded, RoadSoSColors.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Victim medical card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medical_information_rounded, size: 16, color: RoadSoSColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'VICTIM MEDICAL ID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: RoadSoSColors.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Blood Group', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          Text(
                            'O- (Negative)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RoadSoSColors.critical),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Medical Conditions', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          Text(
                            'Asthma',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Allergies', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          Text(
                            'Penicillin Allergy',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RoadSoSColors.warning),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CTAs
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RoadSoSColors.critical,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          widget.onAccept();
                          Navigator.pop(context);
                        },
                        child: const Text('ACCEPT RESPONSE', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _buildDetailsItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.3)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
