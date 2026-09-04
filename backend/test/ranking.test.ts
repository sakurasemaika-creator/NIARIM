import { describe, expect, it } from "vitest";
import {
  computePeriodScore,
  computeRankingScore,
  currentWindowId,
  insertIntoTopList,
  isDeltaRankingPeriod,
  isRankingPeriod,
  isoWeekId,
  rollStatsWindows,
} from "../src/lib/ranking";

describe("computeRankingScore", () => {
  it("viewCountを主軸に、likeCountとcommentCountを加重して合算する", () => {
    expect(
      computeRankingScore({ viewCount: 100, likeCount: 10, commentCount: 5 }),
    ).toBe(100 + 10 * 5 + 5 * 2);
  });

  it("負の値は0として扱う（異常データからの防御）", () => {
    expect(
      computeRankingScore({ viewCount: -5, likeCount: -1, commentCount: -1 }),
    ).toBe(0);
  });

  it("全て0のときは0を返す", () => {
    expect(
      computeRankingScore({ viewCount: 0, likeCount: 0, commentCount: 0 }),
    ).toBe(0);
  });
});

describe("ランキング期間の判定", () => {
  it("仕様書の5種類すべてを期間として認める", () => {
    for (const period of ["all", "yearly", "monthly", "weekly", "daily"]) {
      expect(isRankingPeriod(period)).toBe(true);
    }
  });

  it("累計(all)は差分方式ではない", () => {
    expect(isDeltaRankingPeriod("all")).toBe(false);
  });

  it("年間/月間/週間/デイリーは差分方式と判定する", () => {
    for (const period of ["yearly", "monthly", "weekly", "daily"]) {
      expect(isDeltaRankingPeriod(period)).toBe(true);
    }
  });

  it("未知の値はどちらでもない", () => {
    expect(isRankingPeriod("bogus")).toBe(false);
    expect(isDeltaRankingPeriod("bogus")).toBe(false);
  });
});

describe("currentWindowId", () => {
  const t = new Date("2026-09-02T12:34:56Z"); // 水曜日

  it("年間は西暦4桁", () => {
    expect(currentWindowId("yearly", t)).toBe("2026");
  });

  it("月間はYYYYMM", () => {
    expect(currentWindowId("monthly", t)).toBe("202609");
  });

  it("デイリーはYYYYMMDD", () => {
    expect(currentWindowId("daily", t)).toBe("20260902");
  });

  it("週間はISO週（月曜始まり）で、同じ週の月曜と日曜が同一IDになる", () => {
    const monday = new Date("2026-08-31T00:00:00Z");
    const sunday = new Date("2026-09-06T23:59:59Z");
    const nextMonday = new Date("2026-09-07T00:00:00Z");
    expect(currentWindowId("weekly", monday)).toBe(
      currentWindowId("weekly", sunday),
    );
    expect(currentWindowId("weekly", nextMonday)).not.toBe(
      currentWindowId("weekly", monday),
    );
  });

  it("ISO週は年をまたぐ週で木曜の属する年を採る", () => {
    // 2027-01-01は金曜。その週の木曜は2026-12-31なので2026年の最終週。
    expect(isoWeekId(new Date("2027-01-01T00:00:00Z")).startsWith("2026")).toBe(
      true,
    );
  });
});

describe("rollStatsWindows / computePeriodScore", () => {
  const t0 = new Date("2026-09-02T00:00:00Z");
  const base = { viewCount: 1000, likeCount: 100, commentCount: 10 };

  it("初回は現在値を基準点に置くので、その期間のスコアは0から始まる", () => {
    const windows = rollStatsWindows(undefined, base, t0);
    expect(computePeriodScore(base, windows.daily)).toBe(0);
  });

  it("同じ窓の間は基準点が動かず、伸びた分だけスコアが積み上がる", () => {
    const first = rollStatsWindows(undefined, base, t0);
    const later = new Date("2026-09-02T18:00:00Z"); // 同じ日
    const grown = { viewCount: 1500, likeCount: 120, commentCount: 15 };
    const second = rollStatsWindows(first, grown, later);

    expect(second.daily).toEqual(first.daily); // 基準点は据え置き
    expect(computePeriodScore(grown, second.daily)).toBe(
      computeRankingScore({ viewCount: 500, likeCount: 20, commentCount: 5 }),
    );
  });

  it("窓が変わると基準点が取り直され、スコアが0へ戻る", () => {
    const first = rollStatsWindows(undefined, base, t0);
    const nextDay = new Date("2026-09-03T00:00:00Z");
    const grown = { viewCount: 1500, likeCount: 120, commentCount: 15 };
    const second = rollStatsWindows(first, grown, nextDay);

    expect(second.daily).not.toEqual(first.daily);
    expect(computePeriodScore(grown, second.daily)).toBe(0);
    // 日が変わっただけなので月間・年間の基準点は据え置き。
    expect(second.monthly).toEqual(first.monthly);
    expect(second.yearly).toEqual(first.yearly);
  });

  it("統計が減っても負のスコアにはしない", () => {
    const windows = rollStatsWindows(undefined, base, t0);
    const shrunk = { viewCount: 900, likeCount: 90, commentCount: 5 };
    expect(computePeriodScore(shrunk, windows.daily)).toBe(0);
  });

  it("スナップショットが無い場合は0を返す", () => {
    expect(computePeriodScore(base, undefined)).toBe(0);
  });
});

describe("insertIntoTopList", () => {
  it("スコア降順に並べ、上限を超えたぶんを切り捨てる", () => {
    let list: { workId: string; score: number }[] = [];
    list = insertIntoTopList(list, { workId: "a", score: 10 }, 2);
    list = insertIntoTopList(list, { workId: "b", score: 30 }, 2);
    list = insertIntoTopList(list, { workId: "c", score: 20 }, 2);
    expect(list.map((e) => e.workId)).toEqual(["b", "c"]);
  });

  it("スコア0以下は載せない（その期間に伸びていない作品を除く）", () => {
    expect(insertIntoTopList([], { workId: "a", score: 0 }, 10)).toEqual([]);
    expect(insertIntoTopList([], { workId: "a", score: -5 }, 10)).toEqual([]);
  });

  it("同じ作品を2回入れても重複しない（バッチ再実行時の冪等性）", () => {
    let list = insertIntoTopList([], { workId: "a", score: 10 }, 10);
    list = insertIntoTopList(list, { workId: "a", score: 20 }, 10);
    expect(list).toEqual([{ workId: "a", score: 20 }]);
  });

  it("同スコアはworkIdで安定した順序になる", () => {
    let list = insertIntoTopList([], { workId: "b", score: 10 }, 10);
    list = insertIntoTopList(list, { workId: "a", score: 10 }, 10);
    expect(list.map((e) => e.workId)).toEqual(["a", "b"]);
  });
});
