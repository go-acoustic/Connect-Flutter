class AppendMapIds {
  Map<String, dynamic>? appendMapIds;

  AppendMapIds({this.appendMapIds});

  AppendMapIds.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = {};

    json.forEach((key, value) {
      data[key] = {"mid": value["mid"]};
    });

    appendMapIds = data;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    if (appendMapIds != null) {
      appendMapIds!.forEach((key, value) {
        data[key] = value;
      });
    }
    return data;
  }
}
