# INV-001 — Merchant Chargeback Analysis

![Type](https://img.shields.io/badge/Type-Merchant%20Risk-blue) ![Severity](https://img.shields.io/badge/Severity-High-red)

**Purpose:** Investigate a spike in chargebacks concentrated on a small group of merchants.
**Estimated reading time:** 8 minutes
⬅️ [Back to Investigations Index](../README.md)

---

## 1. Business Problem

NovaPay's Merchant Payments product has seen a **34% month-over-month increase** in chargeback volume,
concentrated in a small number of merchants rather than spread evenly across the merchant base. Rising
chargebacks carry direct financial cost (reversed funds, card scheme penalties) and, past a certain
threshold, risk of card network monitoring programs that can restrict NovaPay's processing privileges.

Leadership needs to know: is this broad market fraud, or a small number of problem merchants — and what
should be done about it?

## 2. Business Context

- NovaPay onboards merchants with a lightweight self-serve flow below a certain transaction volume threshold
- Merchant risk tiering exists but is reviewed periodically, not continuously
- Chargeback reason codes are captured but not routinely analyzed at the merchant level
- Prior to this investigation, merchant risk reviews were largely reactive — triggered by card scheme
  notices rather than internal detection

## 3. Fraud Indicators

- Sudden increase in chargeback rate for a merchant relative to its own historical baseline
- Chargeback reason codes clustering around `fraud_no_auth` rather than `product_not_received` (suggesting
  possible merchant collusion in card-not-present fraud rather than simple service disputes)
- High-value transactions immediately preceding a spike, inconsistent with the merchant's typical ticket size
- Multiple merchants sharing the same settlement bank account or business registration details

## 4. Investigation Plan

1. Quantify chargeback rate by merchant over the trailing 90 days, ranked against each merchant's own baseline
2. Isolate merchants whose chargeback rate significantly exceeds their category (MCC) average
3. Break down chargeback reason codes for the flagged merchants
4. Check for shared onboarding attributes across flagged merchants (registration date clustering, shared bank
   details)
5. Cross-reference flagged merchant risk tier to confirm whether existing tiering already caught this

## 5. Evidence Collected

| Evidence | Source | Relevance |
|---|---|---|
| Merchant-level chargeback rate, trailing 90 days | `fact_chargebacks`, `fact_transactions` | Establishes which merchants are outliers |
| Chargeback reason code distribution | `fact_chargebacks` | Distinguishes fraud disputes from service disputes |
| Merchant onboarding dates and risk tier | `dim_merchants` | Checks whether flagged merchants are recently onboarded / under-tiered |
| Transaction value trend per merchant | `fact_transactions` | Confirms unusual ticket-size behavior before the spike |

## 6. SQL — Investigation

```sql
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
```

## 7. SQL Walkthrough

- **`merchant_txn_volume`** establishes the transaction denominator per merchant — needed before a rate can
  mean anything.
- **`merchant_chargebacks`** / **`merchant_chargeback_totals`** roll up chargebacks to the same merchant grain.
- **`merchant_rates`** joins volume, chargebacks, and merchant attributes to compute a per-merchant chargeback
  rate.
- **`mcc_benchmark`** computes the average chargeback rate per merchant category, so a merchant is judged
  against peers in the same business type — not the entire merchant base.
- The final `SELECT` isolates merchants at **3x or more** their category's average chargeback rate — a
  threshold chosen to surface genuine outliers rather than normal variance.

## 8. Expected Results

| merchant_id | mcc_code | risk_tier | total_transactions | total_chargebacks | chargeback_rate | rate_vs_category_avg |
|---|---|---|---|---|---|---|
| MCH-10432 | 5732 (Electronics) | Standard | 1,180 | 96 | 0.0814 | 6.4x |
| MCH-10917 | 5732 (Electronics) | Standard | 640 | 41 | 0.0641 | 5.0x |
| MCH-11288 | 5411 (Grocery) | Standard | 2,050 | 58 | 0.0283 | 3.8x |

*(Sample/illustrative figures — see [Sample-Results](../Sample-Results/) for full mock output format.)*

## 9. Findings

- Chargebacks were **not** evenly distributed across the merchant base — 3 merchants accounted for a
  disproportionate share of the overall increase
- All 3 flagged merchants were onboarded within the same 6-week window and shared the same `Standard`
  risk tier, despite one being in electronics (a category with historically higher fraud exposure)
- Chargeback reason codes for these merchants were concentrated in `fraud_no_auth`, not `product_not_received`
  — consistent with card-not-present fraud rather than genuine service disputes
- Existing risk tiering had not flagged these merchants because tiering is reviewed periodically rather than
  continuously, and their onboarding volume looked unremarkable at the time

## 10. Risk Assessment

| Factor | Assessment |
|---|---|
| Financial exposure | Moderate-to-high — chargeback penalties plus reversed transaction value |
| Scheme/regulatory risk | Elevated — sustained high chargeback rates risk card network monitoring status |
| Likelihood of recurrence | High if root cause (onboarding/tiering gap) is not addressed |
| Detection gap | Confirmed — periodic tiering review missed a real-time pattern |

**Overall severity: High** — not because of the current transaction volume, but because the underlying
detection gap would allow the same pattern to recur undetected with other merchants.

## 11. Business Recommendation

1. **Immediate:** Escalate the 3 flagged merchants for manual review and temporary transaction holds pending
   verification
2. **Short-term:** Add an automated chargeback-rate-vs-category-average flag to the merchant risk dashboard,
   refreshed daily rather than reviewed periodically
3. **Structural:** Tighten onboarding risk tiering for higher-fraud-exposure categories (e.g. electronics)
   so new merchants in those categories start at a stricter monitoring tier by default

These recommendations were scoped to be deliverable without new headcount — the dashboard flag reuses
existing chargeback and transaction data already captured in the warehouse.

## 12. Operational Impact

- Reduces time-to-detection for merchant-level chargeback spikes from a periodic review cycle to daily
- Gives risk analysts a prioritized queue instead of relying on card scheme notices as the trigger
- Tightens onboarding controls for the specific merchant categories shown to carry higher fraud exposure,
  without adding friction across the entire merchant base

## 13. Lessons Learned

- Periodic risk tiering reviews are structurally too slow for chargeback fraud, which can escalate within
  weeks of onboarding
- Category-relative benchmarking (comparing a merchant to its own MCC peer average) surfaces real outliers
  much more reliably than comparing against the entire merchant base
- Onboarding date clustering across flagged merchants is a useful secondary signal worth checking in future
  investigations, even when it isn't the primary hypothesis

## 14. Interview Questions

1. Why did you benchmark chargeback rate against category average instead of the overall merchant base?
2. How did you distinguish genuine merchant fraud from a merchant simply having a bad month?
3. What would you have done differently if the flagged merchants had been in different risk tiers already?
4. How do you balance false positives against the cost of missing a real chargeback fraud pattern?
5. What would make this detection method break down at 10x NovaPay's current merchant volume?

## 15. Interview Answers

**1. Why benchmark against category average instead of overall merchant base?**
Different merchant categories carry structurally different chargeback baselines — electronics and
high-ticket goods naturally run higher than grocery or bill payments. Comparing against the whole merchant
base would either miss real outliers in low-baseline categories or over-flag normal merchants in
high-baseline categories.

**2. How did you distinguish fraud from a bad month?**
Reason code composition. A merchant having a bad month tends to see `product_not_received` or
`item_not_as_described` disputes. A concentration in `fraud_no_auth` is a much stronger signal of
card-not-present fraud, either merchant-side or via compromised cards being tested through that merchant.

**3. What if they'd already been in stricter risk tiers?**
The recommendation would shift from "fix the tiering gap" to "the existing tier's controls aren't catching
this pattern" — meaning the fix would target monitoring thresholds within that tier rather than tier
assignment itself.

**4. Balancing false positives vs missed fraud?**
The 3x-category-average threshold was set deliberately conservative to avoid flooding analysts with noise;
it's tuned to catch clear outliers first, with room to lower the threshold once the team has capacity to
review a larger flagged queue.

**5. Where would this break down at scale?**
At significantly higher merchant volume, MCC-level benchmarking alone becomes too coarse — you'd want to add
sub-category or geographic benchmarking, and likely move from a threshold-based flag to a statistical
outlier model (e.g. z-score based) to keep pace with a larger, more varied merchant base.

---
⬅️ [Back to Investigations Index](../README.md)
