import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:connect_flutter_plugin/connect_flutter_plugin_helper.dart';

import 'logger.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';

// Export logging types for SDK users
export 'logger.dart' show ConnectLogLevel, LoggerConfig;

/// A widget that logs UI change events.
///
/// This [Connect] widget listens to pointer events such as onPointerDown, onPointerUp, onPointerMove, and onPointerCancel.
/// It logs these events by printing them to the console if the app is running in debug mode.
/// Use this widget to log UI changes and interactions during development and debugging.
class Connect extends StatelessWidget {
  /// The child widget to which the [Connect] is applied.
  final Widget child;
  // final Function(GestureEvent) onGesture;
  final Widget rootWidget; // Store a reference to the root widget

  /// Use as reference time to calculate widget load time
  static int startTime = DateTime.now().millisecondsSinceEpoch;

  static bool isSwiping = false;

  // Create an instance of LoggingNavigatorObserver
  static final LoggingNavigatorObserver loggingNavigatorObserver =
      LoggingNavigatorObserver();

  /// Constructs a [Connect] with the given child.
  ///
  /// The [child] parameter is the widget to which the [Connect] is applied.
  Connect({Key? key, required this.child})
    : rootWidget = child,
      super(key: key);

  static void init() {
    startTime = DateTime.now().millisecondsSinceEpoch;

    /// Handles screen layout data, and Gesture events
    TlBinder().init();
  }

  static bool getIsSwiping() {
    return isSwiping;
  }

  @override
  Widget build(BuildContext context) {
    init();
    UserInteractionLogger.initialize();

    Widget? widget = context.widget;

    tlLogger.t(
      'GestureDetector Build WIDGET: ${widget.runtimeType.toString()} ${widget.hashCode}',
    );

    final WidgetPath wp = WidgetPath.create(context, hash: true);
    wp.addInstance(widget.hashCode);
    wp.addParameters(<String, dynamic>{'type': widget.runtimeType.toString()});

    return NotificationListener(
      onNotification: (Notification? notification) {
        if (notification is ScrollStartNotification) {
          final ScrollStartNotification scrollStartNotification = notification;
          final DragStartDetails? details = scrollStartNotification.dragDetails;
          TlBinder().startScroll(
            details?.globalPosition,
            details?.sourceTimeStamp,
          );
        } else if (notification is ScrollUpdateNotification) {
          final ScrollUpdateNotification scrollUpdateNotification =
              notification;
          final DragUpdateDetails? details =
              scrollUpdateNotification.dragDetails;
          TlBinder().updateScroll(
            details?.globalPosition,
            details?.sourceTimeStamp,
          );
        } else if (notification is ScrollEndNotification) {
          final ScrollEndNotification scrollEndNotification = notification;
          final DragEndDetails? details = scrollEndNotification.dragDetails;
          TlBinder().endScroll(details?.velocity);
          tlLogger.t('Scroll notification completed');
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Listener(
          onPointerUp: (details) {
            ConnectHelper.pointerEventHelper("UP", details);

            if (!Connect.isSwiping) {
              // Handle onPointerUp event here
              // Start time as reference when there's navigation change
              Connect.startTime = DateTime.now().millisecondsSinceEpoch;

              if (ConnectHelper.captureScreen) {
                logWidgetTree()
                    .then((result) async {
                      var touchedTarget = findTouchedWidget(
                        context,
                        details.position,
                      );

                      // Handle onTap gesture and Pass the result to Connect plugin
                      await PluginConnect.onTlGestureEvent(
                        gesture: "tap",
                        id: wp.widgetPath(),
                        target: touchedTarget,
                        data: null,
                        layoutParameters: result,
                      );
                    })
                    .catchError((error) {
                      // Handle errors if the async function throws an error
                      tlLogger.e('Error: $error');
                    });
              }
            }
          },
          onPointerDown: (details) {
            ConnectHelper.pointerEventHelper("DOWN", details);
          },
          onPointerMove: (details) {
            tlLogger.t(
              "Gesture move, swipe event checkForScroll() will fire..",
            );
            ConnectHelper.pointerEventHelper("MOVE", details);
          },
          child: child,
        ),
      ),
    );
  }

  ///
  /// Converts erorr details
  ///
  static Map<String, dynamic> flutterErrorDetailsToMap(
    FlutterErrorDetails details,
  ) {
    return {
      'message': details.exception.toString(),
      'exceptionType': details.exception.runtimeType.toString(),
      'stacktrace': details.stack.toString(),
      'library': details.library,
      'name': details.context.toString(),
      'silent': details.silent,
      'handled': false,
      // Add other fields as needed
    };
  }

  /// Use HitBox test to find touched item on the screen.
  ///
  /// Since the results are just a list of RenderObjects, we'll need to parse the Widget info.
  static String findTouchedWidget(
    final BuildContext context,
    final Offset position,
  ) {
    String jsonString = "";

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final RenderBox renderBox = renderObject;
      final Offset localOffset = renderBox.globalToLocal(position);

      // Perform hit-testing
      final BoxHitTestResult result = BoxHitTestResult();
      renderBox.hitTest(result, position: localOffset);

      // Analyze the hit result to find the widget that was touched.
      for (HitTestEntry entry in result.path) {
        if (entry is! BoxHitTestEntry || entry is SliverHitTestEntry) {
          final targetWidget = entry.target;

          final widgetString = targetWidget.toString();
          jsonString = jsonEncode(widgetString);

          break;
        }
      }
    }
    return jsonString == "" ? "FlutterSurfaceView" : jsonString;
  }
}

