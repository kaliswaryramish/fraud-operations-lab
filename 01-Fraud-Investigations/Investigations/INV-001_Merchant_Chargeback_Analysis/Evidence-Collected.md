# Evidence Collected

⬅️ [Back to case index](./README.md)

| Evidence | Source | Relevance |
|---|---|---|
| Merchant-level chargeback rate, trailing 90 days | `fact_chargebacks`, `fact_transactions` | Establishes which merchants are outliers |
| Chargeback reason code distribution | `fact_chargebacks` | Distinguishes fraud disputes from service disputes |
| Merchant onboarding dates and risk tier | `dim_merchants` | Checks whether flagged merchants are recently onboarded / under-tiered |
| Transaction value trend per merchant | `fact_transactions` | Confirms unusual ticket-size behavior before the spike |

⬅️ [Back to case index](./README.md)
