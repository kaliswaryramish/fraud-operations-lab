# 🛡️ 01 — Fraud Investigations

![Fraud Ops](https://img.shields.io/badge/Focus-Fraud%20Investigations-red)
![Company](https://img.shields.io/badge/Fictional%20Company-NovaPay-blue)
![Status](https://img.shields.io/badge/Status-Active%20Portfolio-brightgreen)
![Experience](https://img.shields.io/badge/Experience-7%2B%20Years-orange)

> **Purpose:** This folder documents real fraud investigation case work, reconstructed against a fictional
> fintech company (**NovaPay**) to protect confidentiality, while preserving the investigative thinking,
> SQL analysis, and business judgment behind each case.
>
> ⏱️ **Estimated reading time (full folder):** ~45–60 minutes

## 📌 Read Me First

> [!IMPORTANT]
> Every case in this folder is built from real professional experience in fraud operations, trust & safety,
> and financial crime prevention. Company name, data, and figures are fictionalized. Investigation logic,
> SQL patterns, and business reasoning reflect actual working methods.

## 🗂️ Contents

| Document | What it covers |
|---|---|
| [Executive-Summary.md](./Executive-Summary.md) | One-page overview of this portfolio's purpose and scope |
| [Business-Overview.md](./Business-Overview.md) | Why fraud investigation matters to a payments business |
| [NovaPay-Overview.md](./NovaPay-Overview.md) | The fictional company these investigations are set inside |
| [Database-Schema.md](./Database-Schema.md) | NovaPay's fraud/risk data model |
| [Data-Dictionary.md](./Data-Dictionary.md) | Field-level definitions used across all SQL |
| [Investigation-Methodology.md](./Investigation-Methodology.md) | The fixed sequence every investigation follows |
| [SQL-Style-Guide.md](./SQL-Style-Guide.md) | How SQL is written and commented in this repo |
| [Interview-Guide.md](./Interview-Guide.md) | How to use this repo in interviews |
| [Business-Recommendations.md](./Business-Recommendations.md) | Cross-investigation themes in recommendations |

## 🔍 Investigations

| ID | Title | Focus |
|---|---|---|
| [INV-001](./Investigations/INV-001_Merchant_Chargeback_Analysis/) | Merchant Chargeback Analysis | Merchant-level chargeback spikes and root cause |
| [INV-002](./Investigations/INV-002_Account_Takeover_Investigation/) | Account Takeover Investigation | Credential-based ATO detection and response |
| [INV-004](./Investigations/INV-004_High_Risk_Merchant_Investigation/) | High-Risk Merchant Investigation | Merchant risk tiering and onboarding controls |
| [INV-009](./Investigations/INV-009_Fraud_Trend_Analysis/) | Fraud Trend Analysis | Cross-market fraud trend reporting to leadership |
| [INV-010](./Investigations/INV-010_Executive_Fraud_Summary/) | Executive Fraud Summary | Board/exec-level fraud posture summary |

> [!NOTE]
> This is the first release of five investigations. Additional investigation types will be added as the
> portfolio expands.

## 🧭 How to Navigate

Each investigation folder is a **self-contained case file** — you can open any single one and understand
the business problem, the analysis, and the outcome without reading the others. Start with
[INV-010](./Investigations/INV-010_Executive_Fraud_Summary/) if you want the fastest overview, or
[INV-001](./Investigations/INV-001_Merchant_Chargeback_Analysis/) for the most detailed walkthrough of the
investigative method.

⬅️ Back to repository root
