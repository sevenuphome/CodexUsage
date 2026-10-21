---
status: ready
priority: p2
issue_id: "002"
tags: [macos, notifications, reliability]
dependencies: []
---

# Retry a failed daily notification enqueue

## Problem Statement

The tracker marks the daily threshold as alerted before `UNUserNotificationCenter.add` succeeds. A transient enqueue failure therefore suppresses every later attempt for that day.

## Findings

- `App/DailyUsageTracker.swift:57` persists the alerted flag when the threshold is crossed.
- `App/DailyUsageAlert.swift` logs an enqueue failure but cannot restore retry eligibility.
- Authorization denial and system suppression are distinct from a transient enqueue failure.

## Proposed Solutions

Separate threshold detection from delivery acknowledgement. Keep the alert pending until the notification center accepts the request, and clear pending state after a failed attempt so a bounded later refresh can retry.

## Recommended Action

Add explicit pending, delivered, and retry state with deterministic tests for authorization denial, asynchronous success, and enqueue failure.

## Acceptance Criteria

- [ ] A failed enqueue does not permanently consume the day's alert.
- [ ] Successful enqueueing still produces at most one notification per day.
- [ ] Retries are bounded and cannot fire every minute indefinitely.
- [ ] Authorization and callback failure tests pass.

## Work Log

### 2026-08-20 - Review discovery

- Identified during reliability review.
- Left out of autofix because it changes the persisted notification state contract.
