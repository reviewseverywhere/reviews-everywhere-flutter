# Cards - Flutter Web App

## Overview
A Flutter web application with Firebase integration. The app includes NFC tag functionality, Firebase authentication (Google Sign-In, Facebook Auth), Cloud Firestore, and Cloud Functions.

## Project Structure
```
├── lib/               # Flutter/Dart source code
│   ├── main.dart      # App entry point
│   ├── app.dart       # Main app widget
│   ├── core/          # Core utilities
│   ├── features/      # Feature modules (NFC tags, etc.)
│   └── firebase/      # Firebase configuration
├── functions/         # Firebase Cloud Functions (Node.js)
├── web/              # Web-specific assets
├── assets/           # App assets
├── build/web/        # Built web app (auto-generated)
└── server.py         # Python server to serve the web app
```

## Technology Stack
- **Frontend**: Flutter 3.32.0 (Dart 3.8.0)
- **Backend**: Firebase Cloud Functions (Node.js 20)
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth (Google, Facebook)
- **Hosting**: Python HTTP server on port 5000

## Development

### Running the App
The workflow "Flutter Web App" automatically:
1. Serves the built Flutter web app on port 5000

### Rebuilding the App
After making changes to Dart code:
```bash
flutter build web --base-href "/"
```

### Installing Dependencies
```bash
flutter pub get          # Flutter dependencies
cd functions && npm install  # Cloud Functions dependencies
```

## Configuration
- Firebase config: `lib/firebase_options.dart`
- Firebase project: `firebase.json`
- Firestore indexes: `firestore.indexes.json`

## Authentication Architecture

### Flow Overview
1. **Shopify** is the billing/entitlement authority (webhooks provision accounts)
2. **Firebase Auth** is the identity/password authority (manages user credentials)
3. **Firestore** stores entitlement status (`accounts/{customerId}.planStatus`)

### User Journey
1. User purchases on Shopify website
2. `orders/paid` webhook provisions:
   - Firestore account document with `planStatus: 'active'`
   - Firebase Auth user (email, no password)
3. User opens app and taps "Forgot Password"
4. Firebase sends password reset email
5. User sets password and logs in
6. App validates entitlement (`planStatus === 'active'`) after login

### Key Files
- `lib/firebase/auth_services.dart` - Flutter auth service
  - `loginWithEmailPassword()` - Firebase email/password login with entitlement check
  - `sendPasswordResetEmail()` - Firebase password reset
  - Social login (Google/Facebook) with entitlement gating
- `functions/shopify/orderPaid.js` - Webhook provisions Firebase Auth users
- `functions/auth/lookupAccountByEmail.js` - Entitlement lookup callable

### Recent Changes (Feb 2026)
- Switched from Shopify password management to Firebase Auth
- `orderPaid` webhook now provisions Firebase Auth users automatically
- Login uses `signInWithEmailAndPassword` with post-login entitlement check

## Notes
- The app uses Firebase for authentication and data storage
- Cloud Functions handle Shopify webhooks and integrations
- NFC functionality is available on supported devices
