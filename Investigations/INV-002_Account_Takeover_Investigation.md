# INV-002 — Account Takeover Investigation

![Type](https://img.shields.io/badge/Type-Account%20Security-blue) ![Severity](https://img.shields.io/badge/Severity-Critical-red)

**Purpose:** Investigate a cluster of accounts showing signs of credential-based takeover.
**Estimated reading time:** 8 minutes
⬅️ [Back to Investigations Index](../README.md)

---

## 1. Business Problem

Customer support has seen a rise in users reporting unauthorized wallet transfers immediately after
reporting they couldn't log in. This pattern — login failure reports followed by unauthorized outbound
transfers — suggests possible account takeover (ATO) via compromised credentials, not simple user error.

The business needs to know: how widespread is this, is it concentrated on shared infrastructure (devices/IPs),
and can it be interrupted before funds leave the platform?

## 2. Business Context

- NovaPay allows login from any registered device without mandatory step-up verification for P2P transfers
  under a certain threshold
- Password reset flows are self-service and do not currently trigger a transfer cool-down period
- Device fingerprinting data exists (`dim_devices`, `fact_login_events`) but has not previously been used to
  cross-reference support tickets against login/transfer sequences

## 3. Fraud Indicators

- A successful login from a **new, previously unseen device** for the account
- That login followed shortly by a **large P2P transfer** to a new recipient
- Multiple victim accounts sharing logins from the **same device_id or IP** in a short window (suggests a
  single actor operating many compromised accounts)
- A support ticket about login trouble filed **before** the unauthorized transfer, indicating the legitimate
  user was already locked out

## 4. Investigation Plan

1. Identify accounts with a successful login from a new device followed by an outbound P2P transfer within
   a short window
2. Cross-reference those accounts against recent KYC/login support tickets
3. Check whether flagged accounts' new-device logins share a device_id or IP cluster with each other
4. Quantify total funds moved through this pattern to size the exposure
5. Assess whether existing risk flags (`dim_risk_flags`) already caught any of these accounts

## 5. Evidence Collected

| Evidence | Source | Relevance |
|---|---|---|
| Login events per account, with device and success flag | `fact_login_events` | Establishes new-device logins |
| First-seen date per device | `dim_devices` | Confirms whether a device is genuinely new to the account |
| Transfers following each new-device login | `fact_transactions` | Confirms the takeover-to-cashout sequence |
| Device/IP overlap across flagged accounts | `fact_login_events`, `dim_devices` | Tests for a single actor operating multiple takeovers |

## 6. SQL — Investigation

```sql
-- ============================================================
-- INV-002: Account Takeover Investigation
-- Purpose: Identify accounts where a new-device login was
--          immediately followed by an outbound P2P transfer,
--          and check for shared device/IP clusters across
--          multiple victim accounts.
-- ============================================================

-- Step 1: Flag logins from devices new to that specific account
WITH new_device_logins AS (
    SELECT
        l.user_id,
        l.device_id,
        l.ip_country,
        l.login_timestamp
    FROM fact_login_events l
    INNER JOIN dim_devices d ON l.device_id = d.device_id
    WHERE l.success_flag = TRUE
      AND d.first_seen_date >= CURRENT_DATE - INTERVAL '30 days'
      AND l.login_timestamp::date = d.first_seen_date
),

-- Step 2: Find outbound P2P transfers within 2 hours of a new-device login
suspicious_transfers AS (
    SELECT
        nd.user_id,
        nd.device_id,
        nd.login_timestamp,
        t.transaction_id,
        t.amount,
        t.created_at
    FROM new_device_logins nd
    INNER JOIN fact_transactions t
        ON nd.user_id = t.user_id
       AND t.transaction_type = 'p2p_transfer'
       AND t.created_at BETWEEN nd.login_timestamp AND nd.login_timestamp + INTERVAL '2 hours'
),

-- Step 3: Identify devices/IPs shared across multiple distinct victim accounts
shared_devices AS (
    SELECT
        device_id,
        COUNT(DISTINCT user_id) AS distinct_accounts_used
    FROM new_device_logins
    GROUP BY device_id
    HAVING COUNT(DISTINCT user_id) > 1
)

-- Step 4: Final output — suspicious transfers, flagged where the device is a shared/cluster device
SELECT
    st.user_id,
    st.device_id,
    st.login_timestamp,
    st.transaction_id,
    st.amount,
    st.created_at,
    CASE
        WHEN sd.device_id IS NOT NULL THEN 'Cluster device (multi-account)'
        ELSE 'Single-account new device'
    END AS device_cluster_flag
FROM suspicious_transfers st
LEFT JOIN shared_devices sd ON st.device_id = sd.device_id
ORDER BY st.amount DESC;
```

## 7. SQL Walkthrough

- **`new_device_logins`** finds logins where the device's `first_seen_date` matches the login date — i.e.
  the very first login from that device on that account.
- **`suspicious_transfers`** joins those logins to P2P transfers occurring within a **2-hour window** — a
  window chosen to capture rapid cashout while excluding coincidental unrelated transfers days later.
- **`shared_devices`** looks for devices used as a "new device" across more than one distinct account —
  a strong signal of a single actor running multiple takeovers from the same device or emulator.
- The final query labels each suspicious transfer by whether it came from a cluster device, which
  materially changes the urgency of the response.

## 8. Expected Results

| user_id | device_id | amount | device_cluster_flag |
|---|---|---|---|
| USR-88213 | DEV-40021 | 1,850.00 | Cluster device (multi-account) |
| USR-77104 | DEV-40021 | 2,200.00 | Cluster device (multi-account) |
| USR-91002 | DEV-51190 | 640.00 | Single-account new device |

*(Sample/illustrative figures — see [Sample-Results](../Sample-Results/) for full mock output format.)*

## 9. Findings

- A clear subset of accounts showed the exact takeover signature: new-device login → rapid P2P transfer
- One device_id was linked to new-device logins on **multiple distinct victim accounts** within the same
  week, strongly suggesting a single actor using stolen credentials across several accounts from one device
- Support tickets for login trouble were filed on the same day as the takeover for most flagged accounts,
  confirming victims were locked out before the unauthorized transfer occurred
- None of the flagged accounts had been caught by existing risk flags — the current flagging logic does not
  cross-reference login device recency against transfer timing

## 10. Risk Assessment

| Factor | Assessment |
|---|---|
| User harm | Critical — direct financial loss to victims, trust impact |
| Financial exposure | High for cluster-device cases (multiple accounts, same actor) |
| Detection gap | Confirmed — no existing flag combines device recency with transfer timing |
| Recurrence likelihood | High — the cluster device pattern suggests an active, repeatable attack method |

**Overall severity: Critical** — this pattern directly moves funds out of victim accounts and shows evidence
of a repeatable, multi-account attack method still active.

## 11. Business Recommendation

1. **Immediate:** Freeze outbound transfers on accounts matching the cluster-device signature and initiate
   manual account recovery for affected users
2. **Short-term:** Introduce a mandatory step-up verification (e.g. OTP) for any P2P transfer occurring
   within a short window of a first-time login from a new device
3. **Structural:** Add "new device + rapid transfer" as a standing automated risk flag, with cluster-device
   reuse escalated automatically to a higher severity tier

This keeps friction targeted — only new-device-plus-rapid-transfer sequences trigger step-up verification,
rather than adding friction to all logins.

## 12. Operational Impact

- Closes a detection gap that previously let takeover-driven transfers go unflagged entirely
- Step-up verification is scoped narrowly (new device + rapid transfer) to avoid broad user friction
- Gives analysts a clear escalation signal (cluster device reuse) to prioritize the highest-risk cases first
- Reduces average time between takeover and detection, shrinking the window in which funds can be moved out

## 13. Lessons Learned

- Device recency alone isn't a strong fraud signal — it's the **combination** with rapid outbound transfer
  timing that makes it meaningful
- Cross-referencing support tickets against transaction timing added confirmation that wouldn't have been
  visible from transaction data alone
- Device/IP clustering across accounts is a high-value signal that should be a standing check in future
  account-security investigations, not a one-off analysis

## 14. Interview Questions

1. Why did you use a 2-hour window between login and transfer, and how would you validate that window?
2. How do you tell the difference between a legitimate user on a new phone and account takeover?
3. What would you do if step-up verification introduced too much friction for legitimate new-device users?
4. How did the support ticket data change your confidence in the finding?
5. If the cluster device belonged to a NAT'd corporate network instead of a fraud ring, how would that
   change your analysis?

## 15. Interview Answers

**1. Why a 2-hour window?**
It's tight enough to capture a rapid cashout attempt (the attacker's goal is to move funds before the
legitimate user regains access) while wide enough to not miss real cases due to minor timing variance. I'd
validate it by checking the actual time distribution between login and transfer across confirmed takeover
cases and adjusting the window to match where the real signal clusters.

**2. Legitimate new device vs takeover?**
The differentiator isn't the new device alone — it's new device **plus** an unusually rapid, often
higher-value transfer to a recipient the account hasn't paid before. Legitimate users on new phones don't
typically follow their first login with an immediate large transfer to a new payee.

**3. What if step-up verification adds too much friction?**
I'd narrow the trigger further — for example, only step-up when the transfer amount also exceeds the
account's historical average, rather than triggering on every new-device-plus-transfer combination
regardless of size.

**4. How did support tickets change confidence?**
They confirmed the mechanism, not just the pattern — the victim being locked out *before* the transfer rules
out the possibility that the account owner made the transfer themselves and forgot.

**5. What if the cluster device was a corporate NAT?**
That would be an important false-positive path — shared corporate IPs or NAT'd networks could produce the
same "multiple accounts, same device_id/IP" signal without any fraud involved. I'd add a check for known
corporate IP ranges or ISP-level NAT before treating device clustering as a standalone fraud signal.

---
⬅️ [Back to Investigations Index](../README.md)
