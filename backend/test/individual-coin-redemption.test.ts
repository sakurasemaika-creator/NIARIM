import {beforeEach,describe,expect,it,vi} from "vitest";
import {GetCommand,TransactWriteCommand} from "@aws-sdk/lib-dynamodb";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  getUser:vi.fn(async()=>({itemType:"USER",membershipTier:"free"})),
}));
import {getUser} from "../src/lib/auth";
import {
  redeemIndividualCoins,individualCoinRedemptionEnabled,
} from "../src/lib/individualCoinRedemption";

const requestId="123e4567-e89b-12d3-a456-426614174000";
const priceVersion="v3-final-annual550000";
const input=()=>({targets:["toneCurve","levelAdjustment"],duration:"week",
  quantity:1,priceVersion,requestId});
const enable=()=>{
  process.env.COIN_INDIVIDUAL_REDEMPTION_ENABLED="true";
  process.env.COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED="true";
  process.env.COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED="true";
  process.env.COIN_PRICE_VERSION=priceVersion;
};
beforeEach(()=>{
  send.mockReset();send.mockResolvedValue({});
  vi.mocked(getUser).mockReset();
  vi.mocked(getUser).mockResolvedValue({
    itemType:"USER",membershipTier:"free",
  } as Awaited<ReturnType<typeof getUser>>);
  process.env.TABLE_NAME="test-table";
  delete process.env.COIN_INDIVIDUAL_REDEMPTION_ENABLED;
  delete process.env.COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED;
  delete process.env.COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED;
  delete process.env.COIN_PRICE_VERSION;
});
describe("fail closed individual benefit redemption",()=>{
  it("cannot debit coins or grant entitlements unless all independent approvals are true",async()=>{
    expect(individualCoinRedemptionEnabled()).toBe(false);
    await expect(redeemIndividualCoins("Naccount",input()))
      .rejects.toMatchObject({code:"REDEMPTION_DISABLED"});
    expect(send).not.toHaveBeenCalled();
    process.env.COIN_INDIVIDUAL_REDEMPTION_ENABLED="true";
    process.env.COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED="true";
    process.env.COIN_PRICE_VERSION=priceVersion;
    expect(individualCoinRedemptionEnabled()).toBe(false);
  });
  it("charges only the server-computed fixed price, granting two account-owned rights atomically",async()=>{
    enable();
    const result=await redeemIndividualCoins("Naccount",{
      ...input(), ...({costCoins:1,accountId:"attacker"} as Record<string,unknown>),
    });
    expect(JSON.parse(result.body??"{}")).toMatchObject({
      redeemed:true,costCoins:6230,duplicate:false,
    });
    const tx=send.mock.calls.find(([cmd])=>cmd instanceof TransactWriteCommand)?.[0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    const rows=tx.input.TransactItems!;
    expect(rows).toHaveLength(6);
    expect(rows[0].Put?.Item?.selectionKey).toBe("toneCurve,levelAdjustment");
    expect(rows[1].Update?.Key?.pk).toBe("USER#Naccount");
    expect(rows[1].Update?.ExpressionAttributeValues?.[":minus"]).toBe(-6230);
    expect(rows[2].Update?.Key?.sk).toBe("ENTITLEMENT#toneCurve");
    expect(rows[3].Update?.Key?.sk).toBe("ENTITLEMENT#levelAdjustment");
    expect(rows[4].ConditionCheck?.Key?.sk).toBe("ENTITLEMENT#fullPremium");
    expect(rows[5].Put?.Item?.deltaCoins).toBe(-6230);
    expect(rows[2].Update?.ConditionExpression).toContain("attribute_not_exists(expiresAtEpochMs)");
  });
  it("rejects price tampering, overlapping ad rights and duplicate targets",async()=>{
    enable();
    await expect(redeemIndividualCoins("Naccount",{
      ...input(),priceVersion:"wrong",
    })).rejects.toMatchObject({code:"REDEMPTION_PRICE_CHANGED"});
    await expect(redeemIndividualCoins("Naccount",{
      ...input(),targets:["allAds","canvasAds"],
    })).rejects.toMatchObject({code:"REDEMPTION_OVERLAPPING_ADS"});
    await expect(redeemIndividualCoins("Naccount",{
      ...input(),targets:["toneCurve","toneCurve"],
    })).rejects.toMatchObject({code:"REDEMPTION_INVALID_SELECTION"});
    expect(send).not.toHaveBeenCalled();
  });
  it("refuses to charge an account with an active verified Play Premium term",async()=>{
    enable();
    vi.mocked(getUser).mockResolvedValueOnce({
      itemType:"USER",membershipTier:"free",
      playPremiumExpiresAtEpochMs:Date.now()+120000,
    } as Awaited<ReturnType<typeof getUser>>);
    await expect(redeemIndividualCoins("Naccount",input()))
      .rejects.toMatchObject({code:"REDEMPTION_SUBSCRIPTION_CONFLICT"});
    expect(send.mock.calls.some(([cmd])=>cmd instanceof TransactWriteCommand))
      .toBe(false);
  });
  it("replays the original receipt without touching the balance again",async()=>{
    enable();
    send.mockImplementation(async(cmd:unknown)=>{
      if(cmd instanceof GetCommand && cmd.input.Key?.sk ===
        `COIN_TX#redeem-${requestId}`) {
        return {Item:{
          itemType:"COIN_REDEMPTION",target:"individualBenefits",
          requestId,selectionKey:"toneCurve,levelAdjustment",
          duration:"week",quantity:1,priceVersion,costCoins:6230,
          expiresAtByTarget:{toneCurve:1900000000000,levelAdjustment:1900000000000},
        }};
      }
      return {};
    });
    const response=await redeemIndividualCoins("Naccount",input());
    expect(JSON.parse(response.body??"{}")).toMatchObject({
      redeemed:true,duplicate:true,costCoins:6230,
    });
    expect(send.mock.calls.some(([cmd])=>cmd instanceof TransactWriteCommand))
      .toBe(false);
  });
});
