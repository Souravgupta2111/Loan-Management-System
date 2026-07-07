# LMS Widgets — status

Most of the wiring is now done in the project. Here's the state and the only
things left for you to verify in Xcode.

## Done (in code / project file)
- Widget extension target **LMSWidgetsExtension** exists.
- Glass widgets implemented: `LMSGlassWidgets.swift` (NextEMIWidget + LoanSummaryWidget)
  and registered in `LMSWidgetsBundle.swift`. (The Xcode sample "LMSWidgets"/timer
  control were replaced/kept harmlessly.)
- **App Group** `group.com.sourav.hi123.LMS` entitlement added to BOTH targets:
  - `LMS/LMS/LMS.entitlements` (app)  → wired via `CODE_SIGN_ENTITLEMENTS`
  - `LMS/LMSWidgets/LMSWidgets.entitlements` (widget) → wired via `CODE_SIGN_ENTITLEMENTS`
- The app publishes a snapshot to that App Group on the dashboard load
  (`WidgetDataProvider`, called from `HomeDashboardView`).
- `appGroupID` matches in `WidgetDataProvider.swift` and `LMSGlassWidgets.swift`.

## Verify in Xcode (1 minute)
1. Open the project. Select the **LMS** target ▸ Signing & Capabilities — you should
   see **App Groups** with `group.com.sourav.hi123.LMS`. If Xcode shows a warning to
   register it, click **Fix** / the refresh arrow (Automatic signing registers it).
2. Do the same check on the **LMSWidgetsExtension** target (same group must be ticked).
3. If your team requires a different App Group id, change it in three places and re-tick:
   `LMS.entitlements`, `LMSWidgets.entitlements`, `WidgetDataProvider.swift`, `LMSGlassWidgets.swift`.

## Run
- Build & run the app once (writes the snapshot on the dashboard).
- Long-press Home Screen ▸ **+** ▸ search "LMS" ▸ add **Next EMI** / **Loan Summary**.
- Tapping a widget deep-links into the app (`lmsapp://emi`, `lmsapp://loans`) and
  routes to the right tab (handled in `ContentView.onOpenURL`).

## Notes
- On the Simulator, App Groups work without portal registration. On a real device,
  Automatic signing registers the group under your team (A92V46D8LJ).
- Until a snapshot exists, widgets show sample data.
