import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';
import 'package:connect_flutter_plugin/tl_http_request_data.dart';
import 'package:connect_flutter_plugin/tl_http_response_data.dart';

class TlHttpLogger {
  String mUrl = "";
  String mDescription = "";
  int mStatusCode = 0;
  int mResponseSize = 0;
  int mInitTime = 0;
  int mLoadTime = 0;

  TlHttpLogger();

  void logRequest(RequestData data) {
    mUrl = data.url.toString();
    mDescription = data.method.toString().split('.')[1];
    mInitTime = DateTime.now().millisecondsSinceEpoch;
  }

  void logResponse(ResponseData data) {
    mStatusCode = data.statusCode;
    mResponseSize = data.contentLength ?? 0;
    mLoadTime = DateTime.now().millisecondsSinceEpoch;

    PluginConnect.tlConnection(
        url: mUrl,
        description: mDescription,
        statusCode: mStatusCode,
        responseSize: mResponseSize,
        initTime: mInitTime,
        loadTime: mLoadTime);
  }
}
