# Acoustic Connect Flutter Plugin

[![pub package](https://img.shields.io/pub/v/connect_flutter_plugin.svg)](https://pub.dev/packages/connect_flutter_plugin)

A comprehensive Flutter plugin that enables behavioral analytics and session replay capabilities for Flutter applications through Acoustic Connect. This plugin allows you to capture user interactions, application data, and performance metrics, which can then be analyzed and replayed in the Acoustic Connect platform.

For more information, see the [Flutter SDK overview](https://developer.goacoustic.com/acoustic-exp-analytics/docs/flutter-sdk-overview).

To start working with the Connect Flutter plugin, Add the plugin to your application and configure Connect. Refer to [Installation instructions](https://developer.goacoustic.com/acoustic-connect/docs/add-acoustic-behavioral-data-sdk-to-an-ios-app#flutter).

Example sample app files you can use to build to view quick example implementations of all core functionalities are provided with the plugin. To start working with the example files, refer to [Build the sample app](https://developer.goacoustic.com/acoustic-connect/docs/build-a-sample-app-to-evaluate-the-connect-sdk#flutter).

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Repository Structure](#repository-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Sample Application](#sample-application)
- [Key Components](#key-components)
- [Subscription Tiers](#subscription-tiers)
- [Platform Support](#platform-support)
- [Privacy and Data Collection](#privacy-and-data-collection)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)
- [License](#license)

## Overview

The Connect Flutter Plugin instruments your Flutter applications to capture comprehensive user behavior data and application telemetry. The data is processed and visualized in Acoustic Connect, providing powerful insights through:

- **Session Replay**: Visual playback of actual user sessions
- **User Interaction Tracking**: Taps, scrolls, gestures, and navigation
- **Performance Monitoring**: Load times, response times, network errors
- **Device Context**: Hardware specifications, OS details, network information
- **Behavioral Analytics**: User flows, conversion funnels, and engagement metrics

## Features

### Core Capabilities

**Automatic Data Capture**
- Hardware information (device type, pixel density, screen dimensions, storage usage)
- Software details (OS version, memory usage, interface language, app version)
- User behavior (navigation patterns, gesture events, keyboard interactions)
- Application performance (load times, response times, battery usage)
- Network information (carrier, connection type, IP address)

**Session Replay** (Ultimate Subscription)
- Full visual replay of user sessions
- Screenshot capture with automatic privacy masking
- Gesture and interaction visualization
- Screen transition tracking
- Timeline-based playback interface

**Privacy Protection**
- Automatic masking of sensitive UI elements
- Configurable privacy settings via `ConnectConfig.json`
- Compliance-ready data handling

**Performance Optimized**
- Minimal app size impact: 3 MB on iOS, 200 KB on Android
- Low memory overhead: 2-3% increase
- Efficient battery usage
- Offline data caching when server unreachable
- ~20 KB data transfer per screen on average

## Requirements

### Development Environment

- **Flutter SDK**: Version 3.16 or later
- **IDE**: Visual Studio Code, Android Studio, or IntelliJ IDEA
- **Acoustic Connect Subscription**: Active subscription required (Pro, Premium, or Ultimate)

### Mobile Platform Support

**Android**
- Minimum: Android 5.0 (API level 21)
- Maximum Tested: Android 14 (API level 34)
- Android Studio: Meerkat Feature Drop | 2024.3.2 Patch 1 or later

**iOS**
- Minimum: iOS 13.0
- Maximum Tested: iOS 17.x
- Xcode: Latest stable version
- CocoaPods: Recent version required

## Repository Structure

```
Connect-Flutter/
├── android/                    # Android platform implementation
│   ├── src/
│   └── build.gradle
├── ios/                        # iOS platform implementation
│   ├── Classes/
│   └── connect_flutter_plugin.podspec
├── lib/                        # Dart implementation
│   ├── connect_flutter_plugin.dart
│   └── method_channel/
├── example/                    # Sample applications
│   └── gallery/               # Comprehensive demo app
│       ├── android/
│       ├── ios/
│       ├── lib/
│       │   ├── main.dart
│       │   └── screens/      # Example screen implementations
│       └── ConnectConfig.json # Configuration template
├── connect_cli/               # Connect Automation CLI
│   ├── bin/
│   │   └── connect_cli.dart  # CLI tool for configuration
│   └── lib/
├── pubspec.yaml              # Package dependencies
├── CHANGELOG.md              # Version history
└── README.md                 # This file
```

## Installation

### 1. Add Dependency

Add the Connect Flutter plugin to your `pubspec.yaml`:

```yaml
dependencies:
  connect_flutter_plugin: ^latest_version
```

Run the package manager:

```bash
cd your_project_root
flutter clean && flutter pub get
```

### 2. Platform-Specific Setup

#### iOS Setup

Update your iOS minimum deployment target in `ios/Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!
```

Install the pods:

```bash
cd ios
pod install
cd ..
```

#### Android Setup

Ensure minimum SDK version in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### 3. Copy Connect CLI

Copy the Connect Automation CLI to your user directory:

```bash
cp -r ~/.pub-cache/hosted/pub.dev/connect_flutter_plugin-<version>/package/connect_cli ~/connect_cli
cd ~/connect_cli
dart pub get
```

## Configuration

### 1. Create Configuration File

Create `ConnectConfig.json` in your project root with the following structure:

```json
{
  "AppKey": "YOUR_APP_KEY_HERE",
  "PostMessageUrl": "YOUR_POST_MESSAGE_URL",
  "KillSwitchEnabled": false,
  "LogLevel": "Level3",
  "SessionizationCookieSecure": false,
  "ClientPostCaptureEnabled": true,
  "CompressPost": true
}
```

### 2. Obtain Credentials

- **AppKey**: Get from your Acoustic Connect account (Settings > Generate API Key)
- **PostMessageUrl**: Provided by Acoustic based on your region

### 3. Update Configuration

Every time you modify `ConnectConfig.json`, run the Connect CLI tool:

```bash
cd ~/connect_cli
dart run bin/connect_cli.dart
```

### 4. Instrument Your App

Add the Connect wrapper to your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';

void main() {
  runApp(
    ConnectWrapper(
      navigatorObserver: ConnectNavigatorObserver(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [ConnectNavigatorObserver()],
      home: HomeScreen(),
    );
  }
}
```

### Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| AppKey | String | Your Acoustic Connect application key | Required |
| PostMessageUrl | String | Data collection endpoint URL | Required |
| KillSwitchEnabled | Boolean | Emergency disable switch | false |
| LogLevel | String | Logging verbosity (Level1-Level4) | Level3 |
| SessionizationCookieSecure | Boolean | Use secure cookies | false |
| ClientPostCaptureEnabled | Boolean | Enable client-side capture | true |
| CompressPost | Boolean | Compress data before sending | true |
| AndroidLibraryVersion | String | Specific Android SDK version | Latest |
| iOSLibraryVersion | String | Specific iOS SDK version | Latest |
| BuildType | String | "release" or "beta" | release |

## Usage

### Basic Screen Tracking

Screens are automatically tracked when using `ConnectNavigatorObserver`. For manual tracking:

```dart
import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';

ConnectFlutterPlugin.logScreenView('ScreenName', 'ScreenClass');
```

### Custom Event Logging

```dart
ConnectFlutterPlugin.logCustomEvent('event_name', {
  'property1': 'value1',
  'property2': 'value2',
});
```

### User Identification

```dart
ConnectFlutterPlugin.setUserId('user123');
ConnectFlutterPlugin.setUserAttribute('email', 'user@example.com');
```

### UI Element Tracking

Assign unique IDs to important UI elements for accurate capture:

```dart
TextField(
  key: Key('login_email_field'),
  // ... other properties
)

ElevatedButton(
  key: Key('submit_button'),
  onPressed: () { },
  child: Text('Submit'),
)
```

## Sample Application

The repository includes a comprehensive sample app in `example/gallery/` demonstrating all core functionalities.

### Building the Sample App

#### 1. Update Dependencies

```bash
cd Connect-Flutter
flutter clean && flutter pub get

cd example/gallery
flutter clean && flutter pub get
```

#### 2. Update iOS Pods

```bash
cd example/gallery/ios
rm Podfile.lock
pod update
# If errors occur, try: pod install
```

#### 3. Configure Credentials (Ultimate Subscription Only)

Update `example/gallery/ConnectConfig.json` with your credentials:

```json
{
  "AppKey": "YOUR_APP_KEY",
  "PostMessageUrl": "YOUR_URL"
}
```

Run the Connect CLI:

```bash
cd ~/connect_cli
dart run bin/connect_cli.dart
```

#### 4. Run the App

**iOS (using Xcode):**
```bash
# Open workspace (not project!)
open example/gallery/ios/Runner.xcworkspace
```

**Android (using Android Studio):**
```bash
# Open the gallery directory
open -a "Android Studio" example/gallery
```

**Or use Flutter CLI:**
```bash
cd example/gallery
flutter run
```

### Testing Session Replay

1. Interact with the sample app
2. Log in to your Acoustic Connect account
3. Navigate to **Optimize > Session Search**
4. Find your session and play it back

**Note**: Sessions timeout after 30 minutes of inactivity

## Key Components

### ConnectWrapper

Main widget that wraps your application to enable Connect functionality.

```dart
ConnectWrapper(
  navigatorObserver: ConnectNavigatorObserver(),
  child: YourApp(),
)
```

### ConnectNavigatorObserver

Automatically tracks screen transitions and navigation events.

```dart
MaterialApp(
  navigatorObservers: [ConnectNavigatorObserver()],
  // ...
)
```

### Connect CLI Tool

Command-line utility for processing configuration changes:
- Updates native platform configurations
- Synchronizes settings across iOS/Android
- Validates configuration parameters
- Downloads specified SDK versions

Located in: `connect_cli/`

## Subscription Tiers

### Pro
- Three behavior signals: identification, add-to-cart, order
- Basic behavioral analytics
- Standard reporting

### Premium
- All behavior signals
- Comprehensive behavioral data reports
- Advanced analytics
- One user flow capture (abandonment)

### Ultimate
- Session replay with visual playback
- Multiple user flows
- Full feature access
- Advanced privacy controls
- Self-service integration

## Platform Support

| Platform | Support Level | Notes |
|----------|--------------|-------|
| Android | ✅ Full | API 21-34 |
| iOS | ✅ Full | iOS 13.0-17.x |
| Android Compose | ⚠️ Beta | View framework + Compose mix not guaranteed |
| iPadOS | ⚠️ Limited | Single-window apps only |
| Web | ❌ Not Supported | Use Connect Web SDK |

### Known Limitations

**Flutter Platform:**
- Only Android and iOS platforms supported
- Null screenview when navigation route not set
- Masking overlay may carry to next screen (Flutter view tree design)

**iOS:**
- iPadOS: Single-window applications only
- Dual SIM: Multiple carrier names reporting is beta

**Android:**
- Generic ComposeView in session replays
- Gesture events may appear under next screen
- View + Compose mixture not guaranteed

## Privacy and Data Collection

### Automatic Data Collection

The SDK automatically captures:
- Screen content (with masking)
- User interactions (taps, gestures, scrolls)
- Navigation patterns
- Device context
- Performance metrics

### Privacy Protection

**Default Behavior:**
- All sensitive UI elements are automatically masked
- Text input fields are obscured in replays
- Images shown as placeholders
- Configurable masking rules

**Best Practices:**
1. Review captured data in test environments
2. Configure additional masking for sensitive screens
3. Implement proper consent management
4. Never transmit unencrypted PII
5. Test privacy settings before production

### Data Storage

- Data batched and sent to Acoustic servers
- Offline caching on device when network unavailable
- Encrypted transmission (HTTPS)
- No local long-term storage on device

## Troubleshooting

### Common Issues

**Build Errors After Update**

```bash
cd your_project_root
flutter clean
flutter pub get
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter run
```

**Plugin Not Using Latest SDK**

Run the Connect CLI tool:
```bash
cd ~/connect_cli
dart run bin/connect_cli.dart
```

**iOS Black Screen on Launch**

Configure SDK using Swift application delegates with proper `appDelegateClass` value in configuration.

**Session Not Appearing in Connect**

1. Verify AppKey and PostMessageUrl are correct
2. Check network connectivity
3. Ensure KillSwitchEnabled is false
4. Check LogLevel for error messages
5. Verify subscription tier supports desired features

**Gradle Sync Issues (Android)**

Ensure your `android/build.gradle` includes:
```gradle
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

### Debug Mode

Enable verbose logging in `ConnectConfig.json`:
```json
{
  "LogLevel": "Level4"
}
```

## Documentation

### Official Documentation
- [Flutter SDK Overview](https://developer.goacoustic.com/acoustic-exp-analytics/docs/flutter-sdk-overview)
- [Installation Instructions](https://developer.goacoustic.com/acoustic-connect/docs/add-acoustic-behavioral-data-sdk-to-an-ios-app#flutter)
- [Build Sample App](https://developer.goacoustic.com/acoustic-connect/docs/build-a-sample-app-to-evaluate-the-connect-sdk#flutter)
- [Integrate Connect Library](https://developer.goacoustic.com/acoustic-connect/docs/integrate-the-connect-library-into-a-flutter-app)
- [Update Guide](https://developer.goacoustic.com/acoustic-connect/docs/update-the-connect-flutter-library)
- [Release Notes](https://developer.goacoustic.com/acoustic-connect/changelog/connect-mobile-sdk-release-notes)

### Package Information
- [pub.dev Package](https://pub.dev/packages/connect_flutter_plugin)
- [Acoustic Developer Portal](https://developer.goacoustic.com/)

### Support
For technical support and feature requests, contact your Acoustic account representative or visit the [Acoustic Support Center](https://support.goacoustic.com).

## Contributing

This is a proprietary plugin maintained by Acoustic. For issues or feature requests, please contact Acoustic support.

## License

Copyright © Acoustic, L.P. All rights reserved.

This software is proprietary to Acoustic, L.P. and requires an active Acoustic Connect subscription for use.

---

**Version Information**: Check [CHANGELOG.md](CHANGELOG.md) for version history and updates.

**Last Updated**: 2025

**Maintained by**: [Acoustic](https://github.com/go-acoustic)
