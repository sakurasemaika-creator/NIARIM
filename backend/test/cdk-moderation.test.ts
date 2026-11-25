import { App } from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";
import { beforeAll, describe, expect, it } from "vitest";
import { NiarimBackendStack } from "../lib/niarim-backend-stack";

// Synthesizing bundles every Lambda with esbuild, which takes several seconds.
let template: Template;
beforeAll(() => {
  template = Template.fromStack(new NiarimBackendStack(new App(), "Moderation", {
    env: { account: "123456789012", region: "ap-northeast-1" },
  }));
}, 120_000);

function policyStatements(): Record<string, unknown>[] {
  return Object.values(template.findResources("AWS::IAM::Policy")).flatMap((policy) =>
    (policy as { Properties: { PolicyDocument: { Statement: Record<string, unknown>[] } } })
      .Properties.PolicyDocument.Statement);
}

describe("moderation infrastructure", () => {
  it("adds no index: the table keeps exactly its existing GSIs", () => {
    const [table] = Object.values(template.findResources("AWS::DynamoDB::Table"));
    const indexes = (table as { Properties: { GlobalSecondaryIndexes: { IndexName: string }[] } })
      .Properties.GlobalSecondaryIndexes.map((index) => index.IndexName);
    expect(indexes).toEqual(["GSI2", "GSI3", "GSI3AllStates", "GSI4", "GSI6Scheduled", "GSI7"]);
  });

  it("runs the worker only for inserted reports, one at a time", () => {
    template.hasResourceProperties("AWS::Lambda::Function", {
      FunctionName: "niarim-moderation-worker", Timeout: 90,
    });
    const mappings = JSON.stringify(template.findResources("AWS::Lambda::EventSourceMapping"));
    expect(mappings).toContain('{\\"eventName\\":[\\"INSERT\\"],\\"dynamodb\\":{\\"NewImage\\":{\\"itemType\\":{\\"S\\":[\\"REPORT\\"]}}}}');
    template.hasResourceProperties("AWS::Lambda::EventSourceMapping", {
      BatchSize: 1, MaximumRetryAttempts: 2, MaximumRecordAgeInSeconds: 3600,
    });
  });

  it("grants SSM reads only for the two named parameters, and keeps values out of the template", () => {
    const ssm = policyStatements().filter((s) => JSON.stringify(s.Action).includes("ssm"));
    const resources = JSON.stringify(ssm.map((s) => s.Resource));
    expect(ssm.every((s) => s.Action === "ssm:GetParameter")).toBe(true);
    expect(resources).toContain(":parameter/niarim/moderation/admin-emails");
    expect(resources).toContain(":parameter/niarim/moderation/resend-api-key");
    // No Anthropic API key: Claude judges reports on the owner's subscription.
    expect(resources).not.toContain("anthropic");
    expect(resources).not.toContain("*");
    template.hasResourceProperties("AWS::Lambda::Function", {
      FunctionName: "niarim-api",
      Environment: { Variables: {
        MODERATION_ADMIN_EMAILS_PARAMETER: "/niarim/moderation/admin-emails",
        ADMIN_ALLOWED_ORIGINS: "https://niarim.miranima-studio.com",
        MODERATION_REPORT_HIDE_THRESHOLD: "3",
        MODERATION_STRIKE_SUSPEND_THRESHOLD: "3",
      } },
    });
    const environments = JSON.stringify(Object.values(template.findResources("AWS::Lambda::Function"))
      .map((fn) => (fn as { Properties: { Environment?: unknown } }).Properties.Environment));
    expect(environments).not.toMatch(/MODERATION_AI_|ANTHROPIC/);
  });
});
