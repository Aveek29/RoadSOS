// Unit tests for the advisory ML severity-prediction client.
//
// Run with: `cd app && flutter test test/severity_prediction_service_test.dart`
// (Requires the Flutter SDK — see docs/testing.md.)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roadsos_app/services/severity_prediction_service.dart';

void main() {
  group('AccidentScenario', () {
    test('serialises exactly the 14 backend feature names', () {
      const scenario = AccidentScenario(
        year: 2021,
        latitude: 13.0827,
        longitude: 80.2707,
        speedLimit: 30,
        hour: 15,
        dayOfWeek: 'Monday',
        month: 'Jan',
        junctionControl: 'Give way or uncontrolled',
        lightConditions: 'Daylight',
        roadSurfaceConditions: 'Dry',
        roadType: 'Single carriageway',
        urbanOrRuralArea: 'Urban',
        weatherConditions: 'Fine no high winds',
        vehicleType: 'Car',
      );

      final json = scenario.toJson();
      expect(json.keys.toSet(), {
        'Year',
        'Latitude',
        'Longitude',
        'Speed_limit',
        'Hour',
        'Day_of_Week',
        'Month',
        'Junction_Control',
        'Light_Conditions',
        'Road_Surface_Conditions',
        'Road_Type',
        'Urban_or_Rural_Area',
        'Weather_Conditions',
        'Vehicle_Type',
      });
      expect(json, containsPair('Year', 2021));
      expect(json, containsPair('Speed_limit', 30));
      expect(json, containsPair('Day_of_Week', 'Monday'));
    });
  });

  group('SeverityPredictionService', () {
    test('parses a successful prediction response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/predictions/severity');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('features'), isTrue);
        return http.Response(
          jsonEncode({
            'success': true,
            'prediction': {
              'severity': 'Slight',
              'probabilities': {'Fatal': 0.02, 'Serious': 0.17, 'Slight': 0.81},
              'classOrder': ['Fatal', 'Serious', 'Slight'],
              'predictedClassIndex': 2,
              'modelVersion': 'c4a7daf40b',
              'latencyMs': 12.4,
            },
            'model': {'name': 'road-accident-severity-prediction'},
            'persisted': false,
            'advisory': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = SeverityPredictionService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final outcome = await service.predictSeverity(_scenario());

      expect(outcome.ok, isTrue);
      expect(outcome.prediction!.severity, 'Slight');
      expect(outcome.prediction!.probabilities['Slight'], closeTo(0.81, 1e-9));
      expect(outcome.prediction!.classOrder, ['Fatal', 'Serious', 'Slight']);
      expect(outcome.persisted, isFalse);
    });

    test('maps a 400 validation error without throwing', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'success': false,
              'error': 'Invalid prediction request',
              'code': 'INVALID_FEATURES',
              'details': ['Speed_limit: must be one of [20, 30]'],
            }),
            400,
            headers: {'content-type': 'application/json'},
          ));

      final service = SeverityPredictionService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final outcome = await service.predictSeverity(_scenario());

      expect(outcome.ok, isFalse);
      expect(outcome.code, 'INVALID_FEATURES');
      expect(outcome.details, isNotEmpty);
      expect(outcome.error, 'Invalid prediction request');
    });

    test('never throws when the backend is unreachable', () async {
      final client = MockClient((request) async =>
          throw http.ClientException('connection refused'));
      final service = SeverityPredictionService(
        client: client,
        baseUrl: 'http://test.local',
      );

      final outcome = await service.predictSeverity(_scenario());
      expect(outcome.ok, isFalse);
      expect(outcome.code, 'UNREACHABLE');

      final health = await service.checkModelHealth();
      expect(health.available, isFalse);

      final schema = await service.fetchSchema();
      expect(schema, isNull);
    });

    test('parses the schema contract served to the UI', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'schemaVersion': '1.0.0',
              'input': {
                'numericFeatures': [
                  'Year',
                  'Latitude',
                  'Longitude',
                  'Speed_limit',
                  'Hour',
                ],
                'categoricalFeatures': {
                  'Day_of_Week': {
                    'values': ['Monday', 'Friday'],
                    'baseline': 'Friday',
                  },
                },
              },
              'output': {
                'classOrder': ['Fatal', 'Serious', 'Slight'],
                'nFeatures': 61,
              },
              'speedLimitAllowed': [20, 30, 40],
              'limits': {
                'yearMin': 1900,
                'yearMax': 2100,
                'hourMin': 0,
                'hourMax': 23,
                'latitudeMin': -90.0,
                'latitudeMax': 90.0,
                'longitudeMin': -180.0,
                'longitudeMax': 180.0,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final service = SeverityPredictionService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final schema = await service.fetchSchema();

      expect(schema, isNotNull);
      expect(schema!.numericFeatures, hasLength(5));
      expect(schema.categoricalFeatures['Day_of_Week'], ['Monday', 'Friday']);
      expect(schema.classOrder, ['Fatal', 'Serious', 'Slight']);
      expect(schema.speedLimitAllowed, [20, 30, 40]);
      expect(schema.limit('hourMax'), 23);
      expect(schema.limit('latitudeMin'), -90.0);
      expect(schema.limit('notAPublishedLimit'), isNull);
    });

    test('tolerates a schema without speedLimitAllowed or limits', () async {
      // Older/partial backends, or a proxy that strips fields, must not crash
      // the client: absent restrictions degrade to "no restriction".
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'input': {'numericFeatures': [], 'categoricalFeatures': {}},
              'output': {'classOrder': ['Fatal', 'Serious', 'Slight']},
              'limits': {'hourMax': null},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final service = SeverityPredictionService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final schema = await service.fetchSchema();

      expect(schema, isNotNull);
      expect(schema!.speedLimitAllowed, isEmpty);
      expect(schema.limits, isEmpty); // null values are dropped
      expect(schema.limit('hourMax'), isNull);
    });
  });
}

AccidentScenario _scenario() => const AccidentScenario(
      year: 2021,
      latitude: 13.0827,
      longitude: 80.2707,
      speedLimit: 30,
      hour: 15,
      dayOfWeek: 'Monday',
      month: 'Jan',
      junctionControl: 'Give way or uncontrolled',
      lightConditions: 'Daylight',
      roadSurfaceConditions: 'Dry',
      roadType: 'Single carriageway',
      urbanOrRuralArea: 'Urban',
      weatherConditions: 'Fine no high winds',
      vehicleType: 'Car',
    );
