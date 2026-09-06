# Implementation Plan: [Feature / Fix / Refactor / Delivery Name]

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: [Draft / Awaiting Approval / Approved / In Progress / Complete]
- Scope Mode: [Surgical Fix / New Feature / Refactor / Documentation] - [Short boundary statement]
- Target Files: [List of primary files affected]

Notice: Update this plan in-place during the planning phase. Once approved by the user, switch live execution tracking to task.md and do not re-read this full document on subsequent coding turns.

---

## 1. Request Understanding & Goals
- Primary Objective: [Plain-English explanation of the intended outcome]
- Concrete Deliverables:
  1. [Observable deliverable]
  2. [Observable deliverable]
  3. [Documentation or verification deliverable]
- Explicit Out-of-Scope: [Systems, files, or behaviors this plan will NOT touch or change]

---

## 2. Current Findings & Technical Root Cause
| Observation / Evidence | Verified Root Cause / Technical Interpretation |
| --- | --- |
| [Log, file, test failure, or report] | [Technical explanation without speculation] |
| [Current architecture behavior] | [Why current logic fails or needs extension] |

---

## 3. Proposed File Changes & In-Place Logic
### [MODIFY / ADD / DELETE] path/to/file
- Primary Responsibility: [What this file is responsible for]
- Planned Change: [Exact methods, logic, contracts, or data structures to add or alter]
- Invariants to Preserve: [Working legacy behavior that must not break]

### [MODIFY / ADD / DELETE] path/to/secondary/file
- Primary Responsibility: [What this file is responsible for]
- Planned Change: [Exact methods, logic, contracts, or data structures to add or alter]
- Invariants to Preserve: [Working legacy behavior that must not break]

---

## 4. Step-by-Step Pseudocode & Implementation Sequence
1. Step 1 (Preparation): [Safe baseline, test fixtures, or interface stubs]
2. Step 2 (Core Logic): [Plain-English pseudocode of the primary algorithm or state change]
3. Step 3 (Integration): [Wiring components, UI adapters, or event channels]
4. Step 4 (Cleanup): [Refactoring, removing dead code, and memory optimization]

---

## 5. Acceptance Criteria & Verification Plan
### Automated Repository Checks
- [ ] [Targeted test suite, compilation check, or linter - Command and expected result]
- [ ] [Regression check ensuring unrelated systems remain functional]

### Manual / User-Owned Checks
- [ ] [Exact user workflow, visual, hardware, or target-device verification step]
- [ ] [Edge case check: cancellation, boundary value, or interrupted input]

---

## 6. Risks, Recovery & Rollback
- Risk: [Potential failure mode, performance hazard, or breaking side-effect]
- Mitigation / Rollback: [Step-by-step procedure to safely reverse or isolate the change]