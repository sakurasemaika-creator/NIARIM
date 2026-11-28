// Every DynamoDB expression in the backend refers to an attribute whose name is
// a DynamoDB reserved word through a placeholder (#name). Written bare,
// DynamoDB rejects the request: the daily post quota and the report quota
// wrote `ttl = :ttl`, so posting and reporting always failed with an internal
// error (found by walking the app against a local backend, 2026-11-28; the
// writes themselves are checked in quota-dynamodb-local.test.ts).
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// DynamoDB's reserved words (Amazon DynamoDB Developer Guide, "Reserved words
// in DynamoDB").
const RESERVED = new Set(
  [
    "ABORT ABSOLUTE ACTION ADD AFTER AGENT AGGREGATE ALL ALLOCATE ALTER ANALYZE AND ANY ARCHIVE",
    "ARE ARRAY AS ASC ASCII ASENSITIVE ASSERTION ASYMMETRIC AT ATOMIC ATTACH ATTRIBUTE AUTH",
    "AUTHORIZATION AUTHORIZE AUTO AVG BACK BACKUP BASE BATCH BEFORE BEGIN BETWEEN BIGINT BINARY",
    "BIT BLOB BLOCK BOOLEAN BOTH BREADTH BUCKET BULK BY BYTE CALL CALLED CALLING CAPACITY",
    "CASCADE CASCADED CASE CAST CATALOG CHAR CHARACTER CHECK CLASS CLOB CLOSE CLUSTER CLUSTERED",
    "CLUSTERING CLUSTERS COALESCE COLLATE COLLATION COLLECTION COLUMN COLUMNS COMBINE COMMENT",
    "COMMIT COMPACT COMPILE COMPRESS CONDITION CONFLICT CONNECT CONNECTION CONSISTENCY",
    "CONSISTENT CONSTRAINT CONSTRAINTS CONSTRUCTOR CONSUMED CONTINUE CONVERT COPY CORRESPONDING",
    "COUNT COUNTER CREATE CROSS CUBE CURRENT CURSOR CYCLE DATA DATABASE DATE DATETIME DAY",
    "DEALLOCATE DEC DECIMAL DECLARE DEFAULT DEFERRABLE DEFERRED DEFINE DEFINED DEFINITION",
    "DELETE DELIMITED DEPTH DEREF DESC DESCRIBE DESCRIPTOR DETACH DETERMINISTIC DIAGNOSTICS",
    "DIRECTORIES DISABLE DISCONNECT DISTINCT DISTRIBUTE DO DOMAIN DOUBLE DROP DUMP DURATION",
    "DYNAMIC EACH ELEMENT ELSE ELSEIF EMPTY ENABLE END EQUAL EQUALS ERROR ESCAPE ESCAPED EVAL",
    "EVALUATE EXCEEDED EXCEPT EXCEPTION EXCEPTIONS EXCLUSIVE EXEC EXECUTE EXISTS EXIT EXPLAIN",
    "EXPLODE EXPORT EXPRESSION EXTENDED EXTERNAL EXTRACT FAIL FALSE FAMILY FETCH FIELDS FILE",
    "FILTER FILTERING FINAL FINISH FIRST FIXED FLATTERN FLOAT FOR FORCE FOREIGN FORMAT FORWARD",
    "FOUND FREE FROM FULL FUNCTION FUNCTIONS GENERAL GENERATE GET GLOB GLOBAL GO GOTO GRANT",
    "GREATER GROUP GROUPING HANDLER HASH HAVE HAVING HEAP HIDDEN HOLD HOUR IDENTIFIED IDENTITY",
    "IF IGNORE IMMEDIATE IMPORT IN INCLUDING INCLUSIVE INCREMENT INCREMENTAL INDEX INDEXED",
    "INDEXES INDICATOR INFINITE INITIALLY INLINE INNER INNTER INOUT INPUT INSENSITIVE INSERT",
    "INSTEAD INT INTEGER INTERSECT INTERVAL INTO INVALIDATE IS ISOLATION ITEM ITEMS ITERATE",
    "JOIN KEY KEYS LAG LANGUAGE LARGE LAST LATERAL LEAD LEADING LEAVE LEFT LENGTH LESS LEVEL",
    "LIKE LIMIT LIMITED LINES LIST LOAD LOCAL LOCALTIME LOCALTIMESTAMP LOCATION LOCATOR LOCK",
    "LOCKS LOG LOGED LONG LOOP LOWER MAP MATCH MATERIALIZED MAX MAXLEN MEMBER MERGE METHOD",
    "METRICS MIN MINUS MINUTE MISSING MOD MODE MODIFIES MODIFY MODULE MONTH MULTI MULTISET NAME",
    "NAMES NATIONAL NATURAL NCHAR NCLOB NEW NEXT NO NONE NOT NULL NULLIF NUMBER NUMERIC OBJECT",
    "OF OFFLINE OFFSET OLD ON ONLINE ONLY OPAQUE OPEN OPERATOR OPTION OR ORDER ORDINALITY OTHER",
    "OTHERS OUT OUTER OUTPUT OVER OVERLAPS OVERRIDE OWNER PAD PARALLEL PARAMETER PARAMETERS",
    "PARTIAL PARTITION PARTITIONED PARTITIONS PATH PERCENT PERCENTILE PERMISSION PERMISSIONS",
    "PIPE PIPELINED PLAN POOL POSITION PRECISION PREPARE PRESERVE PRIMARY PRIOR PRIVATE",
    "PRIVILEGES PROCEDURE PROCESSED PROJECT PROJECTION PROPERTY PROVISIONING PUBLIC PUT QUERY",
    "QUIT QUORUM RAISE RANDOM RANGE RANK RAW READ READS REAL REBUILD RECORD RECURSIVE REDUCE",
    "REF REFERENCE REFERENCES REFERENCING REGEXP REGION REINDEX RELATIVE RELEASE REMAINDER",
    "RENAME REPEAT REPLACE REQUEST RESET RESIGNAL RESOURCE RESPONSE RESTORE RESTRICT RESULT",
    "RETURN RETURNING RETURNS REVERSE REVOKE RIGHT ROLE ROLES ROLLBACK ROLLUP ROUTINE ROW ROWS",
    "RULE RULES SAMPLE SATISFIES SAVE SAVEPOINT SCAN SCHEMA SCOPE SCROLL SEARCH SECOND SECTION",
    "SEGMENT SEGMENTS SELECT SELF SEMI SENSITIVE SEPARATE SEQUENCE SERIALIZABLE SESSION SET",
    "SETS SHARD SHARE SHARED SHORT SHOW SIGNAL SIMILAR SIZE SKEWED SMALLINT SNAPSHOT SOME",
    "SOURCE SPACE SPACES SPARSE SPECIFIC SPECIFICTYPE SPLIT SQL SQLCODE SQLERROR SQLEXCEPTION",
    "SQLSTATE SQLWARNING START STATE STATIC STATUS STORAGE STORE STORED STREAM STRING STRUCT",
    "STYLE SUB SUBMULTISET SUBPARTITION SUBSTRING SUBTYPE SUM SUPER SYMMETRIC SYNONYM SYSTEM",
    "TABLE TABLESAMPLE TEMP TEMPORARY TERMINATED TEXT THAN THEN THROUGHPUT TIME TIMESTAMP",
    "TIMEZONE TINYINT TO TOKEN TOTAL TOUCH TRAILING TRANSACTION TRANSFORM TRANSLATE TRANSLATION",
    "TREAT TRIGGER TRIM TRUE TRUNCATE TTL TUPLE TYPE UNDER UNDO UNION UNIQUE UNIT UNKNOWN",
    "UNLOGGED UNNEST UNPROCESSED UNSIGNED UNTIL UPDATE UPPER URL USAGE USE USER USERS USING",
    "UUID VACUUM VALUE VALUED VALUES VARCHAR VARIABLE VARIANCE VARINT VARYING VIEW VIEWS",
    "VIRTUAL VOID WAIT WHEN WHENEVER WHERE WHILE WINDOW WITH WITHIN WITHOUT WORK WRAPPED WRITE",
    "YEAR ZONE",
  ]
    .join(" ")
    .split(" "),
);

