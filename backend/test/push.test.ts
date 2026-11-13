import { describe, expect, it } from "vitest";
import { hashDeviceToken, invalidFcmRegistration } from "../src/lib/push";

describe("hashDeviceToken", () => {
  it("同じトークンからは同じハッシュになる（再登録が上書きになる）", () => {
    expect(hashDeviceToken("abc")).toBe(hashDeviceToken("abc"));
  });

  it("異なるトークンは異なるハッシュになる（別端末が別レコードになる）", () => {
    expect(hashDeviceToken("abc")).not.toBe(hashDeviceToken("abd"));
  });

  it("ソートキーに使える固定長の16進文字列を返す", () => {
    expect(hashDeviceToken("any-token")).toMatch(/^[0-9a-f]{32}$/);
  });

  it("トークン本体をそのまま含まない（キーに実トークンを出さない）", () => {
    const token = "super-secret-fcm-token";
    expect(hashDeviceToken(token)).not.toContain(token);
  });
});

describe("FCM token cleanup guards", () => {
  const errorBody = (status: string, type: string, code: string) =>
    JSON.stringify({
      error: { status, details: [{
        "@type": type, errorCode: code,
      }] },
    });
  const fcmType = "type.googleapis.com/google.firebase.fcm.v1.FcmError";
  const requestType = "type.googleapis.com/google.rpc.BadRequest";

  it("deletes only a verified UNREGISTERED 404", () => {
    expect(invalidFcmRegistration(404,
      JSON.stringify({ error: { status: "UNREGISTERED" } }))).toBe(true);
    expect(invalidFcmRegistration(404,
      JSON.stringify({ error: { status: "NOT_FOUND" } }))).toBe(false);
    expect(invalidFcmRegistration(404, "")).toBe(false);
  });

  it("deletes only a typed invalid registration token 400", () => {
    expect(invalidFcmRegistration(400,
      errorBody("INVALID_ARGUMENT", fcmType, "INVALID_ARGUMENT")))
      .toBe(true);
  });

  it("keeps the registration when a message payload is invalid", () => {
    expect(invalidFcmRegistration(400,
      errorBody("INVALID_ARGUMENT", requestType, "INVALID_ARGUMENT")))
      .toBe(false);
    expect(invalidFcmRegistration(400,
      JSON.stringify({ error: { status: "INVALID_ARGUMENT" } })))
      .toBe(false);
    expect(invalidFcmRegistration(400,
      JSON.stringify({ error: { status: "INVALID_ARGUMENT", details: [{
        "@type": requestType, fieldViolations: [{
          field: "message.data[0].value",
        }],
      }] } }))).toBe(false);
  });

  it("ignores malformed and unrelated responses", () => {
    expect(invalidFcmRegistration(400, "INVALID_ARGUMENT")).toBe(false);
    expect(invalidFcmRegistration(401,
      JSON.stringify({ error: { status: "UNREGISTERED" } }))).toBe(false);
    expect(invalidFcmRegistration(403,
      JSON.stringify({ error: { status: "SENDER_ID_MISMATCH" } }))).toBe(false);
    expect(invalidFcmRegistration(500,
      JSON.stringify({ error: { status: "INTERNAL" } }))).toBe(false);
  });
});
