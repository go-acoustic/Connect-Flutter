## Overview

Tealeaf Automation CLI for Flutter is a command-line application that setups the Flutter Tealeaf plugin on Android and iOS platforms, reads configuration values from ConnectConfig.json file.

## Configure Tealeaf

Run the Flutter Tealeaf Automation CLI script following these steps:

1. Copy the Tealeaf Automation CLI folder to your Home folder:  
   _$HOME/.pub-cache/hosted/pub.dev/connect_flutter_plugin-<TEALEAF-PLUGIN-VERSION>/package/connect_cli_ to _$HOME/connect_cli_
2. Open a Terminal in the Tealeaf Automation CLI folder:  
   ```shell
   cd $HOME/connect_cli
   ```
3. In the Terminal, run the command:
   ```shell
   dart pub get
   ```
4. Next, change the Terminal to the folder of your Flutter project in which you want to configure the Tealeaf Flutter plugin.
   ```shell
   cd  <YOUR_PROJECT_PATH>
   ```
5. In the Terminal, run the command:
   ```shell
   dart run $HOME/connect_cli/bin/connect_cli.dart
   ```
<!-- 6. Open your iOS project in Xcode.
   1. In the project navigator, right click on the **Runner** folder and select: **Add filles to "Runner"...**.
   2. Select _main.swift_ and _TealeafApplication.swift_ and click on **Add**. -->
