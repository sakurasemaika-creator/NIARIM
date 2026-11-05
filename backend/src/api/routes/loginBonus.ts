import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { randomUUID } from "node:crypto";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { BatchGetCommand, GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { parseJsonObject } from "../../lib/request";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import {
  DAILY_LOGIN_COINS, LOGIN_BONUS_CATALOG_VERSION, LOGIN_BONUS_MILESTONES,
  loginBonusRewardEnabled, milestoneCoins, utcLoginDay,
} from "../../lib/loginBonusCatalog";

const ITEM_TYPE = "LOGIN_BONUS_STATE_V1";
const MILESTONE_TYPE = "LOGIN_BONUS_MILESTONE_V1";

async function owner(event: APIGatewayProxyEventV2): Promise<string> {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  return auth.niarimUserId;
}
function validDays(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value : 0;
}
function snapshot(raw: Record<string, unknown> | undefined) {
  if (raw !== undefined && raw.itemType !== ITEM_TYPE) {
    forbidden("ログイン履歴を確認できません", "LOGIN_BONUS_STATE_INVALID");
  }
  return {
    totalDays: validDays(raw?.totalDays),
    lastVisitedDay: typeof raw?.lastVisitedDay === "string"
      ? raw.lastVisitedDay : null,
    lastClaimedDay: typeof raw?.lastClaimedDay === "string"
      ? raw.lastClaimedDay : null,
  };
}
async function getState(userId: string) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(),Key: Keys.loginBonusState(userId),
    ConsistentRead: true,
  }));
  return snapshot(result.Item);
}

/** Called from the authenticated app entry: records a day even if rewards
 * are currently disabled or the user chooses not to press Claim.
 * No streaks, no coin writes, no client-supplied clock.
 */
export async function visitMyLoginBonus(event: APIGatewayProxyEventV2) {
  const userId = await owner(event);
  const day = utcLoginDay();
  try {
    const result = await ddb.send(new UpdateCommand({
      TableName: tableName(),Key: Keys.loginBonusState(userId),
      UpdateExpression:
        "SET itemType = :type, lastVisitedDay = :day, updatedAt = :at " +
        "ADD totalDays :one",
      ConditionExpression: "attribute_not_exists(pk) OR " +
        "(itemType = :type AND lastVisitedDay < :day)",
      ExpressionAttributeValues: {
        ":type": ITEM_TYPE,":day":day,":at":new Date().toISOString(),":one":1,
      },
      ReturnValues: "ALL_NEW",
    }));
    const state = snapshot(result.Attributes);
    return ok({...state,day,visitedToday:true});
  } catch (error) {
    if (!(error instanceof ConditionalCheckFailedException)) throw error;
    const state = await getState(userId);
    if (state.lastVisitedDay !== day) {
      conflict("ログイン記録が更新されました", "LOGIN_BONUS_RETRY");
    }
    return ok({...state,day,visitedToday:true});
  }
}

