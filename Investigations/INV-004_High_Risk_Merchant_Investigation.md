# INV-004 — High-Risk Merchant Investigation

![Type](https://img.shields.io/badge/Type-Merchant%20Risk-blue) ![Severity](https://img.shields.io/badge/Severity-High-red)

**Purpose:** Investigate whether NovaPay's merchant risk tiering is correctly identifying high-risk merchants.
**Estimated reading time:** 8 minutes
⬅️ [Back to Investigations Index](../README.md)

---

## 1. Business Problem

NovaPay assigns merchants a risk tier (`Standard`, `Elevated`, `High`) at onboarding, which determines
transaction monitoring intensity and payout hold periods. Policy has asked Risk Operations to validate
whether this tiering actually correlates with real fraud/risk outcomes — or whether merchants are being
mis-tiered, leaving genuinely high-risk merchants under-monitored.

## 2. Business Context

- Risk tier is set once at onboarding based on business category, expected volume, and self-declared business
  information
- Tier is only formally reassessed during periodic reviews (see INV-001), not continuously
- Multiple downstream controls (payout hold length, transaction monitoring thresholds) key off this single
  tier value — so a wrong tier compounds across several controls at once

## 3. Fraud Indicators

- Merchants tiered `Standard` but carrying risk-flag counts, chargeback rates, or dispute values consistent
  with `High` tier peers
- Merchants tiered `High` showing no elevated risk activity at all, suggesting overly conservative tiering
  that wastes monitoring capacity
- Category (MCC)-level mismatches — entire business categories systematically under-tiered relative to
  their actual fraud outcomes

## 4. Investigation Plan

1. Pull risk flag counts, chargeback rate, and dispute value per merchant, grouped by current risk tier
2. Compare the distribution of these risk indicators within each tier — a well-calibrated tiering system
   should show materially different risk indicator levels between tiers
3. Identify individual merchants whose risk indicators don't match their assigned tier
4. Check whether mismatches cluster by MCC category (a systemic tiering rule issue) or are scattered
   individually (a case-by-case onboarding issue)

## 5. Evidence Collected

| Evidence | Source | Relevance |
|---|---|---|
| Current risk tier per merchant | `dim_merchants` | The control being validated |
| Risk flags raised per merchant | `dim_risk_flags` | Independent signal of actual risk activity |
| Chargeback rate per merchant | `fact_chargebacks`, `fact_transactions` | Independent signal of actual fraud outcomes |
| MCC category per merchant | `dim_merchants` | Tests whether mismatches are systemic by category |

## 6. SQL — Investigation

```sql
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
```

## 7. SQL Walkthrough

- **`merchant_flags`** and **`merchant_chargeback_rate`** independently measure actual observed risk,
  deliberately not referencing `risk_tier` at all — this keeps the "ground truth" measurement separate from
  the control being validated.
- **`merchant_risk_profile`** brings the assigned tier back together with the independent risk signals.
- **`ranked`** uses `NTILE(4)` **within each tier** (not globally) to find merchants that are outliers
  relative to their own tier peers — a `Standard` merchant in the top quartile of its own tier is a stronger
  signal than comparing it against `High` tier merchants directly.
- The final filter narrows to `Standard`-tier merchants with both top-quartile chargeback rate and at least
  one high-severity flag — reducing false positives from chargeback rate alone.

## 8. Expected Results

| merchant_id | mcc_code | assigned_tier | risk_flag_count | high_severity_flags | chargeback_rate |
|---|---|---|---|---|---|
| MCH-20441 | 5732 | Standard | 6 | 2 | 0.0512 |
| MCH-20988 | 5967 | Standard | 4 | 1 | 0.0389 |

*(Sample/illustrative figures — see [Sample-Results](../Sample-Results/) for full mock output format.)*

## 9. Findings

- A measurable group of `Standard`-tier merchants showed risk activity consistent with `High` tier peers,
  including multiple high-severity flags — meaning tiering had under-classified genuinely risky merchants
- Mismatches clustered in specific MCC categories rather than being randomly scattered, pointing to a
  systemic gap in the onboarding tiering rules for those categories rather than isolated case-by-case errors
- Conversely, some `High` tier merchants showed minimal risk activity, suggesting monitoring capacity was
  being spent on merchants that didn't need it as urgently

## 10. Risk Assessment

| Factor | Assessment |
|---|---|
| Control integrity | Compromised for specific MCC categories — tiering rule gap, not random noise |
| Downstream impact | Multiple controls (payout hold, monitoring threshold) inherit the wrong tier |
| Monitoring efficiency | Reduced — capacity spent on over-tiered merchants while under-tiered ones go less watched |
| Recurrence likelihood | High — every new merchant onboarded in the affected categories inherits the same gap |

**Overall severity: High** — because this is a control calibration issue, it doesn't just affect the
merchants found in this investigation; it silently affects every future merchant onboarded under the same
rule.

## 11. Business Recommendation

1. **Immediate:** Manually re-tier the identified under-tiered merchants to `Elevated` or `High` pending
   review
2. **Structural:** Update onboarding tiering rules for the affected MCC categories so new merchants in those
   categories default to a stricter starting tier
3. **Ongoing:** Replace the periodic tiering review with the same automated quartile-based comparison used
   in this investigation, run monthly, so tier-vs-actual-risk mismatches are caught continuously instead of
   requiring an ad hoc investigation each time

This turns a one-time investigation into a repeatable monitoring check rather than a single fix.

## 12. Operational Impact

- Reallocates monitoring capacity toward merchants that actually carry elevated risk
- Fixes a systemic onboarding rule rather than only correcting the merchants found in this one investigation
- Gives Policy a recurring, data-backed check to validate tiering rules rather than relying on periodic
  manual review
- Reduces the lag between a merchant's real risk profile emerging and the business's monitoring response to it

## 13. Lessons Learned

- Validating a risk control requires measuring "ground truth" risk **independently** of the control itself —
  otherwise the analysis just confirms its own assumptions
- Comparing merchants within their own tier (rather than globally) is essential to catch tier-specific
  mis-calibration
- A one-time investigation is only valuable if it's converted into a recurring check — otherwise the same
  gap reopens as soon as new merchants are onboarded

## 14. Interview Questions

1. How did you avoid circular logic when validating a risk tier using data that might itself be influenced
   by that tier?
2. Why measure risk within each tier rather than across the whole merchant base?
3. What would you do if the mismatches had been scattered randomly instead of clustering by MCC?
4. How would you convince Policy to change onboarding rules based on this analysis?
5. How often should this kind of tiering validation be run, and why?

## 15. Interview Answers

**1. Avoiding circular logic?**
I deliberately built the risk-flag and chargeback-rate measures without referencing `risk_tier` at all in
their calculation — they measure actual observed outcomes independently, and the tier is only reintroduced
afterward for comparison. That keeps the "ground truth" clean.

**2. Why within-tier comparison?**
Because tiers are meant to represent different expected risk baselines. Comparing a `Standard` merchant
directly against `High` tier merchants would always make it look "lower risk" even if it's a clear outlier
within its own tier — which is the actual signal that matters for re-tiering.

**3. What if mismatches were scattered, not clustered?**
That would point to individual onboarding review errors rather than a systemic rule gap — the fix would
shift from "change the onboarding rule for a category" to "add a secondary manual review step for
borderline cases," since there wouldn't be a clean category-level pattern to correct at the rule level.

**4. Convincing Policy?**
By showing the mismatch is measurable and repeatable, not anecdotal — and by tying it to a concrete
downstream cost (under-monitoring merchants that already show high-severity flags), which makes the
business case about risk exposure, not just a process nitpick.

**5. How often to re-run this?**
Monthly is a reasonable cadence — frequent enough to catch onboarding rule drift before too many
merchants accumulate under a wrong tier, but not so frequent that it creates review fatigue for a check that
doesn't change dramatically week to week.

---
⬅️ [Back to Investigations Index](../README.md)
