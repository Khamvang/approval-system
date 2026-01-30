# PR: feat(approvals): add Approvals page + Approval Center with resizable three-column layout

## Summary
Adds a new `Approvals` page and an Approval Center modeled after the Lark UI. Implements a 3-column layout (left: sections & apps, middle: cases, right: case details) with draggable dividers, selectable text across headers/body, and a Lark-style action footer (Approve, Reject, Group Chat, CC, Transfer, Add Approver, Send Back). Adds route `/approvals` and keeps the left sidebar visible on wide screens.

## Files changed / added
- `lib/screens/approvals_page.dart` — NEW / main implementation (UI, sample data, resizable panels, selectable text, action footer with placeholder handlers).
- `lib/main.dart` — route registration for `/approvals`.
- `lib/screens/home_page.dart` — navigation updated to link to the new page.

## Key features
- New `Approvals` page with 3 sub-tabs: Submit Request, Approval Center, Data Management.
- Approval Center: left sections/apps, middle list of cases, right details pane.
- Draggable vertical dividers to resize left / middle / right columns.
- Action footer in details pane with Approve / Reject and additional actions (placeholders).
- All important header and body text replaced with `SelectableText` so users can copy text.
- Preserves existing profile menu / session behavior from `HomePage`.
- Sample data only — backend wiring and approve/reject flows are placeholders.

## How to test locally
1. Ensure Flutter dependencies:
```bash
flutter pub get
```
2. Run app (desktop/web):
```bash
flutter run
# or
flutter run -d chrome
```
3. In the app: open the left nav → click **Approvals** → open the **Approval Center** tab.
4. Verify:
- You can drag the vertical dividers to resize columns.
- Select a case in the middle list → details appear on the right.
- Action buttons show SnackBar placeholders when clicked.
- Headers and body text are selectable for copy/paste.

## Notes / TODOs (future work)
- Replace sample data with backend API calls and implement actual approve/reject flows.
- Consider collapsing less-used actions into a `More` overflow menu to save space.
- Persist panel widths (local storage) if desired for UX.
- Add automated UI tests for resizing and selection behaviors if needed.

## Recommended reviewers / labels
- Reviewers: frontend / UI team, UX reviewer.
- Labels: `feature`, `ui`, `needs-review`.

## Merge suggestion
Prefer `Squash and merge` (or rebase + squash) to keep history tidy for this feature.

## Branch
`feature/approvals-page`

---

_Paste this content into the GitHub PR description when creating the PR._
