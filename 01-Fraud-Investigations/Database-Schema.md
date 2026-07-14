# Database Schema

**Purpose:** Define NovaPay's fraud/risk data model used across all investigation SQL.
**Estimated reading time:** 5 minutes
⬅️ [Back to README](./README.md)

## Entity Relationship Diagram

```mermaid
erDiagram
    dim_users ||--o{ fact_transactions : makes
    dim_users ||--o{ dim_devices : uses
    dim_users ||--o{ fact_login_events : logs_in_via
    dim_users ||--o{ fact_kyc_events : undergoes
    dim_users ||--o{ dim_risk_flags : flagged_by
    dim_merchants ||--o{ fact_transactions : receives
    dim_merchants ||--o{ dim_risk_flags : flagged_by
    fact_transactions ||--o{ fact_chargebacks : disputed_by
    dim_devices ||--o{ fact_login_events : used_in
    dim_users ||--o{ fact_law_enforcement_cases : subject_of

    dim_users {
        string user_id PK
        string full_name
        string email
        string market
        string kyc_status
        date registration_date
    }
    dim_merchants {
        string merchant_id PK
        string merchant_name
        string mcc_code
        string risk_tier
        string market
        date onboarding_date
    }
    dim_devices {
        string device_id PK
        string user_id FK
        string device_type
        date first_seen_date
        date last_seen_date
    }
    fact_transactions {
        string transaction_id PK
        string user_id FK
        string merchant_id FK
        string device_id FK
        decimal amount
        string currency
        string transaction_type
        string channel
        string status
        datetime created_at
        string market
    }
    fact_chargebacks {
        string chargeback_id PK
        string transaction_id FK
        string reason_code
        date filed_date
        string status
        decimal amount
    }
    fact_login_events {
        string login_id PK
        string user_id FK
        string device_id FK
        string ip_country
        datetime login_timestamp
        boolean success_flag
    }
    fact_kyc_events {
        string kyc_id PK
        string user_id FK
        string event_type
        date event_date
        string result
    }
    dim_risk_flags {
        string flag_id PK
        string entity_id FK
        string entity_type
        string flag_type
        date flag_date
        string severity
    }
    fact_law_enforcement_cases {
        string case_id PK
        string user_id FK
        string agency
        string case_type
        date opened_date
        date closed_date
        string outcome
    }
```

## Table Summary

| Table | Grain | Used in |
|---|---|---|
| `dim_users` | 1 row per user | All investigations |
| `dim_merchants` | 1 row per merchant | INV-001, INV-004 |
| `dim_devices` | 1 row per device | INV-002 |
| `fact_transactions` | 1 row per transaction | All investigations |
| `fact_chargebacks` | 1 row per chargeback | INV-001, INV-009 |
| `fact_login_events` | 1 row per login attempt | INV-002 |
| `fact_kyc_events` | 1 row per KYC check | INV-002, INV-010 |
| `dim_risk_flags` | 1 row per flag raised | INV-002, INV-004, INV-009 |
| `fact_law_enforcement_cases` | 1 row per LE case | INV-010 |

⬅️ [Back to README](./README.md)
