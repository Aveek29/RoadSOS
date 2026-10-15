import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roadsos_app/services/severity_prediction_service.dart';
import 'package:roadsos_app/ui/components.dart';
import 'package:roadsos_app/ui/theme.dart';

/// Advisory accident-severity predictor (Random Forest model).
///
/// This screen is a *planning/after-the-fact* tool: it estimates historical
/// accident severity (Slight / Serious / Fatal) from road, weather, light,
/// speed and location inputs. It is deliberately isolated from crash
/// detection, countdowns and dispatch — a failed or slow prediction only ever
/// shows a message here and never delays an emergency response.
class SeverityPredictionScreen extends StatefulWidget {
  const SeverityPredictionScreen({super.key, this.incidentId});

  /// When set, the prediction is also attached to that incident (advisory
  /// field only — the backend never mutates incident status).
  final String? incidentId;

  @override
  State<SeverityPredictionScreen> createState() =>
      _SeverityPredictionScreenState();
}

class _SeverityPredictionScreenState extends State<SeverityPredictionScreen> {
  final SeverityPredictionService _service = SeverityPredictionService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  PredictionSchema? _schema;
  ModelHealth _health = const ModelHealth(available: false, state: 'checking');
  bool _loadingSchema = true;

  bool _loading = false;
  PredictionOutcome? _outcome;
  String? _notice;

  // Numeric inputs (kept as text so the user can type freely).
  final Map<String, TextEditingController> _numeric = {
    'Year': TextEditingController(text: '2021'),
    'Hour': TextEditingController(text: '15'),
    'Speed_limit': TextEditingController(text: '30'),
    'Latitude': TextEditingController(text: '13.0827'),
    'Longitude': TextEditingController(text: '80.2707'),
  };

  final Map<String, String> _categories = {};

  static const Map<String, String> _labels = {
    'Day_of_Week': 'Day of week',
    'Month': 'Month',
    'Junction_Control': 'Junction control',
    'Light_Conditions': 'Light conditions',
    'Road_Surface_Conditions': 'Road surface',
    'Road_Type': 'Road type',
    'Urban_or_Rural_Area': 'Urban / rural',
    'Weather_Conditions': 'Weather',
    'Vehicle_Type': 'Vehicle type',
  };

  static const Map<String, TextInputType> _keyboard = {
    'Year': TextInputType.number,
    'Hour': TextInputType.number,
    'Speed_limit': TextInputType.number,
    'Latitude': TextInputType.numberWithOptions(decimal: true),
    'Longitude': TextInputType.numberWithOptions(decimal: true),
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final health = await _service.checkModelHealth();
    final schema = await _service.fetchSchema();
    if (!mounted) return;
    setState(() {
      _health = health;
      _schema = schema;
      _loadingSchema = false;
      if (schema != null) {
        schema.categoricalFeatures.forEach((feature, values) {
          _categories[feature] = values.first;
        });
        // Speed limits are a closed set from the training data — snap the
        // stored value onto it so a stale/invalid value can never be sent.
        final allowed = schema.speedLimitAllowed;
        if (allowed.isNotEmpty &&
            !allowed.contains(int.tryParse(_numeric['Speed_limit']!.text))) {
          _numeric['Speed_limit']!.text =
              allowed.contains(30) ? '30' : allowed.first.toString();
        }
      } else {
        _notice =
            'Prediction service unavailable — backend unreachable or model not loaded. '
            'Emergency detection and alerts are unaffected.';
      }
    });
  }

  @override
  void dispose() {
    for (final c in _numeric.values) {
      c.dispose();
    }
    _service.dispose();
    super.dispose();
  }

