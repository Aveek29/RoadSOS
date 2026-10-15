import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/main.dart'; // globalEmergencyService

class AlertSentScreen extends StatelessWidget {
  const AlertSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            globalEmergencyService.cancelEmergency();
          },
        ),
        title: const Text(
          'Alert Sent',
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1020), Color(0xFF070B16)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkmark success banner
                const SizedBox(height: 10),
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
                            color: RoadSoSColors.success.withOpacity(0.35),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: RoadSoSColors.success,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Help is on the way!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: RoadSoSColors.success,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your location and alert have been shared\nwith emergency contacts and nearby helpers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 24),

                // Dispatches status Card
                GlassCard(
                  borderRadius: 24,
                  borderColor: Colors.white.withOpacity(0.06),
                  fillColor: Colors.white.withOpacity(0.02),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildStatusRow(
                        icon: Icons.people_outline_rounded,
                        title: 'Emergency Contacts',
                        status: '3 Notified',
                      ),
                      const Divider(height: 1, color: Colors.white10, indent: 56),
                      _buildStatusRow(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'Nearby Helpers',
                        status: '12 Notified',
                      ),
                      const Divider(height: 1, color: Colors.white10, indent: 56),
                      _buildStatusRow(
                        icon: Icons.location_on_outlined,
                        title: 'Live Location',
                        status: 'Sharing Active',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Map View
                const LiveMapPreview(height: 180, showDirections: false),
                const SizedBox(height: 12),

                // Location Sharing labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: RoadSoSColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.share_location_rounded, color: RoadSoSColors.success, size: 14),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sharing Live Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: RoadSoSColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: RoadSoSColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NH48, Koyambedu, Chennai,\nTamil Nadu 600107, India',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Share Location Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E253F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rescue link shared with contacts.'),
                          backgroundColor: RoadSoSColors.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text(
                      'Share Location',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String title,
    required String status,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_rounded,
            color: RoadSoSColors.success,
            size: 16,
          ),
        ],
      ),
    );
  }
}
