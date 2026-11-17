import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import { TransactWriteCommand, paginateQuery } from "@aws-sdk/lib-dynamodb";
import { OAuth2Client } from "google-auth-library";
import { ddb, Keys, tableName } from "../lib/dynamo";
import { rewardAdTiers, rewardCountryPattern, rewardReportDay, rewardReportTimeZone } from "../lib/rewardAdRates";
import { rewardAdUtcDay } from "../lib/rewardAdQuota";

const dayMs = 86_400_000;
const reportRows = 5_000;
const secrets = new SecretsManagerClient({});

type Revenue = { impressions: number; earningsMicros: bigint };
type Views = { completions: number; days: number };

function safeCount(value: unknown): number {
  const count = typeof value === "string" && /^[0-9]+$/.test(value) ? Number(value) : value;
  if (typeof count !== "number" || !Number.isSafeInteger(count) || count < 0) {
    throw new Error("Invalid rewarded ad counter");
  }
  return count;
}

export function parseRewardAdReport(payload: unknown, units: ReadonlySet<string>): Map<string, Revenue> {
  if (!Array.isArray(payload) || !payload[0]?.header || !payload.at(-1)?.footer) {
    throw new Error("Incomplete AdMob revenue report");
  }
  if (payload[0].header.localizationSettings?.currencyCode !== "JPY") {
    throw new Error("Unexpected AdMob report currency");
  }
  const footer = payload.at(-1).footer;
  const rows = payload.slice(1, -1);
  if (safeCount(footer.matchingRowCount ?? 0) !== rows.length ||
      rows.length >= reportRows || (footer.warnings ?? []).length) {
    throw new Error("Truncated or degraded AdMob revenue report");
  }
  const revenue = new Map<string, Revenue>();
  const seen = new Set<string>();
  for (const entry of rows) {
    const row = entry?.row;
    const country = row?.dimensionValues?.COUNTRY?.value;
    const unit = row?.dimensionValues?.AD_UNIT?.value;
    if (typeof country !== "string" || typeof unit !== "string" || !units.has(unit)) {
      throw new Error("Unexpected AdMob report dimension");
    }
    if (!rewardCountryPattern.test(country) || country === "ZZ") continue;
    const key = `${country}/${unit}`;
    if (seen.has(key)) throw new Error("Duplicate AdMob report row");
    seen.add(key);
    const impressions = safeCount(row.metricValues?.IMPRESSIONS?.integerValue ?? 0);
    const micros = row.metricValues?.ESTIMATED_EARNINGS?.microsValue ?? "0";
    if (!(typeof micros === "string" && /^-?\d{1,19}$/.test(micros)) &&
        !(typeof micros === "number" && Number.isSafeInteger(micros))) {
      throw new Error("Invalid AdMob earnings value");
    }
    const sum = revenue.get(country) ?? { impressions: 0, earningsMicros: 0n };
    revenue.set(country, {
      impressions: safeCount(sum.impressions + impressions),
      earningsMicros: sum.earningsMicros + BigInt(micros),
    });
  }
  return revenue;
}

export function regionalRewardRates(
  revenue: ReadonlyMap<string, Revenue>, views: ReadonlyMap<string, Views>,
  tiers: ReadonlyMap<number, string>,
) {
  const rates: Record<string, number> = {};
  const levels = [...tiers.keys()].sort((a, b) => b - a);
  for (const [country, sample] of revenue) {
    const verified = views.get(country);
    if (!verified || verified.days < 7 || verified.completions < 100 ||
        sample.impressions < 100) continue;
    // 100 Opals per JPY reference scale, with half of estimated revenue
    // reserved. The larger denominator is conservative if reports lag SSV.
    const divisor = BigInt(Math.max(verified.completions, sample.impressions)) * 1_000_000n;
    const affordable = sample.earningsMicros * 50n / divisor;
    rates[country] = levels.find(amount => BigInt(amount) <= affordable) ?? 0;
  }
  return rates;
}

function reportDate(epochMs: number) {
  const date = new Date(epochMs);
  return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1, day: date.getUTCDate() };
}

