# Campus Lost & Found Management System

A production-quality Flutter demo app for managing lost and found items on campus.

## Features

- **Found Item Registration**: Officers can register found items with photos, location, and details
- **Search & Browse**: Students and staff can search and filter found items
- **Claim Requests**: Users can submit claim requests with verification notes
- **Claim Review**: Officers can approve/reject claim requests
- **QR Code Generation**: Each item gets a unique QR code for tracking
- **Role-Based Access**: Toggle between Student and Officer roles
- **Audit Logging**: All actions are logged for accountability

## Getting Started

### Prerequisites

- Flutter 3.x
- Dart 3.x

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Generate code (freezed, json_serializable):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
  main.dart                 # App entry point
  app/                      # App configuration
    app.dart               # Main app widget
    router.dart            # Navigation routes
    theme/                 # Theme configuration
  core/                     # Core utilities and widgets
    domain/                # Core domain models
    data/                  # Core repositories
    utils/                 # Utility functions
    widgets/               # Reusable widgets
    constants/             # App constants
  features/                # Feature modules
    found_items/           # Found items feature
    claims/                # Claims feature
    report_found/          # Report found feature
    home/                  # Home screen
    auth_demo/             # Settings/role management
  providers/               # Riverpod providers
```

## Demo Mode

This is a local-only demo app with in-memory data storage. No backend or database is required.

- All data is stored in memory and resets on app restart
- Use the Settings screen to toggle between Student and Officer roles
- In debug mode, a "Reset Demo Data" button is available in Settings

## Architecture

- **State Management**: flutter_riverpod
- **Navigation**: go_router
- **Models**: freezed + json_serializable
- **UI**: Material 3
- **Architecture**: Feature-first with clean separation of concerns

## Testing

Run tests with:
```bash
flutter test
```

## License

This is a demo project for educational purposes.

# SWE_APP
