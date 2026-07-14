# Interview Answers

⬅️ [Back to case index](./README.md)

**1. Why rank by percentage change, not volume?**
Absolute volume favors the largest markets by default, which can hide a smaller market where fraud is
accelerating fastest. Percentage change surfaces direction of travel, which is what actually determines
where investigation capacity should go next.

**2. Presenting to non-technical leadership?**
Lead with the business framing — which market, what direction, what financial exposure — before any
supporting numbers. Leadership needs "market X is accelerating and here's the likely driver," not a table of
raw SQL output.

**3. Conflicting metrics in the same market?**
That's a signal worth calling out explicitly rather than resolving artificially — I'd present both metrics
and note that different fraud types are moving independently, which is itself useful information about
where controls are and aren't working.

**4. Avoiding report fatigue?**
Keep the recurring report focused on what changed and why it matters, not a full re-explanation of every
metric every month — and reserve deep-dive investigation write-ups (like INV-001, INV-002) for when a trend
actually crosses a threshold worth acting on.

**5. Scaling to 5 new markets?**
The market-partitioned window functions in this query scale naturally to more markets without rewriting
logic — the bigger consideration would be whether new markets have enough transaction history yet for
month-over-month comparisons to be statistically meaningful, versus just noise from small sample sizes.

⬅️ [Back to case index](./README.md)
