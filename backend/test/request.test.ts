import { describe, expect, it } from 'vitest';
import { ApiError } from '../src/lib/response';
import { parseJsonObject } from '../src/lib/request';

describe('parseJsonObject', () => {
  it('accepts a JSON object', () => {
    expect(parseJsonObject('{"public":true}')).toEqual({ public: true });
  });

  it.each(['null', '[]', '"text"', '1'])('rejects a non-object JSON value: %s', (raw) => {
    expect(() => parseJsonObject(raw)).toThrow(ApiError);
  });

  it('only accepts an empty body when explicitly allowed', () => {
    expect(parseJsonObject(undefined, { allowEmpty: true })).toEqual({});
    expect(() => parseJsonObject(undefined)).toThrow(ApiError);
  });
});
