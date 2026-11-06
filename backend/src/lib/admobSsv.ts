import { createPublicKey, verify as verifySignature } from "node:crypto";

/**
 * Google AdMob SSV: verify the ORIGINAL raw query bytes. Google signs every
 * parameter before the final "&signature=...&key_id=..." suffix.
 * Never reserialize URLSearchParams before verifying: escaping/order matters.
 * https://developers.google.com/admob/android/ssv
 */
export const ADMOB_KEY_URL =
  "https://www.gstatic.com/admob/reward/verifier-keys.json";
const KEY_CACHE_MS = 6 * 60 * 60 * 1000; // < Google's 24h maximum.
const MAX_QUERY_LENGTH = 4096;
type KeyEntry = { keyId: number; pem: string };
let cachedKeys: Map<number, string> | null = null;
let cachedUntil = 0;

export class SsvVerificationError extends Error {
  constructor(message: string, public readonly temporary = false) {
    super(message);
  }
}

export async function admobPublicKeys(): Promise<Map<number, string>> {
  if (cachedKeys && Date.now() < cachedUntil) return cachedKeys;
  let response: Response;
  try {
    response = await fetch(ADMOB_KEY_URL, {
      signal: AbortSignal.timeout(3000),
      headers: { accept: "application/json" },
    });
    if (!response.ok) throw new Error("key endpoint rejected request");
    const body = await response.json() as { keys?: KeyEntry[] };
    if (!Array.isArray(body.keys) || !body.keys.length ||
        body.keys.length > 30) throw new Error("invalid key set");
    const keys = new Map<number, string>();
    for (const key of body.keys) {
      if (!Number.isSafeInteger(key.keyId) ||
          typeof key.pem !== "string" ||
          !key.pem.startsWith("-----BEGIN PUBLIC KEY-----") ||
          key.pem.length > 2000) throw new Error("invalid key");
      const publicKey = createPublicKey(key.pem);
      if (publicKey.asymmetricKeyType !== "ec") throw new Error("non-ECDSA key");
      keys.set(key.keyId, key.pem);
    }
    cachedKeys = keys;
    cachedUntil = Date.now() + KEY_CACHE_MS;
    return keys;
  } catch {
    // Key retrieval failure is NOT an authentication failure. The endpoint
    // must respond 503 so Google can retry, never credit an unverified ad.
    throw new SsvVerificationError("AdMob public key temporarily unavailable", true);
  }
}

export interface VerifiedAdmobReward {
  adUnit: string;
  rewardAmount: number;
  rewardItem: string;
  transactionId: string;
  timestampMs: number;
  // AdMob's signed URL-verification callback may omit custom_data.
  // An absent binding is NEVER eligible for a wallet credit.
  customData: string | null;
}

export async function verifyAdmobSsv(
  rawQuery: string,
  loadKeys: () => Promise<Map<number, string>> = admobPublicKeys,
): Promise<VerifiedAdmobReward> {
  if (!rawQuery || rawQuery.length > MAX_QUERY_LENGTH ||
      /[\r\n\u0000]/.test(rawQuery)) {
    throw new SsvVerificationError("Invalid callback length");
  }
  const match = /^(.*)&signature=([A-Za-z0-9_-]+)&key_id=([0-9]+)$/.exec(rawQuery);
  if (!match || !match[1]) throw new SsvVerificationError("Invalid callback signature format");
  const [, signedBytes, encodedSignature, keyString] = match;
  const keyId = Number(keyString);
  if (!Number.isSafeInteger(keyId) || encodedSignature.length > 300) {
    throw new SsvVerificationError("Invalid verification key");
  }
  const keys = await loadKeys();
  const pem = keys.get(keyId);
  if (!pem) throw new SsvVerificationError("Unknown AdMob signing key", true);
  let verified = false;
  try {
    verified = verifySignature(
      "sha256",
      Buffer.from(signedBytes, "utf8"),
      createPublicKey(pem),
      Buffer.from(encodedSignature, "base64url"),
    );
  } catch {
    // Do not leak crypto parsing details to a public unauthenticated route.
  }
  if (!verified) throw new SsvVerificationError("Invalid AdMob ECDSA signature");

  const params = new URLSearchParams(signedBytes);
  function required(name: string): string {
    if (params.getAll(name).length !== 1 || !params.get(name)) {
      throw new SsvVerificationError("Missing or duplicated signed field");
    }
    return params.get(name)!;
  }
  const amountString = required("reward_amount");
  const timestampString = required("timestamp");
  const amount = Number(amountString);
  const timestampMs = Number(timestampString);
  const transactionId = required("transaction_id");
  if (!/^[1-9][0-9]{0,8}$/.test(amountString) ||
      !Number.isSafeInteger(amount) ||
      !/^[0-9]{12,17}$/.test(timestampString) ||
      !Number.isSafeInteger(timestampMs) ||
      !/^[0-9a-fA-F]{16,128}$/.test(transactionId)) {
    throw new SsvVerificationError("Invalid signed reward fields");
  }
  return {
    adUnit: required("ad_unit"),
    rewardAmount: amount,
    rewardItem: required("reward_item"),
    transactionId,
    timestampMs,
    customData: (() => {
      const values = params.getAll("custom_data");
      if (values.length > 1) {
        throw new SsvVerificationError("Duplicate signed custom_data field");
      }
      return values.length === 1 && values[0] ? values[0] : null;
    })(),
  };
}

/** Reject stale Google callbacks even if TTL purged the replay item. */
export function validateAdmobOffer(
  reward: VerifiedAdmobReward,
  config: { adUnitId: string; amount: number; nowMs: number },
): { userId: string; nonce: string } {
  const adUnitSuffix = config.adUnitId.split("/").at(-1);
  if (!adUnitSuffix || reward.adUnit !== adUnitSuffix ||
      reward.rewardItem !== "coins" ||
      reward.rewardAmount !== config.amount ||
      reward.timestampMs > config.nowMs + 5 * 60 * 1000 ||
      config.nowMs - reward.timestampMs > 7 * 24 * 3600 * 1000) {
    throw new SsvVerificationError("Ad unit, offer or timestamp mismatch");
  }
  const match = /^v1\.(N[0-9a-f]{32})\.([0-9a-f-]{36})$/.exec(reward.customData ?? "");
  if (!match || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(match[2])) {
    throw new SsvVerificationError("Invalid signed reward session");
  }
  return { userId: match[1], nonce: match[2] };
}
