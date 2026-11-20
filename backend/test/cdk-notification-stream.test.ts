import { App } from "aws-cdk-lib";
import { Match, Template } from "aws-cdk-lib/assertions";
import { expect, it } from "vitest";
import { NiarimBackendStack } from "../lib/niarim-backend-stack";

it("applies 30-day retention to the API and scheduled Lambda log groups", () => {
  const app = new App({
    context: {
      admobReportOAuthSecretArn: "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:niarim-test-abcdef",
      rewardedAdCountryLayerArn: "arn:aws:lambda:ap-northeast-1:123456789012:layer:country-test:1",
    },
  });
  const template = Template.fromStack(new NiarimBackendStack(app, "Retention"));
  for (const functionName of [
    "niarim-api",
    "niarim-scheduled-release",
    "niarim-reward-ad-revenue",
  ]) {
    const functionId = template.getResourceId("AWS::Lambda::Function", {
      Properties: { FunctionName: functionName },
    });
    template.hasResourceProperties("Custom::LogRetention", {
      LogGroupName: { "Fn::Join": ["", ["/aws/lambda/", { Ref: functionId }]] },
      RetentionInDays: 30,
    });
  }
});

it("retains discarded notification records with scoped access and expiry", () => {
  const app = new App();
  const template = Template.fromStack(new NiarimBackendStack(app, "Test", {
    env: { account: "123456789012", region: "ap-northeast-1" },
  }));
  const bucketProperties = {
    BucketEncryption: {
      ServerSideEncryptionConfiguration: [{
        ServerSideEncryptionByDefault: { SSEAlgorithm: "AES256" },
      }],
    },
    LifecycleConfiguration: { Rules: [{ ExpirationInDays: 7, Status: "Enabled" }] },
    PublicAccessBlockConfiguration: {
      BlockPublicAcls: true,
      BlockPublicPolicy: true,
      IgnorePublicAcls: true,
      RestrictPublicBuckets: true,
    },
  };
  const bucketId = template.getResourceId("AWS::S3::Bucket", {
    Properties: bucketProperties,
    DeletionPolicy: "Retain",
  });
  const bucketArn = { "Fn::GetAtt": [bucketId, "Arn"] };
  template.hasResourceProperties("AWS::Lambda::EventSourceMapping", {
    DestinationConfig: { OnFailure: { Destination: bucketArn } },
    MaximumRetryAttempts: 4,
    MaximumRecordAgeInSeconds: 900,
    FunctionResponseTypes: ["ReportBatchItemFailures"],
  });
  const mappings = template.findResources("AWS::Lambda::EventSourceMapping");
  const filters = JSON.stringify(mappings);
  expect(filters).toContain("COMMUNITY_ACTIVITY_V1");
  expect(filters).not.toMatch(/FOLLOWER_RECORD|BOOKMARK|REPOST/);
  template.hasResourceProperties("AWS::IAM::Policy", {
    PolicyDocument: {
      Statement: Match.arrayWith([
        {
          Action: "s3:ListBucket",
          Condition: { StringEquals: { "s3:ResourceAccount": "123456789012" } },
          Effect: "Allow",
          Resource: bucketArn,
        },
        {
          Action: "s3:PutObject",
          Condition: { StringEquals: { "s3:ResourceAccount": "123456789012" } },
          Effect: "Allow",
          Resource: { "Fn::Join": ["", [bucketArn, "/*"]] },
        },
      ]),
    },
  });
  expect(template.findOutputs("NotificationStreamFailureBucket", {
    Value: { Ref: bucketId },
  })).toHaveProperty("NotificationStreamFailureBucket");
});
