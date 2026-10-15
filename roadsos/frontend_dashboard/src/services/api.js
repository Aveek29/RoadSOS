import axios from 'axios';

const BASE_URL = process.env.REACT_APP_API_URL || 'http://127.0.0.1:5000';

// Configure axios defaults
const client = axios.create({
  baseURL: BASE_URL,
  timeout: 10000, // 10 second timeout
  headers: { 'Content-Type': 'application/json' },
});

export const api = {
  getIncidents: async () => {
    try {
      const res = await client.get('/incidents');
      return res.data.data || [];
    } catch (err) {
      if (err.code === 'ECONNABORTED') {
        console.error('[API] Request timeout — backend may be down');
      } else {
        console.error('[API] Failed to fetch incidents:', err.message);
      }
      throw err;
    }
  },

  dispatch: async (type, incidentId) => {
    try {
      const res = await client.post('/dispatch', { incidentId, type });
      return res.data;
    } catch (err) {
      console.error(`[API] Failed to dispatch ${type}:`, err.message);
      return { success: false, error: err.response?.data?.error || err.message };
    }
  },

  updateStatus: async (incidentId, status) => {
    try {
      const res = await client.post('/update-status', { incidentId, status });
      return res.data;
    } catch (err) {
      console.error('[API] Failed to update status:', err.message);
      return { success: false, error: err.response?.data?.error || err.message };
    }
  },

  healthCheck: async () => {
    try {
      const res = await client.get('/health');
      return res.data;
    } catch (err) {
      return { status: 'UNREACHABLE' };
    }
  },

  getAnalytics: async () => {
    try {
      const res = await client.get('/analytics');
      return res.data;
    } catch (err) {
      console.error('[API] Failed to fetch analytics:', err.message);
      return {};
    }
  },

  simulateIncident: async (severityType) => {
    try {
      const res = await client.post('/demo/simulate', { severityType });
      return res.data;
    } catch (err) {
      console.error('[API] Failed to simulate incident:', err.message);
      return { success: false, error: err.response?.data?.error || err.message };
    }
  },

  clearDemoIncidents: async () => {
    try {
      const res = await client.post('/demo/clear');
      return res.data;
    } catch (err) {
      console.error('[API] Failed to clear demo incidents:', err.message);
      return { success: false, error: err.message };
    }
  },

  // --- ML accident-severity prediction (advisory) -------------------------
  modelHealth: async () => {
    try {
      const res = await client.get('/api/v1/model/health');
      return res.data;
    } catch (err) {
      // 503 is a legitimate "model down" signal, not a transport error
      if (err.response) return err.response.data;
      return { success: false, model: { available: false, state: 'unreachable' } };
    }
  },

  getPredictionSchema: async () => {
    try {
      const res = await client.get('/api/v1/predictions/schema');
      return res.data;
    } catch (err) {
      console.error('[API] Failed to fetch prediction schema:', err.message);
      return { success: false, error: err.response?.data?.error || err.message };
    }
  },

  predictSeverity: async (features) => {
    try {
      const res = await client.post('/api/v1/predictions/severity', { features });
      return res.data;
    } catch (err) {
      return {
        success: false,
        error: err.response?.data?.error || err.message,
        details: err.response?.data?.details,
        code: err.response?.data?.code,
        status: err.response?.status,
      };
    }
  },

  predictSeverityForIncident: async (incidentId, features) => {
    try {
      const res = await client.post(
        `/api/v1/incidents/${encodeURIComponent(incidentId)}/severity-prediction`,
        { features }
      );
      return res.data;
    } catch (err) {
      return {
        success: false,
        error: err.response?.data?.error || err.message,
        details: err.response?.data?.details,
        code: err.response?.data?.code,
        status: err.response?.status,
      };
    }
  },
};
