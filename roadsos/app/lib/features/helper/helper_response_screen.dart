import 'package:flutter/material.dart';
import '../../services/socket_service.dart';

/// This screen is shown when a helper receives a Firebase Cloud Messaging
/// notification that an accident was detected nearby.
///
/// Usage: Pass incidentId, helperUid, and distanceMeters as route arguments.
class HelperResponseScreen extends StatefulWidget {
  final String incidentId;
  final String helperUid;
  final double distanceMeters;
  final String? city;

  const HelperResponseScreen({
    super.key,
    required this.incidentId,
    required this.helperUid,
    required this.distanceMeters,
    this.city,
  });

  @override
  State<HelperResponseScreen> createState() => _HelperResponseScreenState();
}

class _HelperResponseScreenState extends State<HelperResponseScreen> {
  bool _isLoading = false;
  bool _responded = false;
  bool _accepted = false;
  String _message = '';

  void _respond(bool accepted) {
    setState(() {
      _isLoading = true;
    });

    try {
      SocketService().emitHelperResponse(
        widget.incidentId,
        widget.helperUid,
        accepted,
        widget.distanceMeters,
        (data) {
          if (!mounted) return;
          
          final success = data is Map ? (data['success'] == true) : false;
          final msg = data is Map ? data['message'] : null;

          setState(() {
            _isLoading = false;
            _responded = true;
            _accepted = accepted && success;
            _message = msg ?? (accepted ? 'You have been assigned.' : 'Response recorded.');
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _responded = true;
        _accepted = false;
        _message = 'Connection error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing alert icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE53935),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Color(0xFFE53935),
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '🚨 ACCIDENT NEARBY',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Someone needs help ${(widget.distanceMeters).toStringAsFixed(0)}m away'
                '${widget.city != null ? ' in ${widget.city}' : ''}.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Can you respond?',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 56),

              if (_responded) ...[
                Icon(
                  _accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: _accepted ? const Color(0xFF43A047) : Colors.grey,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  _message,
                  style: TextStyle(
                    color: _accepted ? const Color(0xFF43A047) : Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white54)),
                ),
              ] else if (_isLoading) ...[
                const CircularProgressIndicator(color: Color(0xFFE53935)),
                const SizedBox(height: 16),
                const Text('Sending response...', style: TextStyle(color: Colors.white54)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                    icon: const Icon(Icons.directions_run, size: 24),
                    label: const Text(
                      'ACCEPT — I\'m Responding',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _respond(true),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('DECLINE', style: TextStyle(fontSize: 15)),
                    onPressed: () => _respond(false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
