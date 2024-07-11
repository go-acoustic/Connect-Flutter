import 'package:http/http.dart';
import 'package:connect_flutter_plugin/tl_http_methods.dart';

// Object used to store the http response data
class ResponseData {
  String url;
  int statusCode;
  Method method;
  Map<String, String>? headers;
  String body;
  List<int>? bodyBytes;
  int? contentLength;
  bool? isRedirect;
  bool? persistentConnection;

  ResponseData({
    required this.method,
    required this.url,
    required this.statusCode,
    this.headers,
    required this.body,
    this.bodyBytes,
    this.contentLength,
    this.isRedirect,
    this.persistentConnection,
  });

  factory ResponseData.fromHttpResponse(Response response) {
    return ResponseData(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
      bodyBytes: response.bodyBytes,
      contentLength: response.contentLength,
      isRedirect: response.isRedirect,
      url: response.request!.url.toString(),
      method: methodFromString(response.request!.method),
      persistentConnection: response.persistentConnection,
    );
  }
}
