-- ============================================================
-- INV-010: Executive Fraud Summary
-- Purpose: Roll up quarterly loss exposure and law enforcement
--          case outcomes into a single executive-level summary.
-- ============================================================

-- Step 1: Quarterly chargeback loss exposure
WITH quarterly_chargeback_loss AS (
    SELECT
        DATE_TRUNC('quarter', filed_date) AS quarter,
        COUNT(*) AS chargeback_count,
        SUM(amount) AS chargeback_loss
    FROM fact_chargebacks
    WHERE filed_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('quarter', filed_date)
),

-- Step 2: Quarterly ATO-linked transfer loss (transfers flagged as high-severity account risk)
quarterly_ato_loss AS (
    SELECT
        DATE_TRUNC('quarter', t.created_at) AS quarter,
        COUNT(DISTINCT t.transaction_id) AS ato_transaction_count,
        SUM(t.amount) AS ato_loss
    FROM fact_transactions t
    INNER JOIN dim_risk_flags rf
        ON t.user_id = rf.entity_id
       AND rf.entity_type = 'user'
       AND rf.flag_type = 'device_anomaly'
       AND rf.severity IN ('high', 'critical')
    WHERE t.transaction_type = 'p2p_transfer'
      AND t.created_at >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('quarter', t.created_at)
),

-- Step 3: Law enforcement case volume and closure outcomes, by quarter
quarterly_le_cases AS (
    SELECT
        DATE_TRUNC('quarter', opened_date) AS quarter,
        COUNT(*) AS cases_opened,
        COUNT(*) FILTER (WHERE outcome = 'resolved_in_favor') AS cases_resolved_favorably
    FROM fact_law_enforcement_cases
    WHERE opened_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('quarter', opened_date)
)

-- Final output: one row per quarter, combining all three exposure/engagement views
SELECT
    cb.quarter,
    cb.chargeback_count,
    cb.chargeback_loss,
    ato.ato_transaction_count,
    ato.ato_loss,
    le.cases_opened,
    le.cases_resolved_favorably
FROM quarterly_chargeback_loss cb
LEFT JOIN quarterly_ato_loss ato ON cb.quarter = ato.quarter
LEFT JOIN quarterly_le_cases le ON cb.quarter = le.quarter
ORDER BY cb.quarter DESC;
