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
- Light / dark mode, RTL for Arabic and Kurdish

Next: Add Patient, Send to other labs, Settings (and its sub-pages), Store,
then connecting to the backend.

## Run

```
flutter pub get
flutter run
```

Code layout: `lib/src/theme.dart` (design colour tokens), `lib/src/strings_data.dart`
(texts copied from the design), `lib/src/app_state.dart` (app state),
`lib/src/screens/` (screens).
