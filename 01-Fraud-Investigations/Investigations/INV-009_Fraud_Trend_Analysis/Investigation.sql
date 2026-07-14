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
