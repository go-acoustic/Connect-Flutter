import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:connect_flutter_plugin/tl_http_logger.dart';
import 'package:connect_flutter_plugin/tl_http_methods.dart';
import 'package:connect_flutter_plugin/tl_http_request_data.dart';
import 'package:connect_flutter_plugin/tl_http_response_data.dart';

class TlHttpClient extends http.BaseClient {
  Duration? requestTimeout;
  TlHttpLogger httpLogger = TlHttpLogger();

  static final Client _client = Client();

  TlHttpClient([this.requestTimeout = const Duration(seconds: 10)]);

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) =>
      _sendUnstreamed('HEAD', url, headers);

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) =>
      _sendUnstreamed('GET', url, headers);

  @override
  Future<Response> post(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _sendUnstreamed('POST', url, headers, body, encoding);

  @override
  Future<Response> put(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _sendUnstreamed('PUT', url, headers, body, encoding);

  @override
  Future<Response> patch(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _sendUnstreamed('PATCH', url, headers, body, encoding);

  @override
  Future<Response> delete(Uri url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _sendUnstreamed('DELETE', url, headers);

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    return get(url, headers: headers).then((response) {
      _checkResponseSuccess(url, response);
      return response.body;
    });
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    return get(url, headers: headers).then((response) {
      _checkResponseSuccess(url, response);
      return response.bodyBytes;
    });
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  Future<Response> _sendUnstreamed(
      String method, url, Map<String, String>? headers,
      [dynamic body, Encoding? encoding]) async {
    if (url is String) url = Uri.parse(url);
    var request = Request(method, url);

    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast<int>();
      } else if (body is Map) {
        request.bodyFields = body.cast<String, String>();
      } else {
        throw ArgumentError('Invalid request body "$body".');
      }
    }

    // Request logging
    httpLogger.logRequest(
      RequestData(
        method: methodFromString(method),
        encoding: encoding,
        body: body,
        url: url,
        headers: headers ?? <String, String>{},
      ),
    );

    var stream = requestTimeout == null
        ? await send(request)
        : await send(request).timeout(requestTimeout!);

    return Response.fromStream(stream).then((response) {
      var responseData = ResponseData.fromHttpResponse(response);

      // Response logging
      httpLogger.logResponse(responseData);

      var resultResponse = Response(
        responseData.body,
        responseData.statusCode,
        headers: responseData.headers ?? {},
        persistentConnection: responseData.persistentConnection ?? false,
        isRedirect: responseData.isRedirect ?? false,
        request: Request(
          responseData.method.toString().substring(7),
          Uri.parse(responseData.url),
        ),
      );

      return resultResponse;
    }).catchError((err) {
      throw ClientException(err.toString().replaceAll("Exception:", ""), url);
    });
  }

  void _checkResponseSuccess(url, Response response) {
    if (response.statusCode < 400) return;
    var message = 'Request to $url failed with status ${response.statusCode}';
    if (response.reasonPhrase != null) {
      message = '$message: ${response.reasonPhrase}';
    }
    if (url is String) url = Uri.parse(url);
    throw ClientException('$message.', url);
  }

  @override
  void close() {
    _client.close();
  }
}
