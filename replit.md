# Reviews Everywhere - Flutter Web App

## Overview
A Flutter web application with Firebase integration for NFC tag management. Features multiple authentication methods (email/password, Google, Facebook), Shopify integration for billing/entitlement management, and a premium mobile-first UI with onboarding flow.

## Project Structure
```
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # Main app widget with routing
│   ├── core/
│   │   ├── theme/app_theme.dart     # Premium design system (colors, spacing, radii, shadows, text styles, widgets)
│   │   └── widgets/premium_widgets.dart  # Reusable premium components (PillBadge, PrimaryButton, etc.)
│   ├── features/
│   │   ├── nfc_tag/                 # Core NFC functionality
│   │   │   ├── presentation/        # UI pages and widgets
│   │   │   ├── domain/              # Use cases (write_url, clear_tag)
│   │   │   └── data/                # Repositories
│   │   ├── onboarding/              # 4-step onboarding flow
│   │   │   ├── presentation/pages/  # Onboarding screens
│   │   │   └── data/                # OnboardingService
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart # NEW premium dashboard (Home tab) + tooltip tour
│   │   │   ├── home_dashboard.dart   # Original NFC dashboard (preserved, not used in Home tab)
│   │   │   └── tour_data.dart        # 11-step tour content (steps 10-11 placeholder)
│   │   └── shell/                   # Bottom navigation shell
│   │       ├── main_shell.dart      # 5-tab navigation (Home = DashboardScreen)
│   │       ├── wristbands_page.dart # Wristbands tab (placeholder)
│   │       ├── teams_page.dart      # Teams tab (placeholder)
│   │       ├── analytics_page.dart  # Analytics tab (placeholder)
│   │       └── account_page.dart    # Account management
│   └── firebase/                    # Firebase configuration
├── functions/                       # Firebase Cloud Functions (Node.js)
├── web/                             # Web-specific assets
├── assets/                          # App assets (logo, animations)
├── build/web/                       # Built web app (auto-generated)
└── server.py                        # Python server (port 5000)
```

## Technology Stack
- **Frontend**: Flutter 3.32.0 (Dart 3.8.0)
- **Backend**: Firebase Cloud Functions (Node.js 20)
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth (Google, Facebook, Email/Password)
- **Hosting**: Python HTTP server on port 5000
- **Typography**: Raleway 700 (headings), Montserrat 500 (buttons), Inter (body text)
- **Brand Colors**: Blue #0075FD (primary), Orange #F75013 (accent)

## App Flow

### Navigation
- **Bottom Navigation Bar** with 5 tabs: Home, Wristbands, Teams, Analytics, Account
- No burger/drawer menu

### Dashboard (Home Tab)
- NEW screen: `dashboard_screen.dart` (replaces old HomeDashboard in Home tab)
- Sections: Header greeting, Slot summary card, Recent activity (empty state), Support card
- "Add new wristband" button visible only when slotsAvailable > 0
- Orange pill badge "No slots available, buy more" when slotsAvailable == 0
- Reads Firestore account data (READ ONLY)

### Onboarding (First Login Only) - Master V3 Logic
1. **Step 1**: Welcome - Purchaser name (min 2 chars), initial slots (1-50 integer)
   - **Auto-prefilled** from existing Firestore account data (same source as View Slots)
   - Purchaser name from displayName (or firstName + lastName fallback)
   - Slots from slotsNet (purchased entitlement count)
   - Both fields remain fully editable after prefill
   - Next button blocked until both fields are valid
2. **Step 2**: Define Wristbands - Pre-initialized with exactly maxWristbands rows from Step 1
   - All names required (min 2 chars), must be unique (case-insensitive)
   - Cannot add more than maxWristbands, can remove down to 1
   - Wristband count syncs if user goes back and changes slots
3. **Step 3**: Define Teams - Team names and members
   - At least 1 team with name (min 2 chars)
   - At least 2 members total across all teams (min 2 chars each)
   - Member names unique within each team (case-insensitive)
4. **Step 4**: Assign Wristbands & Set GBP URL
   - HTTPS URL required (http rejected for security)
   - All wristbands must be assigned to a member
   - Final CTA: "Finish Setup"
5. Data saved to Firestore `accounts/{customerId}.onboardingData`
6. `onboardingComplete: true` prevents re-showing

**Validation Behavior**: 
- Next/Finish button shows disabled state (grayed out) when validation fails
- Clicking shows snackbar + inline error with specific message
- Real-time validation updates as user types

### Add New Wristband (Dashboard)
- **Button visible** only when `slotsAvailable > 0`
- **Message shown** "No slots available, buy more" when `slotsAvailable == 0`
- Launches existing onboarding flow in `addWristbandMode` (locked to 1 wristband)
- On completion: atomically increments `slotsUsed` by 1 via Firestore transaction
- New wristband names + assignments merged into existing `onboardingData`
- Cancel/back does NOT change `slotsUsed`
- Server-side guard: transaction checks `slotsAvailable > 0` before incrementing

### First-Time Dashboard Tour (11 Steps)
- Shows only on first dashboard open (per session currently; needs SharedPreferences for per-device)
- Dark overlay (60% opacity) covers dashboard
- Centered modal card with title, body, progress counter, Prev/Next buttons
- Close (X) or Finish marks tour as completed
- Tour text centralized in `lib/features/dashboard/tour_data.dart`
- Steps 1-9: exact text from screenshots
- Steps 10-11: placeholder text (awaiting screenshots)

### Core Actions (in original HomeDashboard, preserved)
- **View Slots**: Shows account/slot information from Firestore
- **Write URL**: Programs NFC wristband with custom URL
- **Clear URL**: Removes URL from NFC wristband

## Development

### Running the App
The workflow "Flutter Web App" automatically serves the built app on port 5000.

### Rebuilding
```bash
flutter build web --base-href "/"
```

### Installing Dependencies
```bash
flutter pub get                      # Flutter dependencies
cd functions && npm install          # Cloud Functions dependencies
```

## Authentication Architecture

### Flow Overview
1. **Shopify** = billing/entitlement authority (webhooks provision accounts)
2. **Firebase Auth** = identity/password authority (manages credentials)
3. **Firestore** = stores `accounts/{customerId}.planStatus`

### User Journey
1. User purchases on Shopify
2. `orders/paid` webhook provisions Firestore account + Firebase Auth user
3. User opens app → "Forgot Password" → Firebase reset email
4. User sets password → logs in
5. App checks `planStatus === 'active'` after login
6. First login → onboarding flow → dashboard

### Key Files
- `lib/firebase/auth_services.dart` - Auth service
- `lib/features/onboarding/data/onboarding_service.dart` - Onboarding persistence
- `lib/features/shell/main_shell.dart` - Bottom navigation
- `lib/features/dashboard/dashboard_screen.dart` - NEW premium dashboard
- `lib/features/dashboard/home_dashboard.dart` - Original NFC dashboard (preserved)
- `functions/shopify/orderPaid.js` - Webhook provisions users

## Notes
- The app uses Firebase for authentication and data storage
- Cloud Functions handle Shopify webhooks and integrations
- NFC functionality requires device support (simulator mode for testing)
- Onboarding data stored in `accounts/{customerId}.onboardingData`
