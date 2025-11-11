## 2.37.0
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Fix issue with not updating logicalPageName from AutoLayout/<<Navigation Route Name>>

Improvements

- Add support to set a logicalPageName for route item that does not have a value for property name.
  With the following logic:
		- First checking if route.settings.name exists and is not empty
		- If null/empty, it examines the route's runtime type to provide meaningful names:
			- ModalBottomSheetRoute → 'ModalBottomSheet'
			- DialogRoute → 'Dialog'
			- PopupRoute → 'Popup'
			- PageRoute → 'Page_{hashCode}'
			- Any other route type → '{RouteType}_{hashCode}'
- Add support for Android build.gradle.kts.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 26.1
- MacOS 26.0.1
- iOS 13.x to 26.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Sample App has some build issues will be fixed in later version.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Text change event not supported yet.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.

## 2.36.5-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Fix issue with not updating logicalPageName from AutoLayout/<<Navigation Route Name>>

Improvements

- Add support to set a logicalPageName for route item that does not have a value for property name.
  With the following logic:
		- First checking if route.settings.name exists and is not empty
		- If null/empty, it examines the route's runtime type to provide meaningful names:
			- ModalBottomSheetRoute → 'ModalBottomSheet'
			- DialogRoute → 'Dialog'
			- PopupRoute → 'Popup'
			- PageRoute → 'Page_{hashCode}'
			- Any other route type → '{RouteType}_{hashCode}'
- Add support for Android build.gradle.kts.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 26.1
- MacOS 26.0.1
- iOS 13.x to 26.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Sample App has some build issues will be fixed in later version.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Text change event not supported yet.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.

## 2.36.4-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Fix issue with not updating logicalPageName from AutoLayout/<<Navigation Route Name>>

Improvements

- Add support to set a logicalPageName for route item that does not have a value for property name.
  With the following logic:
		- First checking if route.settings.name exists and is not empty
		- If null/empty, it examines the route's runtime type to provide meaningful names:
			- ModalBottomSheetRoute → 'ModalBottomSheet'
			- DialogRoute → 'Dialog'
			- PopupRoute → 'Popup'
			- PageRoute → 'Page_{hashCode}'
			- Any other route type → '{RouteType}_{hashCode}'
- Add support for Android build.gradle.kts.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 26.1
- MacOS 26.0.1
- iOS 13.x to 26.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Text change event not supported yet.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.


## 2.36.3-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Minor bug fix.
- Fix issue with masking text in type 10 data.

Improvements

- Support layoutConfigIos/layoutConfigAndroid as separate LayoutConfig in ConnectConfig.json.
- Support common custom UI Widgets.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 16.4
- MacOS 15.5
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Text change event not supported yet.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.


## 2.35.2-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Fix issue with masking text in type 10 data.

Improvements

- None.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 16.4
- MacOS 15.5
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.


## 2.35.1-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Fix issue with masking text in type 10 data.

Improvements

- None.

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.99.3 (Universal)
- Xcode 16.4
- MacOS 15.5
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.


## 2.35.0
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Logger 2.0.0

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 15.2
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.34.2-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Logger 2.0.0

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 15.2
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.34.1-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Logger 2.0.0

Our environment for this release:

- Flutter SDK 3.27.4
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 15.2
- iOS 13.x to 18.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-35


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.34.0
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Connect Android SDK Config. file names

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 13.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.33.4-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Connect Android SDK Config. file names

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 13.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.33.3-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Connect Android SDK Config. file names

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 13.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Android app will have build issues on AS IDE LadyBug and newer, due to out of date packages.
- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.33.2-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Support Enable or Disable Screen based on ConnectConfig.json

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 13.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.33.1-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.
- Support Emit Signal API.
- Support native SDK configuration item plugin APIs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 13.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.33.0
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.
- Support Emit Signal API.
- Support native SDK configuration item plugin APIs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.32.3-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.
- Support Emit Signal API.
- Support native SDK configuration item plugin APIs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.32.2-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.
- Support Emit Signal API.
- Support native SDK configuration item plugin APIs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.6.5-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.6.4-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.

Our environment for this release:

- Flutter SDK 3.22.2
- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.6.3-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.

Our environment for this release:

- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.6.2-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.

Our environment for this release:

- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
## 2.6.1-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- None.

Improvements

- Flutter plugin for Connect SDKs.

Our environment for this release:

- Visual Studio Code Version: 1.90.2 (Universal)
- Xcode 15.4
- MacOS 14.5
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34


Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.
