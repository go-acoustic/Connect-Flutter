import 'dart:io';
import 'dart:convert';
import 'package:connect_cli/setup_mobile_platforms.dart';
import 'package:yaml/yaml.dart';
import 'models/basic_config_model.dart';
import 'update_config.dart';

String getPluginPath(String currentProjectDir) {
  String pluginName = "connect_flutter_plugin";
  var pubFile = File("$currentProjectDir/pubspec.yaml").readAsStringSync();
  final pubspecLoader = loadYaml(pubFile) as YamlMap;
  final dependencies = pubspecLoader['dependencies'][pluginName];
  if (dependencies is YamlMap) {
    stdout.writeln('Plugin is from local path: ${dependencies['path']}');
    return dependencies['path'];
  }
  if (dependencies == null || dependencies.isEmpty) {
    stdout.writeln(
        'Plugin must be installed with "flutter pub add connect_flutter_plugin"');
    throw FormatException('Invalid pubspec.yaml dependencies');
  } else {
    String version = dependencies.replaceAll('^', '');
    String pluginDirName = "$pluginName-$version";
    stdout.writeln('Plugin from pub dev path: $pluginDirName');
    // return "~/.pub-cache/hosted/pub.dev/$pluginDirName";

    String? pubCacheDir;
    if (Platform.isWindows) {
      pubCacheDir = Platform.environment['APPDATA'];
    } else if (Platform.isMacOS) {
      pubCacheDir = "${Platform.environment['HOME']}/.pub-cache";
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    return "$pubCacheDir/hosted/pub.dev/$pluginDirName";
  }
}

setupMobilePlatforms(String pluginRoot, String currentProjectDir) {
  SetupMobilePlatforms setupMobilePlatforms = SetupMobilePlatforms();
  setupMobilePlatforms.run(pluginRoot, currentProjectDir);
}

void setupJsonConfig(String pluginRoot, String currentProjectDir,
    String? appKey, String? postMessageUrl) {
  var template = "$pluginRoot/automation/ConnectConfig.json";
  var file = "$currentProjectDir/ConnectConfig.json";
  // Ensure the file exists by copying the template first
  if (!File(file).existsSync()) {
    File(template).copySync(file);
    stdout.writeln("$template was copied to $file");
  }

  // Now update the ConnectConfig.json file with AppKey and PostMessageUrl
  updateConnectConfig(file, appKey, postMessageUrl);
  stdout.writeln('ConnectConfig updated with your project settings.');
}

void updateConnectConfig(
    String filePath, String? appKey, String? postMessageUrl) {
  var connectConfig = File(filePath);
  var configContent = connectConfig.readAsStringSync();

  if (appKey != null && postMessageUrl != null) {
    // Use a more flexible way to replace the values
    var updatedConfig = configContent
        .replaceAll(RegExp(r'"AppKey":\s*".*?"'), '"AppKey": "$appKey"')
        .replaceAll(RegExp(r'"PostMessageUrl":\s*".*?"'),
            '"PostMessageUrl": "$postMessageUrl"');

    connectConfig.writeAsStringSync(updatedConfig);
  }
}

updateConnectLayoutConfig(BasicConfig basicConfig, String currentProjectDir) {
  if (basicConfig.connect?.layoutConfig != null) {
    // bool? useRelease = basicConfig.connect?.useRelease;

    // String iosReleasePath =
    //     '$currentProjectDir/ios/Pods/AcousticConnectDebug/SDKs/iOS/ConnectResources.bundle/ConnectLayoutConfig.json';
    // String iosDebugPath =
    //     '$currentProjectDir/ios/Pods/AcousticConnectDebug/SDKs/iOS/Debug/ConnectResources.bundle/ConnectLayoutConfig.json';

    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String prettyprint = encoder.convert(basicConfig.connect!.layoutConfig);

    try {
      File oldAndroidFile = File(
          '$currentProjectDir/android/app/src/main/assets/ConnectLayoutConfig.json');
      if (oldAndroidFile.existsSync()) {
        oldAndroidFile.deleteSync();
      }

      File('$currentProjectDir/android/app/src/main/assets/ConnectLayoutConfig.json')
          .create(recursive: true)
          .then((File file) {
        file.writeAsString(prettyprint);
        stdout.writeln('Updated Android ConnectLayoutConfig.json');
      });

      // if (useRelease != null && useRelease) {
      //   File oldiOSFile = File(iosReleasePath);
      //   if (oldAndroidFile.existsSync()) {
      //     oldiOSFile.deleteSync();
      //   }

      //   File(iosReleasePath).create(recursive: true).then((File file) {
      //     file.writeAsString(prettyprint);
      //     stdout.writeln('Updated iOS ConnectLayoutConfig.json');
      //   });
      // } else if (useRelease != null && !useRelease) {
      //   File oldiOSFile = File(iosDebugPath);
      //   if (oldiOSFile.existsSync()) {
      //     oldiOSFile.deleteSync();
      //   }

      //   File iosFile = File(iosDebugPath);
      //   iosFile.createSync(recursive: true);
      //   iosFile.writeAsStringSync(prettyprint);
      //   stdout.writeln('Updated iOS ConnectLayoutConfig.json (Debug)');
      // } else {
      //   stdout.writeln('useRelease property not found');
      // }
    } catch (e) {
      stdout.writeln(e);
    }
  } else {
    stdout.writeln("Issue with ConnectConfig.json");
  }
}

// void updateFile(String iosDebugPath, String prettyprint) async {
//   // Create the file and ensure it's done before proceeding
//   File file = await File(iosDebugPath).create(recursive: true);

//   // Write the string to the file
//   await file.writeAsString(prettyprint);

//   // Confirm the update
//   stdout.writeln('Updated iOS ConnectLayoutConfig.json');
// }

updateBasicConfig(
    String pluginRoot, String currentProjectDir, String key, dynamic value) {
  try {
    String valueAsString;

    if (value is bool) {
      // Explicitly handle boolean values to convert them to String
      valueAsString = value ? 'true' : 'false';
    } else {
      // For other types, use toString() to convert them to a String
      valueAsString = value.toString();
    }

    String valueType = value.runtimeType.toString();
    updateConfig(currentProjectDir, key, valueAsString, valueType);
  } catch (e) {
    stdout.writeln(e);
  }
}