export async function handler() {
  const base = process.env.ADMOB_REWARDED_AD_UNIT_ID ?? "";
  const tiers = rewardAdTiers(process.env.REWARDED_AD_UNIT_TIERS ?? "", base);
  const publisher = `pub-${base.split("/")[0].slice("ca-app-pub-".length)}`;
  const secretArn = process.env.ADMOB_REPORT_OAUTH_SECRET_ARN;
  if (!secretArn) throw new Error("AdMob reporting OAuth secret is missing");
  const { SecretString } = await secrets.send(new GetSecretValueCommand({ SecretId: secretArn }));
  const { client_id, client_secret, refresh_token } = JSON.parse(SecretString ?? "{}");
  if (![client_id, client_secret, refresh_token].every(value =>
    typeof value === "string" && value.length > 0)) {
    throw new Error("AdMob reporting OAuth secret is incomplete");
  }
  const oauth = new OAuth2Client(client_id, client_secret);
  oauth.setCredentials({ refresh_token });
  const now = Date.now();
  // Leave two days for reporting lag. The public amount is refreshed daily
  // from the trailing 30 closed calendar dates.
  const today = rewardReportDay(now);
  const end = Date.UTC(+today.slice(0, 4), +today.slice(4, 6) - 1, +today.slice(6, 8)) - 2 * dayMs;
  const start = end - 29 * dayMs;
  const units = new Set(tiers.values());
  const response = await oauth.request<unknown>({
    url: `https://admob.googleapis.com/v1/accounts/${publisher}/networkReport:generate`,
    method: "POST", timeout: 15_000,
    data: { reportSpec: {
      dateRange: { startDate: reportDate(start), endDate: reportDate(end) },
      dimensions: ["COUNTRY", "AD_UNIT"],
      metrics: ["ESTIMATED_EARNINGS", "IMPRESSIONS"],
      dimensionFilters: [{ dimension: "AD_UNIT", matchesAny: { values: [...units] } }],
      localizationSettings: { currencyCode: "JPY", languageCode: "en-US" },
      timeZone: rewardReportTimeZone,
      maxReportRows: reportRows,
    } },
  }).catch(() => { throw new Error("AdMob network report request failed"); });
  const revenue = parseRewardAdReport(response.data, units);
  const key = Keys.rewardAdRateSnapshot();
  const views = new Map<string, Views>();
  for await (const page of paginateQuery({ client: ddb, pageSize: 150 }, {
    TableName: tableName(),
    KeyConditionExpression: "pk = :pk AND sk BETWEEN :start AND :end",
    ExpressionAttributeValues: {
      ":pk": key.pk, ":start": `DAY#${rewardAdUtcDay(start)}#`,
      ":end": `DAY#${rewardAdUtcDay(end)}#ZZ`,
    },
    ProjectionExpression: "sk, completions",
  })) {
    for (const row of page.Items ?? []) {
      const country = row.sk?.split("#")[2];
      if (!country || !rewardCountryPattern.test(country)) continue;
      const previous = views.get(country) ?? { completions: 0, days: 0 };
      views.set(country, {
        completions: safeCount(previous.completions + safeCount(row.completions)),
        days: previous.days + 1,
      });
    }
  }
  const rates = regionalRewardRates(revenue, views, tiers);
  const reportWindow = {
    generatedAtMs: now, reportStart: rewardAdUtcDay(start), reportEnd: rewardAdUtcDay(end),
  };
  await ddb.send(new TransactWriteCommand({
    TransactItems: [
      { Put: {
        TableName: tableName(),
        Item: { ...key, itemType: "REWARDED_AD_RATES", ...reportWindow, rates },
        ConditionExpression: "attribute_not_exists(generatedAtMs) OR generatedAtMs < :updated",
        ExpressionAttributeValues: { ":updated": now },
      } },
      { Put: {
        TableName: tableName(),
        Item: {
          ...Keys.rewardAdRevenueSnapshot(), itemType: "REWARDED_AD_REVENUE", ...reportWindow,
          countries: Object.fromEntries([...revenue].map(([country, value]) => [
            country, { impressions: value.impressions, earningsMicros: value.earningsMicros.toString(),
              completions: views.get(country)?.completions ?? 0 },
          ])),
        },
      } },
    ],
  }));
  console.info("Refreshed rewarded-ad rates", { ratedCountries: Object.keys(rates).length });
}
