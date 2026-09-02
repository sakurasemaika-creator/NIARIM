import { Duration, RemovalPolicy, Stack, StackProps, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as path from 'path';

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
 * テーブル本体15 + GSI 6本合計10 = 25で上限ちょうど。将来GSIを追加する
 * 場合は、いずれかの値を減らして総和を25以内に保つこと（超過分は
 * Provisioned Throughputの課金対象になる）。
 */
const CAPACITY_PLAN = {
  table: { read: 15, write: 15 },
  gsi1RankingIndex: { read: 2, write: 2 },
  gsi2BookmarkRankingIndex: { read: 2, write: 2 },
  gsi3AuthorWorksIndex: { read: 1, write: 1 },
  gsi3AllAuthorWorksIndex: { read: 1, write: 1 },
  gsi4LatestIndex: { read: 2, write: 2 },
  gsi7ReportStatusIndex: { read: 1, write: 1 },
} as const;

export class NiarimBackendStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const table = new dynamodb.Table(this, 'NiarimTable', {
      tableName: 'niarim-table',
      partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'sk', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PROVISIONED,
      readCapacity: CAPACITY_PLAN.table.read,
      writeCapacity: CAPACITY_PLAN.table.write,
      timeToLiveAttribute: 'ttl', // DailyCounterItem・FollowNotificationItem共通
      removalPolicy: RemovalPolicy.RETAIN, // 誤ってスタックを消しても作品データを失わない
      pointInTimeRecoverySpecification: { pointInTimeRecoveryEnabled: false }, // 追加コスト回避（$0方針）
    });

    // GSI1：ランキング表示（8.2節）。gsi1pk="RANKING#ALL"固定パーティション。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'gsi1pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi1sk', type: dynamodb.AttributeType.NUMBER },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi1RankingIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi1RankingIndex.write,
    });

    // GSI2：ブックマーク数ランキング（8.5節）。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI2',
      partitionKey: { name: 'gsi2pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi2sk', type: dynamodb.AttributeType.NUMBER },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi2BookmarkRankingIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi2BookmarkRankingIndex.write,
    });

    // GSI3：作者別作品一覧（可視のみ、8.4節）。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI3',
      partitionKey: { name: 'gsi3pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi3sk', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi3AuthorWorksIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi3AuthorWorksIndex.write,
    });

    // GSI3AllStates：投稿者本人が自分の非公開作品も含めて見るための全件版。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI3AllStates',
      partitionKey: { name: 'gsi3AllPk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi3AllSk', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi3AllAuthorWorksIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi3AllAuthorWorksIndex.write,
    });

    // GSI4：新着表示（可視のみ、8.3節）。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI4',
      partitionKey: { name: 'gsi4pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi4sk', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi4LatestIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi4LatestIndex.write,
    });

    // GSI7：通報の対応状況一覧・レート制限チェック用（9章・20章）。
    table.addGlobalSecondaryIndex({
      indexName: 'GSI7',
      partitionKey: { name: 'gsi7pk', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'gsi7sk', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
      readCapacity: CAPACITY_PLAN.gsi7ReportStatusIndex.read,
      writeCapacity: CAPACITY_PLAN.gsi7ReportStatusIndex.write,
    });

    // 注記：GSI5（被ブックマーク一覧、21.1節）は現状どのAPIエンドポイントも
    // クエリしていない（bookmarks.tsは書き込み時にgsi5pk/gsi5skを付与する
    // だけで、対応する読み取りAPIは未実装）ため、Always Free枠（25 RCU/
    // 25 WCU）を消費しないようここでは作成していない。実装時は上記の
    // いずれかのGSIの割り当てを減らして総和を25以内に保つこと。

    const commonEnvironment = {
      TABLE_NAME: table.tableName,
      // 【要設定】15章のOAuth審査で確定するOAuthクライアントID。
      // cdk.context.jsonまたは `-c googleClientId=...` で上書きする。
      GOOGLE_CLIENT_ID: this.node.tryGetContext('googleClientId') ?? 'REPLACE_ME',
    };

    const apiFunction = new NodejsFunction(this, 'ApiFunction', {
      functionName: 'niarim-api',
      entry: path.join(__dirname, '../src/api/handler.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 256,
      timeout: Duration.seconds(10),
      // 公開Function URLへの急増リクエストがLambda/DynamoDBの費用と
      // 同時実行枠を無制限に消費しないよう上限を設ける（最大約100 RPS）。
      reservedConcurrentExecutions: 10,
      environment: commonEnvironment,
      bundling: { minify: true, sourceMap: false },
    });
    table.grantReadWriteData(apiFunction);

    // Lambda Function URL（AuthType: NONE、16章）。
    const functionUrl = apiFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
    });

    const batchFunction = new NodejsFunction(this, 'StatsUpdateFunction', {
      functionName: 'niarim-stats-update',
      entry: path.join(__dirname, '../src/batch/statsUpdate.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 512,
      // 1ページ分の処理（YouTube API呼び出し＋DynamoDB更新）に十分な
      // 時間を確保する。8.1節の「1回の実行は最大15分」はLambdaの上限を
      // 指しているが、1ページ25件なら数十秒〜数分で収まる想定。
      timeout: Duration.minutes(5),
      environment: {
        TABLE_NAME: table.tableName,
        // 【要設定】YouTube Data APIキー（videos.batchGetStats用、10章）。
        // Secrets Managerは月額課金が発生するため、$0方針に合わせて
        // Lambda環境変数（AWS管理キーで暗号化済み）に留めている。
        // より強固な秘匿が必要な場合はSecrets Managerへの切り替えを検討。
        YOUTUBE_API_KEY: this.node.tryGetContext('youtubeApiKey') ?? 'REPLACE_ME',
        SELF_FUNCTION_NAME: 'niarim-stats-update',
      },
      bundling: { minify: true, sourceMap: false },
    });
    table.grantReadWriteData(batchFunction);
    // 自己再帰呼び出し用（8.1節）。
    batchFunction.grantInvoke(batchFunction);

    // EventBridge Scheduler：更新サイクルの開始のみをトリガーする
    // （8.1節）。既定は1日2回（14章：作品数が増えてきたら1日2回を基本）。
    // cron式はUTC。JSTの9時・21時に相当するよう0時・12時UTCで実行する。
    new events.Rule(this, 'StatsUpdateSchedule', {
      ruleName: 'niarim-stats-update-schedule',
      schedule: events.Schedule.expression('cron(0 0,12 * * ? *)'),
      targets: [new targets.LambdaFunction(batchFunction, { event: events.RuleTargetInput.fromObject({}) })],
    });

    new CfnOutput(this, 'ApiFunctionUrl', { value: functionUrl.url });
    new CfnOutput(this, 'TableName', { value: table.tableName });
  }
}
