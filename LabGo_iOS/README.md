# LabGo Flutter App

A beautiful Flutter mobile application for patients to find and book laboratory tests.

## Features

- 🔐 **Authentication** - Login and Register with email/password
- 🔍 **Search Labs** - Find laboratories by name or location
- 🏥 **Lab Details** - View laboratory information, tests, and ratings
- 🌍 **Multi-language** - Supports English, Arabic, Kurdish, and Turkish
- 🎨 **Apple-inspired Design** - Clean, modern UI with smooth animations

## Design

- **Primary Color**: #8378F4 (Purple)
- **Secondary Color**: #F4A900 (Gold)
- **Theme**: Light/White theme
- **Font**: Inter (for English), Cairo (for Arabic/Kurdish)

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode (for mobile development)
- Backend API running on `http://localhost:3000`

## Setup

1. **Install Dependencies**
   ```bash
   cd labgo_app
   flutter pub get
   ```

2. **Add Assets**
   - Create `assets/images/` and `assets/icons/` directories
   - Add the LabGo logo from `backend/public/images/logo.png`
   - Download Inter and Cairo fonts and place in `assets/fonts/`

3. **Update API URL**
   - Edit `lib/src/services/api_service.dart`
   - Change `baseUrl` to your backend URL (e.g., `http://192.168.x.x:3000` for physical device testing)

4. **Run the App**
   ```bash
   flutter run
   ```

## Project Structure

```
labgo_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── src/
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── register_screen.dart
│   │   │   └── home/
│   │   │       └── home_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── auth_service.dart
│   │   │   └── lab_service.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── widgets/
│   │       └── app_logo.dart
│   └── assets/
│       ├── images/
│       ├── icons/
│       └── fonts/
├── pubspec.yaml
└── README.md
```

## Screens

### Login Screen
- Email and password authentication
- Remember me functionality
- Social login placeholders (Google, Apple)
- Link to registration screen

### Register Screen
- Full name, email, phone inputs
- Gender selection
- Date of birth picker
- Password with validation
- Terms and conditions agreement

### Home Screen
- Personalized greeting
- Search laboratories by name/location
- Lab cards with:
  - Logo/Icon
  - Name and verified badge
  - Location
  - Rating and test count
  - Available tests preview
  - View details button

## API Integration

The app integrates with the LabGo backend API:

- **POST** `/api/auth/register` - User registration
- **POST** `/api/auth/login` - User login
- **GET** `/api/labs` - Get all laboratories
- **GET** `/api/labs/:id` - Get laboratory details

## Fonts Used

- **Inter** - For English text
  - Inter-Regular.ttf
  - Inter-Medium.ttf
  - Inter-SemiBold.ttf
  - Inter-Bold.ttf

- **Cairo** - For Arabic/Kurdish text
  - Cairo-Regular.ttf
  - Cairo-Medium.ttf
  - Cairo-SemiBold.ttf
  - Cairo-Bold.ttf

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Notes

- For physical device testing, update the `baseUrl` in `api_service.dart` to your local network IP
- The app requires the backend to be running
- Make sure to enable port forwarding or use your local IP address for emulator testing

## License

Copyright © 2024 LabGo. All rights reserved.
