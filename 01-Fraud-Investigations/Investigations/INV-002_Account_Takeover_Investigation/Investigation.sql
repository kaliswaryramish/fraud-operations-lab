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
