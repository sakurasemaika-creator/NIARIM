import {beforeEach,describe,expect,it,vi} from "vitest";
import {GetCommand,TransactWriteCommand} from "@aws-sdk/lib-dynamodb";
import type {APIGatewayProxyEventV2} from "aws-lambda";

const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({
    niarimUserId:"Nverified",googleSub:"google-sub",membershipTier:"free",
  })),
  getUser:vi.fn(async()=>({itemType:"USER",membershipTier:"free"})),
}));
import {getCoinRedemptionQuote,redeemCoins}
  from "../src/api/routes/coinRedemption";
import {premiumExpiryForDuration}
  from "../src/lib/coinRedemption";
const requestId="123e4567-e89b-12d3-a456-426614174000";
function req(body?:unknown,query?:Record<string,string>) {
  return {
    headers:{authorization:"Bearer test-only"},
    queryStringParameters:query??{target:"fullPremium",duration:"hour",quantity:"2"},
    body:body===undefined?undefined:JSON.stringify(body),
  } as unknown as APIGatewayProxyEventV2;
}
beforeEach(()=>{
  send.mockReset();send.mockResolvedValue({});
  process.env.TABLE_NAME="unit-test-table";
  process.env.COIN_REDEMPTION_ENABLED="true";
  process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED="true";
  process.env.COIN_FULL_PREMIUM_MONTH_COINS="55000";
  process.env.COIN_FULL_PREMIUM_YEAR_COINS="550000";
  process.env.COIN_PRICE_VERSION="v3-final-annual550000";
});
describe("flexible Full Premium duration redemption",()=>{
  it("quotes hourly, daily, weekly and multi-month prices from the server",async()=>{
    const cases=[
      ["hour","2",1000],["day","2",5000],
      ["week","3",54000],["month","2",110000],
      ["month","12",550000],["month","13",605000],
    ] as const;
    for(const [duration,quantity,price] of cases){
      const response=await getCoinRedemptionQuote(req(undefined,{
        target:"fullPremium",duration,quantity,
      }));
      expect(JSON.parse(response.body??"{}")).toMatchObject({
        target:"fullPremium",duration,quantity:Number(quantity),
        enabled:true,priceCoins:price,catalogPriceCoins:price,
        priceVersion:"v3-final-annual550000",
      });
    }
  });
  it("debits only approved price and creates a short-lived Premium entitlement atomically",async()=>{
    const before=Date.now();
    const response=await redeemCoins(req({
      target:"fullPremium",duration:"hour",quantity:2,
      requestId,priceVersion:"v3-final-annual550000",priceCoins:0,
    }));
    expect(JSON.parse(response.body??"{}")).toMatchObject({
      redeemed:true,duplicate:false,costCoins:1000,
    });
    const tx=send.mock.calls.find(([command])=>
      command instanceof TransactWriteCommand)?.[0] as TransactWriteCommand;
    expect(tx).toBeDefined();
    const writes=tx.input.TransactItems!;
    expect(writes).toHaveLength(5);
    expect(writes[0].Put?.Item?.duration).toBe("hour");
    expect(writes[0].Put?.Item?.quantity).toBe(2);
    expect(writes[1].Update?.ExpressionAttributeValues?.[":minus"]).toBe(-1000);
    expect(writes[2].Update?.Key?.sk).toBe("ENTITLEMENT#fullPremium");
    const expiry=Number(writes[2].Update?.ExpressionAttributeValues?.[":expiry"]);
    expect(expiry).toBeGreaterThanOrEqual(before+7200_000);
    expect(expiry).toBeLessThanOrEqual(Date.now()+7200_000);
  });
  it("rejects conflicting fields and invalid duration without any debit",async()=>{
    for(const body of [
      {target:"fullPremium",duration:"week",months:1,quantity:1,requestId},
      {target:"fullPremium",duration:"week",quantity:0,requestId},
      {target:"fullPremium",duration:"year",quantity:1,requestId},
    ]) {
      await expect(redeemCoins(req(body))).rejects.toBeDefined();
    }
    expect(send.mock.calls.some(([c])=>c instanceof TransactWriteCommand))
      .toBe(false);
  });
  it("adds calendar months without overflowing February",()=>{
    expect(new Date(premiumExpiryForDuration(Date.UTC(2028,0,31), "month",1))
      .toISOString()).toBe("2028-02-29T00:00:00.000Z");
    expect(new Date(premiumExpiryForDuration(Date.UTC(2028,1,29), "month",12))
      .toISOString()).toBe("2029-02-28T00:00:00.000Z");
  });
});
