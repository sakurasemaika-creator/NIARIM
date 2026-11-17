import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { open } from "maxmind";
import type { CountryResponse } from "maxmind";
import { ddb, Keys, tableName } from "./dynamo";
import { INITIAL_REWARDED_COINS_PER_COMPLETION, INITIAL_REWARD_OFFER_VERSION } from "./coinEconomyScale";

const adUnitPattern = /^ca-app-pub-([0-9]{16})\/([0-9]{10})$/;
export const rewardCountryPattern = /^[A-Z]{2}$/;
export const rewardSnapshotPeriodMs = 3 * 86_400_000;
export const rewardReportTimeZone = "America/Los_Angeles";
const reportCalendar = new Intl.DateTimeFormat("en-US", {
  timeZone: rewardReportTimeZone, year: "numeric", month: "2-digit", day: "2-digit",
});

export function rewardReportDay(epochMs: number): string {
  const parts = Object.fromEntries(reportCalendar.formatToParts(epochMs).map(p => [p.type, p.value]));
  return parts.year + parts.month + parts.day;
}

export function rewardAdTiers(raw: string, baseUnit: string): Map<number, string> {
  const base = adUnitPattern.exec(baseUnit);
  if (!base || base[1] === "3940256099942544") throw new Error("Invalid base rewarded unit");
  const tiers = new Map<number, string>([[INITIAL_REWARDED_COINS_PER_COMPLETION, baseUnit]]);
  if (!raw) return tiers;
  const values: unknown = JSON.parse(raw);
  if (!values || typeof values !== "object" || Array.isArray(values)) {
    throw new Error("Invalid rewarded unit tiers");
  }
  if (Object.keys(values).length > 11) throw new Error("Too many rewarded unit tiers");
  for (const [key, unit] of Object.entries(values)) {
    const coins = Number(key);
    const id = typeof unit === "string" ? adUnitPattern.exec(unit) : null;
    if (!/^[1-9][0-9]{0,2}$/.test(key) || coins > 100 || !id ||
        id[1] !== base[1] || tiers.has(coins) || [...tiers.values()].includes(unit)) {
      throw new Error("Invalid or duplicate rewarded unit tier");
    }
    tiers.set(coins, unit);
  }
  return tiers;
}

type RewardAdOffer = {
  enabled: boolean;
  adUnitId: string;
  amount: number;
  version: string;
  country?: string;
};

let countryReader: ReturnType<typeof open<CountryResponse>> | undefined;
async function countryForIp(sourceIp: string | undefined): Promise<string | undefined> {
  const file = process.env.REWARDED_AD_COUNTRY_DB;
  if (!file || !sourceIp) return undefined;
  try {
    countryReader ??= open<CountryResponse>(file);
    const field = (await countryReader).get(sourceIp)?.country?.iso_code;
    return field && field !== "ZZ" && rewardCountryPattern.test(field) ? field : undefined;
  } catch {
    countryReader = undefined;
    return undefined;
  }
}

export async function regionalRewardAdOffer(
  base: RewardAdOffer, sourceIp: string | undefined, now: number,
): Promise<RewardAdOffer> {
  if (!base.enabled) return base;
  const country = await countryForIp(sourceIp);
  const fallback = { ...base, country };
  if (!country || process.env.REWARDED_AD_AUTO_RATES_ENABLED !== "true") return fallback;
  try {
    const { Item } = await ddb.send(new GetCommand({
      TableName: tableName(),
      Key: Keys.rewardAdRateSnapshot(),
      ConsistentRead: true,
    }));
    if (Item?.itemType !== "REWARDED_AD_RATES" ||
        !Number.isSafeInteger(Item.generatedAtMs) || Item.generatedAtMs > now ||
        now - Item.generatedAtMs >= rewardSnapshotPeriodMs ||
        !Object.hasOwn(Item.rates ?? {}, country)) return fallback;
    const amount: unknown = Item.rates[country];
    const tiers = rewardAdTiers(process.env.REWARDED_AD_UNIT_TIERS ?? "", base.adUnitId);
    if (amount === 0) return { ...fallback, enabled: false, amount: 0 };
    const adUnitId = typeof amount === "number" ? tiers.get(amount) : undefined;
    if (typeof amount !== "number" || !adUnitId) return fallback;
    return {
      enabled: true, country, adUnitId, amount,
      version: amount === base.amount ? INITIAL_REWARD_OFFER_VERSION :
        `regional-v1-${amount}-${adUnitId.split("/")[1]}`,
    };
  } catch {
    // Existing globally available offer still works during a report outage.
    return fallback;
  }
}
