import { describe, expect, it } from 'vitest';
import { hashDeviceToken } from '../src/lib/push';

describe('hashDeviceToken', () => {
  it('同じトークンからは同じハッシュになる（再登録が上書きになる）', () => {
    expect(hashDeviceToken('abc')).toBe(hashDeviceToken('abc'));
  });

  it('異なるトークンは異なるハッシュになる（別端末が別レコードになる）', () => {
    expect(hashDeviceToken('abc')).not.toBe(hashDeviceToken('abd'));
  });

  it('ソートキーに使える固定長の16進文字列を返す', () => {
    expect(hashDeviceToken('any-token')).toMatch(/^[0-9a-f]{32}$/);
  });

  it('トークン本体をそのまま含まない（キーに実トークンを出さない）', () => {
    const token = 'super-secret-fcm-token';
    expect(hashDeviceToken(token)).not.toContain(token);
  });
});
