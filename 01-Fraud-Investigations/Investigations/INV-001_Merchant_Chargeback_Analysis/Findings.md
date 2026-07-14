# Findings

⬅️ [Back to case index](./README.md)

- Chargebacks were **not** evenly distributed across the merchant base — 3 merchants accounted for a
  disproportionate share of the overall increase
- All 3 flagged merchants were onboarded within the same 6-week window and shared the same `Standard`
  risk tier, despite one being in electronics (a category with historically higher fraud exposure)
- Chargeback reason codes for these merchants were concentrated in `fraud_no_auth`, not `product_not_received`
  — consistent with card-not-present fraud rather than genuine service disputes
- Existing risk tiering had not flagged these merchants because tiering is reviewed periodically rather than
  continuously, and their onboarding volume looked unremarkable at the time

⬅️ [Back to case index](./README.md)
