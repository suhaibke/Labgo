# LabGo Lab App (Flutter)

Mobile app for labs to manage their lab, built 1:1 from the provided design
(`preview_9.html`).

## Status — phase 1 (UI only, sample data, no server calls)

Done:
- Splash, Login (phone / email), Register (2 steps), OTP, Forgot & Reset password
- Top bar (theme switch, language EN / AR / KU, notifications), floating bottom nav
- Reports (home): swipeable stats card (4 views), search, filters, recent reports
- Results: list, result entry with low / normal / high indicator, save
- Print results: printer animation and the lab report paper
- Send result sheet, notifications sheet, logout dialog
- Add Patient (B2B, tests and packages, sample, urgency) with a printed payment receipt
- Send to Other Labs: referrals, tracking, shipping label; Receive B2B samples
- Settings: profile edit, delete account (OTP), general settings, users and roles,
  financial, manage tests (normal ranges by age), create order, packages, about,
  report header/footer and templates, lab data, accent colour; waste management page
- Light / dark mode, RTL for Arabic and Kurdish
- Fonts: SF on iPhone (system font); Inter + IBM Plex Sans Arabic elsewhere

Next: Store (marketplace and auctions, My Orders), then connecting to the backend
so the app and the web dashboard share the same data.

## Run

```
flutter pub get
flutter run
```

Code layout: `lib/src/theme.dart` (design colour tokens), `lib/src/strings_data.dart`
(texts copied from the design), `lib/src/app_state.dart` (app state),
`lib/src/screens/` (screens).
