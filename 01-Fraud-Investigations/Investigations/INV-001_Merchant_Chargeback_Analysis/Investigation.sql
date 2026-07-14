-- ============================================================
-- INV-001: Merchant Chargeback Analysis
-- Purpose: Identify merchants with abnormal chargeback rates
--          and characterize the nature of those chargebacks.
-- ============================================================

-- Step 1: Merchant-level transaction and chargeback volume, trailing 90 days
WITH merchant_txn_volume AS (
    SELECT
        t.merchant_id,
        COUNT(*) AS total_transactions,
        SUM(t.amount) AS total_volume
    FROM fact_transactions t
    WHERE t.created_at >= CURRENT_DATE - INTERVAL '90 days'
      AND t.transaction_type IN ('card_payment', 'qr_payment')
    GROUP BY t.merchant_id
),

merchant_chargebacks AS (
    SELECT
        t.merchant_id,
        cb.reason_code,
        COUNT(*) AS chargeback_count,
        SUM(cb.amount) AS chargeback_amount
    FROM fact_chargebacks cb
    INNER JOIN fact_transactions t ON cb.transaction_id = t.transaction_id
    WHERE cb.filed_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY t.merchant_id, cb.reason_code
),

-- Step 2: Roll up chargebacks per merchant regardless of reason code
merchant_chargeback_totals AS (
    SELECT
        merchant_id,
        SUM(chargeback_count) AS total_chargebacks,
        SUM(chargeback_amount) AS total_chargeback_amount
    FROM merchant_chargebacks
    GROUP BY merchant_id
),

-- Step 3: Compute chargeback rate and compare against category (MCC) average
merchant_rates AS (
    SELECT
        v.merchant_id,
        m.mcc_code,
        m.risk_tier,
        m.onboarding_date,
        v.total_transactions,
        c.total_chargebacks,
        ROUND(c.total_chargebacks::decimal / NULLIF(v.total_transactions, 0), 4) AS chargeback_rate
    FROM merchant_txn_volume v
    INNER JOIN merchant_chargeback_totals c ON v.merchant_id = c.merchant_id
    INNER JOIN dim_merchants m ON v.merchant_id = m.merchant_id
),

mcc_benchmark AS (
    SELECT
        mcc_code,
        AVG(chargeback_rate) AS avg_mcc_chargeback_rate
    FROM merchant_rates
    GROUP BY mcc_code
)

-- Step 4: Final output — merchants whose chargeback rate is 3x+ their category average
SELECT
    r.merchant_id,
    r.mcc_code,
    r.risk_tier,
    r.onboarding_date,
    r.total_transactions,
    r.total_chargebacks,
    r.chargeback_rate,
    b.avg_mcc_chargeback_rate,
    ROUND(r.chargeback_rate / NULLIF(b.avg_mcc_chargeback_rate, 0), 2) AS rate_vs_category_avg
FROM merchant_rates r
INNER JOIN mcc_benchmark b ON r.mcc_code = b.mcc_code
WHERE r.chargeback_rate > 3 * b.avg_mcc_chargeback_rate
ORDER BY rate_vs_category_avg DESC;
