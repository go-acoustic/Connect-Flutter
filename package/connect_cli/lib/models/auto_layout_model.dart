import 'global_screen_settings_model.dart';

class AutoLayout {
  GlobalScreenSettings? globalScreenSettings;

  AutoLayout({this.globalScreenSettings});

  AutoLayout.fromJson(Map<String, dynamic> json) {
    globalScreenSettings = json['GlobalScreenSettings'] != null
        ? GlobalScreenSettings.fromJson(json['GlobalScreenSettings'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (globalScreenSettings != null) {
      data['GlobalScreenSettings'] = globalScreenSettings!.toJson();
    }
    return data;
  }
}
