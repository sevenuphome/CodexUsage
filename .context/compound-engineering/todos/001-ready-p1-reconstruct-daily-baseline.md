---
status: ready
priority: p1
issue_id: "001"
tags: [macos, usage, notifications, persistence]
dependencies: []
---

# Reconstruct usage consumed before app launch

## Problem Statement

The first sample observed on a local day becomes the baseline. If Codex Usage starts after usage has already increased by 20 percentage points that day, it will not alert for that earlier usage.

## Findings

- `App/DailyUsageTracker.swift:26` resets the accumulated daily increase to zero on the first observation for a new day.
- Session logs contain earlier rate-limit snapshots that could establish a local-midnight baseline.
- The desired attribution across missed midnight samples needs an explicit rule.

## Proposed Solutions

Derive the current day's baseline from session snapshots at or immediately before local midnight, then feed the reconstructed daily increase into the tracker.

## Recommended Action

Extend the session reader to return the weekly meter history needed to reconstruct the current local day's increase, including a weekly reset within the day.

## Acceptance Criteria

- [ ] Starting the app after 20 percentage points were already consumed triggers the daily alert.
- [ ] Usage before local midnight is not counted toward the new day.
- [ ] A weekly reset during the day preserves both pre-reset and post-reset usage.
- [ ] Unit and integration tests pass.

## Work Log

### 2026-08-20 - Review discovery

- Identified during adversarial and reliability review of the initial daily-alert implementation.
- Left out of the safe autofix pass because daily attribution requires a product decision and session-history work.
