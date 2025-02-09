import 'dart:io';
import 'package:path/path.dart' as path;

void updateConfig(String projectDir, String key, dynamic value, String type) {
  try {
    // Update Android Configuration
    String androidPath = path.join(projectDir,
        'android/app/src/main/assets/ConnectBasicConfig.properties');
    File androidFile = File(androidPath);
    if (androidFile.existsSync()) {
      String androidContent = androidFile.readAsStringSync();
      RegExp androidRegExp = RegExp('^$key=.*', multiLine: true);
      String androidReplacement = '$key=$value';
      if (androidRegExp.hasMatch(androidContent)) {
        androidContent =
            androidContent.replaceAll(androidRegExp, androidReplacement);
      } else {
        // androidContent += '\n$androidReplacement';
      }
      androidFile.writeAsStringSync(androidContent);
    }

    // Update iOS Configuration
    String iosPath = path.join(projectDir,
        'ios/Pods/AcousticConnectDebug/SDKs/iOS/Debug/ConnectResources.bundle/ConnectBasicConfig.plist');
    File iosFile = File(iosPath);
    if (iosFile.existsSync()) {
      List<String> iosLines = iosFile.readAsLinesSync();
      int keyIndex =
          iosLines.indexWhere((line) => line.trim() == '<key>$key</key>');

      String replacement;
      if (type == 'String') {
        replacement = '<string>$value</string>';
      } else if (type == 'bool') {
        replacement = value == true ? '<true/>' : '<false/>';
      } else if (type == 'int' || type == 'double') {
        replacement = '<$type>$value</$type>';
      } else {
        throw 'Unsupported type: $type';
      }

      if (keyIndex != -1) {
        // Replace the existing value
        iosLines[keyIndex + 1] = '\t$replacement';
      } else {
        // Find the index of the closing tag of the root dictionary
        // int dictCloseIndex = iosLines.lastIndexWhere((line) => line.trim() == '</dict>');
        // if (dictCloseIndex != -1) {
        //   // Insert before the closing </dict> tag
        //   iosLines.insertAll(dictCloseIndex, [
        //     '\t<key>$key</key>',
        //     '\t$replacement',
        //   ]);
        // } else {
        //   throw 'Invalid plist format: missing </dict>';
        // }
      }
      iosFile.writeAsStringSync(iosLines.join('\n'));
    }
  } catch (e) {
    print('Error updating config: $e');
  }
}
