/**
 * Contract tests for the advisory ML methods on the dashboard API client.
 *
 *   cd frontend_dashboard && CI=true npm test -- --watchAll=false
 *
 * axios is mocked, so these tests assert the *client contract* (paths, payload
 * shape, error mapping) without needing a running backend.
 */

import axios from 'axios';
import { api } from './api';

// axios is mocked: these tests assert the *client contract* (paths, payload
// shape, error mapping) without needing a running backend. jest.mock is
// hoisted above the imports by babel-plugin-jest-hoist.
jest.mock('axios', () => {
  const instance = { get: jest.fn(), post: jest.fn() };
  return { create: jest.fn(() => instance) };
});

const client = axios.create.mock.results[0].value;

const FEATURES = {
  Year: 2021,
  Latitude: 51.5074,
  Longitude: -0.1278,
  Speed_limit: 30,
  Hour: 15,
  Day_of_Week: 'Monday',
  Month: 'Jan',
  Junction_Control: 'Give way or uncontrolled',
  Light_Conditions: 'Daylight',
  Road_Surface_Conditions: 'Dry',
  Road_Type: 'Single carriageway',
  Urban_or_Rural_Area: 'Urban',
  Weather_Conditions: 'Fine no high winds',
  Vehicle_Type: 'Car',
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe('ML prediction client', () => {
  test('predictSeverity POSTs { features } to the severity endpoint', async () => {
    client.post.mockResolvedValue({
      data: {
        success: true,
        prediction: {
          severity: 'Slight',
          probabilities: { Fatal: 0.02, Serious: 0.17, Slight: 0.81 },
          classOrder: ['Fatal', 'Serious', 'Slight'],
          latencyMs: 12.4,
        },
        advisory: true,
      },
    });

    const res = await api.predictSeverity(FEATURES);

    expect(client.post).toHaveBeenCalledWith('/api/v1/predictions/severity', {
      features: FEATURES,
    });
    expect(res.prediction.severity).toBe('Slight');
    expect(res.advisory).toBe(true);
  });

  test('predictSeverity surfaces backend validation errors without throwing', async () => {
    client.post.mockRejectedValue({
      message: 'Request failed with status code 400',
      response: {
        status: 400,
        data: {
          success: false,
          error: 'Invalid prediction request',
          code: 'INVALID_FEATURES',
          details: ["Speed_limit: must be one of [10, 15, 20, 30, 40, 50, 60, 70]"],
        },
      },
    });

    const res = await api.predictSeverity(FEATURES);

    expect(res.success).toBe(false);
    expect(res.code).toBe('INVALID_FEATURES');
    expect(res.status).toBe(400);
    expect(res.details).toHaveLength(1);
  });

  test('predictSeverityForIncident URL-encodes the incident id', async () => {
    client.post.mockResolvedValue({ data: { success: true, persisted: false } });

    await api.predictSeverityForIncident('abc/123 xyz', FEATURES);

    expect(client.post).toHaveBeenCalledWith(
      '/api/v1/incidents/abc%2F123%20xyz/severity-prediction',
      { features: FEATURES }
    );
  });

  test('predictSeverityForIncident reports MODEL_UNAVAILABLE', async () => {
    client.post.mockRejectedValue({
      message: 'Request failed with status code 503',
      response: {
        status: 503,
        data: { success: false, error: 'model down', code: 'MODEL_UNAVAILABLE' },
      },
    });

    const res = await api.predictSeverityForIncident('inc1', FEATURES);

    expect(res.success).toBe(false);
    expect(res.code).toBe('MODEL_UNAVAILABLE');
  });

  test('modelHealth treats a 503 as a valid "model down" signal', async () => {
    client.get.mockRejectedValue({
      message: 'Request failed with status code 503',
      response: {
        status: 503,
        data: { success: true, model: { available: false, state: 'missing' } },
      },
    });

    const res = await api.modelHealth();

    expect(client.get).toHaveBeenCalledWith('/api/v1/model/health');
    expect(res.model.available).toBe(false);
    expect(res.model.state).toBe('missing');
  });

  test('modelHealth reports unreachable when there is no HTTP response', async () => {
    client.get.mockRejectedValue({ message: 'Network Error' });

    const res = await api.modelHealth();

    expect(res.success).toBe(false);
    expect(res.model.available).toBe(false);
    expect(res.model.state).toBe('unreachable');
  });

  test('getPredictionSchema returns the schema document', async () => {
    client.get.mockResolvedValue({
      data: {
        success: true,
        input: {
          numericFeatures: ['Year', 'Latitude', 'Longitude', 'Speed_limit', 'Hour'],
          categoricalFeatures: {
            Day_of_Week: { values: ['Friday', 'Monday'], baseline: 'Friday' },
          },
        },
        output: { classOrder: ['Fatal', 'Serious', 'Slight'], nFeatures: 61 },
      },
    });

    const res = await api.getPredictionSchema();

    expect(client.get).toHaveBeenCalledWith('/api/v1/predictions/schema');
    expect(res.input.categoricalFeatures.Day_of_Week.values).toContain('Monday');
    expect(res.output.nFeatures).toBe(61);
  });

  test('getPredictionSchema degrades to a failure object when the backend is down', async () => {
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    client.get.mockRejectedValue({ message: 'Network Error' });

    const res = await api.getPredictionSchema();

    expect(res.success).toBe(false);
    expect(res.error).toBe('Network Error');
    spy.mockRestore();
  });
});
