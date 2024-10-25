
class AutoLayout {
  Map<String, dynamic>? json;

  AutoLayout({this.json});

  AutoLayout.fromJson(Map<String, dynamic> this.json);

  Map<String, dynamic> toJson() {
    return json ?? {};
  }
}
