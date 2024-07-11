import 'append_map_ids_model.dart';
import 'auto_layout_model.dart';

class LayoutConfig {
  AutoLayout? autoLayout;
  AppendMapIds? appendMapIds;

  LayoutConfig({this.autoLayout, this.appendMapIds});

  LayoutConfig.fromJson(Map<String, dynamic> json) {
    autoLayout = json['AutoLayout'] != null
        ? AutoLayout.fromJson(json['AutoLayout'])
        : null;

    appendMapIds = json['AppendMapIds'] != null
        ? AppendMapIds.fromJson(json['AppendMapIds'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (autoLayout != null) {
      data['AutoLayout'] = autoLayout!.toJson();
    }
    if (appendMapIds != null) {
      data['AppendMapIds'] = appendMapIds!.toJson();
    }
    return data;
  }
}
