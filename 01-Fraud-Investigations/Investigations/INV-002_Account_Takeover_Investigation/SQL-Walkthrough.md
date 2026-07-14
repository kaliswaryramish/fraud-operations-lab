# SQL Walkthrough

⬅️ [Back to case index](./README.md)

- **`new_device_logins`** finds logins where the device's `first_seen_date` matches the login date — i.e.
  the very first login from that device on that account.
- **`suspicious_transfers`** joins those logins to P2P transfers occurring within a **2-hour window** — a
  window chosen to capture rapid cashout while excluding coincidental unrelated transfers days later.
- **`shared_devices`** looks for devices used as a "new device" across more than one distinct account —
  a strong signal of a single actor running multiple takeovers from the same device or emulator.
- The final query labels each suspicious transfer by whether it came from a cluster device, which
  materially changes the urgency of the response.

⬅️ [Back to case index](./README.md)
