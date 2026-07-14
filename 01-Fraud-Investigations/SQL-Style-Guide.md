# SQL Style Guide

**Purpose:** How SQL is written across every investigation in this repo.
**Estimated reading time:** 2 minutes
⬅️ [Back to README](./README.md)

## Principles

1. **Readability over cleverness.** A reviewer should understand the logic without running it.
2. **CTEs over nested subqueries.** Each CTE names one clear step of the analysis.
3. **Comment every CTE** with what it does and why it exists.
4. **Window functions only where they add real value** (e.g. ranking repeat offenders, calculating rolling
   trends) — not used to demonstrate syntax.
5. **Explicit column lists** in SELECT statements — no `SELECT *` in final outputs.
6. **Meaningful aliases** — `t` for transactions is fine in a 2-table join; a 5-table join gets descriptive
   aliases like `txn`, `mer`, `cb`.

## Example pattern used throughout this repo

```sql
-- Step 1: Isolate the population under investigation
WITH flagged_merchants AS (
    SELECT merchant_id
    FROM dim_risk_flags
    WHERE entity_type = 'merchant'
      AND flag_type = 'chargeback_spike'
),

-- Step 2: Bring in transaction-level detail for that population
merchant_transactions AS (
    SELECT
        t.merchant_id,
        t.transaction_id,
        t.amount,
        t.created_at
    FROM fact_transactions t
    INNER JOIN flagged_merchants fm ON t.merchant_id = fm.merchant_id
)

-- Step 3: Final aggregation answering the business question
SELECT
    merchant_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_volume
FROM merchant_transactions
GROUP BY merchant_id
HAVING COUNT(*) > 50;
```

⬅️ [Back to README](./README.md)
