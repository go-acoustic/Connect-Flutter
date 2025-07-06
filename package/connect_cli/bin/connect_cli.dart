import 'dart:convert';
import 'dart:io';
import 'package:connect_cli/connect_cli.dart' as connect_cli;
import 'package:connect_cli/models/basic_config_model.dart';

void main(List<String> arguments) async {
  stdout.writeln('connect_cli working...');

  String? appKey;
  String? postmessageURL;

  if (arguments.length == 2) {
    appKey = arguments[0];
    postmessageURL = arguments[1];

    stdout.writeln('Arguments passed in: $appKey, $postmessageURL \n');
  }

  // For test only
  // String currentProjectDir =
  //     "/Users/changjieyang/developer/Acoustic/Connect-Flutter-beta/example/gallery";

  String currentProjectDir = Directory.current.path;
  String pluginRoot = connect_cli.getPluginPath(currentProjectDir);
  stdout.writeln('currentProjectDir:  $currentProjectDir');
  stdout.writeln('pluginRoot:  $pluginRoot \n');

  // Setup ConnectConfig.json
  stdout.writeln('Setup ConnectConfig.json');
  connect_cli.setupJsonConfig(
      pluginRoot, currentProjectDir, appKey, postmessageURL);

  // Setup mobile platforms
  stdout.writeln('Setup mobile platforms');
  connect_cli.setupMobilePlatforms(pluginRoot, currentProjectDir);

  // Update config
  var input = File("$currentProjectDir/ConnectConfig.json").readAsStringSync();
  Map<String, dynamic> configMap = jsonDecode(input);
  BasicConfig basicConfig = BasicConfig.fromJson(configMap);

  stdout.writeln('Updating LayoutConfig');
  connect_cli.updateConnectLayoutConfig(basicConfig, currentProjectDir);

  // Update Tealeaf basic config.
  basicConfig.connect!.toJson().forEach((key, value) async {
    if (key == "layoutConfig") return;

    if (key == "AppKey" && appKey != null) {
      value = appKey;
    }
    if (key == "PostMessageUrl" && postmessageURL != null) {
      value = postmessageURL;
    }

    connect_cli.updateBasicConfig(pluginRoot, currentProjectDir, key, value);
  });

  stdout.writeln('connect_flutter_plugin configured');
  stdout.writeln(
      'connect_flutter_plugin running build and pub get for the Flutter app. \n');

  // Then, clean and rebuild the Flutter app:
  Process.runSync('flutter', ['build'], runInShell: true);
  Process.runSync('flutter', ['pub', 'get'], runInShell: true);
}
