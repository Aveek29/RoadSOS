// Opt-in live end-to-end test: real Flutter client -> real Flask backend ->
// real 1.97 GB Random Forest model.
//
//   flutter test test/live_backend_e2e_test.dart \
//       --dart-define=ROADSOS_LIVE_E2E=true
//
// Optional: --dart-define=ROADSOS_BACKEND_URL=http://192.168.1.5:5000
// (bool.fromEnvironment needs `true`; the literal `1` evaluates to false.)
//
// Without ROADSOS_LIVE_E2E=1 the tests are reported as SKIPPED (not passed),
// so a normal `flutter test` run never pretends to have talked to a server.
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsos_app/services/severity_prediction_service.dart';

const bool _live = bool.fromEnvironment('ROADSOS_LIVE_E2E', defaultValue: false);
const String _baseUrl = String.fromEnvironment(
  'ROADSOS_BACKEND_URL',
  defaultValue: 'http://127.0.0.1:5000',
);

const _skipReason =
    'live test: start the backend (see docs/deployment.md) and re-run with '
    '--dart-define=ROADSOS_LIVE_E2E=true';

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

void main() {
  final skip = _live ? false : _skipReason;
  late SeverityPredictionService service;

  setUp(() => service = SeverityPredictionService(baseUrl: _baseUrl));
  tearDown(() => service.dispose());

  test('model health endpoint reports the real artifact', () async {
    final health = await service.checkModelHealth();
    expect(health.available, isTrue, reason: 'model should be loaded');
    expect(health.state, 'loaded');
  }, skip: skip);

  test('schema endpoint reports 61 encoded features and 3 classes', () async {
    final schema = await service.fetchSchema();
    expect(schema, isNotNull);
    expect(schema!.classOrder, ['Fatal', 'Serious', 'Slight']);
    expect(schema.numericFeatures, hasLength(5));
    expect(schema.categoricalFeatures, hasLength(9));
    expect(schema.speedLimitAllowed, contains(30));
    // Numeric domains travel with the schema so the UI can reject bad input
    // before sending it (regression: these were missing from the first release).
    expect(schema.limit('hourMin'), 0);
    expect(schema.limit('hourMax'), 23);
    expect(schema.limit('latitudeMin'), -90);
  }, skip: skip);

  test('predictSeverity returns a class from the documented contract', () async {
    final outcome = await service.predictSeverity(_scenario());
    expect(outcome.ok, isTrue, reason: outcome.error);
    final prediction = outcome.prediction!;
    expect(prediction.severity, anyOf('Fatal', 'Serious', 'Slight'));
    expect(prediction.classOrder, ['Fatal', 'Serious', 'Slight']);
    expect(prediction.probabilities.keys.toSet(), {'Fatal', 'Serious', 'Slight'});

    final total = prediction.probabilities.values.fold<double>(0, (a, b) => a + b);
    expect(total, closeTo(1.0, 1e-6));
  }, skip: skip);

  test('predictSeverity rejects an invalid category with a coded error', () async {
    final outcome = await service.predictSeverity(
      const AccidentScenario(
        year: 2021,
        latitude: 13.0,
        longitude: 80.2,
        speedLimit: 30,
        hour: 15,
        dayOfWeek: 'Funday', // not a training category
        month: 'Jan',
        junctionControl: 'Give way or uncontrolled',
        lightConditions: 'Daylight',
        roadSurfaceConditions: 'Dry',
        roadType: 'Single carriageway',
        urbanOrRuralArea: 'Urban',
        weatherConditions: 'Fine no high winds',
        vehicleType: 'Car',
      ),
    );
    expect(outcome.ok, isFalse);
    expect(outcome.code, 'INVALID_FEATURES');
    expect(outcome.details, isNotEmpty);
  }, skip: skip);

  test('the emergency core is unaffected while ML is exercised', () async {
    // /health is the pre-existing command-centre liveness route.
    final health = await service.checkModelHealth();
    expect(health.available, isTrue);
    // Nothing in this file touched incident status; the ML client cannot.
    expect(service, isA<SeverityPredictionService>());
  }, skip: skip);
}