export async function getMyLoginBonus(event: APIGatewayProxyEventV2) {
  const userId = await owner(event),day = utcLoginDay();
  const table = tableName();
  const [state,marks] = await Promise.all([
    getState(userId),
    ddb.send(new BatchGetCommand({
      RequestItems: {
        [table]: {
          Keys: LOGIN_BONUS_MILESTONES.map(m=>
            Keys.loginBonusMilestone(userId,m.days)),
          ConsistentRead:true,
        },
      },
    })),
  ]);
  if ((marks.UnprocessedKeys?.[table]?.Keys?.length??0)>0) {
    throw new Error("Unprocessed login bonus milestone reads");
  }
  const claimed = new Set<number>();
  for (const row of marks.Responses?.[table]??[]) {
    if (row.pk === `USER#${userId}` && row.itemType === MILESTONE_TYPE &&
        typeof row.days === "number" && Number.isSafeInteger(row.days)) {
      claimed.add(row.days);
    }
  }
  return ok({
    ...state, day,
    visitedToday:state.lastVisitedDay===day,
    dailyClaimed:state.lastClaimedDay===day,
    dailyCoins:DAILY_LOGIN_COINS,
    rewardEnabled:loginBonusRewardEnabled(),
    catalogVersion:LOGIN_BONUS_CATALOG_VERSION,
    resetTimeZone:"UTC",
    milestones:LOGIN_BONUS_MILESTONES.map(m=>({
      ...m,eligible:state.totalDays>=m.days,claimed:claimed.has(m.days),
    })),
  });
}
function walletTransaction(userId:string,amount:number) {
  return {Update:{
    TableName:tableName(),Key:Keys.coinWallet(userId),
    UpdateExpression:"SET itemType = :walletType " +
      "ADD balanceCoins :award, missionEarnedCoins :award",
    ConditionExpression:
      "(attribute_not_exists(itemType) OR itemType = :walletType) AND " +
      "(attribute_not_exists(balanceCoins) OR balanceCoins BETWEEN :zero AND :limit)",
    ExpressionAttributeValues:{
      ":walletType":"COIN_WALLET",":award":amount,":zero":0,
      ":limit":Number.MAX_SAFE_INTEGER-amount,
    },
  }};
}
function historyTransaction(userId:string,amount:number,missionId:string) {
  const now=Date.now();
  return {Put:{
    TableName:tableName(),
    Item:{
      ...Keys.coinHistory(userId,now,`login-${randomUUID()}`),
      itemType:"COIN_HISTORY",source:"login-bonus",deltaCoins:amount,
      missionId,occurredAtEpochMs:now,
    },
    ConditionExpression:"attribute_not_exists(pk)",
  }};
}
/** Manual, once-per-date or once-per-goal claim. Zero payout by default. */
export async function claimMyLoginBonus(event: APIGatewayProxyEventV2) {
  const userId=await owner(event);
  const body=parseJsonObject(event.body);
  const kind=body.kind;
  if (kind!=="daily" && kind!=="milestone") {
    badRequest("受取種別が不正です", "LOGIN_BONUS_INVALID_KIND");
  }
  if (!loginBonusRewardEnabled()) {
    forbidden("ログイン報酬の公開準備中です", "LOGIN_BONUS_PAYOUTS_DISABLED");
  }
  const today=utcLoginDay();
  const table=tableName();
  let amount:number,missionId:string;
  const stateKey=Keys.loginBonusState(userId);
  const items:any[]=[];
  if (kind==="daily") {
    if (body.days!==undefined)badRequest("日数を指定できません");
    amount=DAILY_LOGIN_COINS;
    missionId=`login_daily_${today.replaceAll("-","")}`;
    items.push({Update:{
      TableName:table,Key:stateKey,
      UpdateExpression:"SET lastClaimedDay = :day",
      ConditionExpression:
        "itemType = :type AND lastVisitedDay = :day AND " +
        "(attribute_not_exists(lastClaimedDay) OR lastClaimedDay <> :day)",
      ExpressionAttributeValues:{":type":ITEM_TYPE,":day":today},
    }});
  } else {
    const days=body.days;
    if (typeof days!=="number"||!Number.isSafeInteger(days)) {
      badRequest("達成日数が不正です","LOGIN_BONUS_INVALID_GOAL");
    }
    const offer=milestoneCoins(days);
    if (offer===undefined)badRequest("未定義の節目です","LOGIN_BONUS_INVALID_GOAL");
    amount=offer;
    missionId=`login_total_${days}`;
    items.push({ConditionCheck:{
      TableName:table,Key:stateKey,
      ConditionExpression:"itemType = :type AND totalDays >= :days",
      ExpressionAttributeValues:{":type":ITEM_TYPE,":days":days},
    }});
    items.push({Put:{
      TableName:table,
      Item:{
        ...Keys.loginBonusMilestone(userId,days),
        itemType:MILESTONE_TYPE,days,claimedAt:new Date().toISOString(),
      },
      ConditionExpression:"attribute_not_exists(pk)",
    }});
  }
  items.push(walletTransaction(userId,amount),
    historyTransaction(userId,amount,missionId));
  try {
    await ddb.send(new TransactWriteCommand({TransactItems:items}));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      conflict("受取済み、または達成状況が更新されました",
        "LOGIN_BONUS_ALREADY_CLAIMED_OR_NOT_ELIGIBLE");
    }
    throw error;
  }
  return ok({claimed:true,awardedCoins:amount,missionId,
    kind,day:today,...(kind==="milestone"?{days:body.days}:{})});
}
