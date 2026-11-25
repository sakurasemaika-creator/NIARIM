import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { verifyGoogleIdentity } from "./auth";
import { moderationConfig } from "./moderation";
import { forbidden } from "./response";
import { readSecureParameter } from "./ssmParameters";

/**
 * Authentication for the moderation admin API (`/admin/...`).
 *
 * A request needs BOTH a valid Google ID token for the app's OAuth client
 * (the same GOOGLE_CLIENT_ID audience as every other API) AND a verified
 * email address in the allowlist. The allowlist is a comma-separated
 * SecureString in SSM Parameter Store (name in
 * MODERATION_ADMIN_EMAILS_PARAMETER); it is never stored in the repository.
 * Without the parameter every admin request is refused with 403.
 *
 * Admins are not NIARIM accounts: no NIARIM user is created for them.
 */
export interface AdminIdentity {
  email: string;
}

export function parseAdminEmails(raw: string | undefined): Set<string> {
  return new Set((raw ?? "")
    .split(/[\s,;]+/)
    .map((value) => value.trim().toLowerCase())
    .filter((value) => /^[^@\s]+@[^@\s]+$/.test(value)));
}

export async function authenticateAdmin(event: APIGatewayProxyEventV2): Promise<AdminIdentity> {
  const allowlist = parseAdminEmails(
    await readSecureParameter(moderationConfig().adminEmailsParameter),
  );
  if (allowlist.size === 0) {
    forbidden("管理画面は設定されていません", "ADMIN_DISABLED");
  }
  const payload = await verifyGoogleIdentity(
    event.headers?.["authorization"] ?? event.headers?.["Authorization"],
  );
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  if (!email || payload.email_verified !== true || !allowlist.has(email)) {
    forbidden("このアカウントには管理の権限がありません", "ADMIN_FORBIDDEN");
  }
  return { email };
}
