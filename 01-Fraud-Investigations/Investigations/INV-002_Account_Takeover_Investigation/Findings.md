# Findings

⬅️ [Back to case index](./README.md)

- A clear subset of accounts showed the exact takeover signature: new-device login → rapid P2P transfer
- One device_id was linked to new-device logins on **multiple distinct victim accounts** within the same
  week, strongly suggesting a single actor using stolen credentials across several accounts from one device
- Support tickets for login trouble were filed on the same day as the takeover for most flagged accounts,
  confirming victims were locked out before the unauthorized transfer occurred
- None of the flagged accounts had been caught by existing risk flags — the current flagging logic does not
  cross-reference login device recency against transfer timing

⬅️ [Back to case index](./README.md)
