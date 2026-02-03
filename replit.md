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

## Notes
- The app uses Firebase for authentication and data storage
- Cloud Functions handle Shopify webhooks and integrations
- NFC functionality is available on supported devices
