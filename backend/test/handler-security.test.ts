import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { describe, expect, it } from 'vitest';
import { handler } from '../src/api/handler';

function event(path: string, body?: string, isBase64Encoded = false): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: '$default',
    rawPath: path,
    rawQueryString: '',
    headers: {},
    requestContext: {
      accountId: 'anonymous',
      apiId: 'test',
      domainName: 'example.test',
      domainPrefix: 'example',
      http: { method: 'GET', path, protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
      requestId: 'test',
      routeKey: '$default',
      stage: '$default',
      time: '01/Jan/2026:00:00:00 +0000',
      timeEpoch: 0,
    },
    body,
    isBase64Encoded,
  };
}

describe('API router security boundaries', () => {
  it('rejects request bodies over 64 KiB before route dispatch', async () => {
    const result = await handler(event('/missing', 'a'.repeat(64 * 1024 + 1)));
    expect(result.statusCode).toBe(413);
    expect(JSON.parse(result.body ?? '{}').code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('rejects malformed percent encoding as a client error', async () => {
    const result = await handler(event('/users/%E0%A4%A/works'));
    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body ?? '{}').code).toBe('INVALID_PATH_ENCODING');
  });

  it('rejects malformed base64 request bodies', async () => {
    const result = await handler(event('/missing', 'not base64!', true));
    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body ?? '{}').code).toBe('INVALID_BASE64');
  });

  it('adds defensive headers to API responses', async () => {
    const result = await handler(event('/missing'));
    expect(result.headers).toMatchObject({
      'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
      'referrer-policy': 'no-referrer',
      'strict-transport-security': 'max-age=31536000; includeSubDomains',
    });
  });
});