/// A navigator observer that logs navigation events using the Connect plugin.
///
/// This [NavigatorObserver] subclass logs the navigation events, such as push and pop,
/// and communicates with the Connect plugin to log the screen layout events.
class LoggingNavigatorObserver extends NavigatorObserver {
  /// Constructs a [LoggingNavigatorObserver].
  LoggingNavigatorObserver() : super();

  /// Helper function to extract a meaningful route name from various route types
  String _getRouteName(Route<dynamic> route) {
    // First, try to get the name from route settings
    if (route.settings.name != null && route.settings.name!.isNotEmpty) {
      return route.settings.name!;
    }

    tlLogger.t(
      'PluginConnect._getRouteName - Missing:route.settings.name. Will adjust based on route type.',
    );

    // Handle different route types
    final String routeType = route.runtimeType.toString();

    // For ModalBottomSheetRoute and similar routes, use the route type
    if (routeType.contains('ModalBottomSheetRoute')) {
      return 'ModalBottomSheet';
    }

    if (routeType.contains('DialogRoute')) {
      return 'Dialog';
    }

    if (routeType.contains('PopupRoute')) {
      return 'Popup';
    }

    if (routeType.contains('PageRoute')) {
      return 'Page_${route.hashCode}';
    }

    // For any other route type, use the runtime type with hash
    return '${routeType}_${route.hashCode}';
  }

  /// Called when a route is pushed onto the navigator.
  ///
  /// The `route` parameter represents the route being pushed onto the navigator.
  /// The `previousRoute` parameter represents the route that was previously on top of the navigator.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = endTime - Connect.startTime;

      var logicalPageName = _getRouteName(route);
      ConnectHelper.currentLogicalPageName = logicalPageName;

      tlLogger.t(
        'PluginConnect.didPush - Pushed original route name: $logicalPageName',
      );

      // Load AutoLayout JSON configuration
      final jsonString = PluginConnect.getStringItemForKey(
        'AutoLayout',
        'Tealeaf',
      );
      // tlLogger.d('PluginConnect getStringItemForKey: $jsonString');
      jsonString
          .then((result) {
            if (result != null &&
                ConnectHelper.canCaptureScreen(logicalPageName, result)) {
              // Fix up name
              logicalPageName = ConnectHelper.updateLogicalPageName(
                logicalPageName,
                result,
              );
              ConnectHelper.currentLogicalPageName = logicalPageName;

              /// Calls Connect plugin to log the screen layout
              PluginConnect.logScreenLayout(logicalPageName);
              tlLogger.t(
                'PluginConnect.logScreenLayout - Pushed $logicalPageName',
              );
            }
          })
          .catchError((error) {
            tlLogger.e('Error: $error');
          });

      PluginConnect.logPerformanceEvent(
        loadEventStart: 0,
        loadEventEnd: duration,
      );
    });
  }

  /// Called when a route is popped from the navigator.
  ///
  /// The `route` parameter represents the route being popped from the navigator.
  /// The `previousRoute` parameter represents the route that will now be on top of the navigator.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final routeName = _getRouteName(route);
    final previousRouteName = previousRoute != null
        ? _getRouteName(previousRoute)
        : "";

    PluginConnect.logScreenViewContextUnLoad(routeName, previousRouteName);

    tlLogger.t('PluginConnect.logScreenViewContextUnLoad -Popped $routeName');
  }
}

///
/// Log tree from current screen frame.
///
Future<List<Map<String, dynamic>>> logWidgetTree() async {
  final completer = Completer<List<Map<String, dynamic>>>();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Wait for the microtask to complete after the frame rendering
    await SchedulerBinding.instance.endOfFrame;

    final element = WidgetsBinding.instance.rootElement;
    if (element != null) {
      completer.complete(parseWidgetTree(element));
    } else {
      completer.completeError('Failed to retrieve the render view element');
    }
  });

  return completer.future;
}

/// Parses the Flutter widget tree and returns a list of widget data maps.
///
/// [element]: The root element of the widget tree to parse.
Future<List<Map<String, dynamic>>> parseWidgetTree(Element element) async {
  final widgetTree = <Map<String, dynamic>>[];
  final List<AccessiblePosition?> accessiblePositionList = [];
  AccessiblePosition? accessibility;

  /// All controls excluding the type 10 root node
  final List<Map<String, dynamic>> allControlsList = [];

  try {
    // Recursively parse the widget tree
    void traverse(
      Element element, [
      int depth = 0,
      bool insideSemantics = false,
    ]) {
      try {
        final widget = element.widget;

        // Only process widgets that have a render object with size
        final renderObject = element.renderObject;
        if (renderObject is RenderBox && renderObject.hasSize) {
          try {
            final position = renderObject.localToGlobal(Offset.zero);
            final size = renderObject.size;

            // Only pass accessibility if we're inside a Semantics widget or this is a Semantics widget
            final currentAccessibility =
                (insideSemantics || widget is Semantics) ? accessibility : null;

            // Parse individual widget and add to results if meaningful
            final result = _parseIndividualWidget(
              widget,
              element,
              position,
              size,
              currentAccessibility,
              accessiblePositionList,
            );

            // Update accessibility - only Semantics widgets should create new accessibility objects
            AccessiblePosition? newAccessibility;

            if (result != null) {
              newAccessibility = result['accessibility'] as AccessiblePosition?;
              accessibility = result['accessibility'] as AccessiblePosition?;
              final widgetData = result['widgetData'] as Map<String, dynamic>?;
              final controlData =
                  result['controlData'] as Map<String, dynamic>?;

              if (widgetData != null) {
                widgetTree.add(widgetData);
              }

              if (controlData != null) {
                allControlsList.add(controlData);
              }
            }

            // Update accessibility - only Semantics widgets should create new accessibility objects
            if (newAccessibility != null && insideSemantics) {
              accessibility = newAccessibility;
            } else {
              accessibility = null;
            }

            // if (accessibility != null &&
            //     !(insideSemantics || widget is Semantics)) {
            //   accessibility = null;
            // }
          } catch (e) {
            final widgetType = widget.runtimeType;
            tlLogger.e(
              'Failed to process render object for widget $widgetType: $e',
            );
          }
        }

        /// Recursively traverse all children
        element.visitChildren((child) {
          try {
            bool visible = true;
            if (widget is Visibility) {
              try {
                final visibility = widget;
                if (!visibility.visible) {
                  visible = false;
                }
              } catch (e) {
                tlLogger.e('Failed to check visibility: $e');
              }
            }

            /// Skip invisible Widgets
            if (visible) {
              // Pass down the insideSemantics flag - true if we're already inside Semantics or this widget is Semantics
              traverse(
                child,
                depth + 1,
                insideSemantics || widget is Semantics,
              );
            }
          } catch (e) {
            tlLogger.e('Failed to traverse child widget: $e');
          }
          return;
        });
      } catch (e) {
        final widget = element.widget;
        final widgetType = widget.runtimeType;
        tlLogger.e('Failed to parse widget $widgetType: $e');
        // Continue with next widget instead of crashing
      }
    }

    /// Starting to parse tree
    traverse(element, 0);
  } catch (error) {
    // Handle errors using try-catch block
    tlLogger.e('Error caught in parseWidgetTree: $error');
  }

  return allControlsList;
}

