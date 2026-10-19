import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:roadsos_app/config/app_config.dart';
import 'package:roadsos_app/services/socket_service.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/ui/theme.dart';

/// Live incident history.
///
/// Loads incidents from the backend REST API and keeps the list in sync with
/// the backend's real-time Socket.IO broadcasts (`incident_created`,
/// `incident_updated`, `incident_deleted`). When the backend is unreachable
/// (or has no incidents yet) it falls back to the bundled demo history so the
/// screen is never empty — the UI always states which source is shown.
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  final List<Map<String, dynamic>> _incidents = <Map<String, dynamic>>[];
  final Set<String> _seenIds = <String>{};
  StreamSubscription<Map<String, dynamic>>? _eventsSub;

  bool _loading = true;
  bool _usingFallback = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Real-time updates: keep the list live even while the screen is open.
    _eventsSub = SocketService().serverEvents.listen(_onServerEvent);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  /// Merges a socket broadcast into the local list.
  void _onServerEvent(Map<String, dynamic> event) {
    final name = event['event'];
    final data = event['data'] as Map<String, dynamic>? ?? const {};

    if (name == 'incident_created' || name == 'incident_updated') {
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) return;
      setState(() {
        final index = _incidents.indexWhere((i) => i['id'] == id);
        if (index >= 0) {
          _incidents[index] = data;
        } else {
          _incidents.insert(0, data);
        }
        _usingFallback = false;
      });
    } else if (name == 'incident_deleted') {
      final id = data['id']?.toString();
      if (id == null) return;
      setState(() {
        _incidents.removeWhere((i) => i['id'] == id);
        _seenIds.remove(id);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // History = active incidents + resolved ones.
      final results = await Future.wait([
        _fetchIncidents(),
        _fetchIncidents(status: 'RESOLVED'),
      ]);

      final merged = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final list in results) {
        for (final incident in list) {
          final id = incident['id']?.toString() ?? '';
          if (seen.add(id)) merged.add(incident);
        }
      }
      merged.sort((a, b) =>
          (b['timestamp']?.toString() ?? '').compareTo(a['timestamp']?.toString() ?? ''));

      if (!mounted) return;
      setState(() {
        _incidents
          ..clear()
          ..addAll(merged);
        _seenIds
          ..clear()
          ..addAll(seen);
        _usingFallback = merged.isEmpty;
        if (merged.isEmpty) {
          _incidents.addAll(_demoIncidents());
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _incidents
          ..clear()
          ..addAll(_demoIncidents());
        _usingFallback = true;
        _loading = false;
        _error = 'Backend unreachable — showing demo history.';
      });
      debugPrint('[Incidents] load failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIncidents({String? status}) async {
    final uri = AppConfig.uri('/incidents').replace(
      queryParameters: {
        if (status != null) 'status': status,
        'limit': '100',
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw http.ClientException('GET /incidents -> ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw http.ClientException('GET /incidents failed: ${body['error']}');
    }
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  // -- display helpers -----------------------------------------------------
  String _title(Map<String, dynamic> incident) {
    final source = (incident['source'] ?? '').toString();
    final severity = (incident['severity'] ?? '').toString();
    if (source == 'demo') return 'Demo Incident — ${incident['city'] ?? 'Chennai'}';
    if (source == 'mobile') {
      return severity == 'CRITICAL'
          ? 'Critical Accident Detected'
          : 'Accident Detected';
    }
    return 'Command Centre Alert';
  }

  String _location(Map<String, dynamic> incident) {
    final city = incident['city'];
    if (city != null && city.toString().isNotEmpty) return city.toString();
    final plusCode = incident['plusCode'];
    if (plusCode != null && plusCode.toString().isNotEmpty) {
      return plusCode.toString();
    }
    final lat = incident['victimLat'] ?? incident['latitude'];
    final lng = incident['victimLng'] ?? incident['longitude'];
    if (lat is num && lng is num) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
    return 'Location unavailable';
  }

  String _time(Map<String, dynamic> incident) {
    final raw = incident['timestamp']?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return 'Unknown time';
    final local = parsed.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} • $hh:$mm';
  }

  String _statusLabel(Map<String, dynamic> incident) {
    switch ((incident['status'] ?? 'ACTIVE').toString()) {
      case 'RESOLVED':
        return 'Resolved';
      case 'RESPONDING':
        return 'Responding';
      case 'CRITICAL':
        return 'Critical';
      default:
        return 'Active';
    }
  }

  String _response(Map<String, dynamic> incident) {
    final helpers = incident['acceptedHelpers'];
    final dispatched = incident['dispatchedResources'];
    final parts = <String>[];
    if (helpers is List && helpers.isNotEmpty) {
      parts.add('${helpers.length} volunteer${helpers.length == 1 ? '' : 's'} responding');
    }
    if (dispatched is List && dispatched.isNotEmpty) {
      final types = dispatched
          .whereType<Map>()
          .map((d) => d['type']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet();
      if (types.isNotEmpty) {
        parts.add('${types.map((t) => t[0].toUpperCase() + t.substring(1)).join(' + ')} dispatched');
      }
    }
    return parts.isEmpty ? 'Awaiting responders.' : '${parts.join('. ')}.';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return RoadSoSColors.success;
      case 'Responding':
        return RoadSoSColors.warning;
      case 'Critical':
        return RoadSoSColors.critical;
      default:
        return Colors.lightBlueAccent;
    }
  }

  /// Bundled history used only when the backend has nothing to show.
  List<Map<String, dynamic>> _demoIncidents() => [
        {
          'id': 'demo_history_1',
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
          'id': 'demo_history_2',
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
          'id': 'demo_history_3',
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

  /// Normalizes either a backend incident or a bundled demo entry into the
  /// field set rendered by the card.
  Map<String, dynamic> _viewModel(Map<String, dynamic> incident) {
    if (incident.containsKey('title')) return incident; // bundled demo entry
    final status = _statusLabel(incident);
    final severity = (incident['severity'] ?? 'LOW').toString();
    return {
      'id': incident['id'],
      'title': _title(incident),
      'time': _time(incident),
      'type': incident['source'] == 'demo' ? 'Demo' : 'Rider Emergency',
      'severity': severity,
      'status': status,
      'location': _location(incident),
      'response': _response(incident),
      'isCritical': severity == 'CRITICAL' || severity == 'HIGH',
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = _incidents.map(_viewModel).toList();

    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      appBar: AppBar(
        title: const Text('Incident History'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh from command centre',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
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
          child: Column(
            children: [
              if (_usingFallback)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error ?? 'No incidents on the command centre yet — showing demo history.',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 16.0),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _IncidentTile(
                              incident: items[index],
                              isLast: index == items.length - 1,
                              statusColor: _statusColor(items[index]['status'] as String),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.incident,
    required this.isLast,
    required this.statusColor,
  });

  final Map<String, dynamic> incident;
  final bool isLast;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final isCritical = incident['isCritical'] as bool;
    final severity = incident['severity'] as String;

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
                child: isLast
                    ? const SizedBox.shrink()
                    : Container(width: 2, color: Colors.white10),
              ),
            ],
          ),
          const SizedBox(width: 16),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.white54),
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
                        const Icon(Icons.info_outline,
                            size: 14, color: Colors.white54),
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
                          color: isCritical
                              ? RoadSoSColors.critical
                              : RoadSoSColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          severity,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCritical
                                ? RoadSoSColors.critical
                                : RoadSoSColors.warning,
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
  }
}
