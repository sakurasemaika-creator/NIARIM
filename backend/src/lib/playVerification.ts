import { GoogleAuth } from "google-auth-library";

export const PLAY_PACKAGE_NAME = "com.niarim.niarim" as const;
export const PLAY_SUBSCRIPTION_PRODUCTS = [
  "niarim_premium_monthly", "niarim_premium_yearly",
] as const;
export type PlayProductId = (typeof PLAY_SUBSCRIPTION_PRODUCTS)[number];

/**
 * Derive access exclusively from Google's subscription state, matching product
 * ID and the actual expiry. Canceled-but-not-expired is still active; pending,
 * paused, on hold, refunded or expired must not grant Premium.
 */
export function evaluatePlaySubscription(
  raw: unknown, productId: PlayProductId, nowMs: number,
): { active: boolean; expiresAtEpochMs: number | null } {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("Invalid Play response");
  }
  const data = raw as {subscriptionState?: unknown; lineItems?: unknown};
  if (!Array.isArray(data.lineItems) || data.lineItems.length > 20) {
    throw new Error("Invalid Play subscription items");
  }
  let expiry = 0;
  for (const value of data.lineItems) {
    if (value === null || typeof value !== "object") continue;
    const item = value as {productId?: unknown; expiryTime?: unknown};
    if (item.productId !== productId || typeof item.expiryTime !== "string") continue;
    const ms = Date.parse(item.expiryTime);
    if (Number.isSafeInteger(ms) && ms > expiry) expiry = ms;
  }
  const active = (data.subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ||
    data.subscriptionState === "SUBSCRIPTION_STATE_CANCELED" ||
    data.subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD") &&
    expiry > nowMs;
  return { active, expiresAtEpochMs: expiry > 0 ? expiry : null };
}

/** Separate, keyless Google Play credentials. FCM's sender account must
 * not silently become a payment-verification identity.
 * The service account needs Google Play Console API access and this AWS
 * Lambda execution role must be permitted to impersonate it via Google WIF.
 */
export function playWorkloadIdentityConfig():
    { audience: string; serviceAccount: string } | null {
  const audience = process.env.PLAY_WIF_AUDIENCE ?? "";
  const serviceAccount = process.env.PLAY_VERIFIER_SERVICE_ACCOUNT ?? "";
  if (!/^\/\/iam\.googleapis\.com\/projects\/[0-9]+\/locations\/global\/workloadIdentityPools\/[A-Za-z0-9_-]+\/providers\/[A-Za-z0-9_-]+$/.test(audience) ||
      !/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.iam\.gserviceaccount\.com$/.test(serviceAccount)) {
    return null;
  }
  return { audience, serviceAccount };
}

/** ADC/workload identity only; never embed keys or raw purchase tokens in app. */
export async function queryGooglePlaySubscription(
  packageName: typeof PLAY_PACKAGE_NAME, purchaseToken: string,
): Promise<unknown> {
  const credential = playWorkloadIdentityConfig();
  if (!credential) {
    throw new Error("Google Play workload identity is not configured");
  }
  // AWS4-signed subject tokens are exchanged for short-lived Google tokens;
  // no long-lived Google private keys are stored in Lambda, CDK or Flutter.
  const client = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  }).fromJSON({
    type: "external_account",
    universe_domain: "googleapis.com",
    audience: credential.audience,
    subject_token_type: "urn:ietf:params:aws:token-type:aws4_request",
    token_url: "https://sts.googleapis.com/v1/token",
    credential_source: {
      environment_id: "aws1",
      region_url: "http://169.254.169.254/latest/meta-data/placement/availability-zone",
      url: "http://169.254.169.254/latest/meta-data/iam/security-credentials",
      regional_cred_verification_url:
        "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15",
    },
    service_account_impersonation_url:
      `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${credential.serviceAccount}:generateAccessToken`,
  } as any);
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    "applications/" + encodeURIComponent(packageName) +
    "/purchases/subscriptionsv2/tokens/" + encodeURIComponent(purchaseToken);
  const response = await client.request({ url, method: "GET" });
  return response.data;
}
