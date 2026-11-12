import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({niarimUserId:"Nverified-user",
    membershipTier:"free",googleSub:"sub"})),
  getUser:vi.fn(async()=>({itemType:"USER",membershipTier:"free"})),
}));
import { redeemCoins, getCoinRedemptionQuote }
  from "../src/api/routes/coinRedemption";
import { premiumAnnualRedemptionOffer, addOneCalendarYearUtc }
  from "../src/lib/coinRedemption";
const requestId="123e4567-e89b-12d3-a456-426614174000";
const event=(body?:unknown,query?:Record<string,string>)=>({
  headers:{authorization:"Bearer test"},
  queryStringParameters:query??{target:"fullPremium",months:"12"},
  body:body===undefined?undefined:JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;
beforeEach(()=>{
  send.mockReset();send.mockResolvedValue({});
  process.env.TABLE_NAME="test-table";
  process.env.COIN_REDEMPTION_ENABLED="true";
  process.env.COIN_REDEMPTION_REVIEW_APPROVED="true";
  process.env.COIN_FULL_PREMIUM_MONTH_COINS="55000";
  process.env.COIN_FULL_PREMIUM_YEAR_COINS="550000";
  process.env.COIN_PRICE_VERSION="v3-final-annual550000";
  delete process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED;
});
describe("independently gated annual Premium redemption",()=>{
  it("remains disabled and cannot debit even with existing monthly approval",async()=>{
    expect(premiumAnnualRedemptionOffer().enabled).toBe(false);
    const res=await getCoinRedemptionQuote(event());
    expect(JSON.parse(res.body??"{}")).toMatchObject({
      enabled:false,priceCoins:null,catalogPriceCoins:550000,months:12,
    });
    await expect(redeemCoins(event({target:"fullPremium",months:12,
      priceVersion:"v3-final-annual550000",requestId})))
      .rejects.toMatchObject({code:"REDEMPTION_DISABLED"});
    expect(send).not.toHaveBeenCalled();
  });
  it("checks the exact approved annual rate and separate release switch",()=>{
    process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED="true";
    expect(premiumAnnualRedemptionOffer()).toMatchObject({
      enabled:true,priceCoins:550000,priceVersion:"v3-final-annual550000",
    });
    process.env.COIN_FULL_PREMIUM_YEAR_COINS="660000";
    expect(premiumAnnualRedemptionOffer().enabled).toBe(false);
  });
  it("extends a calendar year without skipping leap-day birthdays",()=>{
    expect(new Date(addOneCalendarYearUtc(Date.UTC(2028,1,29,9)))
      .toISOString()).toBe("2029-02-28T09:00:00.000Z");
    expect(new Date(addOneCalendarYearUtc(Date.UTC(2027,0,31,9)))
      .toISOString()).toBe("2028-01-31T09:00:00.000Z");
  });
  it("debits the final annual price atomically, only when separately approved",async()=>{
    process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED="true";
    const response=await redeemCoins(event({
      target:"fullPremium",months:12,
      priceVersion:"v3-final-annual550000",requestId,priceCoins:1,
    }));
    expect(JSON.parse(response.body??"{}")).toMatchObject({
      redeemed:true,costCoins:550000,duplicate:false,
    });
    const tx=send.mock.calls.find(([c])=>c instanceof TransactWriteCommand)?.[0] as TransactWriteCommand;
    expect(tx.input.TransactItems).toHaveLength(5);
    expect(tx.input.TransactItems?.[0].Put?.Item?.months).toBe(12);
    expect(tx.input.TransactItems?.[1].Update?.ExpressionAttributeValues?.[":minus"])
      .toBe(-550000);
    expect(tx.input.TransactItems?.[2].Update?.Key?.sk).toBe("ENTITLEMENT#fullPremium");
  });
  it("rejects unsupported options without writes",async()=>{
    process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED="true";
    await expect(redeemCoins(event({target:"allAds",months:12,requestId})))
      .rejects.toMatchObject({code:"REDEMPTION_NOT_AVAILABLE"});
    expect(send).not.toHaveBeenCalled();
  });
});
