import 'append_map_ids_model.dart';

class LayoutConfig {
  Map<String, dynamic>? autoLayout;
  AppendMapIds? appendMapIds;

  LayoutConfig({this.autoLayout, this.appendMapIds});

  LayoutConfig.fromJson(Map<String, dynamic> json) {
    autoLayout = json['AutoLayout'];

    appendMapIds = json['AppendMapIds'] != null
        ? AppendMapIds.fromJson(json['AppendMapIds'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (autoLayout != null) {
      data['AutoLayout'] = autoLayout;
    }
    if (appendMapIds != null) {
      data['AppendMapIds'] = appendMapIds!.toJson();
    }
    return data;
  }
}
