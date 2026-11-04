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

/** ADC/workload identity only; never embed keys or raw purchase tokens in app. */
export async function queryGooglePlaySubscription(
  packageName: typeof PLAY_PACKAGE_NAME, purchaseToken: string,
): Promise<unknown> {
  const client = await new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  }).getClient();
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    "applications/" + encodeURIComponent(packageName) +
    "/purchases/subscriptionsv2/tokens/" + encodeURIComponent(purchaseToken);
  const response = await client.request({ url, method: "GET" });
  return response.data;
}
