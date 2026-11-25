import { GetParameterCommand, SSMClient } from "@aws-sdk/client-ssm";

/**
 * Reads SecureString values from SSM Parameter Store at runtime. Secrets and
 * the moderator allowlist never live in the repository, the CloudFormation
 * template or Lambda environment variables; only the parameter NAMES do.
 *
 * Values are cached per Lambda instance for a few minutes so a burst of admin
 * requests or reports does not call SSM every time. A missing parameter (or
 * any error reading it) yields `undefined`: callers treat that as "feature
 * off" (admin API answers 403, mail and AI are skipped).
 */
const client = new SSMClient({});
const FOUND_TTL_MS = 5 * 60_000;
const MISSING_TTL_MS = 60_000;

interface CacheEntry {
  value: string | undefined;
  expiresAt: number;
}
const cache = new Map<string, CacheEntry>();

export async function readSecureParameter(
  name: string | undefined,
): Promise<string | undefined> {
  if (!name) return undefined;
  const now = Date.now();
  const cached = cache.get(name);
  if (cached && cached.expiresAt > now) return cached.value;
  let value: string | undefined;
  try {
    const result = await client.send(new GetParameterCommand({
      Name: name, WithDecryption: true,
    }));
    const raw = result.Parameter?.Value?.trim();
    value = raw ? raw : undefined;
  } catch (error) {
    // ParameterNotFound is the expected "not configured" state. Anything else
    // (permissions, throttling) is logged without the parameter value.
    const kind = error instanceof Error ? error.name : "UnknownError";
    if (kind !== "ParameterNotFound") {
      console.warn("SSM parameter could not be read", name, kind);
    }
    value = undefined;
  }
  cache.set(name, {
    value,
    expiresAt: now + (value === undefined ? MISSING_TTL_MS : FOUND_TTL_MS),
  });
  return value;
}

/** Test hook: forget cached values. */
export function clearSecureParameterCache(): void {
  cache.clear();
}
