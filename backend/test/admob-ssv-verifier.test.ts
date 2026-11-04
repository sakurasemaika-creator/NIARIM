import { createSign, generateKeyPairSync } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  SsvVerificationError, validateAdmobOffer, verifyAdmobSsv,
} from "../src/lib/admobSsv";

const { privateKey, publicKey } = generateKeyPairSync("ec", {
  namedCurve: "prime256v1",
});
const keyId = 123;
const keys = async () => new Map([[keyId,
  publicKey.export({ type: "spki", format: "pem" }).toString()]]);
const userId = `N${"a".repeat(32)}`;
const nonce = "123e4567-e89b-12d3-a456-426614174000";
const timestamp = Date.now();
const adUnitId = "ca-app-pub-1111111111111111/2222222222";
const content = (customData = `v1.${userId}.${nonce}`) =>
  "ad_network=12345&ad_unit=2222222222&" +
  `custom_data=${encodeURIComponent(customData)}&reward_amount=10&reward_item=coins&` +
  `timestamp=${timestamp}&transaction_id=18fa792de1bca816048293fc71035638`;
function signed(raw: string): string {
  const signer = createSign("SHA256");
  signer.update(raw, "utf8");
  signer.end();
  return `${raw}&signature=${signer.sign(privateKey).toString("base64url")}&key_id=${keyId}`;
}

describe("AdMob ECDSA callback verification", () => {
  it("accepts only the original signed bytes and bound, versioned offer", async () => {
    const reward = await verifyAdmobSsv(signed(content()), keys);
    expect(validateAdmobOffer(reward, {
      adUnitId, amount: 10, nowMs: timestamp,
    })).toEqual({ userId, nonce });
  });

  it("rejects changed coin amount, timestamp and custom data", async () => {
    const original = signed(content());
    await expect(verifyAdmobSsv(
      original.replace("reward_amount=10", "reward_amount=500"), keys,
    )).rejects.toBeInstanceOf(SsvVerificationError);
    const altered = await verifyAdmobSsv(signed(content("v1.fake-id.fake-id")), keys);
    expect(() => validateAdmobOffer(altered, {
      adUnitId, amount: 10, nowMs: timestamp,
    })).toThrow();
    const valid = await verifyAdmobSsv(original, keys);
    expect(() => validateAdmobOffer(valid, {
      adUnitId, amount: 10, nowMs: timestamp + 8 * 24 * 3600 * 1000,
    })).toThrow();
  });

  it("rejects wrong signing key, duplicate query fields and unsigned callback", async () => {
    await expect(verifyAdmobSsv(signed(content()), async () => new Map()))
      .rejects.toBeInstanceOf(SsvVerificationError);
    await expect(verifyAdmobSsv(signed(content() + "&reward_amount=1"), keys))
      .rejects.toBeInstanceOf(SsvVerificationError);
    await expect(verifyAdmobSsv(content(), keys))
      .rejects.toBeInstanceOf(SsvVerificationError);
  });
});
