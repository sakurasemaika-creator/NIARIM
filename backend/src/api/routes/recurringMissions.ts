import { randomUUID } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException,
  TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { parseJsonObject } from "../../lib/request";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import {
  RECURRING_MISSIONS, RECURRING_MISSION_CATALOG_VERSION,
  RECURRING_MISSION_STATE_TYPE, normalizeRecurringState,
  recurringPeriodKeys, recurringProgress, recurringMissionPayoutEnabled,
} from "../../lib/recurringMissionCatalog";

async function loadState(userId: string) {
  const row = await ddb.send(new GetCommand({
    TableName: tableName(),
    Key: Keys.recurringMissionState(userId),
    ConsistentRead: true,
  }));
  if (row.Item?.itemType &&
      row.Item.itemType !== RECURRING_MISSION_STATE_TYPE) {
    forbidden("期間ミッションの記録を確認できません", "RECURRING_STATE_INVALID");
  }
  return normalizeRecurringState(row.Item);
}

/**
 * Record a login visit once per JST date; no time/period values from client.
 * Called after the existing authenticated daily login visit (including safe
 * repeated requests). Exactly one row updated per user/day; other visits are
 * GET-only and claims never trigger writes from a GET.
 */
export async function recordRecurringLoginVisit(userId: string): Promise<void> {
  const period = recurringPeriodKeys();
  // A coin claim can modify either claimed mask while today's visit is being
  // read. Compare both masks and retry rather than overwriting a paid claim.
  for (let attempt=0; attempt<3; attempt++) {
    const state = await loadState(userId);
    if (state.lastVisitedDay >= period.day) return;
    const sameWeek = state.weekKey === period.week;
    const sameMonth = state.monthKey === period.month;
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(),
        Key: Keys.recurringMissionState(userId),
        UpdateExpression:
          "SET itemType = :type, lastVisitedDay = :day, " +
          "weekKey = :week, weekDays = :weekDays, weekClaimedMask = :weekMask, " +
          "monthKey = :month, monthDays = :monthDays, monthClaimedMask = :monthMask",
        ConditionExpression:
          "(attribute_not_exists(lastVisitedDay) OR lastVisitedDay < :day) " +
          "AND (attribute_not_exists(weekClaimedMask) OR " +
          "weekClaimedMask = :oldWeekMask) " +
          "AND (attribute_not_exists(monthClaimedMask) OR " +
          "monthClaimedMask = :oldMonthMask)",
        ExpressionAttributeValues: {
          ":type": RECURRING_MISSION_STATE_TYPE,
          ":day": period.day,
          ":week": period.week,
          ":weekDays": sameWeek ? Math.min(state.weekDays + 1, 7) : 1,
          ":weekMask": sameWeek ? state.weekClaimedMask : 0,
          ":oldWeekMask": state.weekClaimedMask,
          ":month": period.month,
          ":monthDays": sameMonth ? Math.min(state.monthDays + 1, 31) : 1,
          ":monthMask": sameMonth ? state.monthClaimedMask : 0,
          ":oldMonthMask": state.monthClaimedMask,
        },
      }));
      return;
    } catch (error) {
      if (error instanceof ConditionalCheckFailedException) continue;
      throw error;
    }
  }
  throw new Error("Concurrent recurring visit state change; retry later");
}

/** Read-only current JST week/month goals. All rewards are feature-gated. */
export async function getMyRecurringMissions(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const periods = recurringPeriodKeys();
  const state = await loadState(auth.niarimUserId);
  const enabled = recurringMissionPayoutEnabled();
  return ok({
    enabled,
    catalogVersion: RECURRING_MISSION_CATALOG_VERSION,
    resetTimeZone: "Asia/Tokyo",
    weekKey: periods.week, monthKey: periods.month,
    missions: RECURRING_MISSIONS.map((m) => {
      const result = recurringProgress(state, m, periods);
      return {
        ...m, ...result,
        eligible: result.progressDays >= m.requiredDays,
        ready: enabled && result.progressDays >= m.requiredDays && !result.claimed,
      };
    }),
  });
}

