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
import * as iam from "aws-cdk-lib/aws-iam";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as logs from "aws-cdk-lib/aws-logs";
import { DynamoEventSource } from "aws-cdk-lib/aws-lambda-event-sources";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import * as path from "path";
import {
  COIN_BENEFIT_PRICE_VERSION,
  FINAL_PREMIUM_MONTHLY_COINS,
  FINAL_PREMIUM_YEARLY_COINS,
} from "../src/lib/coinBenefitProposal";

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
 */
const CAPACITY_PLAN = {
  table: { read: 15, write: 15 },
  gsi2BookmarkRankingIndex: { read: 2, write: 2 },
  gsi3AuthorWorksIndex: { read: 1, write: 1 },
  gsi3AllAuthorWorksIndex: { read: 1, write: 1 },
  gsi4LatestIndex: { read: 2, write: 2 },
  gsi6ScheduledReleaseIndex: { read: 1, write: 1 },
  gsi7ReportStatusIndex: { read: 1, write: 1 },
} as const;

/** DynamoDB Always Free枠の上限（アカウント単位・永続）。 */
const FREE_TIER_CAPACITY = 25;
const FUNCTION_LOG_RETENTION = logs.RetentionDays.ONE_MONTH;

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
      timeToLiveAttribute: "ttl",
      stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
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

    const reportSecretArn = this.node.tryGetContext("admobReportOAuthSecretArn") as string | undefined;
    const countryLayerArn = this.node.tryGetContext("rewardedAdCountryLayerArn") as string | undefined;
    const countryDataDirectory = this.node.tryGetContext("rewardedAdCountryDataDirectory") as string | undefined;
    const autoRewardRates = this.node.tryGetContext("rewardedAdAutoRatesEnabled") === "true";
    const rewardedUnitTiers = String(this.node.tryGetContext("rewardedAdUnitTiers") ?? "");
    const rewardedBaseUnit = String(this.node.tryGetContext("admobRewardedAdUnitId") ?? "");
    if (countryLayerArn && countryDataDirectory) {
      throw new Error("Choose one country database layer source");
    }
    if ((reportSecretArn && !countryLayerArn && !countryDataDirectory) ||
        (autoRewardRates && !reportSecretArn)) {
      throw new Error("Regional rewarded ads require the country database layer and AdMob reporting OAuth secret");
    }
    const rewardCountryLayer = countryDataDirectory
      ? new lambda.LayerVersion(this, "RewardAdCountryData", {
        code: lambda.Code.fromAsset(path.resolve(countryDataDirectory)),
        description: "IP to Country Lite by DB-IP, CC BY 4.0",
        compatibleRuntimes: [lambda.Runtime.NODEJS_22_X],
      }) : countryLayerArn
        ? lambda.LayerVersion.fromLayerVersionArn(this, "RewardAdCountryLayer", countryLayerArn)
        : undefined;
    const usesCountryLite = countryDataDirectory ||
      /:layer:niarim-reward-country-data:[0-9]+$/.test(countryLayerArn ?? "");

    const apiFunction = new NodejsFunction(this, "ApiFunction", {
      functionName: "niarim-api",
      // Apply retention to the existing default group, including old logs.
      logRetention: FUNCTION_LOG_RETENTION,
      entry: path.join(__dirname, "../src/api/handler.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 256,
      ...(rewardCountryLayer ? { layers: [rewardCountryLayer] } : {}),
      timeout: Duration.seconds(10),
      // 2026-11-06: ap-northeast-1 のアカウント同時実行上限は10。
      // AWS Lambdaは予約なしの同時実行枠を最低10残す必要があるため、
      // reservedConcurrentExecutions: 10 はCREATE_FAILEDになる。
      // この環境ではアカウント全体の上限10が代わりに同時実行を制限する。
      // 将来クォータを20以上へ引き上げた場合は、公開APIの費用抑制のため
      // 予約同時実行10を改めて設定・検証すること。
      environment: {
        ...commonEnvironment,
        NOTIFICATION_STREAM_ENABLED: "true",
        // Default-off. ADC must be provisioned using a Google-to-AWS
        // workload identity federation or equivalent secure credential source.
        PLAY_PURCHASE_VERIFICATION_ENABLED:
          this.node.tryGetContext("playPurchaseVerificationEnabled") === "true"
            ? "true" : "false",
        // Independent, non-secret GCP Workload Identity Federation for the
        // Android Publisher API. Do NOT reuse the FCM sender service account.
        // Actual Billing remains OFF until the service account has explicit
        // Play Console API permission and an end-to-end purchase is tested.
        PLAY_WIF_AUDIENCE:
          String(this.node.tryGetContext("playWifAudience") ?? ""),
        PLAY_VERIFIER_SERVICE_ACCOUNT:
          String(this.node.tryGetContext("playVerifierServiceAccount") ?? ""),
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
        // Ranked placements and social bookmarks need independent
        // anti-sybil review before they can credit coins (default OFF).
        CREATOR_RANKING_REWARDS_REVIEW_APPROVED:
          this.node.tryGetContext("creatorRankingRewardsReviewApproved")==="true"
            ? "true":"false",
        // Authenticated server-clock pilot is candidate-only. No env or
        // CDK context can upgrade device-reported edits to coin-bearing time.
        CREATOR_EDIT_SESSION_PILOT_ENABLED:
          this.node.tryGetContext("creatorEditSessionPilotEnabled")==="true"
            ? "true":"false",
        // All 480-stage grid rewards are owner-approved FINAL amounts.
        // Independent anti-abuse / cross-work consistency review gates
        // still default OFF; economic approval is NOT operational approval.
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
        // Retain independently authorized recurring/plaza mission settings.
        // Omitting them from CDK would silently revoke current live payouts
        // during a future unrelated infrastructure deployment.
        RECURRING_MISSION_PAYOUTS_ENABLED:
          this.node.tryGetContext("recurringMissionPayoutsEnabled") === "true"
            ? "true" : "false",
        PLAZA_MISSION_PAYOUTS_ENABLED:
          this.node.tryGetContext("plazaMissionPayoutsEnabled") === "true"
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
          rewardedBaseUnit,
        ...(rewardCountryLayer ? {
          REWARDED_AD_COUNTRY_DB: usesCountryLite ? "/opt/country.mmdb" : "/opt/GeoLite2-Country.mmdb",
        } : {}),
        ...(reportSecretArn ? { REWARDED_AD_REPORTING_ENABLED: "true" } : {}),
        ...(autoRewardRates ? { REWARDED_AD_AUTO_RATES_ENABLED: "true" } : {}),
        ...(rewardedUnitTiers ? { REWARDED_AD_UNIT_TIERS: rewardedUnitTiers } : {}),
        REWARDED_AD_SSV_ENABLED:
          this.node.tryGetContext("rewardedAdSsvEnabled") === "true"
            ? "true" : "false",
        REWARDED_AD_REVIEW_APPROVED:
          this.node.tryGetContext("rewardedAdReviewApproved") === "true"
            ? "true" : "false",
        // Set a numeric UTC-day grant cap or explicitly select "unlimited".
        REWARDED_AD_DAILY_LIMIT:
          String(this.node.tryGetContext("rewardedAdDailyLimit") ?? ""),
        // Coin exchange development toggles. All amounts are computed again
        // by the backend from the approved fixed catalog before debiting.
        COIN_REDEMPTION_ENABLED:
          this.node.tryGetContext("coinRedemptionEnabled") === "true"
            ? "true" : "false",
        // Financial activation additionally requires independent security
        // approval; prerelease CDK context must never grant entitlements.
        COIN_REDEMPTION_REVIEW_APPROVED:
          this.node.tryGetContext("coinRedemptionReviewApproved") === "true"
            ? "true" : "false",
        COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED:
          this.node.tryGetContext("coinIndividualRedemptionReviewApproved") === "true"
            ? "true" : "false",
        COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED:
          this.node.tryGetContext("coinIndividualRightsConsumersApproved") === "true"
            ? "true" : "false",
        COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED:
          this.node.tryGetContext("coinPremiumAnnualRedemptionEnabled") === "true"
            ? "true" : "false",
        COIN_INDIVIDUAL_REDEMPTION_ENABLED:
          this.node.tryGetContext("coinIndividualRedemptionEnabled") === "true"
            ? "true" : "false",
        COIN_FULL_PREMIUM_MONTH_COINS:
          String(this.node.tryGetContext("coinFullPremiumMonthCoins") ?? FINAL_PREMIUM_MONTHLY_COINS),
        COIN_FULL_PREMIUM_YEAR_COINS:
          String(this.node.tryGetContext("coinFullPremiumYearCoins") ?? FINAL_PREMIUM_YEARLY_COINS),
        COIN_PRICE_VERSION:
          String(this.node.tryGetContext("coinPriceVersion") ??
            COIN_BENEFIT_PRICE_VERSION),
      },
      bundling: { minify: true, sourceMap: false },
    });
    table.grantReadWriteData(apiFunction);

    const notificationFailures = new s3.Bucket(this, "NotificationStreamFailures", {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy: RemovalPolicy.RETAIN,
      lifecycleRules: [{ expiration: Duration.days(7) }],
    });
    new CfnOutput(this, "NotificationStreamFailureBucket", {
      value: notificationFailures.bucketName,
    });

    // Reuse the already federated API role for FCM. The worker receives only
    // committed DynamoDB changes; an HTTP client cannot trigger this handler.
    apiFunction.addEventSource(new DynamoEventSource(table, {
      startingPosition: lambda.StartingPosition.TRIM_HORIZON,
      batchSize: 1,
      maxRecordAge: Duration.minutes(15),
      retryAttempts: 4,
      reportBatchItemFailures: true,
      onFailure: {
        bind: (mapping, handler) => {
          // Lambda writes the original stream payload to S3. Limit the role to
          // the actions it needs and to buckets owned by this account.
          const conditions = { StringEquals: { "s3:ResourceAccount": this.account } };
          iam.Grant.addToPrincipal({
            grantee: handler,
            actions: ["s3:ListBucket"],
            resourceArns: [notificationFailures.bucketArn],
            conditions,
          }).applyBefore(mapping);
          iam.Grant.addToPrincipal({
            grantee: handler,
            actions: ["s3:PutObject"],
            resourceArns: [notificationFailures.arnForObjects("aws/lambda/*")],
            conditions,
          }).applyBefore(mapping);
          return { destination: notificationFailures.bucketArn };
        },
      },
      filters: [
        lambda.FilterCriteria.filter({ dynamodb: {
          OldImage: { youtubePrivacyStatus: { S: ["private"] } },
          NewImage: {
            itemType: { S: ["WORK"] },
            youtubePrivacyStatus: { S: ["public"] },
            scheduledReleaseConfirmedAt: { S: [{ exists: true }] },
          },
        } }),
        lambda.FilterCriteria.filter({ eventName: ["INSERT"], dynamodb: {
          NewImage: { itemType: { S: ["WORK"] } },
        } }),
        lambda.FilterCriteria.filter({ dynamodb: {
          OldImage: { isNiarimPublished: { BOOL: [false] } },
          NewImage: {
            itemType: { S: ["WORK"] }, isNiarimPublished: { BOOL: [true] },
            plazaPublicationConfirmedAt: { S: [{ exists: true }] },
          },
        } }),
        lambda.FilterCriteria.filter({ dynamodb: { NewImage: {
          itemType: { S: ["MISSION_ACTIVITY_V1", "COMMUNITY_ACTIVITY_V1"] },
          pushPending: { BOOL: [true] },
        } } }),
      ],
    }));

    // Lambda Function URL（AuthType: NONE、16章）。
    const functionUrl = apiFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
    });

    // This is not the retired video-statistics batch. A low-cost minute
    // rule queries only scheduled work IDs and confirms YouTube is PUBLIC
    // before inserting a release into NIARIM's discovery indexes.
    const releaseFunction = new NodejsFunction(this, "ScheduledReleaseFunction", {
      functionName: "niarim-scheduled-release",
      logRetention: FUNCTION_LOG_RETENTION,
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

    if (reportSecretArn) {
      const reportSecret = secretsmanager.Secret.fromSecretCompleteArn(
        this, "AdmobReportOAuthSecret", reportSecretArn,
      );
      const reportFunction = new NodejsFunction(this, "RewardAdRevenueFunction", {
        functionName: "niarim-reward-ad-revenue",
        logRetention: FUNCTION_LOG_RETENTION,
        entry: path.join(__dirname, "../src/batch/rewardAdRevenue.ts"),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        memorySize: 256,
        timeout: Duration.seconds(60),
        environment: {
          TABLE_NAME: table.tableName,
          ADMOB_REWARDED_AD_UNIT_ID: rewardedBaseUnit,
          ADMOB_REPORT_OAUTH_SECRET_ARN: reportSecret.secretArn,
          REWARDED_AD_UNIT_TIERS: rewardedUnitTiers,
        },
      });
      reportSecret.grantRead(reportFunction);
      reportFunction.addToRolePolicy(new iam.PolicyStatement({
        actions: ["dynamodb:Query", "dynamodb:PutItem"],
        resources: [table.tableArn],
        conditions: {
          "ForAllValues:StringEquals": { "dynamodb:LeadingKeys": ["REWARDED_AD_OPTIMIZATION"] },
        },
      }));
      new events.Rule(this, "RewardAdRevenueDailyRule", {
        schedule: events.Schedule.cron({ minute: "15", hour: "20" }),
        targets: [new targets.LambdaFunction(reportFunction, {
          retryAttempts: 2, maxEventAge: Duration.hours(3),
        })],
      });
    }

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
