/**
 * Optional daily cap on VERIFIED rewarded-coin grants per NIARIM account.
 * This is NOT AdMob's impression frequency cap and does not predict fill.
 *
 * No arbitrary launch cap: a production owner must configure one explicitly.
 * Missing/invalid configuration disables production SSV coin issuance.
 * UTC boundaries are fixed on the server so device timezone changes cannot
 * bypass the counter. A late SSV is charged against its signed ad day.
 */
export interface RewardAdDailyQuota {
  limit: number | null;
  dayUtc: string;
  resetsAtEpochMs: number;
}

export function rewardAdUtcDay(epochMs: number): string {
  if (!Number.isSafeInteger(epochMs) || epochMs < 0 ||
      epochMs > 8_640_000_000_000_000) {
    throw new Error("Invalid reward ad timestamp");
  }
  return new Date(epochMs).toISOString().slice(0, 10).replaceAll("-", "");
}

export function dailyRewardLimit(): number | null {
  const raw = process.env.REWARDED_AD_DAILY_LIMIT ?? "";
  // Null means not configured (production issuance disabled).
  // AdMob may separately cap impressions or have no fill.
  if (raw === "") return null;
  if (!/^[1-9][0-9]{0,2}$/.test(raw)) return null;
  const limit = Number(raw);
  return limit >= 1 && limit <= 500 ? limit : null;
}

export function rewardAdDailyQuota(now: number): RewardAdDailyQuota {
  const dayUtc = rewardAdUtcDay(now);
  return {
    limit: dailyRewardLimit(),
    dayUtc,
    resetsAtEpochMs: Date.parse(
      `${dayUtc.slice(0, 4)}-${dayUtc.slice(4, 6)}-${dayUtc.slice(6, 8)}T00:00:00.000Z`,
    ) + 86_400_000,
  };
}

export function remainingRewardedGrants(
  limit: number | null, consumed: unknown,
): number | null {
  if (limit === null) return null;
  const used = typeof consumed === "number" &&
    Number.isSafeInteger(consumed) && consumed > 0 ? consumed : 0;
  return Math.max(0, limit - used);
}
