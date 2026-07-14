# Interview Answers

⬅️ [Back to case index](./README.md)

**1. Avoiding circular logic?**
I deliberately built the risk-flag and chargeback-rate measures without referencing `risk_tier` at all in
their calculation — they measure actual observed outcomes independently, and the tier is only reintroduced
afterward for comparison. That keeps the "ground truth" clean.

**2. Why within-tier comparison?**
Because tiers are meant to represent different expected risk baselines. Comparing a `Standard` merchant
directly against `High` tier merchants would always make it look "lower risk" even if it's a clear outlier
within its own tier — which is the actual signal that matters for re-tiering.

**3. What if mismatches were scattered, not clustered?**
That would point to individual onboarding review errors rather than a systemic rule gap — the fix would
shift from "change the onboarding rule for a category" to "add a secondary manual review step for
borderline cases," since there wouldn't be a clean category-level pattern to correct at the rule level.

**4. Convincing Policy?**
By showing the mismatch is measurable and repeatable, not anecdotal — and by tying it to a concrete
downstream cost (under-monitoring merchants that already show high-severity flags), which makes the
business case about risk exposure, not just a process nitpick.

**5. How often to re-run this?**
Monthly is a reasonable cadence — frequent enough to catch onboarding rule drift before too many
merchants accumulate under a wrong tier, but not so frequent that it creates review fatigue for a check that
doesn't change dramatically week to week.

⬅️ [Back to case index](./README.md)