/// Parses an individual widget and extracts its text, styling, and accessibility information.
///
/// Returns a map containing:
/// - 'accessibility': AccessiblePosition object if semantics found
/// - 'widgetData': Simple widget data for widgetTree
/// - 'controlData': Detailed control data for allControlsList
///
/// Returns null if the widget has no meaningful content to log or is not explicitly handled.
Map<String, dynamic>? _parseIndividualWidget(
  Widget widget,
  Element element,
  Offset position,
  Size size,
  AccessiblePosition? accessibility,
  List<AccessiblePosition?> accessiblePositionList,
) {
  Map<String, dynamic>? aStyle;
  Map<String, dynamic>? font;
  String? text = "";

  ///
  /// Begin parsing UI Widgets of current screen
  /// Only widgets explicitly checked in if/else if statements will return data
  ///
  if (widget is Semantics) {
    // Handle Semantics widgets
    try {
      final Semantics semantics = widget;

      if (semantics.properties.label?.isNotEmpty == true ||
          semantics.properties.hint?.isNotEmpty == true) {
        final String? hint = semantics.properties.hint;
        final String? label = semantics.properties.label;

        /// Get Accessibility object, and its position for masking purpose
        accessibility = AccessiblePosition(
          id: element.toStringShort(),
          label: label ?? '',
          hint: hint ?? '',
          dx: position.dx,
          dy: position.dy,
          width: size.width,
          height: size.height,
        );
        accessiblePositionList.add(accessibility);

        // Return data for Semantics widget
        final widgetId =
            widget.runtimeType.toString() + widget.hashCode.toString();
        final controlData = <String, dynamic>{
          'id': widgetId,
          'cssId': widgetId,
          'idType': (-4).toString(),
          'tlType': 'semantics',
          'type': widget.runtimeType.toString(),
          'subType': widget.runtimeType.toString(),
          'position': <String, String>{
            'x': position.dx.toInt().toString(),
            'y': position.dy.toInt().toString(),
            'width': size.width.toInt().toString(),
            'height': size.height.toInt().toString(),
          },
          'zIndex': "501",
          'currState': <String, dynamic>{'text': label ?? '', 'font': font},
          'accessibility': {
            'id': accessibility.id,
            'label': accessibility.label,
            'hint': accessibility.hint,
          },
          'originalId': "",
          'masked': 'true',
        };

        return {'accessibility': accessibility, 'controlData': controlData};
      }
    } catch (e) {
      tlLogger.e('Failed to parse Semantics widget: $e');
    }
  } else if (widget is Text) {
    try {
      // Handle Text widgets
      final TextStyle style = widget.style ?? TextStyle();
      final TextAlign align = widget.textAlign ?? TextAlign.left;

      Widget currentWidget = widget;
      Padding? padding;

      font = {
        'family': style.fontFamily,
        'size': style.fontSize.toString(),
        'bold':
            (style.fontWeight != null &&
                    FontWeight.values.indexOf(style.fontWeight!) >
                        FontWeight.values.indexOf(FontWeight.normal))
                .toString(),
        'italic': (style.fontStyle == FontStyle.italic).toString(),
      };

      double top = 0, bottom = 0, left = 0, right = 0;

      /// Get Padding
      element.visitAncestorElements((ancestor) {
        try {
          currentWidget = ancestor.widget;
          if (currentWidget is Padding) {
            padding = currentWidget as Padding;

            if (padding?.padding is EdgeInsets) {
              final EdgeInsets eig = padding!.padding as EdgeInsets;
              top = eig.top;
              bottom = eig.bottom;
              left = eig.left;
              right = eig.right;
            }
            return false;
          }
        } catch (e) {
          tlLogger.e('Failed to parse ancestor widget: $e');
        }
        return true;
      });

      aStyle = {
        'textColor': style.color != null
            ? (style.color!.value & 0xFFFFFF).toString()
            : '0',
        'textAlphaColor': (style.color?.alpha ?? 0).toString(),
        'textAlphaBGColor': (style.backgroundColor?.alpha ?? 0).toString(),
        'textAlign': align.toString().split('.').last,
        'paddingBottom': bottom.toInt().toString(),
        'paddingTop': top.toInt().toString(),
        'paddingLeft': left.toInt().toString(),
        'paddingRight': right.toInt().toString(),
        'hidden': (style.color?.opacity == 1.0).toString(),
        'colorPrimary': (style.foreground?.color ?? 0).toString(),
        'colorPrimaryDark': 0.toString(), // TBD: Dark theme??
        'colorAccent': style.decorationColor != null
            ? (style.decorationColor!.value & 0xFFFFFF).toString()
            : '0',
      };

      if (widget.data != null) {
        text = widget.data;
      } else if (widget.textSpan != null) {
        try {
          text = _extractTextFromInlineSpan(widget.textSpan!);
        } catch (e) {
          tlLogger.e('Failed to extract text from TextSpan: $e');
          text = '';
        }
      } else {
        text = '';
      }

      final widgetData = {
        'type': widget.runtimeType.toString(),
        'text': text,
        'position':
            'x: ${position.dx}, y: ${position.dy}, width: ${size.width}, height: ${size.height}',
      };

      Map<String, dynamic> accessibilityMap = {
        'id': accessibility?.id,
        'label': accessibility?.label,
        'hint': accessibility?.hint,
      };

      final masked = (accessibility != null) ? true : false;
      final widgetId =
          widget.runtimeType.toString() + widget.hashCode.toString();

      final controlData = <String, dynamic>{
        'id': widgetId,
        'cssId': widgetId,
        'idType': (-4).toString(),
        'tlType': (text != null && text.contains('\n')) ? 'textArea' : 'label',
        'type': widget.runtimeType.toString(),
        'subType': widget.runtimeType.toString(),
        'position': <String, String>{
          'x': position.dx.toInt().toString(),
          'y': position.dy.toInt().toString(),
          'width': size.width.toInt().toString(),
          'height': size.height.toInt().toString(),
        },
        'zIndex': "501",
        'currState': <String, dynamic>{'text': text, 'font': font},
        'style': aStyle,
        if (accessibility != null) 'accessibility': accessibilityMap,
        'originalId': "",
        'masked': '$masked',
      };

      return {
        'accessibility': accessibility,
        'widgetData': widgetData,
        'controlData': controlData,
      };
    } catch (e) {
      tlLogger.e('Failed to parse Text widget: $e');
    }
  } else if (widget is TextFormField || widget is TextField) {
    try {
      // Handle TextFormField and TextField by extracting from toString()
      final String widgetString = widget.toString();
      final List<String> decorationTexts = [];

      // Extract decoration properties from the widget's string representation
      try {
        if (widgetString.contains('labelText:')) {
          final match = RegExp(
            r'labelText:\s*([^,}]+)',
          ).firstMatch(widgetString);
          if (match != null) {
            decorationTexts.add('labelText: ${match.group(1)?.trim()}');
          }
        }
        if (widgetString.contains('hintText:')) {
          final match = RegExp(
            r'hintText:\s*([^,}]+)',
          ).firstMatch(widgetString);
          if (match != null) {
            decorationTexts.add('hintText: ${match.group(1)?.trim()}');
          }
        }
        if (widgetString.contains('helperText:')) {
          final match = RegExp(
            r'helperText:\s*([^,}]+)',
          ).firstMatch(widgetString);
          if (match != null) {
            decorationTexts.add('helperText: ${match.group(1)?.trim()}');
          }
        }
        if (widgetString.contains('prefixText:')) {
          final match = RegExp(
            r'prefixText:\s*([^,}]+)',
          ).firstMatch(widgetString);
          if (match != null) {
            decorationTexts.add('prefixText: ${match.group(1)?.trim()}');
          }
        }
        if (widgetString.contains('suffixText:')) {
          final match = RegExp(
            r'suffixText:\s*([^,}]+)',
          ).firstMatch(widgetString);
          if (match != null) {
            decorationTexts.add('suffixText: ${match.group(1)?.trim()}');
          }
        }
      } catch (e) {
        tlLogger.e('Failed to parse TextField decoration: $e');
      }

      if (decorationTexts.isNotEmpty) {
        text = decorationTexts.join(', ');

        // Return data for TextField/TextFormField widget
        final widgetId =
            widget.runtimeType.toString() + widget.hashCode.toString();
        final controlData = <String, dynamic>{
          'id': widgetId,
          'cssId': widgetId,
          'idType': (-4).toString(),
          'tlType': 'textField',
          'type': widget.runtimeType.toString(),
          'subType': widget.runtimeType.toString(),
          'position': <String, String>{
            'x': position.dx.toInt().toString(),
            'y': position.dy.toInt().toString(),
            'width': size.width.toInt().toString(),
            'height': size.height.toInt().toString(),
          },
          'zIndex': "501",
          'currState': <String, dynamic>{'text': text, 'font': font},
          if (accessibility != null)
            'accessibility': {
              'id': accessibility.id,
              'label': accessibility.label,
              'hint': accessibility.hint,
            },
          'originalId': "",
          'masked': '${accessibility != null}',
        };

        return {'accessibility': accessibility, 'controlData': controlData};
      }
    } catch (e) {
      tlLogger.e('Failed to parse TextField/TextFormField: $e');
    }
  } else if (widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FloatingActionButton ||
      widget is IconButton) {
    try {
      String? buttonText;
      String? buttonType;
      if (widget is ElevatedButton) {
        final btn = widget;
        if (btn.child is Text) {
          buttonText = (btn.child as Text).data;
        }
      } else if (widget is TextButton) {
        final btn = widget;
        if (btn.child is Text) {
          buttonText = (btn.child as Text).data;
        }
      } else if (widget is OutlinedButton) {
        final btn = widget;
        if (btn.child is Text) {
          buttonText = (btn.child as Text).data;
        }
      } else if (widget is FloatingActionButton) {
        final btn = widget;
        if (btn.child is Text) {
          buttonText = (btn.child as Text).data;
        } else {
          // FloatingActionButton with Icon or other child should still be logged
          buttonText = 'FloatingActionButton';
        }
      } else if (widget is IconButton) {
        // IconButton itself does not have a text label, but may be wrapped in Semantics
        buttonType = 'IconButton';
      }
      buttonType = buttonType ?? widget.runtimeType.toString();

      final controlData = <String, dynamic>{
        'id': widget.runtimeType.toString() + widget.hashCode.toString(),
        'cssId': widget.runtimeType.toString() + widget.hashCode.toString(),
        'idType': (-4).toString(),
        'tlType': 'button',
        'type': buttonType,
        'subType': widget.runtimeType.toString(),
        'position': <String, String>{
          'x': position.dx.toInt().toString(),
          'y': position.dy.toInt().toString(),
          'width': size.width.toInt().toString(),
          'height': size.height.toInt().toString(),
        },
        'zIndex': "501",
        'currState': <String, dynamic>{'text': buttonText, 'font': font},
        if (accessibility != null)
          'accessibility': {
            'id': accessibility.id,
            'label': accessibility.label,
            'hint': accessibility.hint,
          },
        'originalId': "",
        'masked': '${accessibility != null}',
      };

      return {'accessibility': accessibility, 'controlData': controlData};
    } catch (e) {
      tlLogger.e('Failed to parse button widget: $e');
    }
  }

  // Return null for any widget not explicitly handled in the if/else if statements
  return null;
}

