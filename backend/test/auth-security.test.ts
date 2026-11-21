import { describe, expect, it } from "vitest";
import { authenticate } from "../src/lib/auth";

describe("authentication input limits", () => {
  it("rejects an oversized bearer token before external verification", async () => {
    await expect(
      authenticate(`Bearer ${"a".repeat(8193)}`),
    ).rejects.toMatchObject({
      statusCode: 401,
      code: "UNAUTHORIZED",
    });
  });

  it("rejects an empty bearer token", async () => {
    await expect(authenticate("Bearer ")).rejects.toMatchObject({
      statusCode: 401,
    });
  });
});