  AccidentScenario? _buildScenario() {
    final schema = _schema;
    if (schema == null) return null;
    try {
      return AccidentScenario(
        year: int.parse(_numeric['Year']!.text.trim()),
        latitude: double.parse(_numeric['Latitude']!.text.trim()),
        longitude: double.parse(_numeric['Longitude']!.text.trim()),
        speedLimit: int.parse(_numeric['Speed_limit']!.text.trim()),
        hour: int.parse(_numeric['Hour']!.text.trim()),
        dayOfWeek: _categories['Day_of_Week'] ?? '',
        month: _categories['Month'] ?? '',
        junctionControl: _categories['Junction_Control'] ?? '',
        lightConditions: _categories['Light_Conditions'] ?? '',
        roadSurfaceConditions: _categories['Road_Surface_Conditions'] ?? '',
        roadType: _categories['Road_Type'] ?? '',
        urbanOrRuralArea: _categories['Urban_or_Rural_Area'] ?? '',
        weatherConditions: _categories['Weather_Conditions'] ?? '',
        vehicleType: _categories['Vehicle_Type'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns a human-readable message when a numeric value is outside the
  /// domain the server published — checked *before* sending so the user gets
  /// a local message instead of a round-trip 400.
  String? _rangeError(PredictionSchema schema) {
    final year = int.tryParse(_numeric['Year']!.text.trim());
    final hour = int.tryParse(_numeric['Hour']!.text.trim());
    final lat = double.tryParse(_numeric['Latitude']!.text.trim());
    final lon = double.tryParse(_numeric['Longitude']!.text.trim());
    if (year == null || hour == null || lat == null || lon == null) {
      return 'Please enter valid numbers for all numeric fields.';
    }
    String? fail(String field, num value, String limitKeyMin, String limitKeyMax) {
      final min = schema.limit(limitKeyMin);
      final max = schema.limit(limitKeyMax);
      if (min != null && value < min) return '$field must be $min or more.';
      if (max != null && value > max) return '$field must be $max or less.';
      return null;
    }

    final speed = int.tryParse(_numeric['Speed_limit']!.text.trim());
    final allowed = schema.speedLimitAllowed;
    if (speed == null ||
        (allowed.isNotEmpty && !allowed.contains(speed))) {
      return allowed.isEmpty
          ? 'Please enter a valid speed limit.'
          : 'Speed limit must be one of: ${allowed.join(', ')} mph.';
    }

    return fail('Year', year, 'yearMin', 'yearMax') ??
        fail('Hour', hour, 'hourMin', 'hourMax') ??
        fail('Latitude', lat, 'latitudeMin', 'latitudeMax') ??
        fail('Longitude', lon, 'longitudeMin', 'longitudeMax');
  }

  Future<void> _run() async {
    final schema = _schema;
    if (schema != null) {
      final rangeError = _rangeError(schema);
      if (rangeError != null) {
        setState(() => _notice = rangeError);
        return;
      }
    }
    final scenario = _buildScenario();
    if (scenario == null) {
      setState(() => _notice = 'Please enter valid numbers for all numeric fields.');
      return;
    }
    setState(() {
      _loading = true;
      _notice = null;
      _outcome = null;
    });

    final outcome = widget.incidentId != null
        ? await _service.predictForIncident(widget.incidentId!, scenario)
        : await _service.predictSeverity(scenario);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _outcome = outcome;
      if (!outcome.ok && outcome.code == 'UNREACHABLE') {
        _health = const ModelHealth(available: false, state: 'unreachable');
      }
    });
  }

  Color _severityColor(String severity) => switch (severity) {
        'Fatal' => RoadSoSColors.critical,
        'Serious' => RoadSoSColors.warning,
        _ => RoadSoSColors.success,
      };

  static String _shortRevision(String revision) =>
      revision.length > 10 ? revision.substring(0, 10) : revision;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadSoSColors.bgDeepDark,
      appBar: AppBar(
        title: const Text('Severity Predictor'),
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
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_loadingSchema) _buildBusy() else if (_schema == null)
                _buildUnavailable()
              else
                _buildForm(),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _buildNotice(_notice!),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                _buildBusy(),
              ],
              if (_outcome != null) ...[
                const SizedBox(height: 16),
                _outcome!.ok
                    ? _buildResult(_outcome!.prediction!)
                    : _buildError(_outcome!),
              ],
              const SizedBox(height: 24),
              const Text(
                'The estimate is produced by the published Random Forest accident-severity '
                'model from historical structured data. It is advisory only: not a confirmed '
                'outcome, not a medical assessment, and never a dispatch instruction.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.white38,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final online = _health.available;
    return GlassCard(
      borderRadius: 20,
      borderColor: Colors.white.withOpacity(0.06),
      fillColor: Colors.white.withOpacity(0.02),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Accident Severity Analysis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (online ? RoadSoSColors.success : RoadSoSColors.critical)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  online ? 'MODEL ONLINE' : 'MODEL OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: online
                        ? RoadSoSColors.success
                        : RoadSoSColors.critical,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estimates Slight / Serious / Fatal severity from road, weather, light, '
            'speed and location inputs using the trained Random Forest model. '
            'Optional and separate from live crash detection.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusy() {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
        SizedBox(width: 10),
        Text('Working…',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }

  Widget _buildUnavailable() {
    return GlassCard(
      borderRadius: 16,
      borderColor: RoadSoSColors.warning.withOpacity(0.4),
      fillColor: RoadSoSColors.warning.withOpacity(0.06),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: RoadSoSColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Prediction service unavailable. This is optional — crash detection, '
              'alerts and dispatch keep working normally.',
              style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RoadSoSColors.warning.withOpacity(0.08),
        border: Border.all(color: RoadSoSColors.warning.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: RoadSoSColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: RoadSoSColors.warning,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final schema = _schema!;
    return Form(
      key: _formKey,
      child: GlassCard(
        borderRadius: 20,
        borderColor: Colors.white.withOpacity(0.06),
        fillColor: Colors.white.withOpacity(0.02),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in _numeric.entries)
                  if (!(entry.key == 'Speed_limit' &&
                      schema.speedLimitAllowed.isNotEmpty))
                    SizedBox(
                      width: 150,
                      child: _numericField(entry.key, entry.value),
                    ),
                if (schema.speedLimitAllowed.isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: _speedDropdown(schema.speedLimitAllowed),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in schema.categoricalFeatures.entries)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _categories[entry.key],
                      isExpanded: true,
                      dropdownColor: RoadSoSColors.bgElevatedDark,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _labels[entry.key] ?? entry.key,
                        labelStyle:
                            const TextStyle(fontSize: 12, color: Colors.white54),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: RoadSoSColors.success),
                        ),
                      ),
                      items: [
                        for (final value in entry.value)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _categories[entry.key] = v;
                          _outcome = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoadSoSColors.success,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  widget.incidentId != null
                      ? 'Predict & attach to incident'
                      : 'Run severity analysis',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numericField(String name, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: _keyboard[name] ?? TextInputType.number,
      inputFormatters: [
        if (name == 'Latitude' || name == 'Longitude')
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(fontSize: 13, color: Colors.white),
      decoration: InputDecoration(
        labelText: _labels[name] ?? name.replaceAll('_', ' '),
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white54),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RoadSoSColors.success),
        ),
      ),
      onChanged: (_) => setState(() => _outcome = null),
    );
  }

  /// Speed limits come from a closed set in the training data, so use a select
  /// (with a guaranteed-valid fallback) instead of a free-text number box.
  Widget _speedDropdown(List<int> allowed) {
    final current = int.tryParse(_numeric['Speed_limit']!.text.trim());
    final value = allowed.contains(current) ? current : allowed.first;
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      dropdownColor: RoadSoSColors.bgElevatedDark,
      style: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Speed limit (mph)',
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white54),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RoadSoSColors.success),
        ),
      ),
      items: [
        for (final v in allowed)
          DropdownMenuItem(value: v, child: Text('$v mph')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _numeric['Speed_limit']!.text = v.toString();
          _outcome = null;
          _notice = null;
        });
      },
    );
  }

  Widget _buildResult(SeverityPrediction prediction) {
    final color = _severityColor(prediction.severity);
    return GlassCard(
      borderRadius: 20,
      borderColor: color.withOpacity(0.45),
      fillColor: color.withOpacity(0.06),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREDICTED SEVERITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Colors.white54,
                ),
              ),
              Text(
                prediction.severity.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final cls in prediction.classOrder)
            _probabilityBar(
              cls,
              prediction.probabilities[cls] ?? 0.0,
              _severityColor(cls),
            ),
          const SizedBox(height: 12),
          Text(
            'Model${prediction.modelVersion.isEmpty ? '' : ' rev ${_shortRevision(prediction.modelVersion)}'}'
            ' · ${prediction.latencyMs.toStringAsFixed(1)} ms · advisory estimate only',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          if (widget.incidentId != null && _outcome!.persisted == false)
            const Text(
              'Not persisted (backend store offline) — shown locally only.',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  Widget _probabilityBar(String label, double value, Color color) {
    final pct = (value * 100).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(PredictionOutcome outcome) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RoadSoSColors.critical.withOpacity(0.08),
        border: Border.all(color: RoadSoSColors.critical.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 16, color: RoadSoSColors.critical),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  outcome.error ?? 'Prediction failed',
                  style: TextStyle(
                      fontSize: 12,
                      color: RoadSoSColors.critical,
                      height: 1.4),
                ),
              ),
            ],
          ),
          if (outcome.details != null && outcome.details!.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final d in outcome.details!.take(5))
              Text('• $d',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
          const SizedBox(height: 6),
          const Text(
            'Emergency detection, alerts and dispatch are unaffected.',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
