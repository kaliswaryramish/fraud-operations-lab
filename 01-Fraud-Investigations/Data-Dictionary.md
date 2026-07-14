# Data Dictionary

**Purpose:** Field-level reference for every table used in this repo's SQL.
**Estimated reading time:** 4 minutes
⬅️ [Back to README](./README.md)

## `fact_transactions`

| Field | Type | Notes |
|---|---|---|
| transaction_id | string | Primary key |
| user_id | string | FK to dim_users |
| merchant_id | string | FK to dim_merchants (null for P2P) |
| device_id | string | FK to dim_devices |
| amount | decimal | Transaction value |
| currency | string | ISO currency code |
| transaction_type | string | wallet_topup, p2p_transfer, qr_payment, card_payment, bill_payment |
| channel | string | app, web, api |
| status | string | completed, failed, reversed, disputed |
| created_at | datetime | Transaction timestamp |
| market | string | Country/market code |

## `fact_chargebacks`

| Field | Type | Notes |
|---|---|---|
| chargeback_id | string | Primary key |
| transaction_id | string | FK to fact_transactions |
| reason_code | string | e.g. fraud_no_auth, product_not_received, duplicate_charge |
| filed_date | date | Date chargeback was filed |
| status | string | open, under_review, won, lost |
| amount | decimal | Disputed amount |

## `fact_login_events`

| Field | Type | Notes |
|---|---|---|
| login_id | string | Primary key |
| user_id | string | FK to dim_users |
| device_id | string | FK to dim_devices |
| ip_country | string | Country derived from login IP |
| login_timestamp | datetime | Login attempt time |
| success_flag | boolean | Whether login succeeded |

## `dim_risk_flags`

| Field | Type | Notes |
|---|---|---|
| flag_id | string | Primary key |
| entity_id | string | user_id or merchant_id |
| entity_type | string | user, merchant |
| flag_type | string | e.g. velocity_spike, device_anomaly, chargeback_spike |
| flag_date | date | Date flag was raised |
| severity | string | low, medium, high, critical |

## `fact_kyc_events` / `fact_law_enforcement_cases` / `dim_users` / `dim_merchants` / `dim_devices`

See [Database-Schema.md](./Database-Schema.md) for full field lists — these tables are referenced less
frequently and are documented inline within each investigation's SQL comments.

⬅️ [Back to README](./README.md)
