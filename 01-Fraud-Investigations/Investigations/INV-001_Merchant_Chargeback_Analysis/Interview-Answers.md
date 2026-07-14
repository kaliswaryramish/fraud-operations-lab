# Interview Answers

⬅️ [Back to case index](./README.md)

**1. Why benchmark against category average instead of overall merchant base?**
Different merchant categories carry structurally different chargeback baselines — electronics and
high-ticket goods naturally run higher than grocery or bill payments. Comparing against the whole merchant
base would either miss real outliers in low-baseline categories or over-flag normal merchants in
high-baseline categories.

**2. How did you distinguish fraud from a bad month?**
Reason code composition. A merchant having a bad month tends to see `product_not_received` or
`item_not_as_described` disputes. A concentration in `fraud_no_auth` is a much stronger signal of
card-not-present fraud, either merchant-side or via compromised cards being tested through that merchant.

**3. What if they'd already been in stricter risk tiers?**
The recommendation would shift from "fix the tiering gap" to "the existing tier's controls aren't catching
this pattern" — meaning the fix would target monitoring thresholds within that tier rather than tier
assignment itself.

**4. Balancing false positives vs missed fraud?**
The 3x-category-average threshold was set deliberately conservative to avoid flooding analysts with noise;
it's tuned to catch clear outliers first, with room to lower the threshold once the team has capacity to
review a larger flagged queue.

**5. Where would this break down at scale?**
At significantly higher merchant volume, MCC-level benchmarking alone becomes too coarse — you'd want to add
sub-category or geographic benchmarking, and likely move from a threshold-based flag to a statistical
outlier model (e.g. z-score based) to keep pace with a larger, more varied merchant base.

⬅️ [Back to case index](./README.md)
