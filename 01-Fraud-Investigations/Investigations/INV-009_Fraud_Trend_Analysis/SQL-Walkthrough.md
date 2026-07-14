# SQL Walkthrough

⬅️ [Back to case index](./README.md)

- **`monthly_chargebacks`** rolls chargebacks up to market-month grain — the base unit for trend analysis.
- **`monthly_flags`** does the same for risk flags, unioning user-level and merchant-level flags since both
  share the same `dim_risk_flags` table but join to different dimension tables.
- **`chargeback_trend`** uses `LAG()` to compare each market-month against its own prior month, producing a
  month-over-month percentage change — the core metric leadership actually needs, since raw counts don't
  convey direction of travel.
- The final query surfaces the **latest month**, ranked by steepest increase — designed to answer "where is
  fraud accelerating right now," not just "where is fraud largest historically."

⬅️ [Back to case index](./README.md)
