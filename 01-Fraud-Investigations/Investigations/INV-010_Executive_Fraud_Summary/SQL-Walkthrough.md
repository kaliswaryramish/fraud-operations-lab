# SQL Walkthrough

⬅️ [Back to case index](./README.md)

- **`quarterly_chargeback_loss`** and **`quarterly_ato_loss`** independently roll up the two largest fraud
  loss categories NovaPay tracks, kept separate because they have different root causes and different
  owning teams for remediation.
- **`quarterly_le_cases`** summarizes law enforcement engagement — case volume and favorable resolution rate
  — which is a distinct but related signal of fraud posture (how effectively the platform supports
  investigations once cases are escalated externally).
- The final query joins all three onto a single quarter grain, producing exactly the shape an executive
  summary slide needs: one row per quarter, headline numbers only.

⬅️ [Back to case index](./README.md)
