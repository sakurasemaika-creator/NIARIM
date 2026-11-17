import { describe, expect, it } from "vitest";
import { parseRewardAdReport, regionalRewardRates } from "../src/batch/rewardAdRevenue";
import { rewardAdTiers, rewardReportDay } from "../src/lib/rewardAdRates";

const base = "ca-app-pub-1111111111111111/2222222222";
const lower = "ca-app-pub-1111111111111111/3333333333";
const higher = "ca-app-pub-1111111111111111/4444444444";
const units = new Set([base, lower, higher]);
const header = { header: { localizationSettings: { currencyCode: "JPY" } } };
const footer = (count: number) => ({ footer: { matchingRowCount: String(count) } });
const row = (country: string, adUnit: string, impressions: number, micros: string | number) => ({
  row: {
    dimensionValues: { COUNTRY: { value: country }, AD_UNIT: { value: adUnit } },
    metricValues: {
      IMPRESSIONS: { integerValue: String(impressions) },
      ESTIMATED_EARNINGS: { microsValue: micros },
    },
  },
});

describe("regional rewarded ad reporting", () => {
  it("selects the best affordable configured unit from conservative JPY estimates", () => {
    const report = parseRewardAdReport([
      header, row("JP", base, 200, "80000000"), row("JP", higher, 200, 84_000_000),
      row("US", base, 200, "20000000"), row("FR", base, 100, "1000000"),
      row("GB", base, 800, "400000000"), footer(5),
    ], units);
    const views = new Map([
      ["JP", { days: 12, completions: 370 }],
      ["US", { days: 10, completions: 180 }],
      ["FR", { days: 7, completions: 120 }],
      ["GB", { days: 6, completions: 200 }],
    ]);
    expect(regionalRewardRates(report, views, rewardAdTiers(
      JSON.stringify({ 5: lower, 20: higher }), base,
    ))).toEqual({ JP: 20, US: 5, FR: 0 });
    expect(regionalRewardRates(report, views, rewardAdTiers("", base)))
      .toEqual({ JP: 10, US: 0, FR: 0 });
  });

  it("rejects partial or duplicate rows, unexpected currencies and duplicate units", () => {
    expect(() => parseRewardAdReport([header, row("JP", base, 2, "130000"), footer(2)], units))
      .toThrow(/Truncated/);
    expect(() => parseRewardAdReport([
      header, row("JP", base, 2, 1), row("JP", base, 3, 2), footer(2),
    ], units)).toThrow(/Duplicate/);
    expect(() => parseRewardAdReport([
      { header: { localizationSettings: { currencyCode: "USD" } } }, footer(0),
    ], units)).toThrow(/currency/);
    expect(() => rewardAdTiers(JSON.stringify({ 5: base }), base)).toThrow(/duplicate/);
  });

  it("keeps report dates aligned on either side of daylight saving time", () => {
    expect(rewardReportDay(Date.parse("2026-03-08T07:59:00Z"))).toBe("20260307");
    expect(rewardReportDay(Date.parse("2026-03-08T08:00:00Z"))).toBe("20260308");
    expect(rewardReportDay(Date.parse("2026-03-09T07:00:00Z"))).toBe("20260309");
  });
});
