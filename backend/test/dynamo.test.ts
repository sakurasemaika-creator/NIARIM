import { describe, expect, it } from "vitest";
import { Keys, todayYyyymmdd, GLOBAL_COUNTER_USER_ID } from "../src/lib/dynamo";

describe("Keys（キー生成ヘルパー）", () => {
  it("workは`WORK#{id}`/`META`を返す", () => {
    expect(Keys.work("abc123")).toEqual({ pk: "WORK#abc123", sk: "META" });
  });

  it("followerRecordはtargetを基点にフォロワーIDをSKへ載せる", () => {
    expect(Keys.followerRecord("target1", "follower1")).toEqual({
      pk: "USER#target1",
      sk: "FOLLOWER#follower1",
    });
  });

  it("followingRecordはfollowerを基点にtargetIDをSKへ載せる（二重書き込みのミラー）", () => {
    expect(Keys.followingRecord("follower1", "target1")).toEqual({
      pk: "USER#follower1",
      sk: "FOLLOWING#target1",
    });
  });

  it("dailyCounterはユーザーIDと日付でキーを分ける", () => {
    expect(Keys.dailyCounter("N1", "20260101")).toEqual({
      pk: "COUNTER#N1#20260101",
      sk: "META",
    });
    expect(Keys.dailyCounter(GLOBAL_COUNTER_USER_ID, "20260101")).toEqual({
      pk: "COUNTER#GLOBAL#20260101",
      sk: "META",
    });
  });
});

describe("todayYyyymmdd", () => {
  it("UTC基準でyyyymmdd形式に整形する", () => {
    expect(todayYyyymmdd(new Date("2026-03-05T12:00:00Z"))).toBe("20260305");
  });

  it("日付が1桁月・1桁日でもゼロ埋めされる", () => {
    expect(todayYyyymmdd(new Date("2026-01-09T00:00:00Z"))).toBe("20260109");
  });
});
