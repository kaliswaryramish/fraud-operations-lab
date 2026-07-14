# Evidence Collected

⬅️ [Back to case index](./README.md)

| Evidence | Source | Relevance |
|---|---|---|
| Current risk tier per merchant | `dim_merchants` | The control being validated |
| Risk flags raised per merchant | `dim_risk_flags` | Independent signal of actual risk activity |
| Chargeback rate per merchant | `fact_chargebacks`, `fact_transactions` | Independent signal of actual fraud outcomes |
| MCC category per merchant | `dim_merchants` | Tests whether mismatches are systemic by category |

⬅️ [Back to case index](./README.md)