///
/// Connect Log Exception.
///
class ConnectException implements Exception {
  ConnectException.create({
    required int code,
    required this.msg,
    this.nativeMsg,
    this.nativeStacktrace,
    this.nativeDetails,
  }) {
    this.code = _getCode(code);
  }

  ConnectException(PlatformException pe, {this.msg})
    : code = pe.code,
      nativeStacktrace = pe.stacktrace,
      nativeMsg = pe.message,
      nativeDetails = pe.details?.toString();

  static String logErrorMsg = 'Error logging an exception';
  static int codeBase = 600;

  String? nativeStacktrace;
  String? nativeDetails;
  String? nativeMsg;
  String? msg;
  String? code;

  static String _getCode(int num) => 'Connect API error: #${num + codeBase}';
  String? get getMsg => msg;
  String? get getNativeMsg => nativeMsg;
  String? get getNativeStacktrace => nativeStacktrace;
  String? get getNativeDetails => nativeDetails;
}

///
/// Connect Plugin API calls.
///
class PluginConnect {
  static const MethodChannel _channel = MethodChannel('connect_flutter_plugin');

  static Future<String> get platformVersion async {
    try {
      return await _channel.invokeMethod('getPlatformVersion');
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process platform version request message!',
      );
    }
  }

  static Future<String> get connectVersion async {
    try {
      final String version = await _channel.invokeMethod('getConnectVersion');
      tlLogger.t("Connect version: $version");
      return version;
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process Connect request version message!',
      );
    }
  }

  static Future<String> get connectSessionId async {
    try {
      final String sessionId = await _channel.invokeMethod(
        'getConnectSessionId',
      );
      tlLogger.t("Connect sessionId: $sessionId");
      return sessionId;
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process Connect request sessionId message!',
      );
    }
  }

  static Future<String> get pluginVersion async {
    try {
      // TODO:
      // final String pubspecData = ("See connect_flutter_plugin version in pubspec.yaml.");

      return "2.0.0";
    } on Exception catch (e) {
      throw ConnectException.create(
        code: 7,
        msg: 'Unable to obtain platform version: ${e.toString()}',
      );
    }
  }

  /// Sets the log level for the Connect SDK
  ///
  /// This allows SDK users to control the verbosity of logging output.
  /// By default, debug level is used in debug builds and error level in release builds.
  ///
  /// [level] The desired log level from ConnectLogLevel enum
  ///
  /// Example usage:
  /// ```dart
  /// // Disable all logging
  /// PluginConnect.setLogLevel(ConnectLogLevel.off);
  ///
  /// // Enable trace logging for detailed debugging
  /// PluginConnect.setLogLevel(ConnectLogLevel.trace);
  ///
  /// // Show only errors
  /// PluginConnect.setLogLevel(ConnectLogLevel.error);
  /// ```
  static void setLogLevel(ConnectLogLevel level) {
    LoggerConfig.setLogLevel(level);
    tlLogger.t('Connect SDK log level set to: ${level.toString()}');
  }

  /// Gets the current log level for the Connect SDK
  ///
  /// Returns the current ConnectLogLevel setting
  static ConnectLogLevel getLogLevel() {
    return LoggerConfig.logLevel;
  }

  static Future<String> get appKey async {
    try {
      return await _channel.invokeMethod('getAppKey');
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process app key request message!',
      );
    }
  }

  static Future<void> tlSetEnvironment({
    required int screenWidth,
    required int screenHeight,
  }) async {
    try {
      await _channel.invokeMethod('setenv', {
        'screenw': screenWidth,
        'screenh': screenHeight,
      });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to send Flutter screen parameters message!',
      );
    }
  }

  /// Records network connection metrics for a specific URL.
  ///
  /// [url]: The URL of the network connection.
  /// [statusCode]: The HTTP status code of the network response.
  /// [description]: Optional description of the network connection.
  /// [responseSize]: Optional size of the network response data, in bytes.
  /// [initTime]: Optional time at which the network request was initiated.
  /// [loadTime]: Optional time at which the network response was received.
  /// [responseTime]: Optional time it took to receive the network response,
  ///   calculated as `loadTime - initTime` if not provided.
  static Future<void> tlConnection({
    required String url,
    required int statusCode,
    String description = '',
    int responseSize = 0,
    int initTime = 0,
    int loadTime = 0,
    responseTime = 0,
  }) async {
    if (responseTime == 0) {
      responseTime = loadTime - initTime;
    }
    try {
      await _channel.invokeMethod('connection', {
        'url': url,
        'statusCode': statusCode.toString(),
        'responseDataSize': responseSize.toString(),
        'initTime': initTime.toString(),
        'loadTime': loadTime.toString(),
        'responseTime': responseTime.toString(),
        'description': description,
      });
    } on PlatformException catch (pe) {
      throw ConnectException(pe, msg: 'Unable to process connection message!');
    }
  }

  /// Logs a custom event with optional custom data and log level.
  ///
  /// This function sends a custom event message to the native side with the specified
  /// event name, custom data, and log level. It uses platform-specific channel
  /// communication to invoke the 'customevent' method.
  ///
  /// Throws a [ConnectException] if there is an error during the process,
  /// including if there is an issue with the Connect plugin or platform-specific errors.
  ///
  /// Example usage:
  /// ```dart
  /// await tlApplicationCustomEvent(
  ///   eventName: 'ButtonClicked',
  ///   customData: {'buttonName': 'Submit'},
  ///   logLevel: 2,
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [eventName]: The name of the custom event.
  /// - [customData]: A map containing additional custom data for the event (optional).
  /// - [logLevel]: The log level for the custom event (optional).
  ///
  /// Throws:
  /// - [ConnectException]: If there is an issue processing the custom event message.
  static Future<void> tlApplicationCustomEvent({
    required String? eventName,
    Map<String, String?>? customData,
    int? logLevel,
  }) async {
    if (eventName == null) {
      throw ConnectException.create(code: 6, msg: 'eventName is null');
    }
    try {
      await _channel.invokeMethod('customevent', {
        'eventname': eventName,
        'loglevel': logLevel,
        'data': customData,
      });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process custom event message!',
      );
    }
  }

  ///
  /// For Application level handled exception
  ///
  static Future<void> tlApplicationCaughtException({
    dynamic caughtException,
    StackTrace? stack,
    Map<String, String>? appData,
  }) async {
    try {
      if (caughtException == null) {
        throw ConnectException.create(
          code: 4,
          msg: 'User caughtException is null',
        );
      }
      await _channel.invokeMethod('exception', {
        "name": caughtException.runtimeType.toString(),
        "message": caughtException.toString(),
        "stacktrace": stack == null ? "" : stack.toString(),
        "handled": true,
        "appdata": appData,
      });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process user caught exception message!',
      );
    }
  }

  ///
  /// For global unhandled exception
  ///
  static Future<void> onTlException({
    required Map<dynamic, dynamic> data,
  }) async {
    try {
      await _channel.invokeMethod('exception', data);
    } on PlatformException catch (pe) {
      tlLogger.t(
        'Unable to log app exception: ${pe.message}, stack: ${pe.stacktrace}',
      );
      throw ConnectException(pe, msg: ConnectException.logErrorMsg);
    }
  }

  static Future<void> onTlPointerEvent({required Map fields}) async {
    tlLogger.t('fields: ${fields.toString()}');

    try {
      await _channel.invokeMethod('pointerEvent', fields);
    } on PlatformException catch (pe, stack) {
      tlLogger.t(
        "pointerEvent exception: ${pe.toString()}, stack: ${stack.toString()}",
      );
      throw ConnectException(
        pe,
        msg: 'Unable to process flutter pointer event message!',
      );
    }
  }

  /// Handles incoming gesture events from the Flutter engine.
  ///
  /// [gesture]: The type of gesture, e.g., 'pinch', 'swipe', 'taphold', 'doubletap', or 'tap'.
  /// [id]: The unique identifier of the gesture event.
  /// [target]: The target of the gesture event, e.g., a widget ID.
  /// [data]: Additional data associated with the gesture event, if any.
  /// [layoutParameters]: Layout parameters associated with the gesture event, if any.
  ///
  /// Throws a [ConnectException] if the gesture type is not supported or if there is an error processing the gesture message.
  static Future<void> onTlGestureEvent({
    required String? gesture,
    required String id,
    required String target,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? layoutParameters,
  }) async {
    try {
      if (["pinch", "swipe", "taphold", "doubletap", "tap"].contains(gesture)) {
        return await _channel.invokeMethod('gesture', <dynamic, dynamic>{
          'tlType': gesture,
          'id': id,
          'target': target,
          'data': data,
          'layoutParameters': layoutParameters ?? <Map<String, dynamic>>[],
        });
      }
      throw ConnectException.create(
        code: 3,
        msg: 'Illegal gesture type: "$gesture"',
      );
    } on PlatformException catch (pe) {
      throw ConnectException(pe, msg: 'Unable to process gesture message!');
    }
  }

  /// Logs the layout of the screen and captures a Connect screen view event.
  ///
  /// This function logs the widgets on the screen using the [logWidgetTree] function
  /// and then calls the Connect screen capture API to capture the screen load event.
  /// The captured event includes the logical page name provided as [logicalPageName].
  ///
  /// Throws a [ConnectException] if there is an error during the process,
  /// including if there is an issue with the Connect plugin or platform-specific errors.
  ///
  /// Example usage:
  /// ```dart
  /// await logScreenLayout('HomePage');
  /// ```
  ///
  /// Parameters:
  /// - [logicalPageName]: The logical name of the page/screen to be used in the Connect event.
  ///
  /// Throws:
  /// - [ConnectException]: If there is an issue processing the screen capture.
  static Future<void> logScreenLayout(String logicalPageName) async {
    try {
      /// First logs the screen widgets, then call Connect screen capture API
      logWidgetTree()
          .then((result) {
            /// Captures screen load event, with page name
            PluginConnect.onScreenview("LOAD", logicalPageName, result);
          })
          .catchError((error) {
            tlLogger.e('Error: $error');
          });
    } on PlatformException catch (pe) {
      throw ConnectException(pe, msg: 'Unable to process screen capture');
    }
  }

  /// Logs the unloading context of a screen view with additional information.
  ///
  /// This function sends a screen view unload event to the native side with the
  /// logical page name and referrer information. It uses platform-specific channel
  /// communication to invoke the 'logScreenViewContextUnLoad' method.
  ///
  /// Throws a [ConnectException] if there is an error during the process,
  /// including if there is an issue with the Connect plugin or platform-specific errors.
  ///
  /// Example usage:
  /// ```dart
  /// await logScreenViewContextUnLoad('DetailsPage', 'HomePage');
  /// ```
  ///
  /// Parameters:
  /// - [logicalPageName]: The logical name of the page/screen for the screen view event.
  /// - [referrer]: The logical name of the referring page/screen for context information.
  ///
  /// Throws:
  /// - [ConnectException]: If there is an issue processing the logScreenViewContextUnLoad message.
  static Future<void> logScreenViewContextUnLoad(
    String logicalPageName,
    String referrer,
  ) async {
    try {
      // Send the screen view event to the native side
      return await _channel.invokeMethod(
        'logScreenViewContextUnLoad',
        <dynamic, dynamic>{'name': logicalPageName, 'referrer': referrer},
      );
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process logScreenViewContextUnLoad (update) message!',
      );
    }
  }

  /// Triggers a screen view event in the app. The event can be a load, unload or visit event.
  ///
  /// The `tlType` argument should be a string representing the type of screen transition:
  /// - "LOAD" for when the screen is being loaded,
  /// - "UNLOAD" for when the screen is being unloaded,
  /// - "VISIT" for when the screen is visited.
  ///
  ///
  /// The `layoutParameters` is an optional list of maps where each map has a `String` key and dynamic value.
  /// It can be used to pass extra parameters related to the screen transition.
  ///
  /// Throws a [ConnectException] if the provided `tlType` argument is not one of the allowed types
  /// or when the native platform throws a [PlatformException].
  static Future<void> onScreenview(
    String tlType,
    String logicalPageName, [
    List<Map<String, dynamic>>? layoutParameters,
  ]) async {
    try {
      if (["LOAD", "UNLOAD", "VISIT"].contains(tlType)) {
        // Send the screen view event to -the native side
        return await _channel.invokeMethod('screenview', <dynamic, dynamic>{
          'tlType': tlType,
          'logicalPageName': logicalPageName,
          'layoutParameters': layoutParameters,
        });
      }

      throw ConnectException.create(
        code: 2,
        msg: 'Illegal screenview transition type',
      );
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process screen view (update) message!',
      );
    }
  }

  static Future<String> getGlobalConfiguration() async {
    try {
      return await _channel.invokeMethod('getGlobalConfiguration');
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process global configuration settings message!',
      );
    }
  }

  static Future<String> maskText(String text, [String? page]) async {
    try {
      return await _channel.invokeMethod('maskText', <dynamic, dynamic>{
        'text': text,
        'page': page ?? "",
      });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process string masking request!',
      );
    }
  }

  static Future<void> badCall() async {
    await _channel.invokeMethod('no such method');
  }

  static void tlFocusChanged(
    String widgetId,
    double x,
    double y,
    bool focused,
  ) async {
    try {
      await _channel.invokeMethod('focuschanged', <dynamic, dynamic>{
        'widgetId': widgetId,
        'x': x.toString(),
        'y': y.toString(),
        'focused': focused.toString(),
      });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process focus change message!',
      );
    }
  }

  ///
  /// Logs performance event with params:
  ///
  /// [navigationType]   the navigation type, Default NAVIGATE = 0, RELOAD = 1, BACK_FORWARD = 2, RESERVED = 255
  /// [redirectCount]    the redirect count, Default 0
  /// [navigationStart]  the navigation start time - Default 0
  /// [unloadEventStart] the unload event start time - Default 0, onDestroy
  /// [unloadEventEnd]   the unload event end time - Time ending from unloadStart
  /// [redirectStart]    the redirect start time - Default 0
  /// [redirectEnd]      the redirect end time - Time ending from redirectStart
  /// [loadEventStart]   the load event start time - Default 0, onCreate
  /// [loadEventEnd]     the load event end time - End time of loading page, onResume
  ///
  /// Returns true if log performance event succeed, false otherwise
  ///
  static Future<bool> logPerformanceEvent({
    final int navigationType = 0,
    final int redirectCount = 0,
    final int navigationStart = 0,
    final int unloadEventStart = 0,
    final int unloadEventEnd = 0,
    final int redirectStart = 0,
    final int redirectEnd = 0,
    final int loadEventStart = 0,
    final int loadEventEnd = 0,
  }) async {
    try {
      if (navigationType < 0) {
        throw ArgumentError("navigationType must be positive");
      }
      if (redirectCount < 0) {
        throw ArgumentError("redirectCount must be positive");
      }
      if (navigationStart < 0) {
        throw ArgumentError("navigationStart must be positive");
      }
      if (unloadEventStart < 0) {
        throw ArgumentError("navigationType must be positive");
      }
      if (unloadEventEnd < 0) {
        throw ArgumentError("unloadEventStart must be positive");
      }
      if (redirectStart < 0) {
        throw ArgumentError("redirectStart must be positive");
      }
      if (redirectEnd < 0) throw ArgumentError("redirectEnd must be positive");
      if (loadEventStart < 0) {
        throw ArgumentError("loadEventStart must be positive");
      }
      if (loadEventEnd < 0) {
        throw ArgumentError("loadEventEnd must be positive");
      }

      return await _channel
          .invokeMethod('logPerformanceEvent', <dynamic, dynamic>{
            'navigationType': navigationType.toString(),
            'redirectCount': redirectCount.toString(),
            'navigationStart': navigationStart.toString(),
            'unloadEventStart': unloadEventStart.toString(),
            'unloadEventEnd': unloadEventEnd.toString(),
            'redirectStart': redirectStart.toString(),
            'redirectEnd': redirectEnd.toString(),
            'loadEventStart': loadEventStart.toString(),
            'loadEventEnd': loadEventEnd.toString(),
          });
    } on PlatformException catch (pe) {
      throw ConnectException(
        pe,
        msg: 'Unable to process log performance event message!',
      );
    }
  }

  /// Emits a signal with the given data.
  ///
  /// [customData]: A map containing custom data to be logged.
  /// [logLevel]: The severity level of the log message. Defaults to [LogLevel.info].
  ///
  /// Example usage:
  ///
  /// ```dart
  /// PluginConnect.logSignal({
  ///   "behaviorType": "orderConfirmation",
  ///   "orderId": "145667",
  ///   "orderSubtotal": 10,
  ///   "orderShip": 10,
  ///   "orderTax": 5.99,
  ///   "orderDiscount": "10%",
  ///   "currency": "USD",
  /// });
  /// ```
  static Future<void> logSignal({
    required Map<String, dynamic> signalData,
    int? logLevel,
  }) async {
    try {
      if (!ConnectHelper.captureScreen) {
        return;
      }

      await _channel.invokeMethod('logSignal', {
        'loglevel': logLevel,
        'data': signalData,
      });
    } on PlatformException catch (pe) {
      throw ConnectException(pe, msg: 'Unable to process logSignal message.');
    }
  }

  /// Gets a boolean configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [moduleName] The name of the module.
  static Future<bool> getBooleanConfigItemForKey(
    String key,
    String moduleName,
  ) async {
    return await _channel.invokeMethod('getBooleanConfigItemForKey', {
      'key': key,
      'moduleName': moduleName,
    });
  }

  /// Gets a string configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [moduleName] The name of the module.
  /// [defaultValue] The default value to return if the key is not found.
  static Future<String?> getStringItemForKey(
    String key,
    String moduleName, {
    String? defaultValue,
  }) async {
    return await _channel.invokeMethod('getStringItemForKey', {
      'key': key,
      'moduleName': moduleName,
      'theDefault': defaultValue,
    });
  }

  /// Gets a number configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [moduleName] The name of the module.
  /// [defaultValue] The default value to return if the key is not found.
  static Future<int?> getNumberItemForKey(
    String key,
    String moduleName, {
    int defaultValue = 0,
  }) async {
    return await _channel.invokeMethod('getNumberItemForKey', {
      'key': key,
      'moduleName': moduleName,
      'theDefault': defaultValue,
    });
  }

  /// Sets a boolean configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [value] The configuration value.
  /// [moduleName] The name of the module.
  static Future<bool> setBooleanConfigItemForKey(
    String key,
    bool value,
    String moduleName,
  ) async {
    return await _channel.invokeMethod('setBooleanConfigItemForKey', {
      'key': key,
      'value': value,
      'moduleName': moduleName,
    });
  }

  /// Sets a string configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [value] The configuration value.
  /// [moduleName] The name of the module.
  static Future<dynamic> setStringItemForKey(
    String key,
    String value,
    String moduleName,
  ) async {
    return await _channel.invokeMethod('setStringItemForKey', {
      'key': key,
      'value': value,
      'moduleName': moduleName,
    });
  }

  /// Sets a number configuration item for the specified key.
  ///
  /// [key] The configuration key.
  /// [value] The configuration value.
  /// [moduleName] The name of the module.
  /// [defaultValue] The default value to return if the key is not found.
  static Future<dynamic> setNumberItemForKey(
    String key,
    num value,
    String moduleName,
  ) async {
    return await _channel.invokeMethod('setNumberItemForKey', {
      'key': key,
      'value': value,
      'moduleName': moduleName,
    });
  }
}

