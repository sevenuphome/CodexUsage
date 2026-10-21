---
status: ready
priority: p1
issue_id: "003"
tags: [usage, rate-limits, persistence, edge-case]
dependencies: []
---

# Preserve reset metadata across incomplete samples

## Problem Statement

A same-day sample without `resetsAt` clears the last known reset timestamp. If the next complete sample belongs to a new weekly window, rollover detection cannot count its post-reset usage.

## Findings

- `App/DailyUsageTracker.swift:54` removes the saved reset timestamp whenever `resetsAt` is nil.
- Correctness, reliability, and adversarial reviewers independently identified the present-to-nil-to-new-reset sequence.

## Proposed Solutions

Retain the last known non-nil reset timestamp during an existing day. Only clear missing reset metadata when establishing a new day's baseline.

## Recommended Action

Preserve the timestamp in `record`, keep the current new-day behavior explicit, and add a present-to-nil-to-new-reset regression test.

## Acceptance Criteria

- [ ] A temporary nil `resetsAt` does not erase the previous reset boundary.
- [ ] A later weekly rollover counts post-reset usage correctly.
- [ ] Existing decrease-without-reset behavior remains unchanged.
- [ ] Tracker tests pass.

## Work Log

### 2026-08-20 - Review discovery

- Identified by correctness, reliability, and adversarial review.
- Routed as residual work after disagreement between safe-auto and manual classifications.
