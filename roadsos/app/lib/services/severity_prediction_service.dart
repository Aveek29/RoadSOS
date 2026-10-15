/// Optional ML accident-severity prediction client (advisory only).
///
/// Talks to the RoadSOS backend inference endpoints:
///   * `GET  /api/v1/model/health`
///   * `GET  /api/v1/predictions/schema`
///   * `POST /api/v1/predictions/severity`
///   * `POST /api/v1/incidents/<id>/severity-prediction`
///
/// SAFETY CONTRACT
/// ---------------
/// Nothing in this file participates in crash detection, countdowns, SMS,
/// notifications or dispatch. Every public method is total: it catches its own
/// errors and returns a result object, so a missing backend, a slow model or a
/// malformed response can never throw into an emergency workflow.
///
/// The prediction itself is a statistical estimate (Slight / Serious / Fatal)
/// produced from historical structured accident data — it is not a live crash
/// assessment and never mutates incident status.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Backend address. `10.0.2.2` is the Android emulator's alias for the host
/// machine's localhost — same convention as `SocketService`.
/// Override at build time with:
/// `flutter run --dart-define=ROADSOS_BACKEND_URL=http://192.168.1.20:5000`
const String kBackendBaseUrl = String.fromEnvironment(
  'ROADSOS_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// The 14 raw features the model contract accepts (5 numeric + 9 categorical).
/// Names match the backend schema exactly — they are not re-derived here.
class AccidentScenario {
  const AccidentScenario({
    required this.year,
    required this.latitude,
    required this.longitude,
    required this.speedLimit,
    required this.hour,
    required this.dayOfWeek,
    required this.month,
    required this.junctionControl,
    required this.lightConditions,
    required this.roadSurfaceConditions,
    required this.roadType,
    required this.urbanOrRuralArea,
    required this.weatherConditions,
    required this.vehicleType,
  });

  final int year;
  final double latitude;
  final double longitude;
  final int speedLimit;
  final int hour;
  final String dayOfWeek;
  final String month;
  final String junctionControl;
  final String lightConditions;
  final String roadSurfaceConditions;
  final String roadType;
  final String urbanOrRuralArea;
  final String weatherConditions;
  final String vehicleType;

  Map<String, dynamic> toJson() => {
        'Year': year,
        'Latitude': latitude,
        'Longitude': longitude,
        'Speed_limit': speedLimit,
        'Hour': hour,
        'Day_of_Week': dayOfWeek,
        'Month': month,
        'Junction_Control': junctionControl,
        'Light_Conditions': lightConditions,
        'Road_Surface_Conditions': roadSurfaceConditions,
        'Road_Type': roadType,
        'Urban_or_Rural_Area': urbanOrRuralArea,
        'Weather_Conditions': weatherConditions,
        'Vehicle_Type': vehicleType,
      };
}

/// Predicted severity result: class label plus the model's vote distribution.
class SeverityPrediction {
  const SeverityPrediction({
    required this.severity,
    required this.probabilities,
    required this.classOrder,
    required this.modelVersion,
    required this.latencyMs,
    this.predictedIndex = -1,
  });

  final String severity;
  final Map<String, double> probabilities;
  final List<String> classOrder;
  final String modelVersion;
  final double latencyMs;
  final int predictedIndex;

  factory SeverityPrediction.fromJson(Map<String, dynamic> json) {
    final rawProbs = (json['probabilities'] as Map?) ?? const {};
    return SeverityPrediction(
      severity: json['severity'] as String? ?? 'unknown',
      probabilities: rawProbs.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
      classOrder: (json['classOrder'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Fatal', 'Serious', 'Slight'],
      modelVersion: json['modelVersion'] as String? ?? '',
      latencyMs: (json['latencyMs'] as num?)?.toDouble() ?? 0.0,
      predictedIndex: (json['predictedClassIndex'] as num?)?.toInt() ?? -1,
    );
  }
}

/// Input contract served by `/api/v1/predictions/schema`.
/// The UI renders its dropdowns from this — categories are never hard-coded.
class PredictionSchema {
  const PredictionSchema({
    required this.numericFeatures,
    required this.categoricalFeatures,
    required this.classOrder,
    required this.speedLimitAllowed,
    this.limits = const {},
  });

  final List<String> numericFeatures;
  final Map<String, List<String>> categoricalFeatures;
  final List<String> classOrder;
  final List<int> speedLimitAllowed;

  /// Numeric domains published by the server, e.g. `hourMin`, `hourMax`,
  /// `yearMin`, `latitudeMax`… Used to reject bad input *before* it is sent.
  final Map<String, num> limits;

  /// `null` when the server did not publish that limit.
  num? limit(String key) => limits[key];

  factory PredictionSchema.fromJson(Map<String, dynamic> json) {
    final input = (json['input'] as Map?) ?? const {};
    final categorical = (input['categoricalFeatures'] as Map?) ?? const {};
    final output = (json['output'] as Map?) ?? const {};
    final rawLimits = (json['limits'] as Map?) ?? const {};
    return PredictionSchema(
      numericFeatures: (input['numericFeatures'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      categoricalFeatures: categorical.map(
        (key, value) => MapEntry(
          key.toString(),
          ((value as Map)['values'] as List)
              .map((e) => e.toString())
              .toList(),
        ),
      ),
      classOrder: (output['classOrder'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Fatal', 'Serious', 'Slight'],
      speedLimitAllowed: (json['speedLimitAllowed'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      limits: {
        for (final e in rawLimits.entries)
          if (e.value is num) e.key.toString(): e.value as num,
      },
    );
  }

  /// Preferred starting value for a category (schema baseline, else first).
  String baselineFor(String feature) => categoricalFeatures[feature]?.first ?? '';
}

/// Model availability reported by `/api/v1/model/health`.
class ModelHealth {
  const ModelHealth({required this.available, required this.state});

  final bool available;
  final String state;

  factory ModelHealth.fromJson(Map<String, dynamic> json) {
    final model = (json['model'] as Map?) ?? const {};
    return ModelHealth(
      available: model['available'] == true,
      state: model['state']?.toString() ?? 'unknown',
    );
  }
}

/// Uniform, non-throwing outcome wrapper for prediction calls.
class PredictionOutcome {
  const PredictionOutcome.success(this.prediction, {this.persisted = true})
      : ok = true,
        error = null,
        details = null,
        code = null;

  const PredictionOutcome.failure({
    required this.error,
    this.details,
    this.code,
  })  : ok = false,
        prediction = null,
        persisted = false;

  final bool ok;
  final SeverityPrediction? prediction;
  final String? error;
  final List<String>? details;
  final String? code;
  final bool persisted;
}

class SeverityPredictionService {
  SeverityPredictionService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? kBackendBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  // Generous: the first inference after a cold start waits for the model to
  // load (~7-10 s), and the backend warms it at startup.
  static const Duration _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Model health. Never throws — unreachable backend ⇒ `available: false`.
  Future<ModelHealth> checkModelHealth() async {
    try {
      final res = await _client
          .get(_uri('/api/v1/model/health'))
          .timeout(_timeout);
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) return ModelHealth.fromJson(body);
      return const ModelHealth(available: false, state: 'bad_response');
    } catch (_) {
      return const ModelHealth(available: false, state: 'unreachable');
    }
  }

  /// Input contract. Returns `null` when the backend/schema cannot be reached;
  /// callers must treat that as "feature unavailable", never as an emergency.
  Future<PredictionSchema?> fetchSchema() async {
    try {
      final res = await _client
          .get(_uri('/api/v1/predictions/schema'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic> && body['success'] == true) {
        return PredictionSchema.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Standalone scenario prediction.
  Future<PredictionOutcome> predictSeverity(AccidentScenario scenario) =>
      _post('/api/v1/predictions/severity', scenario);

  /// Prediction attached to an existing incident (advisory field only — the
  /// backend never changes the incident's status or escalation).
  Future<PredictionOutcome> predictForIncident(
    String incidentId,
    AccidentScenario scenario,
  ) =>
      _post(
        '/api/v1/incidents/${Uri.encodeComponent(incidentId)}/severity-prediction',
        scenario,
      );

  Future<PredictionOutcome> _post(String path, AccidentScenario scenario) async {
    try {
      final res = await _client
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'features': scenario.toJson()}),
          )
          .timeout(_timeout);

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map<String, dynamic>) {
        return const PredictionOutcome.failure(
          error: 'Malformed response from backend',
          code: 'BAD_RESPONSE',
        );
      }

      if (res.statusCode == 200 && body['success'] == true) {
        final prediction = body['prediction'];
        if (prediction is! Map<String, dynamic>) {
          return const PredictionOutcome.failure(
            error: 'Response did not contain a prediction',
            code: 'BAD_RESPONSE',
          );
        }
        return PredictionOutcome.success(
          SeverityPrediction.fromJson(prediction),
          persisted: body['persisted'] == true,
        );
      }

      final details = body['details'];
      return PredictionOutcome.failure(
        error: body['error']?.toString() ?? 'Prediction request failed',
        details: details is List ? details.map((e) => e.toString()).toList() : null,
        code: body['code']?.toString(),
      );
    } on TimeoutException {
      return const PredictionOutcome.failure(
        error: 'Prediction timed out — backend or model still starting',
        code: 'TIMEOUT',
      );
    } catch (_) {
      // Deliberately swallowed: an ML outage must never propagate into the
      // emergency flow. The UI shows the message; detection keeps running.
      return const PredictionOutcome.failure(
        error: 'Could not reach the prediction service',
        code: 'UNREACHABLE',
      );
    }
  }

  void dispose() => _client.close();
}
