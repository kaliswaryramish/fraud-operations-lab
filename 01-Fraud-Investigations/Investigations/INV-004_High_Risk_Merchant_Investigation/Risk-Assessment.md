# Risk Assessment

⬅️ [Back to case index](./README.md)

| Factor | Assessment |
|---|---|
| Control integrity | Compromised for specific MCC categories — tiering rule gap, not random noise |
| Downstream impact | Multiple controls (payout hold, monitoring threshold) inherit the wrong tier |
| Monitoring efficiency | Reduced — capacity spent on over-tiered merchants while under-tiered ones go less watched |
| Recurrence likelihood | High — every new merchant onboarded in the affected categories inherits the same gap |

**Overall severity: High** — because this is a control calibration issue, it doesn't just affect the
merchants found in this investigation; it silently affects every future merchant onboarded under the same
rule.

⬅️ [Back to case index](./README.md)
