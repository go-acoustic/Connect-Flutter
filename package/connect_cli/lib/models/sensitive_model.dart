class Sensitive {
  String? capitalCaseAlphabet;
  String? number;
  String? smallCaseAlphabet;
  String? symbol;

  Sensitive(
      {this.capitalCaseAlphabet,
      this.number,
      this.smallCaseAlphabet,
      this.symbol});

  Sensitive.fromJson(Map<String, dynamic> json) {
    capitalCaseAlphabet = json['capitalCaseAlphabet'];
    number = json['number'];
    smallCaseAlphabet = json['smallCaseAlphabet'];
    symbol = json['symbol'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    if (capitalCaseAlphabet != null) {
      data['capitalCaseAlphabet'] = capitalCaseAlphabet;
    }

    if (number != null) {
      data['number'] = number;
    }

    if (smallCaseAlphabet != null) {
      data['smallCaseAlphabet'] = smallCaseAlphabet;
    }

    if (symbol != null) {
      data['symbol'] = symbol;
    }

    return data;
  }
}
