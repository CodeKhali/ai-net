import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

const responseTime = new Trend('get_agents_response_time');
const errorRate = new Rate('get_agents_error_rate');
const requestCount = new Counter('get_agents_requests');

export const options = {
  scenarios: {
    get_agents_load: {
      executor: 'constant-vus',
      vus: 100,
      duration: '60s',
    },
  },
  thresholds: {
    'get_agents_response_time': ['p(95)<500'],
    'get_agents_error_rate': ['rate<0.001'],
    'http_req_duration{scenario:get_agents_load}': ['p(95)<500', 'p(99)<1000'],
    'http_req_failed': ['rate<0.001'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const res = http.get(`${BASE_URL}/api/agents`, {
    headers: { 'Accept': 'application/json' },
  });
  
  responseTime.add(res.timings.duration);
  requestCount.add(1);
  
  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has agents array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body) || (body && typeof body === 'object');
      } catch {
        return false;
      }
    },
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  errorRate.add(!ok);
  sleep(0.1);
}
