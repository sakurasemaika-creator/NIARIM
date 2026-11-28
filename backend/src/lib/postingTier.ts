import type { MembershipTier } from "./types";

/**
 * The membership tier that sets the daily post limit: premium when the
 * signed-in request is premium (verified Google Play subscription or
 * Premium redeemed with Opals, as `authenticate` works out) or the stored
 * user record says premium. Verifying a Play subscription does not update
 * the stored tier, so using only the stored one gave Play Premium members the
 * free limit (1 a day instead of 3).
 */
export function postingMembershipTier(
  signedIn: MembershipTier,
  stored: MembershipTier,
): MembershipTier {
  return signedIn === "premium" || stored === "premium" ? "premium" : "free";
}
