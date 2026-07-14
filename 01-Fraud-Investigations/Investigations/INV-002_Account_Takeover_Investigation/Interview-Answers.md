# Interview Answers

⬅️ [Back to case index](./README.md)

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

⬅️ [Back to case index](./README.md)
