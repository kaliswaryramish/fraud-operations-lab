# INV-009 — Fraud Trend Analysis

![Type](https://img.shields.io/badge/Type-Trend%20Analysis-blue) ![Severity](https://img.shields.io/badge/Severity-Medium--High-orange)

**Purpose:** Produce a cross-market fraud trend view for leadership and Policy stakeholders.
**Estimated reading time:** 8 minutes
⬅️ [Back to Investigations Index](../README.md)

---

## 1. Business Problem

Individual investigations (like INV-001, INV-002, INV-004) catch specific patterns as they emerge, but
leadership and Policy need a **standing, cross-market view** of fraud trends — which fraud types are rising,
in which markets, and whether existing controls are keeping pace. Without this, the business only reacts to
issues one investigation at a time instead of tracking direction of travel.

## 2. Business Context

- NovaPay operates across 5 Southeast Asian markets, each with different regulatory environments and fraud
  patterns
- Fraud type data (chargebacks, ATO-linked risk flags, merchant risk flags) exists but has historically been
  analyzed per-investigation rather than rolled up into a recurring trend view
- Policy and leadership stakeholders need trend data framed in business terms (volume, financial exposure,
  direction of change) rather than raw case counts

## 3. Fraud Indicators

This investigation aggregates indicators already validated in prior investigations, rather than introducing
new ones:

- Chargeback volume and rate, by market and month
- Risk flag volume, by flag type and market
- Month-over-month percentage change in each, to identify direction and speed of trend

## 4. Investigation Plan

1. Aggregate chargeback and risk-flag volume by market and month over a 6-month window
2. Calculate month-over-month percentage change per market and fraud type
3. Rank markets and fraud types by rate of increase, not just absolute volume, so emerging trends are visible
   even before they become the largest by volume
4. Package results into a recurring format Policy and leadership can consume monthly

## 5. Evidence Collected

| Evidence | Source | Relevance |
|---|---|---|
| Monthly chargeback volume by market | `fact_chargebacks`, `fact_transactions` | Core trend metric |
| Monthly risk flag volume by market and type | `dim_risk_flags` | Captures fraud types beyond chargebacks (ATO, merchant risk) |
| Market metadata | `dim_users`, `dim_merchants` | Enables market-level rollup |

## 6. SQL — Investigation

```sql
-- ============================================================
-- INV-009: Fraud Trend Analysis
-- Purpose: Produce a month-over-month, market-level view of
--          chargeback and risk-flag trends for leadership.
-- ============================================================

-- Step 1: Monthly chargeback volume by market
WITH monthly_chargebacks AS (
    SELECT
        t.market,
        DATE_TRUNC('month', cb.filed_date) AS month,
        COUNT(*) AS chargeback_count,
        SUM(cb.amount) AS chargeback_amount
    FROM fact_chargebacks cb
    INNER JOIN fact_transactions t ON cb.transaction_id = t.transaction_id
    WHERE cb.filed_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY t.market, DATE_TRUNC('month', cb.filed_date)
),

-- Step 2: Monthly risk flag volume by market and flag type
monthly_flags AS (
    SELECT
        u.market,
        DATE_TRUNC('month', rf.flag_date) AS month,
        rf.flag_type,
        COUNT(*) AS flag_count
    FROM dim_risk_flags rf
    INNER JOIN dim_users u ON rf.entity_id = u.user_id AND rf.entity_type = 'user'
    WHERE rf.flag_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY u.market, DATE_TRUNC('month', rf.flag_date), rf.flag_type

    UNION ALL

    SELECT
        m.market,
        DATE_TRUNC('month', rf.flag_date) AS month,
        rf.flag_type,
        COUNT(*) AS flag_count
    FROM dim_risk_flags rf
    INNER JOIN dim_merchants m ON rf.entity_id = m.merchant_id AND rf.entity_type = 'merchant'
    WHERE rf.flag_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY m.market, DATE_TRUNC('month', rf.flag_date), rf.flag_type
),

-- Step 3: Month-over-month change in chargeback volume, using LAG()
chargeback_trend AS (
    SELECT
        market,
        month,
        chargeback_count,
        LAG(chargeback_count) OVER (PARTITION BY market ORDER BY month) AS prior_month_count,
        ROUND(
            100.0 * (chargeback_count - LAG(chargeback_count) OVER (PARTITION BY market ORDER BY month))
            / NULLIF(LAG(chargeback_count) OVER (PARTITION BY market ORDER BY month), 0), 1
        ) AS mom_pct_change
    FROM monthly_chargebacks
)

-- Final output: markets with the steepest month-over-month chargeback increase in the latest month
SELECT
    market,
    month,
    chargeback_count,
    prior_month_count,
    mom_pct_change
FROM chargeback_trend
WHERE month = (SELECT MAX(month) FROM monthly_chargebacks)
ORDER BY mom_pct_change DESC NULLS LAST;
```

## 7. SQL Walkthrough

- **`monthly_chargebacks`** rolls chargebacks up to market-month grain — the base unit for trend analysis.
- **`monthly_flags`** does the same for risk flags, unioning user-level and merchant-level flags since both
  share the same `dim_risk_flags` table but join to different dimension tables.
- **`chargeback_trend`** uses `LAG()` to compare each market-month against its own prior month, producing a
  month-over-month percentage change — the core metric leadership actually needs, since raw counts don't
  convey direction of travel.
- The final query surfaces the **latest month**, ranked by steepest increase — designed to answer "where is
  fraud accelerating right now," not just "where is fraud largest historically."

## 8. Expected Results

| market | month | chargeback_count | prior_month_count | mom_pct_change |
|---|---|---|---|---|
| MY | 2026-06 | 412 | 305 | +35.1% |
| PH | 2026-06 | 268 | 240 | +11.7% |
| SG | 2026-06 | 190 | 205 | -7.3% |

*(Sample/illustrative figures — see [Sample-Results](../Sample-Results/) for full mock output format.)*

## 9. Findings

- One market showed a significantly steeper month-over-month chargeback increase than the others, flagging
  it as the priority for the coming month's investigation capacity
- Risk flag trends did not always move in the same direction as chargeback trends in the same market —
  suggesting different fraud types were emerging at different speeds, and a single "fraud is up" headline
  would have masked which specific pattern was actually accelerating
- Packaging this as a recurring monthly view (rather than a one-off report) surfaced the accelerating market
  earlier than it would have been caught by individual, unrelated investigations

## 10. Risk Assessment

| Factor | Assessment |
|---|---|
| Visibility gap (before this) | High — no standing cross-market trend view existed |
| Financial exposure | Concentrated in the fastest-accelerating market |
| Decision-making impact | Without this, Policy and leadership were working from anecdote and individual case counts rather than trend direction |

**Overall severity: Medium-High** — the risk here is less about a single fraud event and more about slow
leadership decision-making without a reliable trend signal.

## 11. Business Recommendation

1. **Immediate:** Prioritize the accelerating market for the next investigation cycle rather than spreading
   capacity evenly across all markets
2. **Structural:** Convert this analysis into a recurring monthly report distributed to Policy and
   leadership, rather than an ad hoc query
3. **Longer-term:** Feed this same aggregation into a dashboard so stakeholders can self-serve the trend view
   between formal reporting cycles

## 12. Operational Impact

- Gives Policy and leadership a recurring, comparable view of fraud direction across markets instead of
  isolated case-by-case updates
- Allows investigation capacity to be allocated toward the market/fraud type accelerating fastest, rather
  than reactively
- Creates a foundation for a self-serve dashboard, reducing repeated ad hoc reporting requests to the fraud
  operations team

## 13. Lessons Learned

- Absolute volume and rate-of-change tell different stories — ranking by month-over-month change surfaced a
  market that wasn't the largest by volume, but was accelerating fastest
- Chargeback trend and risk flag trend don't always move together, so leadership reporting needs to show
  both rather than picking one as a proxy for "fraud" overall
- A one-off trend analysis has limited value unless it's converted into a recurring reporting cadence

## 14. Interview Questions

1. Why rank by month-over-month percentage change instead of absolute volume?
2. How do you present a fraud trend to a non-technical leadership audience?
3. What would you do if two fraud metrics (chargebacks and risk flags) told conflicting stories in the same
   market?
4. How do you avoid this kind of trend report becoming just noise that leadership tunes out?
5. How would this analysis change if NovaPay expanded into 5 new markets tomorrow?

## 15. Interview Answers

**1. Why rank by percentage change, not volume?**
Absolute volume favors the largest markets by default, which can hide a smaller market where fraud is
accelerating fastest. Percentage change surfaces direction of travel, which is what actually determines
where investigation capacity should go next.

**2. Presenting to non-technical leadership?**
Lead with the business framing — which market, what direction, what financial exposure — before any
supporting numbers. Leadership needs "market X is accelerating and here's the likely driver," not a table of
raw SQL output.

**3. Conflicting metrics in the same market?**
That's a signal worth calling out explicitly rather than resolving artificially — I'd present both metrics
and note that different fraud types are moving independently, which is itself useful information about
where controls are and aren't working.

**4. Avoiding report fatigue?**
Keep the recurring report focused on what changed and why it matters, not a full re-explanation of every
metric every month — and reserve deep-dive investigation write-ups (like INV-001, INV-002) for when a trend
actually crosses a threshold worth acting on.

**5. Scaling to 5 new markets?**
The market-partitioned window functions in this query scale naturally to more markets without rewriting
logic — the bigger consideration would be whether new markets have enough transaction history yet for
month-over-month comparisons to be statistically meaningful, versus just noise from small sample sizes.

---
⬅️ [Back to Investigations Index](../README.md)
