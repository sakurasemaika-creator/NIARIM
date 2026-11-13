import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import {
  ConditionalCheckFailedException,TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { ddb,Keys,tableName } from "./dynamo";
import { getUser } from "./auth";
import { badRequest,conflict,forbidden,ok } from "./response";
import { catalogSelectionQuote } from "./coinRedemptionCatalog";
import { COIN_BENEFIT_PRICE_VERSION } from "./coinBenefitProposal";

/**
 * Atomic redemption pipeline for selected individual benefits.
 *
 * OFF by default, including when fullPremium monthly is approved.
 * Feature-consumer audit MUST verify that every paid feature refuses access
 * without this account's active server-issued entitlement before operators
 * explicitly enable the independent release switches.
 */
export function individualCoinRedemptionEnabled(): boolean {
  // A development switch is not financial approval. Both independent
  // checks must be explicitly passed before any wallet debit can occur.
  return process.env.COIN_INDIVIDUAL_REDEMPTION_ENABLED === "true" &&
    process.env.COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED === "true" &&
    process.env.COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED === "true" &&
    process.env.COIN_PRICE_VERSION === COIN_BENEFIT_PRICE_VERSION;
}

const requestIdPattern =
  /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;

function expiryAfter(startMs: number, duration: string, count: number) {
  if (!Number.isSafeInteger(startMs) || startMs < 0 ||
      !Number.isSafeInteger(count) || count < 1 || count > 120) {
    throw new Error("Invalid entitlement time");
  }
  if (duration !== "month") {
    const unitMs = duration === "hour" ? 3_600_000
      : duration === "day" ? 86_400_000
      : duration === "week" ? 604_800_000 : 0;
    if (!unitMs) throw new Error("Invalid duration");
    const expiry = startMs + count * unitMs;
    if (!Number.isSafeInteger(expiry)) throw new Error("Expiry overflow");
    return expiry;
  }
  const d = new Date(startMs);
  const n = d.getUTCFullYear() * 12 + d.getUTCMonth() + count;
  const year = Math.floor(n / 12),month = n % 12;
  const lastDay = new Date(Date.UTC(year,month+1,0)).getUTCDate();
  const expiry = Date.UTC(year,month,Math.min(d.getUTCDate(),lastDay),
    d.getUTCHours(),d.getUTCMinutes(),
    d.getUTCSeconds(),d.getUTCMilliseconds());
  if (!Number.isSafeInteger(expiry)) throw new Error("Expiry overflow");
  return expiry;
}

export interface IndividualCoinRedemptionBody {
  targets?: unknown;
  duration?: unknown;
  quantity?: unknown;
  priceVersion?: unknown;
  requestId?: unknown;
}

export async function redeemIndividualCoins(
  niarimUserId: string,body: IndividualCoinRedemptionBody,
) {
  if (!individualCoinRedemptionEnabled()) {
    forbidden("個別特典の交換は準備中です","REDEMPTION_DISABLED");
  }
  if (!Array.isArray(body.targets) || body.targets.length < 1 ||
      body.targets.length > 11 ||
      body.targets.some(target=>typeof target !== "string")) {
    badRequest("特典の選択が不正です","REDEMPTION_INVALID_SELECTION");
  }
  if (typeof body.duration !== "string" ||
      typeof body.quantity !== "number" ||
      !Number.isSafeInteger(body.quantity)) {
    badRequest("交換期間が不正です","REDEMPTION_INVALID_DURATION");
  }
  if (typeof body.requestId !== "string" ||
      !requestIdPattern.test(body.requestId)) {
    badRequest("リクエストIDが不正です","REDEMPTION_REQUEST_ID_INVALID");
  }
  const requestId = body.requestId as string;
  const quote = catalogSelectionQuote({
    targets: (body.targets as string[]).join(","),
    duration: body.duration as string,
    quantity: String(body.quantity),
  });
  // A full bundle is handled exclusively by the verified Premium route.
  if (quote.targets.includes("fullPremium")) {
    badRequest("この交換内容は未対応です","REDEMPTION_NOT_AVAILABLE");
  }
  if (body.priceVersion !== COIN_BENEFIT_PRICE_VERSION) {
    conflict("交換価格が変更されました","REDEMPTION_PRICE_CHANGED");
  }

  const receiptKey=Keys.coinTransaction(niarimUserId,`redeem-${requestId}`);
  const existing=await ddb.send(new GetCommand({
    TableName:tableName(),Key:receiptKey,ConsistentRead:true,
  }));
  const signature=quote.targets.join(",");
  const matches=(item:Record<string,unknown>|undefined):boolean=>
    item?.itemType === "COIN_REDEMPTION" &&
    item.target === "individualBenefits" &&
    item.requestId === requestId &&
    item.selectionKey === signature &&
    item.duration === quote.duration &&
    item.quantity === quote.quantity &&
    item.priceVersion === quote.priceVersion &&
    item.costCoins === quote.catalogPriceCoins &&
    typeof item.expiresAtByTarget === "object" &&
    item.expiresAtByTarget !== null;

  if (existing.Item) {
    if (!matches(existing.Item)) {
      conflict("交換履歴が一致しません","REDEMPTION_REQUEST_REUSED");
    }
    return ok({
      redeemed:true,duplicate:true,targets:quote.targets,
      costCoins:quote.catalogPriceCoins,
      expiresAtByTarget:existing.Item.expiresAtByTarget,
    });
  }
  const now=Date.now();
  const user=await getUser(niarimUserId);
  const playActive=typeof user?.playPremiumExpiresAtEpochMs === "number" &&
    Number.isSafeInteger(user.playPremiumExpiresAtEpochMs) &&
    user.playPremiumExpiresAtEpochMs > now;
  if (!user || user.itemType !== "USER" ||
      user.membershipTier !== "free" || playActive) {
    forbidden("プレミアム加入中の特典交換は現在未対応です",
      "REDEMPTION_SUBSCRIPTION_CONFLICT");
  }

  // A fullPremium coin entitlement already includes every individual right.
  const full=await ddb.send(new GetCommand({
    TableName:tableName(),
    Key:Keys.rewardEntitlement(niarimUserId,"fullPremium"),
    ConsistentRead:true,
  }));
  if (full.Item?.itemType==="REWARD_ENTITLEMENT" &&
      full.Item.status==="active" &&
      typeof full.Item.expiresAtEpochMs==="number" &&
      full.Item.expiresAtEpochMs>now) {
    forbidden("同じ機能を含むPremium特典が有効です",
      "REDEMPTION_OVERLAPPING_BUNDLE");
  }
  if (full.Item?.status==="paused") {
    conflict("停止中の特典を確認してください",
      "REDEMPTION_PAUSED_ENTITLEMENT");
  }

  const prior=await Promise.all(quote.targets.map(target=>
    ddb.send(new GetCommand({
      TableName:tableName(),
      Key:Keys.rewardEntitlement(niarimUserId,target),
      ConsistentRead:true,
    })),
  ));
  const expiresAtByTarget:Record<string,number>={};
  const entitlementWrites=quote.targets.map((target,index)=>{
    const previous=prior[index].Item;
    if (previous?.status==="paused") {
      conflict("停止中の特典を確認してください",
        "REDEMPTION_PAUSED_ENTITLEMENT");
    }
    if (previous?.itemType && previous.itemType!=="REWARD_ENTITLEMENT") {
      forbidden("特典データに不整合があります",
        "ENTITLEMENT_TYPE_CONFLICT");
    }
    const expiry=previous?.expiresAtEpochMs;
    if (expiry!==undefined && (!Number.isSafeInteger(expiry)||expiry<0)) {
      forbidden("特典期限の再検証が必要です","ENTITLEMENT_INVALID");
    }
    const from=Math.max(now,typeof expiry==="number"?expiry:0);
    const next=expiryAfter(from,quote.duration,quote.quantity);
    expiresAtByTarget[target]=next;
    return {
      Update:{
        TableName:tableName(),
        Key:Keys.rewardEntitlement(niarimUserId,target),
        UpdateExpression:
          "SET itemType = :type, entitlement = :entitlement, " +
          "#status = :active, expiresAtEpochMs = :expiry, " +
          "source = :source, lastRedemptionId = :requestId",
        ConditionExpression:
          "(attribute_not_exists(itemType) OR itemType = :type) AND " +
          "(attribute_not_exists(#status) OR #status = :active) AND " +
          (expiry===undefined
            ? "attribute_not_exists(expiresAtEpochMs)"
            : "expiresAtEpochMs = :oldExpiry"),
        ExpressionAttributeNames:{"#status":"status"},
        ExpressionAttributeValues:{
          ":type":"REWARD_ENTITLEMENT",":entitlement":target,
          ":active":"active",":expiry":next,":source":"coin-redemption",
          ":requestId":requestId,
          ...(expiry===undefined?{}:{":oldExpiry":expiry}),
        },
      },
    };
  });

  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems:[
        {Put:{
          TableName:tableName(),
          Item:{...receiptKey,itemType:"COIN_REDEMPTION",
            requestId,target:"individualBenefits",selectionKey:signature,
            duration:quote.duration,quantity:quote.quantity,
            priceVersion:quote.priceVersion,costCoins:quote.catalogPriceCoins,
            redeemedAtMs:now,expiresAtByTarget},
          ConditionExpression:"attribute_not_exists(pk)",
        }},
        {Update:{
          TableName:tableName(),Key:Keys.coinWallet(niarimUserId),
          UpdateExpression:"SET updatedAtEpochMs = :now ADD " +
            "balanceCoins :minus, redeemedCoins :price",
          ConditionExpression:"itemType = :wallet AND balanceCoins >= :price",
          ExpressionAttributeValues:{
            ":now":now,":minus":-quote.catalogPriceCoins,
            ":price":quote.catalogPriceCoins,":wallet":"COIN_WALLET",
          },
        }},
        ...entitlementWrites,
        // A Play verification or membership change can commit between the
        // preflight getUser read and this transaction. Verify the user state
        // atomically with the debit, rather than trusting the stale read.
        {ConditionCheck:{
          TableName:tableName(),
          Key:Keys.user(niarimUserId),
          ConditionExpression:
            "itemType = :user AND membershipTier = :free AND " +
            "(attribute_not_exists(playPremiumExpiresAtEpochMs) OR " +
            "playPremiumExpiresAtEpochMs <= :now)",
          ExpressionAttributeValues:{
            ":user":"USER",":free":"free",":now":now,
          },
        }},
        // Guard against a concurrent fullPremium purchase that would grant
        // these rights at the same moment. The preflight read alone is not
        // sufficient to prevent a double charge.
        {ConditionCheck:{
          TableName:tableName(),
          Key:Keys.rewardEntitlement(niarimUserId,"fullPremium"),
          ConditionExpression:
            "attribute_not_exists(itemType) OR " +
            "(itemType = :type AND (#status = :active AND " +
            "expiresAtEpochMs <= :now))",
          ExpressionAttributeNames:{"#status":"status"},
          ExpressionAttributeValues:{
            ":type":"REWARD_ENTITLEMENT",
            ":active":"active",":now":now,
          },
        }},
        {Put:{
          TableName:tableName(),
          Item:{
            ...Keys.coinHistory(niarimUserId,now,`redeem-${requestId}`),
            itemType:"COIN_HISTORY",source:"coin-redemption",
            deltaCoins:-quote.catalogPriceCoins,occurredAtEpochMs:now,
            target:"individualBenefits",selectionKey:signature,requestId,
          },
          ConditionExpression:"attribute_not_exists(pk)",
        }},
      ],
    }));
  } catch(error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      const after=await ddb.send(new GetCommand({
        TableName:tableName(),Key:receiptKey,ConsistentRead:true,
      }));
      if (matches(after.Item)) {
        return ok({redeemed:true,duplicate:true,targets:quote.targets,
          costCoins:quote.catalogPriceCoins,
          expiresAtByTarget:after.Item?.expiresAtByTarget});
      }
      conflict("残高または特典状態が更新されました",
        "REDEMPTION_STATE_CHANGED");
    }
    throw error;
  }
  return ok({
    redeemed:true,duplicate:false,targets:quote.targets,
    costCoins:quote.catalogPriceCoins,expiresAtByTarget,
  });
}
