// The daily post quota and the report quota write a counter with an expiry
// attribute named `ttl`, a DynamoDB reserved word. Written bare in the
// UpdateExpression, DynamoDB rejected every write, so posting a work and
// reporting a work always failed with an internal error (found by walking the
// app against a local copy of the backend, 2026-11-28).
import {
  CreateTableCommand,
  DeleteTableCommand,
  DynamoDBClient,
  waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("../src/lib/dynamo", async (original) => {
  const source = await original<typeof import("../src/lib/dynamo")>();
  const { DynamoDBClient: Client } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient: Doc } = await import("@aws-sdk/lib-dynamodb");
  return {
    ...source,
    ddb: Doc.from(
      new Client({
        endpoint: "http://127.0.0.1:8000",
        region: "ap-northeast-1",
        credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
      }),
      { marshallOptions: { removeUndefinedValues: true } },
    ),
  };
});

import { ddb, Keys, todayYyyymmdd } from "../src/lib/dynamo";
import {
  readPostQuota,
  releasePostQuota,
  reservePostQuota,
} from "../src/lib/quota";
import {
  REPORT_MAX_PER_WINDOW,
  reportWindowId,
  reserveReportQuota,
} from "../src/lib/reportQuota";

const local = new DynamoDBClient({
  endpoint: "http://127.0.0.1:8000",
  region: "ap-northeast-1",
  credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
});
const TableName = "niarim-quota-local-" + Date.now();
const user = "N" + "c".repeat(32);

describe.skipIf(process.env.NIARIM_DYNAMODB_LOCAL_TESTS !== "1")(
  "post and report quotas in DynamoDB Local",
  () => {
    beforeAll(async () => {
      vi.stubEnv("TABLE_NAME", TableName);
      await local.send(
        new CreateTableCommand({
          TableName,
          BillingMode: "PAY_PER_REQUEST",
          AttributeDefinitions: [
            { AttributeName: "pk", AttributeType: "S" },
            { AttributeName: "sk", AttributeType: "S" },
          ],
          KeySchema: [
            { AttributeName: "pk", KeyType: "HASH" },
            { AttributeName: "sk", KeyType: "RANGE" },
          ],
        }),
      );
      await waitUntilTableExists(
        { client: local, maxWaitTime: 30, minDelay: 1 },
        { TableName },
      );
    });
    afterAll(async () => {
      vi.unstubAllEnvs();
      await local
        .send(new DeleteTableCommand({ TableName }))
        .catch(() => undefined);
    });

    it("reserves a free member's one post a day with an expiry, refuses the second, and gives it back", async () => {
      await reservePostQuota(user, "free");
      const date = todayYyyymmdd();
      const counter = (
        await ddb.send(
          new GetCommand({
            TableName,
            Key: Keys.dailyCounter(user, date),
            ConsistentRead: true,
          }),
        )
      ).Item;
      expect(counter?.count).toBe(1);
      expect(typeof counter?.ttl).toBe("number");
      await expect(reservePostQuota(user, "free")).rejects.toMatchObject({
        statusCode: 409,
        code: "POST_QUOTA_EXCEEDED",
      });
      await releasePostQuota(user);
      await expect(reservePostQuota(user, "free")).resolves.toBeUndefined();
    });

    it("reads the same counter the reservation writes, without writing", async () => {
      const reader = "N" + "d".repeat(32);
      expect(await readPostQuota(reader, "free")).toEqual({
        limit: 1,
        used: 0,
        remaining: 1,
      });
      await reservePostQuota(reader, "free");
      expect(await readPostQuota(reader, "free")).toEqual({
        limit: 1,
        used: 1,
        remaining: 0,
      });
      expect(await readPostQuota(reader, "premium")).toEqual({
        limit: 3,
        used: 1,
        remaining: 2,
      });
      await releasePostQuota(reader);
      expect((await readPostQuota(reader, "free")).remaining).toBe(1);
    });

    it("counts reports with an expiry and limits a burst", async () => {
      const now = new Date();
      for (let i = 0; i < REPORT_MAX_PER_WINDOW; i++)
        await reserveReportQuota(user, now);
      const counter = (
        await ddb.send(
          new GetCommand({
            TableName,
            Key: Keys.reportCounter(user, reportWindowId(now)),
            ConsistentRead: true,
          }),
        )
      ).Item;
      expect(counter?.count).toBe(REPORT_MAX_PER_WINDOW);
      expect(typeof counter?.ttl).toBe("number");
      await expect(reserveReportQuota(user, now)).rejects.toMatchObject({
        statusCode: 409,
        code: "REPORT_RATE_LIMITED",
      });
    });
  },
);
