import { describe, expect, it } from "vitest";
import { catalogRedemptionQuote } from "../src/lib/coinRedemptionCatalog";

describe("authenticated catalog preview contract", () => {
  it("reports owner-fixed prices for each period but never claims redemption", () => {
    for (const [duration,price] of [
      ["hour", 500],["day",2500],["week",18000],["month",55000],
    ] as const) {
      const q = catalogRedemptionQuote({target:"fullPremium",duration});
      expect(q).toMatchObject({
        target:"fullPremium",duration,quantity:1,
        catalogPriceCoins:price,
        enabled:false,priceCoins:null,
        reason:"REDEMPTION_NOT_IMPLEMENTED",
        priceVersion:"v3-final-annual550000",
      });
    }
  });
  it("supports separately priced benefits without charging or granting rights", () => {
    const quote = catalogRedemptionQuote({
      target:"toneCurve",duration:"week",quantity:"3",
    });
    expect(quote.catalogPriceCoins).toBe(10560);
    expect(quote.enabled).toBe(false);
    expect(quote.priceCoins).toBeNull();
  });
  it("honors the explicitly approved annual bundle discount", () => {
    const quote = catalogRedemptionQuote({
      target:"fullPremium",duration:"month",quantity:"12",
    });
    expect(quote.catalogPriceCoins).toBe(550000);
    expect(quote.enabled).toBe(false);
  });
  it("rejects malformed targets, quantities and conflicting durations", () => {
    for (const query of [
      {target:"unknown"},{target:"communityPostQuota"},
      {target:"allAds",duration:"years"},
      {target:"fullPremium",quantity:"0"},
      {target:"fullPremium",quantity:"121"},
      {target:"fullPremium",quantity:"1.5"},
      {target:"fullPremium",months:"2",duration:"week"},
    ]) {
      expect(()=>catalogRedemptionQuote(query)).toThrow();
    }
  });
});
