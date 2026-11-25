import { BatchGetCommand, type BatchGetCommandOutput } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "./dynamo";

export type TableRow = Record<string, unknown>;

/** Map key of a table key (`pk` + `sk`). */
export function itemKey(item: { pk: unknown; sk: unknown }): string {
  return `${String(item.pk)}\n${String(item.sk)}`;
}

/**
 * Reads many items by key (100 per request, unprocessed keys retried a few
 * times). Returns the found items by `itemKey`; missing keys are absent.
 */
export async function batchGetItems(keys: { pk: string; sk: string }[]): Promise<Map<string, TableRow>> {
  const found = new Map<string, TableRow>();
  const unique = [...new Map(keys.map((k) => [itemKey(k), k])).values()];
  const TableName = tableName();
  for (let start = 0; start < unique.length; start += 100) {
    let request: Record<string, { Keys: TableRow[] }> | undefined = {
      [TableName]: { Keys: unique.slice(start, start + 100) },
    };
    for (let attempt = 0; request && attempt < 4; attempt++) {
      const result: BatchGetCommandOutput = await ddb.send(
        new BatchGetCommand({ RequestItems: request }));
      for (const item of result?.Responses?.[TableName] ?? []) {
        found.set(itemKey(item as { pk: unknown; sk: unknown }), item);
      }
      const rest: TableRow[] | undefined = result?.UnprocessedKeys?.[TableName]?.Keys;
      request = rest?.length ? { [TableName]: { Keys: rest } } : undefined;
    }
  }
  return found;
}
