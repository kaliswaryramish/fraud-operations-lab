# Evidence Collected

⬅️ [Back to case index](./README.md)

| Evidence | Source | Relevance |
|---|---|---|
| Login events per account, with device and success flag | `fact_login_events` | Establishes new-device logins |
| First-seen date per device | `dim_devices` | Confirms whether a device is genuinely new to the account |
| Transfers following each new-device login | `fact_transactions` | Confirms the takeover-to-cashout sequence |
| Device/IP overlap across flagged accounts | `fact_login_events`, `dim_devices` | Tests for a single actor operating multiple takeovers |

⬅️ [Back to case index](./README.md)