/**
 * A conditional bitmask, wallet credit and history form a single transaction.
 * Repeat/multi-device claims cannot pay twice; request supplies only mission
 * ID, never coins or a progress counter.
 */
export async function claimMyRecurringMission(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (!recurringMissionPayoutEnabled()) {
    forbidden("期間ミッションのコイン受取は公開準備中です", "RECURRING_PAYOUT_DISABLED");
  }
  const body = parseJsonObject(event.body);
  const mission = RECURRING_MISSIONS.find((m) => m.id === body.missionId);
  if (!mission) badRequest("不明な期間ミッションです", "RECURRING_MISSION_INVALID");
  const period = recurringPeriodKeys();
  const state = await loadState(auth.niarimUserId);
  const result = recurringProgress(state, mission, period);
  if (result.claimed) {
    return ok({claimed: true, duplicate: true, awardedCoins: 0,
      missionId: mission.id, periodKey: result.periodKey});
  }
  if (result.progressDays < mission.requiredDays) {
    conflict("期間ミッションの条件を満たしていません", "RECURRING_NOT_ELIGIBLE");
  }
  const maskAttr = mission.period === "week" ? "weekClaimedMask" : "monthClaimedMask";
  const keyAttr = mission.period === "week" ? "weekKey" : "monthKey";
  const daysAttr = mission.period === "week" ? "weekDays" : "monthDays";
  const oldMask = mission.period === "week" ? state.weekClaimedMask : state.monthClaimedMask;
  const nextMask = oldMask + 2 ** mission.bit;
  const now = Date.now();
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(),
            Key: Keys.recurringMissionState(auth.niarimUserId),
            UpdateExpression: "SET #mask = :nextMask",
            ConditionExpression: "itemType = :type AND #key = :period " +
              "AND #days >= :required AND #mask = :oldMask",
            ExpressionAttributeNames: {
              "#mask": maskAttr, "#key": keyAttr, "#days": daysAttr,
            },
            ExpressionAttributeValues: {
              ":type": RECURRING_MISSION_STATE_TYPE,
              ":period": result.periodKey,
              ":required": mission.requiredDays,
              ":oldMask": oldMask, ":nextMask": nextMask,
            },
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.coinWallet(auth.niarimUserId),
            UpdateExpression:
              "SET itemType = :type ADD balanceCoins :coins, " +
              "missionEarnedCoins :coins",
            ConditionExpression:
              "(attribute_not_exists(itemType) OR itemType = :type) " +
              "AND (attribute_not_exists(balanceCoins) OR " +
              "balanceCoins BETWEEN :zero AND :max)",
            ExpressionAttributeValues: {
              ":type": "COIN_WALLET", ":coins": mission.coins,
              ":zero": 0,
              ":max": Number.MAX_SAFE_INTEGER - mission.coins,
            },
          },
        },
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.coinHistory(auth.niarimUserId, now,
                `recurring-${mission.id}-${randomUUID()}`),
              itemType: "COIN_HISTORY", source: "recurring-mission",
              missionId: mission.id, periodKey: result.periodKey,
              deltaCoins: mission.coins, occurredAtEpochMs: now,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      // A concurrent request may have paid successfully. Show current state
      // rather than charging again, and leave history/wallet server-owned.
      const updated = recurringProgress(
        await loadState(auth.niarimUserId), mission, recurringPeriodKeys(),
      );
      if (updated.claimed && updated.periodKey === result.periodKey) {
        return ok({claimed: true, duplicate: true, awardedCoins: 0,
          missionId: mission.id, periodKey: result.periodKey});
      }
      conflict("進捗または受取状態が更新されました", "RECURRING_STATE_CHANGED");
    }
    throw error;
  }
  return ok({
    claimed: true, duplicate: false, awardedCoins: mission.coins,
    missionId: mission.id, periodKey: result.periodKey,
  });
}
