import 'package:flutter/material.dart';
import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/ui/screens/medical_id_screen.dart';
import 'package:roadsos_app/ui/screens/incidents_screen.dart';
import 'package:roadsos_app/ui/screens/severity_prediction_screen.dart';
import 'package:roadsos_app/ui/screens/simulated_lock_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      appBar: AppBar(
        title: const Text('Profile Settings'),
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
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // User Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // Profile Sections
            _buildSectionHeader('Medical & Emergency'),
            const SizedBox(height: 10),
            _buildSettingsItem(
              context,
              'Emergency Medical ID',
              'Blood group, allergies, medications',
              Icons.medical_services_rounded,
              RoadSoSColors.critical,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MedicalIDScreen(isReadOnly: false)),
              ),
            ),
            _buildSettingsItem(
              context,
              'Emergency Contacts',
              'Manage 2 active rescue notification phones',
              Icons.contacts_rounded,
              RoadSoSColors.warning,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MedicalIDScreen(isReadOnly: false)),
              ),
            ),
            _buildSettingsItem(
              context,
              'Simulated Lock Screen',
              'Verify bypass medical card & QR scanner',
              Icons.lock_person_rounded,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SimulatedLockScreen()),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('History & Logs'),
            const SizedBox(height: 10),
            _buildSettingsItem(
              context,
              'Incident History',
              'Timeline of past crashes & rescue assists',
              Icons.history_rounded,
              RoadSoSColors.success,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IncidentsScreen()),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('Analytics (optional)'),
            const SizedBox(height: 10),
            _buildSettingsItem(
              context,
              'Severity Predictor',
              'ML estimate: Slight / Serious / Fatal from road conditions',
              Icons.psychology_alt_rounded,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SeverityPredictionScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('Device & System'),
            const SizedBox(height: 10),
            _buildSettingsItem(
              context,
              'Calibrate Sensors',
              'Accelerometer & Gyroscope thresholds',
              Icons.tune_rounded,
              Colors.purple,
              null,
            ),
            _buildSettingsItem(
              context,
              'App Permissions',
              'System overlay, GPS, notifications',
              Icons.settings_applications_rounded,
              Colors.grey,
              null,
            ),
            const SizedBox(height: 40),
            
            // Version Info
            Center(
              child: Text(
                'RoadSOS Consumer App v2.4.0',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Intelligent Rider Guard Protection Active',
                style: TextStyle(
                  fontSize: 10,
                  color: RoadSoSColors.success.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return GlassCard(
      borderRadius: 24,
      borderColor: Colors.white.withOpacity(0.05),
      fillColor: Colors.white.withOpacity(0.01),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: RoadSoSColors.bgElevatedDark,
            child: const Icon(Icons.person_rounded, size: 40, color: Colors.white60),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dakshin Harrington',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: RoadSoSColors.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rider Protection Enabled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white38,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: GlassCard(
        borderRadius: 16,
        borderColor: Colors.white.withOpacity(0.05),
        fillColor: Colors.white.withOpacity(0.01),
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sensor calibration module is automated and running in the background.'),
                backgroundColor: RoadSoSColors.bgElevatedDark,
              ),
            );
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ),
      ),
    );
  }
}
