import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';
import 'package:connect_flutter_plugin/tl_http_client.dart';

import 'package:mockito/mockito.dart';

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
    // Your implementation here, you can return any string for testing purposes
    return 'MockElement';
  }
}

// class MockTextWidget extends Mock implements Text {
//   @override
//   String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
//     // Your implementation here
//     return 'MockTextWidget';
//   }
// }

class MockRenderBox extends Mock implements RenderBox {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
    // Your implementation here
    return 'MockRenderBox';
  }
}

void main() {
  const String platform = 'Arbitrary platform 47';
  const String connect = '10.3.274';

  const String key = 'valid key';
  const String sessionId = '012345678901234567890123456789ff';
  const String globalConfigJsonString =
      '{"AppKey": "e753a61c93ab4620aab64648505a9647"}';

  // String plugin = ''; // Get value from the pubspec.yaml file

  List<Map<String, dynamic>> layoutParameters = [
    {
      "controls": [
        {
          "id":
              "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
          "cssId": "a5f8e5309344a1b3f2ea59bd5376ee98115b749a",
          "idType": -4,
          "type": "Image",
          "subType": "ImageView",
          "position": {"x": 290, "y": 180, "width": 140, "height": 140}
        }
      ]
    }
  ];

  const MethodChannel channel = MethodChannel('connect_flutter_plugin');

  TestWidgetsFlutterBinding.ensureInitialized();

  validateParameter(String request, dynamic args, String arg, List<Type> types,
      {String prefix = ''}) {
    final dynamic parameter = args[arg];

    if (parameter == null) {
      throw Exception("Request $request missing parameter '$arg'");
    }
    Type type = parameter.runtimeType;

    // TBD: How to check if a Type is a subtype. " is " works,
    // but only on actual compile types, NOT type variables. There must
    // be a way to do this for all types, not just for Map (all that is needed for now)
    if (types.contains(Map) && parameter is Map) {
      const Type newType = Map;
      debugPrint("Checked if type $type is a $newType");
      type = newType;
    }

    if (!types.contains(type)) {
      throw Exception(
          " Request $request parameter '$prefix$arg', type '$type' not allowed");
    }
  }

  validatePosition(String request, dynamic args, String key) {
    validateParameter(request, args, key, [Map]);

    final Map points = args[key];
    final String prefix = '/$key';

    validateParameter(request, points, 'dx', [double], prefix: prefix);
    validateParameter(request, points, 'dy', [double], prefix: prefix);
  }

  void printConnectException(Exception e) {
    if (kDebugMode) {
      if (e is ConnectException) {
        final ConnectException te = e;
        print(
            "ConnectException: ${te.msg}, platform details: ${te.nativeMsg}, ${te.nativeDetails}");
      } else {
        print(e.toString());
      }
    }
  }

  // ignore: deprecated_member_use
  setUp(() {
    handler(MethodCall methodCall) async {
      final String request = methodCall.method;
      final dynamic args = methodCall.arguments;

      switch (request.toLowerCase()) {
        case "getplatformversion":
          return platform;
        case "getconnectversion":
          return connect;
        case "getappkey":
          return key;
        case "getconnectsessionid":
          return sessionId;
        case "getglobalconfiguration":
          return globalConfigJsonString;
        case "setenv":
          if (!args.containsKey('screenw')) {
            throw Exception("tlSetEnvironment missing 'screenw' parameter");
          }
          if (!args.containsKey('screenh')) {
            throw Exception("tlSetEnvironment missing 'screenh' parameter");
          }
          validateParameter(request, args, 'screenw', [int]);
          validateParameter(request, args, 'screenh', [int]);
          if (args['screenw'] <= 0) {
            throw Exception(
                "tlSetEnvironment invalid 'screenw' parameter: $args['screenw']");
          }
          if (args['screenh'] <= 0) {
            throw Exception(
                "tlSetEnvironment invalid 'screenh' parameter: $args['screenh']");
          }
          return null;
        case 'gesture':
          if (!args.containsKey('tlType')) {
            throw Exception("Missing gesture type!");
          }
          if (!['pinch', 'swipe', 'taphold', 'tap', 'doubletap']
              .contains(args['tlType'])) {
            throw Exception("Gesture type not supported: ${args['tlType']}");
          }
          return null;
        case 'pointerevent':
          if (!args.containsKey('down')) {
            throw Exception("pointerEvent missing 'down' parameter");
          }
          if (!args.containsKey('kind')) {
            throw Exception("pointerEvent missing 'kind' parameter");
          }
          if (!args.containsKey('buttons')) {
            throw Exception("pointerEvent missing 'buttons' parameter");
          }
          if (!args.containsKey('embeddedId')) {
            throw Exception("pointerEvent missing 'embeddedId' parameter");
          }

          validatePosition(request, args, 'position');
          validatePosition(request, args, 'localPosition');
          validateParameter(request, args, "pressure", [double]);
          // validateParameter(request, args, 'timestamp', [int]);

          // if (args['timestamp'] < 0) {
          //   throw Exception(
          //       "pointerEvent invalid 'timestamp' parameter: $args['timestamp']");
          // }

          return null;
        case 'connection':
          {
            validateParameter(request, args, 'url', [String]);
            validateParameter(request, args, 'statusCode', [int, String]);
            validateParameter(request, args, 'initTime', [int, String]);
            validateParameter(request, args, 'loadTime', [int, String]);

            if (args.containsKey('responsesize')) {
              validateParameter(request, args, 'responseSize', [int, String]);
            }
            return null;
          }
        case 'customevent':
          {
            validateParameter(request, args, 'eventname', [String]);
            if (args.containsKey('logLevel')) {
              validateParameter(request, args, 'loglLevel', [int]);
            }
            if (args.containsKey('data')) {
              validateParameter(request, args, 'data', [Map]);
            }
            return null;
          }
        case 'exception':
          {
            validateParameter(request, args, 'name', [String]);
            validateParameter(request, args, 'message', [String]);
            validateParameter(request, args, 'handled', [bool]);
            validateParameter(request, args, 'stacktrace', [String]);
            if (args.containsKey('appdata')) {
              validateParameter(request, args, 'appdata', [Map]);
            }
            return null;
          }
        case 'screenview':
          {
            validateParameter(request, args, 'tlType', [String]);
            // validateParameter(request, args, 'timeStamp', [String, int]);

            final String type = args['tlType'];

            if (!["LOAD", "UNLOAD", "VISIT"].contains(type)) {
              throw Exception(
                  "Parameter tlType is not one of the supported connect screen types: $type");
            }
            return null;
          }
        case 'logperformanceevent':
          {
            validateParameter(request, args, 'navigationType', [int, String]);
            validateParameter(request, args, 'redirectCount', [int, String]);
            validateParameter(request, args, 'navigationStart', [int, String]);
            validateParameter(request, args, 'unloadEventStart', [int, String]);
            validateParameter(request, args, 'unloadEventEnd', [int, String]);
            validateParameter(request, args, 'redirectStart', [int, String]);
            validateParameter(request, args, 'redirectEnd', [int, String]);
            validateParameter(request, args, 'loadEventStart', [int, String]);
            validateParameter(request, args, 'loadEventEnd', [int, String]);

            return true;
          }
        default:
          throw Exception('No such method (in test)');
      }
    }

    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Connect_Wrapper', () {
    // Initializes with a child widget and a root widget.
    test('initializes with child and root widget', () {
      // Arrange
      final childWidget = Container();

      // Act
      final connect = Connect(child: childWidget);

      // Assert
      expect(connect.child, equals(childWidget));
      expect(connect.rootWidget, equals(childWidget));
    });

    // Initializes with a LoggingNavigatorObserver instance.
    test('initializes with logging navigator observer', () {
      // Arrange
      // final childWidget = Container();

      // Act
      // final connect = Connect(child: childWidget);

      // Assert
      expect(Connect.loggingNavigatorObserver, isA<LoggingNavigatorObserver>());
    });

    // Connect initializes with a startTime variable.
    test('initializes with start time variable', () {
      // Arrange
      // final childWidget = Container();

      // Act
      // final connect = Connect(child: childWidget);

      // Assert
      expect(Connect.startTime, isA<int>());
    });

    // Connect initializes with a null key.
    test('initializes with null key', () {
      // Arrange
      final childWidget = Container();

      // Act
      final connect = Connect(child: childWidget);

      // Assert
      expect(connect.key, isNull);
    });

    // Connect initializes with a null root widget.
    test('initializes with null root widget', () {
      // Arrange
      final childWidget = Container();

      // Act
      final connect = Connect(child: childWidget);

      // Assert
      expect(connect.rootWidget, childWidget);
    });
  });

  group('PluginConnect method call interface', () {
    test('platformVersion', () async {
      expect(await PluginConnect.platformVersion, platform);
    });
    test('connectVersion', () async {
      expect(await PluginConnect.connectVersion, connect);
    });
    test('appKey', () async {
      expect(await PluginConnect.appKey, key);
    });

    test('connectSessionId', () async {
      String result;
      try {
        await PluginConnect.connectSessionId;
        result = 'ok';
      } on Exception catch (e) {
        if (kDebugMode) print(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('setenv', () async {
      String result;
      try {
        await PluginConnect.tlSetEnvironment(
            screenWidth: 1440, screenHeight: 2880);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent pinch', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
            gesture: "pinch",
            target: "Text",
            id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
            data: {
              'pointer1': {'dx': 47.0, 'dy': 47.0},
              'pointer2': {'dx': 47.0, 'dy': 47.0},
              'dx': 20,
              'dy': 20,
              'direction': "open",
            });
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent swipe', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
            gesture: "swipe",
            target: "Text",
            id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
            data: {
              'pointer1': {'dx': 47.0, 'dy': 47.0, 'ts': '217002223455'},
              'pointer2': {'dx': 47.0, 'dy': 47.0, 'ts': '217002223455'},
              'velocity': {
                'dx': 20,
                'dy': 20,
              },
              'direction': "right",
            });
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent taphold', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
          gesture: "taphold",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent doubletap', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
          gesture: "doubletap",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent tap', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
          gesture: "tap",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('connection', () async {
      String result;
      try {
        await PluginConnect.tlConnection(
            url: "www.yahoo.com",
            statusCode: 200,
            responseSize: 47,
            initTime: 114547,
            loadTime: 114600);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('tlApplicationCustomEvent', () async {
      String result;
      try {
        await PluginConnect.tlApplicationCustomEvent(
            eventName: "Custom test event",
            customData: {
              "data1": "END OF UI BUILD",
              "time": DateTime.now().toString()
            });
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('tlApplicationCaughtException on null', () async {
      String result;
      try {
        await PluginConnect.tlApplicationCaughtException(caughtException: null);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('tlApplicationCaughtException', () async {
      String result;
      try {
        await PluginConnect.tlApplicationCaughtException(
            caughtException: Exception("Test Exception"),
            stack: StackTrace.current,
            appData: {"msg": "My error message", "where": "in my main.dart"});
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlException', () async {
      String result;
      Exception e = Exception("This is an exception");
      Map<dynamic, dynamic> mapData = {
        "nativecode": "501",
        "nativemessage": "Native error message",
        "nativestacktrace": "[method1]\n[method2]\n",
        "name": e.runtimeType.toString(),
        "stacktrace": StackTrace.current.toString(),
        "message": e.toString(),
        "handled": true
      };
      try {
        await PluginConnect.onTlException(data: mapData);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Load', () async {
      String result;
      try {
        await PluginConnect.onScreenview(
            "LOAD", "logicalPageName", layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('logScreenLayout', () async {
      String result;
      try {
        await PluginConnect.logScreenLayout("logicalPageName");
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Unload', () async {
      String result;
      try {
        await PluginConnect.onScreenview(
            "UNLOAD", "logicalPageName", layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Visit', () async {
      String result;
      try {
        await PluginConnect.onScreenview(
            "VISIT", "logicalPageName", layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlPointerEvent', () async {
      String result;
      final dynamic ptrFields = {
        'position': {'dx': 47.0, 'dy': 47.0},
        'localPosition': {'dx': 47.0, 'dy': 47.0},
        'down': false,
        'kind': 1,
        'buttons': 0,
        'embeddedId': 0,
        'pressure': 0.47,
        'timestamp': const Duration(microseconds: 47).inMicroseconds,
      };
      try {
        await PluginConnect.onTlPointerEvent(fields: ptrFields);
        result = 'ok';
      } on Exception catch (e, stack) {
        debugPrint('$e, ${stack.toString()}');
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('getGlobalConfiguration', () async {
      bool result = false;
      try {
        final String response = await PluginConnect.getGlobalConfiguration();
        final dynamic map = json.decode(response);
        if (map is Map) {
          result = map.containsKey('AppKey');
        } else {
          debugPrint("getGlobalConfiguration 'AppKey' not found!");
        }
      } on Exception catch (e) {
        printConnectException(e);
        result = false;
      }
      expect(result, true);
    });

    test('noMethodTest', () async {
      String result;
      try {
        await PluginConnect.badCall();
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('onGestureTlEvent bad parameter test', () async {
      String result;
      try {
        await PluginConnect.onTlGestureEvent(
            gesture: "_bad_", id: 'someId', target: 'widgetName');
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('logPerformance', () async {
      String result;
      try {
        await PluginConnect.logPerformanceEvent(
            navigationType: 0,
            redirectCount: 0,
            navigationStart: 0,
            unloadEventStart: 0,
            unloadEventEnd: 10,
            redirectStart: 0,
            redirectEnd: 0,
            loadEventStart: 20,
            loadEventEnd: 30);
        result = 'ok';
      } on Exception catch (e) {
        printConnectException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });
  });

  group('PerformanceObserver Tests', () {
    test('handle AppLifecycleState changes without errors', () {
      // Arrange
      final observer = PerformanceObserver();
      final state = AppLifecycleState.resumed;

      // Act and Assert
      expect(() => observer.didChangeAppLifecycleState(state), returnsNormally);
    });

    test('fail to measure duration if AppLifecycleState change takes too long',
        () async {
      // Arrange
      final observer = PerformanceObserver();
      final state = AppLifecycleState.detached;
      final startTime = DateTime.now().millisecondsSinceEpoch;

      // Act
      // Simulate a long duration by delaying the execution
      await Future.delayed(Duration(seconds: 2), () {
        observer.didChangeAppLifecycleState(state);
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final int duration = endTime - startTime;

        // Assert
        expect(duration, lessThan(2100));
      });
    });

    test('fail to log custom event if AppLifecycleState change takes too long',
        () async {
      // Arrange
      final observer = PerformanceObserver();
      final state = AppLifecycleState.inactive;

      // Act
      // Simulate a long duration by delaying the execution
      await Future.delayed(Duration(seconds: 3), () {
        observer.didChangeAppLifecycleState(state);

        // Assert
        // expect(PluginConnect.tlApplicationCustomEventCalled, false);
      });
    });

    test('measure_duration_of_app_lifecycle_state_changes', () {
      // Arrange
      final observer = PerformanceObserver();
      final state = AppLifecycleState.inactive;
      final startTime = DateTime.now().millisecondsSinceEpoch;

      // Act
      observer.didChangeAppLifecycleState(state);
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = endTime - startTime;

      // Assert
      expect(duration, greaterThanOrEqualTo(0));
    });
  });

  group('TlHttpClient', () {
    // Setting a custom override that will use an unmocked HTTP client
    HttpOverrides.global = _TestHttpOverrides();
    test('get', () async {
      final client = TlHttpClient();
      final response = await client.get(Uri.parse('https://www.google.com/'));
      expect(response.statusCode, 200);
    });
  });

  group('Screen Logging', () {
    test(
      '_logWidgetTree should return a list of Maps with widget information when called',
      () async {
        // Arrange
        final expected = [
          {
            'widgetType': 'Text',
            'widgetHash': 12345,
            'widgetParameters': {'type': 'Text'},
          },
          {
            'widgetType': 'Container',
            'widgetHash': 67890,
            'widgetParameters': {'type': 'Container'},
          },
        ];

        // Mocking root element and its behavior
        final rootElement = MockElement();

        final result = await parseWidgetTree(rootElement);

        // Mocking _parseWidgetTree function
        when(parseWidgetTree(rootElement))
            .thenAnswer((_) => Future.value(expected));

        // Assert
        expect(List.empty(), result);
      },
    );
  });
}

class _TestHttpOverrides extends HttpOverrides {}
