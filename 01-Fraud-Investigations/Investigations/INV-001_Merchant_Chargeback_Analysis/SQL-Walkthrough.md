# SQL Walkthrough

⬅️ [Back to case index](./README.md)

- **`merchant_txn_volume`** establishes the transaction denominator per merchant — needed before a rate can
  mean anything.
- **`merchant_chargebacks`** / **`merchant_chargeback_totals`** roll up chargebacks to the same merchant grain.
- **`merchant_rates`** joins volume, chargebacks, and merchant attributes to compute a per-merchant chargeback
  rate.
- **`mcc_benchmark`** computes the average chargeback rate per merchant category, so a merchant is judged
  against peers in the same business type — not the entire merchant base.
- The final `SELECT` isolates merchants at **3x or more** their category's average chargeback rate — a
  threshold chosen to surface genuine outliers rather than normal variance.

⬅️ [Back to case index](./README.md)
