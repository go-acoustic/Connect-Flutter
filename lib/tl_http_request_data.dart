import 'dart:convert';

import 'package:connect_flutter_plugin/tl_http_methods.dart';

// Object used to store the http request data
class RequestData {
  Method method;
  Uri url;
  Map<String, String>? headers;
  dynamic body;
  Encoding? encoding;

  RequestData({
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.encoding,
  });
}
