# LMS Staff Widgets — setup

All the code is written. Because the staff project has **no widget extension target
yet**, you need to create it in Xcode (same as you did for the borrower app), then
I'll wire the App Group / entitlements into the project file.

## Step 1 — Create the widget extension target (you do this in Xcode)
1. Open `LMS Staff.xcodeproj`.
2. **File ▸ New ▸ Target… ▸ Widget Extension**.
3. Product name: **StaffWidgets**. Uncheck "Include Live Activity" and
   "Include Configuration Intent". Finish. (Activate the scheme if prompted.)
4. Xcode creates a `StaffWidgets` group with template files
   (`StaffWidgetsBundle.swift`, `StaffWidgetsControl.swift`, `AppIntent.swift`, sample widget).
   **Delete those template `.swift` files** — the real code is `StaffWidgets/StaffWidgets.swift`.
5. Make sure `StaffWidgets/StaffWidgets.swift` is a member of the **StaffWidgets** target
   (File Inspector ▸ Target Membership).

## Step 2 — Tell me it's created
Once the target exists I'll:
- Wire `CODE_SIGN_ENTITLEMENTS` for the **LMS Staff** app → `LMSStaff.entitlements`
  and the **StaffWidgets** target → `StaffWidgets.entitlements` (files already created).
- Both use App Group `group.com.sourav.hi123.LMS-Staff`.
- Validate the project file.

(If you prefer, you can add the App Group capability to both targets yourself under
Signing & Capabilities — same group id.)

## What's already done in code
- **App side:** `StaffWidgetDataProvider` fetches role metrics (officer queue / manager
  portfolio / admin overview) and publishes a snapshot to the App Group. Called from
  `StaffTabRouter.onAppear`. No-op until the App Group exists.
- **Deep links:** `lmsstaffapp://applications | portfolio | npa | disbursements |
  assistant?q=…` routed in the staff `ContentView` via `StaffIntentRouter`.
- **Widgets (9):**
  - Officer: My Review Queue, Oldest Pending / SLA, AI Copilot quick-ask.
  - Manager: Portfolio Pulse (large), Pending Approvals, NPA & Overdue.
  - Admin: System Overview (large), Audit Activity.
  - Lock Screen: role-aware queue/NPA gauge (inline / circular / rectangular).
- Widgets are **role-aware** — they read the snapshot's `role` and show a
  "Sign in as …" hint if it doesn't match.
- Neutral liquid glass styling (no brand tint).

## Run
Build & run the staff app once (writes the snapshot on login), then add widgets from
the Home Screen gallery.
