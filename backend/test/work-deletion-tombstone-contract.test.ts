import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const deleteSource = readFileSync(
  resolve(__dirname, "../src/api/routes/worksDelete.ts"),
  "utf8",
);
const createSource = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
  "utf8",
);
const statsSource = readFileSync(
  resolve(__dirname, "../src/batch/statsUpdate.ts"),
  "utf8",
);

describe("work deletion tombstone contract", () => {
  it("replaces a deleted work with a tombstone on the same WORK key", () => {
    expect(deleteSource).toContain("const key = Keys.work(workId)");
    expect(deleteSource).toContain('itemType: "WORK_TOMBSTONE"');
    expect(deleteSource).toContain("workId,");
    expect(deleteSource).toContain("deletedAt: new Date().toISOString()");
  });

  it("only tombstones the current author's live WORK item", () => {
    expect(deleteSource).toContain(
      'ConditionExpression: "itemType = :workType AND authorId = :authorId"',
    );
    expect(deleteSource).toContain('":workType": TABLE_ITEM_TYPE.Work');
    expect(deleteSource).toContain('":authorId": auth.niarimUserId');
  });

  it("never allows a deleted YouTube video id to become a new NIARIM work again", () => {
    expect(createSource).toContain(
      'existingRaw?.itemType === "WORK_TOMBSTONE"',
    );
    expect(createSource).toContain('"WORK_DELETED"');
  });

  it("keeps tombstones out of the stats scan and retry path", () => {
    expect(statsSource).toContain('ExpressionAttributeValues: { ":type": "WORK" }');
    expect(statsSource).toContain(
      "latestRaw?.itemType === TABLE_ITEM_TYPE.Work",
    );
  });
});
