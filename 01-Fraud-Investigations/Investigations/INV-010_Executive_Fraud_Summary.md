# INV-010 — Executive Fraud Summary

![Type](https://img.shields.io/badge/Type-Executive%20Reporting-blue) ![Severity](https://img.shields.io/badge/Severity-Strategic-purple)

**Purpose:** Roll up findings across investigations into a single executive/board-level fraud posture summary.
**Estimated reading time:** 7 minutes
⬅️ [Back to Investigations Index](../README.md)

---

## 1. Business Problem

Leadership and the board need a single, defensible view of NovaPay's fraud posture each quarter — covering
loss exposure, control gaps identified, remediation status, and regulatory/law-enforcement engagement —
without needing to read every individual investigation. Fraud operations needs a way to represent quarterly
work that connects tactical case findings to strategic risk posture.

## 2. Business Context

- NovaPay engages regularly with regulators (National Fraud Portal reporting) and law enforcement (SPF
  liaison) on fraud and scam matters
- Individual investigations (chargebacks, ATO, merchant risk, trend analysis) each produce findings and
  recommendations, but leadership needs these connected into one narrative of overall fraud posture and
  remediation progress
- Board and executive audiences need the summary framed around risk exposure and control maturity, not
  investigation mechanics

## 3. Fraud Indicators

This is a roll-up investigation — it consolidates indicators already established elsewhere rather than
introducing new detection logic:

- Total confirmed fraud loss exposure for the quarter, by fraud type
- Number and severity of control gaps identified (e.g. tiering gaps from INV-004, detection gaps from INV-002)
- Law enforcement case volume and outcomes
- Status of remediation actions recommended in prior investigations

## 4. Investigation Plan

1. Aggregate quarterly loss exposure across chargebacks and confirmed ATO cases
2. Summarize control gaps identified during the quarter and their remediation status
3. Summarize law enforcement case volume and outcomes for the quarter
4. Package the above into a structure suitable for executive/board consumption — headline figures first,
   detail available on request

## 5. Evidence Collected

| Evidence | Source | Relevance |
|---|---|---|
| Quarterly chargeback loss | `fact_chargebacks` | Core loss exposure figure |
| Confirmed ATO-linked transfer loss | `fact_transactions`, `dim_risk_flags` | Second loss category, distinct fraud type |
| Law enforcement case volume/outcomes | `fact_law_enforcement_cases` | Regulatory/LE engagement summary |
| Remediation status of prior investigation recommendations | Cross-referenced from INV-001, INV-002, INV-004 | Shows progress, not just problems |

## 6. SQL — Investigation

```sql
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
```

## 7. SQL Walkthrough

- **`quarterly_chargeback_loss`** and **`quarterly_ato_loss`** independently roll up the two largest fraud
  loss categories NovaPay tracks, kept separate because they have different root causes and different
  owning teams for remediation.
- **`quarterly_le_cases`** summarizes law enforcement engagement — case volume and favorable resolution rate
  — which is a distinct but related signal of fraud posture (how effectively the platform supports
  investigations once cases are escalated externally).
- The final query joins all three onto a single quarter grain, producing exactly the shape an executive
  summary slide needs: one row per quarter, headline numbers only.

## 8. Expected Results

| quarter | chargeback_count | chargeback_loss | ato_transaction_count | ato_loss | cases_opened | cases_resolved_favorably |
|---|---|---|---|---|---|---|
| 2026-Q2 | 1,240 | 186,500 | 38 | 71,200 | 22 | 17 |
| 2026-Q1 | 980 | 142,300 | 29 | 54,900 | 19 | 14 |

*(Sample/illustrative figures — see [Sample-Results](../Sample-Results/) for full mock output format.)*

## 9. Findings

- Chargeback loss remained the larger of the two loss categories by volume, but ATO-linked loss grew faster
  quarter-over-quarter, consistent with the detection gap identified in INV-002
- Law enforcement case resolution rate stayed consistently favorable, reflecting the value of the
  established SPF liaison relationship and structured escalation workflow
- Remediation actions from INV-001 and INV-004 were in progress but not yet fully reflected in the loss
  figures for the most recent quarter, since dashboard-based monitoring changes take a full cycle to show
  measurable impact

## 10. Risk Assessment

| Factor | Assessment |
|---|---|
| Overall loss trend | Chargeback loss largest by volume; ATO loss smaller but accelerating |
| Regulatory/LE posture | Strong — consistent favorable case resolution rate |
| Remediation maturity | In progress — recent fixes not yet fully reflected in the numbers |
| Board-level risk | Manageable if ATO remediation (INV-002) lands on schedule; would become a headline risk if it stalls |

**Overall severity: Strategic** — no single figure here is alarming in isolation, but the combination shapes
where leadership should focus attention and resourcing next quarter.

## 11. Business Recommendation

1. **Reporting cadence:** Adopt this summary format as the standing quarterly fraud posture report to
   leadership and the board
2. **Prioritization:** Given ATO loss is the faster-growing category, prioritize completing the INV-002
   remediation (step-up verification, cluster-device flagging) ahead of other in-progress items
3. **Stakeholder communication:** Continue highlighting the law enforcement resolution rate as a concrete,
   positive metric of the SPF liaison relationship's value when engaging regulators and leadership

## 12. Operational Impact

- Gives leadership a consistent, comparable quarterly view instead of ad hoc updates pulled together
  investigation by investigation
- Creates a clear line of sight from tactical investigation work (INV-001, INV-002, INV-004) to strategic
  reporting, making it easier to justify continued investment in remediation work
- Surfaces which remediation items are time-sensitive (ATO) versus lower-urgency, informing resourcing
  decisions for the next quarter

## 13. Lessons Learned

- Executive reporting is strongest when it's a genuine roll-up of validated investigation findings, not a
  separately-built narrative — it keeps the story consistent from case file to board slide
- Growth rate matters as much as absolute size when prioritizing which remediation item leadership should
  push hardest on
- Law enforcement outcomes are a legitimate and persuasive fraud posture metric, not just an operational
  detail — they belong in executive reporting alongside loss figures

## 14. Interview Questions

1. How do you decide what belongs in an executive summary versus what stays in the detailed investigation?
2. Why report chargeback loss and ATO loss separately instead of a single "total fraud loss" number?
3. How do you communicate an in-progress remediation without sounding like you're making excuses for the
   numbers?
4. How would you defend the law enforcement resolution rate as a meaningful metric, if challenged?
5. What would make you escalate an item out of the quarterly cadence and flag it immediately instead?

## 15. Interview Answers

**1. What belongs in the executive summary vs the detailed case?**
The executive summary carries headline numbers, direction of trend, and what leadership needs to decide or
approve. Investigation mechanics — SQL, specific merchant IDs, technical thresholds — stay in the underlying
case files, referenced but not repeated.

**2. Why separate chargeback and ATO loss instead of one total?**
They have different root causes, different owning remediation tracks, and different growth trajectories.
Combining them into one number would hide that ATO is the faster-growing, higher-urgency category even
though it's currently smaller in absolute terms.

**3. Communicating in-progress remediation honestly?**
By being specific about what's been shipped, what's in progress, and why the loss numbers haven't fully
moved yet — dashboard and monitoring changes take a full quarter to show up in loss trends, and saying that
plainly is more credible than implying an instant fix.

**4. Defending the law enforcement resolution rate as a metric?**
It reflects real operational quality — case documentation, evidence handling, and response time all
directly affect whether a case resolves favorably. It's not a vanity metric; it's a proxy for investigation
quality that regulators and law enforcement partners can independently verify.

**5. What would trigger an off-cycle escalation?**
A loss category accelerating sharply within a single quarter, a control gap with active, ongoing exploitation
(like an unpatched ATO vector), or a law enforcement or regulatory request that carries its own deadline —
none of those should wait for the next quarterly cycle.

---
⬅️ [Back to Investigations Index](../README.md)
