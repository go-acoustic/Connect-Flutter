import 'dart:io';
import 'package:path/path.dart' as path;

void updateConfig(String projectDir, String key, dynamic value, String type) {
  try {
    // Update Android Configuration
    String androidPath = path.join(projectDir,
        'android/app/src/main/assets/TealeafBasicConfig.properties');
    File androidFile = File(androidPath);
    if (androidFile.existsSync()) {
      String androidContent = androidFile.readAsStringSync();
      RegExp androidRegExp = RegExp('^$key=.*', multiLine: true);
      String androidReplacement = '$key=$value';
      if (androidRegExp.hasMatch(androidContent)) {
        androidContent =
            androidContent.replaceAll(androidRegExp, androidReplacement);
      } else {
        androidContent += '\n$androidReplacement';
      }
      androidFile.writeAsStringSync(androidContent);
    }

    // Update iOS Configuration
    String iosPath = path.join(projectDir,
        'ios/Pods/TealeafDebug/SDKs/iOS/Debug/TLFResources.bundle/TealeafBasicConfig.plist');
    File iosFile = File(iosPath);
    if (iosFile.existsSync()) {
      List<String> iosLines = iosFile.readAsLinesSync();
      int keyIndex =
          iosLines.indexWhere((line) => line.trim() == '<key>$key</key>');

      String replacement;
      if (type == 'String') {
        replacement = '<string>$value</string>';
      } else if (type == 'bool') {
        replacement =
            '<true/>'; // Assuming value is always true for bool. Handle false case as needed.
      } else if (type == 'int' || type == 'double') {
        replacement = '<$type>$value</$type>';
      } else {
        throw 'Unsupported type: $type';
      }

      if (keyIndex != -1) {
        // Replace the existing value
        iosLines[keyIndex + 1] = '\t$replacement';
      } else {
        // Add new key-value pair
        iosLines.addAll(['\t<key>$key</key>', '\t$replacement']);
      }
      iosFile.writeAsStringSync(iosLines.join('\n'));
    }
  } catch (e) {
    print('Error updating config: $e');
  }
}

void main(List<String> args) {
  if (args.length < 5) {
    print('Usage: dart updateConfig.dart <projectDir> <KEY> <VALUE> <TYPE>');
    exit(1);
  }

  String projectDir = args[0];
  String key = args[1];
  String value = args[2];
  String type = args[3];

  updateConfig(projectDir, key, value, type);

  print('updateConfig done.');
}
