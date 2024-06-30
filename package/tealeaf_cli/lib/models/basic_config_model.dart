import 'connect_model.dart';

class BasicConfig {
  Connect? connect;

  BasicConfig({this.connect});

  BasicConfig.fromJson(Map<String, dynamic> json) {
    connect =
        json['Connect'] != null ? Connect.fromJson(json['Connect']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (connect != null) {
      data['Connect'] = connect!.toJson();
    }
    return data;
  }
}
