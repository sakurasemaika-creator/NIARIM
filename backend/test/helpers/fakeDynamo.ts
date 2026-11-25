import {
  ConditionalCheckFailedException,
  TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  BatchGetCommand,
  GetCommand,
  PutCommand,
  QueryCommand,
  TransactWriteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";

/**
 * A tiny in-memory stand-in for the DynamoDB document client, enough for the
 * moderation code paths: Get, Put, Update (SET / REMOVE / ADD), Query (base
 * table and GSIs by partition attribute), BatchGet and TransactWrite, with
 * the condition expressions those paths use (=, <>, <, <=, >, >=, IN, AND,
 * OR, NOT, parentheses, attribute_exists, attribute_not_exists, begins_with).
 * Not a general DynamoDB emulator.
 */
type Item = Record<string, unknown>;
type Names = Record<string, string> | undefined;
type Values = Record<string, unknown> | undefined;

const GSI_KEYS: Record<string, [string, string]> = {
  GSI7: ["gsi7pk", "gsi7sk"],
  GSI3AllStates: ["gsi3AllPk", "gsi3AllSk"],
  GSI3: ["gsi3pk", "gsi3sk"],
  GSI4: ["gsi4pk", "gsi4sk"],
};

function tokenize(expression: string): string[] {
  return expression.match(/<>|<=|>=|[()=<>,]|[#:]?[A-Za-z_][A-Za-z0-9_]*/g) ?? [];
}

class Evaluator {
  private i = 0;
  constructor(
    private tokens: string[],
    private item: Item | undefined,
    private names: Names,
    private values: Values,
  ) {}

  static check(expression: string | undefined, item: Item | undefined, names: Names, values: Values) {
    if (!expression) return true;
    const ev = new Evaluator(tokenize(expression), item, names, values);
    const result = ev.or();
    if (ev.i !== ev.tokens.length) throw new Error(`Unparsed condition: ${expression}`);
    return result;
  }

  private peek() { return this.tokens[this.i]; }
  private next() { return this.tokens[this.i++]; }
  private expect(token: string) {
    const got = this.next();
    if (got !== token) throw new Error(`Expected ${token}, got ${got}`);
  }

  private name(token: string): string {
    if (token.startsWith("#")) {
      const resolved = this.names?.[token];
      if (!resolved) throw new Error(`Missing name ${token}`);
      return resolved;
    }
    return token;
  }

  private operand(token: string): unknown {
    if (token.startsWith(":")) {
      if (!this.values || !(token in this.values)) throw new Error(`Missing value ${token}`);
      return this.values[token];
    }
    return this.item?.[this.name(token)];
  }

  or(): boolean {
    let value = this.and();
    while (this.peek() === "OR") { this.next(); const right = this.and(); value = value || right; }
    return value;
  }

  private and(): boolean {
    let value = this.unary();
    while (this.peek() === "AND") { this.next(); const right = this.unary(); value = value && right; }
    return value;
  }

  private unary(): boolean {
    if (this.peek() === "NOT") { this.next(); return !this.unary(); }
    return this.primary();
  }

  private primary(): boolean {
    const token = this.next();
    if (token === "(") { const value = this.or(); this.expect(")"); return value; }
    if (token === "attribute_exists" || token === "attribute_not_exists") {
      this.expect("(");
      const attribute = this.name(this.next());
      this.expect(")");
      const exists = this.item !== undefined && this.item[attribute] !== undefined;
      return token === "attribute_exists" ? exists : !exists;
    }
    if (token === "begins_with") {
      this.expect("(");
      const left = this.operand(this.next());
      this.expect(",");
      const right = this.operand(this.next());
      this.expect(")");
      return typeof left === "string" && typeof right === "string" && left.startsWith(right);
    }
    const left = this.operand(token);
    const op = this.next();
    if (op === "IN") {
      this.expect("(");
      const options: unknown[] = [this.operand(this.next())];
      while (this.peek() === ",") { this.next(); options.push(this.operand(this.next())); }
      this.expect(")");
      return options.some((option) => option === left);
    }
    const right = this.operand(this.next());
    switch (op) {
      case "=": return left !== undefined && left === right;
      case "<>": return left !== right;
      case "<": return left !== undefined && (left as number) < (right as number);
      case "<=": return left !== undefined && (left as number) <= (right as number);
      case ">": return left !== undefined && (left as number) > (right as number);
      case ">=": return left !== undefined && (left as number) >= (right as number);
      default: throw new Error(`Unknown operator ${op}`);
    }
  }
}

function applyUpdate(item: Item, expression: string, names: Names, values: Values): Item {
  const result: Item = { ...item };
  const sections = expression.split(/\b(SET|REMOVE|ADD)\b/).map((s) => s.trim()).filter(Boolean);
  const resolve = (name: string) => name.startsWith("#") ? names![name] : name;
  for (let i = 0; i < sections.length; i += 2) {
    const kind = sections[i];
    const parts = sections[i + 1].split(",").map((p) => p.trim()).filter(Boolean);
    for (const part of parts) {
      if (kind === "SET") {
        const [left, right] = part.split("=").map((p) => p.trim());
        if (!right.startsWith(":")) throw new Error(`Unsupported SET ${part}`);
        result[resolve(left)] = values![right];
      } else if (kind === "REMOVE") {
        delete result[resolve(part)];
      } else {
        const [left, right] = part.split(/\s+/);
        const name = resolve(left);
        result[name] = ((result[name] as number | undefined) ?? 0) + (values![right] as number);
      }
    }
  }
  return result;
}

export class FakeDynamo {
  items = new Map<string, Item>();
  calls: unknown[] = [];

  private key(key: { pk: unknown; sk: unknown }) {
    return `${String(key.pk)}\u0000${String(key.sk)}`;
  }

  put(item: Item) {
    this.items.set(this.key(item as { pk: unknown; sk: unknown }), structuredClone(item));
  }

  get(pk: string, sk: string): Item | undefined {
    return this.items.get(this.key({ pk, sk }));
  }

  private conditionFailed() {
    return new ConditionalCheckFailedException({ message: "The conditional request failed", $metadata: {} });
  }

  private update(input: Record<string, any>, write = true): Item {
    const id = this.key(input.Key);
    const before = this.items.get(id);
    if (!Evaluator.check(input.ConditionExpression, before, input.ExpressionAttributeNames,
      input.ExpressionAttributeValues)) throw this.conditionFailed();
    const after = applyUpdate(before ?? { ...input.Key }, input.UpdateExpression,
      input.ExpressionAttributeNames, input.ExpressionAttributeValues);
    if (write) this.items.set(id, after);
    return after;
  }

  send = async (command: unknown): Promise<any> => {
    this.calls.push(command);
    const input = (command as { input: Record<string, any> }).input;
    if (command instanceof GetCommand) {
      const item = this.items.get(this.key(input.Key));
      return { Item: item ? structuredClone(item) : undefined };
    }
    if (command instanceof PutCommand) {
      const id = this.key(input.Item);
      if (!Evaluator.check(input.ConditionExpression, this.items.get(id),
        input.ExpressionAttributeNames, input.ExpressionAttributeValues)) throw this.conditionFailed();
      this.items.set(id, structuredClone(input.Item));
      return {};
    }
    if (command instanceof UpdateCommand) {
      const after = this.update(input);
      return input.ReturnValues === "ALL_NEW" ? { Attributes: structuredClone(after) } : {};
    }
    if (command instanceof BatchGetCommand) {
      const responses: Record<string, Item[]> = {};
      for (const [table, request] of Object.entries(input.RequestItems as Record<string, { Keys: Item[] }>)) {
        responses[table] = request.Keys.flatMap((key) => {
          const item = this.items.get(this.key(key as { pk: unknown; sk: unknown }));
          return item ? [structuredClone(item)] : [];
        });
      }
      return { Responses: responses, UnprocessedKeys: {} };
    }
    if (command instanceof QueryCommand) {
      const [hashKey, rangeKey] = input.IndexName ? GSI_KEYS[input.IndexName] : ["pk", "sk"];
      let matches = [...this.items.values()].filter((item) =>
        item[hashKey] !== undefined &&
        Evaluator.check(input.KeyConditionExpression, item, input.ExpressionAttributeNames,
          input.ExpressionAttributeValues) &&
        Evaluator.check(input.FilterExpression, item, input.ExpressionAttributeNames,
          input.ExpressionAttributeValues));
      matches.sort((a, b) => String(a[rangeKey]).localeCompare(String(b[rangeKey])));
      if (input.ScanIndexForward === false) matches.reverse();
      if (input.ExclusiveStartKey) {
        const at = matches.findIndex((item) => item.pk === input.ExclusiveStartKey.pk &&
          item.sk === input.ExclusiveStartKey.sk);
        matches = matches.slice(at + 1);
      }
      const limited = input.Limit ? matches.slice(0, input.Limit) : matches;
      const last = input.Limit && matches.length > input.Limit ? limited.at(-1) : undefined;
      return {
        Items: input.Select === "COUNT" ? undefined : limited.map((item) => structuredClone(item)),
        Count: limited.length,
        LastEvaluatedKey: last ? {
          pk: last.pk, sk: last.sk,
          ...(input.IndexName ? { [hashKey]: last[hashKey], [rangeKey]: last[rangeKey] } : {}),
        } : undefined,
      };
    }
    if (command instanceof TransactWriteCommand) {
      const staged = new Map<string, Item>();
      const reasons: { Code: string }[] = [];
      for (const entry of input.TransactItems as Record<string, any>[]) {
        try {
          if (entry.ConditionCheck) {
            const c = entry.ConditionCheck;
            if (!Evaluator.check(c.ConditionExpression, this.items.get(this.key(c.Key)),
              c.ExpressionAttributeNames, c.ExpressionAttributeValues)) throw this.conditionFailed();
          } else if (entry.Update) {
            staged.set(this.key(entry.Update.Key), this.update(entry.Update, false));
          } else if (entry.Put) {
            const p = entry.Put;
            if (!Evaluator.check(p.ConditionExpression, this.items.get(this.key(p.Item)),
              p.ExpressionAttributeNames, p.ExpressionAttributeValues)) throw this.conditionFailed();
            staged.set(this.key(p.Item), structuredClone(p.Item));
          }
          reasons.push({ Code: "None" });
        } catch (error) {
          if (!(error instanceof ConditionalCheckFailedException)) throw error;
          reasons.push({ Code: "ConditionalCheckFailed" });
        }
      }
      if (reasons.some((r) => r.Code !== "None")) {
        throw new TransactionCanceledException({
          message: "Transaction cancelled", $metadata: {}, CancellationReasons: reasons,
        });
      }
      for (const [id, item] of staged) this.items.set(id, item);
      return {};
    }
    throw new Error(`FakeDynamo does not support ${(command as object).constructor.name}`);
  };
}
