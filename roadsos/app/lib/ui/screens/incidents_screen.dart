import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';

class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock incident history data
    final incidents = [
      {
        'title': 'Accident Detected - NH-48 Expressway',
        'time': 'May 28, 2026 • 18:42',
        'type': 'Rider Emergency',
        'severity': 'Critical Impact',
        'status': 'Resolved',
        'location': 'NH-48, Koyambedu, Chennai',
        'response': 'Ambulance + 2 Volunteers dispatched.',
        'isCritical': true,
      },
      {
        'title': 'Accident Nearby - IIT Madras Campus',
        'time': 'May 24, 2026 • 09:15',
        'type': 'Volunteer Assist',
        'severity': 'High Severity',
        'status': 'Assisted & Resolved',
        'location': 'IIT Madras Adyar Gate, Chennai',
        'response': 'You responded and provided CPR support.',
        'isCritical': false,
      },
      {
        'title': 'Calibration Trigger - Test Event',
        'time': 'May 15, 2026 • 14:02',
        'type': 'Rider Emergency',
        'severity': 'Minor Impact',
        'status': 'Cancelled by User',
        'location': 'Velachery Main Road, Chennai',
        'response': 'Auto-cancelled within 10s countdown.',
        'isCritical': false,
      },
    ];

    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      appBar: AppBar(
        title: const Text('Incident History'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              final isCritical = incident['isCritical'] as bool;
              final statusColor = incident['status'] == 'Resolved' || incident['status'] == 'Assisted & Resolved'
                  ? RoadSoSColors.success
                  : Colors.grey;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline vertical line and dot
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCritical ? RoadSoSColors.critical : RoadSoSColors.warning,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                        ),
                        Expanded(
                          child: index == incidents.length - 1
                              ? const SizedBox.shrink()
                              : Container(
                                  width: 2,
                                  color: Colors.white10,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Glass Card content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: GlassCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(16),
                          borderColor: Colors.white.withOpacity(0.06),
                          fillColor: Colors.white.withOpacity(0.02),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      incident['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      incident['status'] as String,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                incident['time'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Divider(height: 20, color: Colors.white12),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      incident['location'] as String,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      incident['response'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    isCritical ? Icons.report_problem_rounded : Icons.info,
                                    size: 14,
                                    color: isCritical ? RoadSoSColors.critical : RoadSoSColors.warning,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    incident['severity'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isCritical ? RoadSoSColors.critical : RoadSoSColors.warning,
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
            },
          ),
        ),
      ),
    );
  }
}
