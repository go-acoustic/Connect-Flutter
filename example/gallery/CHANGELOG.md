## 2.5.1-beta
Beta Connect-Flutter Change Notes: 
Bug Fixes

- Minor changes.

Improvements

- In maven central, libraries moved from namespace acoustic-analytics to go-acoustic.
- Support Gesture Auto instrumentation.
- Support Flutter Gesture meta data capture.
- Support Mask by Accesibility.

Our environment for this release:

- Visual Studio Code Version: 1.80.0 (Universal)
- Xcode 15.2
- MacOS 14.3
- iOS 12.x to 15.x
- Supported architectures:
	- simulator
		- arm64
		- x86_64
	- device
		- arm64
-Android 21-34

List of items are in the roadmap but not supported yet

Known Issues

- Only Android & IOS platforms are supported.
- When Navigation route isn't set, replay shows null screenview.
- Sometimes masking overlay carries to next screen due to Flutter view tree design.