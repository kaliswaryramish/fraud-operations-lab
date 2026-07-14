-- ============================================================
-- INV-004: High-Risk Merchant Investigation
-- Purpose: Validate whether assigned merchant risk tier
--          correlates with actual observed risk activity.
-- ============================================================

-- Step 1: Actual risk flag activity per merchant
WITH merchant_flags AS (
    SELECT
        entity_id AS merchant_id,
        COUNT(*) AS risk_flag_count,
        COUNT(*) FILTER (WHERE severity IN ('high', 'critical')) AS high_severity_flags
    FROM dim_risk_flags
    WHERE entity_type = 'merchant'
      AND flag_date >= CURRENT_DATE - INTERVAL '180 days'
    GROUP BY entity_id
),

-- Step 2: Actual chargeback rate per merchant (reuses same logic pattern as INV-001)
merchant_chargeback_rate AS (
    SELECT
        t.merchant_id,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        COUNT(DISTINCT cb.chargeback_id) AS total_chargebacks,
        ROUND(
            COUNT(DISTINCT cb.chargeback_id)::decimal / NULLIF(COUNT(DISTINCT t.transaction_id), 0), 4
        ) AS chargeback_rate
    FROM fact_transactions t
    LEFT JOIN fact_chargebacks cb ON t.transaction_id = cb.transaction_id
    WHERE t.created_at >= CURRENT_DATE - INTERVAL '180 days'
    GROUP BY t.merchant_id
),

-- Step 3: Combine assigned tier with actual observed risk signals
merchant_risk_profile AS (
    SELECT
        m.merchant_id,
        m.mcc_code,
        m.risk_tier AS assigned_tier,
        COALESCE(f.risk_flag_count, 0) AS risk_flag_count,
        COALESCE(f.high_severity_flags, 0) AS high_severity_flags,
        COALESCE(c.chargeback_rate, 0) AS chargeback_rate
    FROM dim_merchants m
    LEFT JOIN merchant_flags f ON m.merchant_id = f.merchant_id
    LEFT JOIN merchant_chargeback_rate c ON m.merchant_id = c.merchant_id
),

-- Step 4: Rank merchants by observed risk within each assigned tier
ranked AS (
    SELECT
        *,
        NTILE(4) OVER (PARTITION BY assigned_tier ORDER BY chargeback_rate DESC) AS risk_quartile_within_tier
    FROM merchant_risk_profile
)

-- Final output: Standard-tier merchants whose observed risk lands in the top quartile of their own tier
-- AND carries high-severity flags -- i.e. merchants that behave like they should be tiered higher
SELECT
    merchant_id,
    mcc_code,
    assigned_tier,
    risk_flag_count,
    high_severity_flags,
    chargeback_rate
FROM ranked
WHERE assigned_tier = 'Standard'
  AND risk_quartile_within_tier = 1
  AND high_severity_flags > 0
ORDER BY chargeback_rate DESC;