///
/// UI Interaction Logger
///
class UserInteractionLogger {
  static void initialize() {
    ///
    /// Catch unhandled app exception
    ///
    FlutterError.onError = (errorDetails) {
      PluginConnect.onTlException(
        data: Connect.flutterErrorDetailsToMap(errorDetails),
      );
    };
    // _setupGestureLogging();
    // _setupNavigationLogging();
    _setupPerformanceLogging();
  }

  static void _setupPerformanceLogging() {
    // Enable performance metric logging
    WidgetsBinding.instance.addObserver(PerformanceObserver());
  }
}

/// Log App Performance
///
///
class PerformanceObserver extends WidgetsBindingObserver {
  void _performanceCustomEvent(AppLifecycleState state) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = endTime - startTime;

      PluginConnect.logPerformanceEvent(
        loadEventStart: 0,
        loadEventEnd: duration,
      );

      tlLogger.t('_PerformanceObserver($state): $duration');
    });
  }

  @override
  void didHaveMemoryPressure() {
    PluginConnect.tlApplicationCustomEvent(
      eventName: 'Performance Metric',
      customData: {'didHaveMemoryPressure': 'true'},
      logLevel: 1,
    );

    super.didHaveMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _performanceCustomEvent(state);
  }
}

String _extractTextFromInlineSpan(InlineSpan span) {
  final StringBuffer buffer = StringBuffer();
  void extract(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text != null) buffer.write(span.text);
      if (span.children != null) {
        for (final child in span.children!) {
          extract(child);
        }
      }
    }
    // Ignore WidgetSpan for text extraction
  }

  extract(span);
  return buffer.toString();
}
