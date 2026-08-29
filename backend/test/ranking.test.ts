import { describe, expect, it } from 'vitest';
import { computeRankingScore, isImplementedRankingPeriod } from '../src/lib/ranking';

describe('computeRankingScore', () => {
  it('viewCountを主軸に、likeCountとcommentCountを加重して合算する', () => {
    expect(computeRankingScore({ viewCount: 100, likeCount: 10, commentCount: 5 })).toBe(
      100 + 10 * 5 + 5 * 2,
    );
  });

  it('負の値は0として扱う（異常データからの防御）', () => {
    expect(computeRankingScore({ viewCount: -5, likeCount: -1, commentCount: -1 })).toBe(0);
  });

  it('全て0のときは0を返す', () => {
    expect(computeRankingScore({ viewCount: 0, likeCount: 0, commentCount: 0 })).toBe(0);
  });
});

describe('isImplementedRankingPeriod', () => {
  it('allのみ実装済みと判定する', () => {
    expect(isImplementedRankingPeriod('all')).toBe(true);
  });

  it('yearly/monthly/weekly/dailyは未実装と判定する', () => {
    for (const period of ['yearly', 'monthly', 'weekly', 'daily']) {
      expect(isImplementedRankingPeriod(period)).toBe(false);
    }
  });

  it('未知の値は未実装と判定する', () => {
    expect(isImplementedRankingPeriod('bogus')).toBe(false);
  });
});
