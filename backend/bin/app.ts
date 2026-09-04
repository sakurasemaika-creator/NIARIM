#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";
import { NiarimBackendStack } from "../lib/niarim-backend-stack";

const app = new cdk.App();
new NiarimBackendStack(app, "NiarimBackendStack", {
  description:
    "NIARIM作品広場バックエンド（29_動画投稿・ランキング機能仕様.md 16章）",
  // 【要設定】デプロイ先のAWSアカウント・リージョン。未指定の場合は
  // `aws configure`で設定済みのデフォルト認証情報から解決される。
  // env: { account: '123456789012', region: 'ap-northeast-1' },
});
