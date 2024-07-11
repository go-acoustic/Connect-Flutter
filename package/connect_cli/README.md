## Overview

Connect Automation CLI for Flutter is a command-line application that setups the Flutter Connect plugin on Android and iOS platforms, reads configuration values from ConnectConfig.json file.

## Configure Connect

Run the Flutter Connect Automation CLI script following these steps:

1. Copy the Connect Automation CLI folder to your Home folder:  
   _$HOME/.pub-cache/hosted/pub.dev/connect_flutter_plugin-<Connect-PLUGIN-VERSION>/package/connect_cli_ to _$HOME/connect_cli_
2. Open a Terminal in the Connect Automation CLI folder:  
   ```shell
   cd $HOME/connect_cli
   ```
3. In the Terminal, run the command:
   ```shell
   dart pub get
   ```
4. Next, change the Terminal to the folder of your Flutter project in which you want to configure the Connect Flutter plugin.
   ```shell
   cd  <YOUR_PROJECT_PATH>
   ```
5. In the Terminal, run the command:
   ```shell
   dart run $HOME/connect_cli/bin/connect_cli.dart
   ```