// Keywords and functions of the expression syntax itself.
const SYNTAX = new Set(
  "SET ADD REMOVE DELETE AND OR NOT BETWEEN IN attribute_exists attribute_not_exists attribute_type begins_with contains size if_not_exists list_append".split(
    " ",
  ),
);

const EXPRESSION =
  /(UpdateExpression|ConditionExpression|FilterExpression|KeyConditionExpression|ProjectionExpression)\s*:\s*/g;

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return path.endsWith(".ts") ? [path] : [];
  });
}

/** The value given to an expression property, up to the next top-level comma. */
function expressionValue(source: string, start: number): string {
  let depth = 0;
  let quote: string | null = null;
  let out = "";
  for (let i = start; i < source.length; i++) {
    const c = source[i];
    if (quote) {
      out += c;
      if (c === quote && source[i - 1] !== "\\") quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      quote = c;
      out += c;
      continue;
    }
    if ("([{".includes(c)) depth++;
    if (")]}".includes(c)) {
      if (depth === 0) break;
      depth--;
    }
    if (c === "," && depth === 0) break;
    out += c;
  }
  return out;
}

function bareNames(): { name: string; at: string }[] {
  const root = join(__dirname, "..", "src");
  const found: { name: string; at: string }[] = [];
  for (const file of sourceFiles(root)) {
    const source = readFileSync(file, "utf8");
    for (const match of source.matchAll(EXPRESSION)) {
      const value = expressionValue(source, match.index! + match[0].length);
      const line = source.slice(0, match.index).split("\n").length;
      for (const literal of value.matchAll(/"([^"]*)"|'([^']*)'|`([^`]*)`/g)) {
        const text = (literal[1] ?? literal[2] ?? literal[3]).replace(
          /\$\{[^}]*\}/g,
          " ",
        );
        for (const word of text.matchAll(
          /(?<![#:\w.])([A-Za-z_][A-Za-z0-9_]*)/g,
        )) {
          if (!SYNTAX.has(word[1])) {
            found.push({
              name: word[1],
              at: `${file.slice(root.length + 1)}:${line}`,
            });
          }
        }
      }
    }
  }
  return found;
}

describe("DynamoDB expressions", () => {
  it("name no reserved word bare (use #name in ExpressionAttributeNames)", () => {
    const names = bareNames();
    // The scan reads the expressions: guard against it silently finding none.
    expect(names.length).toBeGreaterThan(100);
    const reserved = names.filter(({ name }) =>
      RESERVED.has(name.toUpperCase()),
    );
    expect(reserved).toEqual([]);
  });
});
