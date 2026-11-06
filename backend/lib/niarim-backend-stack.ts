import {
  Duration,
  RemovalPolicy,
  Stack,
  StackProps,
  CfnOutput,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import * as path from "path";

/**
 * NIARIM作品広場バックエンド（`29_動画投稿・ランキング機能仕様.md` 16章）。
 *
 * ## $0運用の設計方針
 *
 * DynamoDBのAlways Free枠（25 GBストレージ・25 RCU・25 WCU、アカウント
 * 単位で永続的に無料。12ヶ月限定の新規アカウント特典とは別枠）に収まる
 * よう、テーブル本体とGSI合計であらかじめ容量を割り振っている
 * （下記`CAPACITY_PLAN`参照）。オンデマンド課金（PAY_PER_REQUEST）は
 * Always Free枠の対象外で最初のリクエストから課金が発生するため
 * 採用しない。
 *
 * Lambda・EventBridge SchedulerもAlways Free枠（Lambda：月100万
 * リクエスト＋40万GB秒、EventBridge Scheduler：低頻度実行なら
 * ほぼ無視できるコスト）に収まる想定。
 */

/**
 * DynamoDBの容量配分（Always Free枠 25 RCU / 25 WCU に収める）。
 * テーブル本体15 + GSI 6本合計8 = 23。GSIを増減する場合は
 * 必ず`assertCapacityWithinFreeTier()`が通る範囲に収めること（超過分は
 * Provisioned Throughputの課金対象になる）。
 *
 * GSI5（被ブックマーク一覧、21.1節）は今回追加した。追加前の合計は24で
 * 1単位空いていたため（旧コメントは「GSI 6本合計10」としていたが実際は
 * 9だった）、テーブル本体を削らずにGSI5へ1 RCU/1 WCUを割り当てられた。
 * GSI5は「作品詳細で誰がブックマークしたかを開いたときだけ」引かれる
 * 低頻度アクセスなのでこの配分で足りるという判断。実運用でスロットリングが
 * 出たら、CloudWatchの`ThrottledRequests`を見て配分を調整すること。
 */
const CAPACITY_PLAN = {
  table: { read: 15, write: 15 },
  gsi2BookmarkRankingIndex: { read: 2, write: 2 },
  gsi3AuthorWorksIndex: { read: 1, write: 1 },
  gsi3AllAuthorWorksIndex: { read: 1, write: 1 },
  gsi4LatestIndex: { read: 2, write: 2 },
  gsi5WorkBookmarksIndex: { read: 1, write: 1 },
  gsi6ScheduledReleaseIndex: { read: 1, write: 1 },
  gsi7ReportStatusIndex: { read: 1, write: 1 },
} as const;

/** DynamoDB Always Free枠の上限（アカウント単位・永続）。 */
const FREE_TIER_CAPACITY = 25;

/**
 * 容量配分がAlways Free枠を超えていないことを合成時に検証する。
 * GSIを足したときにうっかり課金が発生するのを、デプロイ前（`cdk synth`）
 * の段階で止めるためのガード。
 */
function assertCapacityWithinFreeTier(): void {
  const entries = Object.values(CAPACITY_PLAN);
  const read = entries.reduce((sum, e) => sum + e.read, 0);
  const write = entries.reduce((sum, e) => sum + e.write, 0);
  if (read > FREE_TIER_CAPACITY || write > FREE_TIER_CAPACITY) {
    throw new Error(
      `CAPACITY_PLANの合計がDynamoDB Always Free枠（${FREE_TIER_CAPACITY}）を超えています：` +
        `read=${read} / write=${write}。GSIを追加した場合は他の割り当てを減らしてください。`,
    );
  }
}

export class NiarimBackendStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    assertCapacityWithinFreeTier();

    const table = new dynamodb.Table(this, "NiarimTable", {
      tableName: "niarim-table",
      partitionKey: { name: "pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "sk", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PROVISIONED,
      readCapacity: CAPACITY_PLAN.table.read,
      writeCapacity: CAPACITY_PLAN.table.write,
      timeToLiveAttribute: "ttl", // DailyCounterItem・FollowNotificationItem共通
      removalPolicy: RemovalPolicy.RETAIN, // 誤ってスタックを消しても作品データを失わない
      pointInTimeRecoverySpecification: { pointInTimeRecoveryEnabled: false }, // 追加コスト回避（$0方針）
    });

    // GSI2：ブックマーク数ランキング（8.5節）。
    table.addGlobalSecondaryIndex({
      indexName: "GSI2",
      partitionKey: { name: "gsi2pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi2sk", type: dynamodb.AttributeType.NUMBER },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi2BookmarkRankingIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi2BookmarkRankingIndex.write,
    });

    // GSI3：作者別作品一覧（可視のみ、8.4節）。
    table.addGlobalSecondaryIndex({
      indexName: "GSI3",
      partitionKey: { name: "gsi3pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi3sk", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi3AuthorWorksIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi3AuthorWorksIndex.write,
    });

    // GSI3AllStates：投稿者本人が自分の非公開作品も含めて見るための全件版。
    table.addGlobalSecondaryIndex({
      indexName: "GSI3AllStates",
      partitionKey: { name: "gsi3AllPk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi3AllSk", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi3AllAuthorWorksIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi3AllAuthorWorksIndex.write,
    });

    // GSI4：新着表示（可視のみ、8.3節）。
    table.addGlobalSecondaryIndex({
      indexName: "GSI4",
      partitionKey: { name: "gsi4pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi4sk", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi4LatestIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi4LatestIndex.write,
    });

    // GSI6: private uploads waiting for a confirmed YouTube public release.
    // Only scheduled works have these keys, so each minute tick reads a
    // tiny due-only set instead of scanning all published works.
    table.addGlobalSecondaryIndex({
      indexName: "GSI6Scheduled",
      partitionKey: { name: "gsi6pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi6sk", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi6ScheduledReleaseIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi6ScheduledReleaseIndex.write,
    });

    // GSI7：通報の対応状況一覧・レート制限チェック用（9章・20章）。
    table.addGlobalSecondaryIndex({
      indexName: "GSI7",
      partitionKey: { name: "gsi7pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi7sk", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi7ReportStatusIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi7ReportStatusIndex.write,
    });

    // GSI5：被ブックマーク一覧（21.1節）。`GET /works/{id}/bookmarkers`が
    // `WORKBOOKMARKS#{workId}`をブックマーク日時の降順で引く。
    table.addGlobalSecondaryIndex({
      indexName: "GSI5",
      partitionKey: { name: "gsi5pk", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "gsi5sk", type: dynamodb.AttributeType.STRING },
      // 一覧に必要なのはブックマークしたユーザーIDと日時だけ。ALLだと
      // BookmarkItem全体が複製されてストレージと書き込み容量を余計に
      // 使うため、KEYS_ONLYに近い最小構成にする（niarimUserIdは
      // pkから復元できるが、明示的に持たせた方が読み側が簡潔になる）。
      projectionType: dynamodb.ProjectionType.INCLUDE,
      nonKeyAttributes: ["niarimUserId", "workId", "bookmarkedAt", "itemType"],
      readCapacity: CAPACITY_PLAN.gsi5WorkBookmarksIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi5WorkBookmarksIndex.write,
    });

    const commonEnvironment = {
      TABLE_NAME: table.tableName,
      // 【要設定】15章のOAuth審査で確定するOAuthクライアントID。
      // cdk.context.jsonまたは `-c googleClientId=...` で上書きする。
      GOOGLE_CLIENT_ID:
        this.node.tryGetContext("googleClientId") ?? "REPLACE_ME",
      // 2026-11: Keyless AWS -> Google Cloud Workload Identity Federation.
      // All three values are identifiers, NOT service account private keys.
      // Provider's CEL condition must restrict requests to this Lambda role.
      FCM_PROJECT_ID: "niarim-513201",
      FCM_WIF_AUDIENCE:
        "//iam.googleapis.com/projects/673224289740/locations/global/workloadIdentityPools/niarim-aws-fcm/providers/niarim-aws-lambda",
      FCM_SENDER_SERVICE_ACCOUNT:
        "niarim-fcm-sender@niarim-513201.iam.gserviceaccount.com",
    };

    const apiFunction = new NodejsFunction(this, "ApiFunction", {
      functionName: "niarim-api",
      entry: path.join(__dirname, "../src/api/handler.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 256,
      timeout: Duration.seconds(10),
      // 2026-11-06: ap-northeast-1 のアカウント同時実行上限は10。
      // AWS Lambdaは予約なしの同時実行枠を最低10残す必要があるため、
      // reservedConcurrentExecutions: 10 はCREATE_FAILEDになる。
      // この環境ではアカウント全体の上限10が代わりに同時実行を制限する。
      // 将来クォータを20以上へ引き上げた場合は、公開APIの費用抑制のため
      // 予約同時実行10を改めて設定・検証すること。
      environment: {
        ...commonEnvironment,
        // Default-off. ADC must be provisioned using a Google-to-AWS
        // workload identity federation or equivalent secure credential source.
        PLAY_PURCHASE_VERIFICATION_ENABLED:
          this.node.tryGetContext("playPurchaseVerificationEnabled") === "true"
            ? "true" : "false",
        // Payout economics and wallet/moderation signoff are independent.
        // Early community policy permits multiple accounts and reciprocal
        // bookmarks; exactly-once credits are still mandatory.
        CREATOR_MISSION_CLAIMS_ENABLED:
          this.node.tryGetContext("creatorMissionClaimsEnabled") === "true"
            ? "true" : "false",
        // Demand-driven 10,000-work candidate scanner; read budget is bounded.
        // Does not mint coins and defaults OFF to protect free-tier capacity.
        CREATOR_QUALIFIED_WORK_SCAN_ENABLED:
          this.node.tryGetContext("creatorQualifiedWorkScanEnabled") === "true"
            ? "true" : "false",
        CREATOR_MISSION_CLAIMS_REVIEW_APPROVED:
          this.node.tryGetContext("creatorMissionClaimsReviewApproved") === "true"
            ? "true" : "false",
        // New 480-stage matrix has independent, default-OFF review gates.
        // Draft coin amounts may NEVER pay until pricing is approved.
        // Cumulative login visit tracking is available without payouts.
        // New daily/milestone coin grants require independent human review.
        LOGIN_BONUS_CLAIMS_ENABLED:
          this.node.tryGetContext("loginBonusClaimsEnabled") === "true"
            ? "true" : "false",
        LOGIN_BONUS_REWARDS_REVIEW_APPROVED:
          this.node.tryGetContext("loginBonusRewardsReviewApproved") === "true"
            ? "true" : "false",
        CREATOR_GRID_PAYOUTS_ENABLED:
          this.node.tryGetContext("creatorGridPayoutsEnabled") === "true"
            ? "true" : "false",
        CREATOR_GRID_REWARDS_REVIEW_APPROVED:
          this.node.tryGetContext("creatorGridRewardsReviewApproved") === "true"
            ? "true" : "false",
        PLAY_ANDROID_PACKAGE_NAME: "com.niarim.niarim",
        // YouTube由来のランキングは追加指標利用の承認があるまで非公開。
        // Playback preflight reads the public YouTube video status server-side.
        // Never ship this API key in the Flutter binary or an API response.
        YOUTUBE_API_KEY:
          this.node.tryGetContext("youtubeApiKey") ?? "REPLACE_ME",
        // All reward issuance remains OFF until real AdMob verification,
        // economics review and explicit human production approval.
        ADMOB_REWARDED_AD_UNIT_ID:
          this.node.tryGetContext("admobRewardedAdUnitId") ?? "",
        REWARDED_AD_SSV_ENABLED:
          this.node.tryGetContext("rewardedAdSsvEnabled") === "true"
            ? "true" : "false",
        REWARDED_AD_REVIEW_APPROVED:
          this.node.tryGetContext("rewardedAdReviewApproved") === "true"
            ? "true" : "false",
        // Optional UTC-day cap on verified rewarded coin grants. Blank means
        // no NIARIM-specific count cap; Google may independently no-fill.
        REWARDED_AD_DAILY_LIMIT:
          String(this.node.tryGetContext("rewardedAdDailyLimit") ?? ""),
        // Exchange price must be explicitly approved; no placeholder price
        // can accidentally spend user coins or mint Premium.
        COIN_REDEMPTION_ENABLED:
          this.node.tryGetContext("coinRedemptionEnabled") === "true"
            ? "true" : "false",
        COIN_REDEMPTION_REVIEW_APPROVED:
          this.node.tryGetContext("coinRedemptionReviewApproved") === "true"
            ? "true" : "false",
        COIN_FULL_PREMIUM_MONTH_COINS:
          this.node.tryGetContext("coinFullPremiumMonthCoins") ?? "",
        COIN_PRICE_VERSION:
          this.node.tryGetContext("coinPriceVersion") ?? "",
      },
      bundling: { minify: true, sourceMap: false },
    });
    table.grantReadWriteData(apiFunction);

    // Lambda Function URL（AuthType: NONE、16章）。
    const functionUrl = apiFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
    });

    // This is not the retired video-statistics batch. A low-cost minute
    // rule queries only scheduled work IDs and confirms YouTube is PUBLIC
    // before inserting a release into NIARIM's discovery indexes.
    const releaseFunction = new NodejsFunction(this, "ScheduledReleaseFunction", {
      functionName: "niarim-scheduled-release",
      entry: path.join(__dirname, "../src/batch/scheduledRelease.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 128,
      timeout: Duration.seconds(30),
      environment: {
        TABLE_NAME: table.tableName,
        YOUTUBE_API_KEY:
          this.node.tryGetContext("youtubeApiKey") ?? "REPLACE_ME",
      },
      bundling: { minify: true, sourceMap: false },
    });
    table.grantReadWriteData(releaseFunction);
    new events.Rule(this, "ScheduledReleaseMinuteRule", {
      schedule: events.Schedule.rate(Duration.minutes(1)),
      targets: [new targets.LambdaFunction(releaseFunction)],
    });

    // YouTube再生数の定期取得は採用しない。統計バッチと定期イベントは作成しない。
    // ランキングはNIARIM独自ブックマークのGSI2から取得する。

    new CfnOutput(this, "ApiFunctionUrl", { value: functionUrl.url });
    new CfnOutput(this, "AdmobSsvCallbackUrl", {
      value: `${functionUrl.url}admob/ssv`,
      description: "Configure this URL ONLY in the AdMob rewarded-ad SSV setting",
    });
    new CfnOutput(this, "TableName", { value: table.tableName });
  }
}
