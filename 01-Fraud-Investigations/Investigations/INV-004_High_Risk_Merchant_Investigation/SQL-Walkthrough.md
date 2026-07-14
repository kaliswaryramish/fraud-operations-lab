# SQL Walkthrough

⬅️ [Back to case index](./README.md)

- **`merchant_flags`** and **`merchant_chargeback_rate`** independently measure actual observed risk,
  deliberately not referencing `risk_tier` at all — this keeps the "ground truth" measurement separate from
  the control being validated.
- **`merchant_risk_profile`** brings the assigned tier back together with the independent risk signals.
- **`ranked`** uses `NTILE(4)` **within each tier** (not globally) to find merchants that are outliers
  relative to their own tier peers — a `Standard` merchant in the top quartile of its own tier is a stronger
  signal than comparing it against `High` tier merchants directly.
- The final filter narrows to `Standard`-tier merchants with both top-quartile chargeback rate and at least
  one high-severity flag — reducing false positives from chargeback rate alone.

⬅️ [Back to case index](./README.md)
