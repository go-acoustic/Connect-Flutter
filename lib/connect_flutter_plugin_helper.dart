import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';
import 'package:connect_flutter_plugin/logger.dart';

/// Tracks Widgets during runtime, for Connect type 10 & type 11
///
///
class WidgetPath {
  WidgetPath();

  static const String excl = r'^(Focus|Semantics|InheritedElement|.*\n_).*$';
  static const String reduce = r"[a-z]";
  static const String sep = '/';
  static Hash get digest => sha1;

  static Map<int, dynamic> widgetContexts = {};
  static Map<Widget, String> pathCache = {};

  BuildContext? context;
  Element? parent;
  String? parentWidgetType;
  String? pathHash;
  int? key;
  late bool shorten;
  late bool hash;
  late String path;

  int position = 0;
  bool usedInLayout = false;
  Map<String, dynamic> parameters = {};

  int siblingPosition(Element parent, Widget child) {
    int result;

    try {
      final dynamic currentWidget = parent.widget;
      final List<Widget> children = currentWidget.children;
      result = children.indexOf(child);
    } catch (e) {
      result = -1;
    }

    return result;
  }

  WidgetPath.create(this.context,
      {this.shorten = true, this.hash = false, String exclude = excl}) {
    if (context == null) {
      return;
    }

    final StringBuffer path = StringBuffer();
    final RegExp re = RegExp(exclude, multiLine: true);
    final List<dynamic> stk = [];
    final Widget widget = context!.widget;

    String widgetName = '$sep${widget.runtimeType.toString()}';
    Widget? child;

    this.path = '';

    context?.visitAncestorElements((ancestor) {
      final Widget parentWidget = ancestor.widget;
      String prt = parentWidget.runtimeType.toString();
      final String art = '${ancestor.runtimeType.toString()}\n$prt';

      if (stk.isEmpty) {
        parent = ancestor;
      }
      final String? parentPath = pathCache[parentWidget];
      if (parentPath != null) {
        path.write(parentPath);
        return false;
      }
      if (!re.hasMatch(art)) {
        if (child != null) {
          final int index = siblingPosition(ancestor, child!);
          if (index != -1) {
            prt += '_$index';
          }
        }
        stk.add(parentWidget);
        stk.add(makeShorter(prt));
      }
      child = ancestor.widget;
      return true;
    });

    for (int index = stk.length; index > 0;) {
      path.write('$sep${stk[--index]}');
      pathCache[stk[--index]] = path.toString();
    }

    path.write(widgetName);
    this.path = path.toString();
    parentWidgetType = parent!.widget.runtimeType.toString();

    tlLogger.t(
        'Widget path added: ${widget.runtimeType.toString()}, path: $this.path, digest: ${widgetDigest()}');
  }

  List<int> findExistingPathKeys() {
    final List<int> matches = [];

    for (MapEntry<int, dynamic> entry in widgetContexts.entries) {
      final WidgetPath wp = entry.value;
      if (this == wp) {
        tlLogger.t("Skip removing current widget path entry");
        continue;
      }
      if (isEqual(wp)) {
        tlLogger.t("Path match [${entry.key}]");
        matches.add(entry.key);
      }
    }
    return matches;
  }

  bool isEqual(WidgetPath other) {
    final bool equal = path.compareTo(other.path) == 0;
    if (equal) {
      tlLogger.t("Widget paths are equal!");
    }
    return equal;
  }

  void addInstance(int key) {
    final List<int> existingKeys = findExistingPathKeys();
    final int keyCount = existingKeys.length;
    if (keyCount > 0) {
      final WidgetPath firstPath = widgetContexts[existingKeys[0]];
      if (!firstPath.usedInLayout) {
        if (keyCount == 1) {
          firstPath.position = 1;
        }
        position = keyCount + 1;
        tlLogger.t('path sibling, count: $position');
      } else {
        if (existingKeys.contains(key)) {
          WidgetPath wp = widgetContexts[key];
          position = wp.position;
          tlLogger.t('Replacing logged widget: $key, position: $position');
        } else {
          tlLogger.t(
              'Removing $keyCount siblings(new key: $key): ...${firstPath.path.substring(max(0, firstPath.path.length - 90))}');
          for (int eKey in existingKeys) {
            WidgetPath wp = widgetContexts[eKey];
            tlLogger.t(
                'Removing $eKey, position: ${wp.position}, used: ${wp.usedInLayout}');
            removePath(eKey);
          }
        }
      }
    }
    this.key = key;
    widgetContexts[key] = this;
  }

  String widgetPath() => (position == 0) ? path : '$path/$position';

  String? widgetDigest() {
    if (hash && pathHash == null) {
      pathHash = digest.convert(utf8.encode(widgetPath())).toString();
    }
    return pathHash;
  }

  void addParameters(Map<String, dynamic> parameters) =>
      this.parameters.addAll(parameters);

  static WidgetPath? getPath(int key) => widgetContexts[key];
  static void removePath(int? key) {
    if (key != null) widgetContexts.remove(key);
  }

  static bool containsKey(int key) => widgetContexts.containsKey(key);
  static void clear() => widgetContexts.clear();
  static int get size => widgetContexts.length;
  static Function removeWhere = widgetContexts.removeWhere;
  static List<dynamic> entryList() =>
      widgetContexts.entries.toList(growable: false);
  static void clearPathCache() => pathCache.clear();
  String makeShorter(String str) =>
      shorten ? str.replaceAll(RegExp(reduce), '') : str;
}

typedef _Loader = Future<String> Function();

class _TlConfiguration {
  factory _TlConfiguration() => _instance ??= _TlConfiguration._internal();

  _TlConfiguration._internal() {
    _dataLoader ??= PluginConnect.getGlobalConfiguration;
  }

  static _Loader? _dataLoader;
  static Map<String, dynamic>? _configureInformation;
  static _TlConfiguration? _instance;

  Future<void> load([dynamic loader]) async {
    if (loader != null) {
      _dataLoader = loader;
      _configureInformation = null;
    }
    if (_configureInformation == null) {
      if (_dataLoader == null) {
        throw Exception("No data loader defined for configuration!");
      }
      final String data = await _dataLoader!();
      _configureInformation = jsonDecode(data);
      tlLogger.t('Global configuration loaded');
    }
  }

  dynamic get(String item) async {
    await load();

    dynamic value = _configureInformation;

    if (item.isNotEmpty) {
      final List<String> ids = item.split('/');
      final int idsLength = ids.length;

      int index;
      for (index = 0; index < idsLength && value != null; index++) {
        if (value is Map) {
          value = (value as Map<String, dynamic>)[ids[index]];
        } else {
          break;
        }
      }
      if (index != idsLength) {
        value = null;
      }
    }
    return value;
  }
}

// ignore: lint, unused_element
class TlBinder extends WidgetsBindingObserver {
  factory TlBinder() => _instance ?? TlBinder._internal();

  TlBinder._internal() {
    _instance = this;
    tlLogger.t('TlBinder INSTANTIATED!!');
  }

  static const bool createRootLayout = false;
  static const bool usePostFrame = false;

  static int rapidFrameRateLimitMs = 160;
  static int rapidSequenceCompleteMs = 2 * rapidFrameRateLimitMs;
  static bool initRapidFrameRate = true;

  static TlBinder? _instance;
  static List<Map<String, dynamic>>? layoutParametersForGestures;

  bool initEnvironment = true;
  String frameHash = "";
  int screenWidth = 0;
  int screenHeight = 0;
  int lastFrameTime = 0;
  bool loggingScreen = false;
  // Timer? logFrameTimer;

  bool? maskingEnabled;
  List<dynamic>? maskIds;
  List<dynamic>? maskValuePatterns;

  // ignore: library_private_types_in_public_api
  _Swipe? scrollCapture;

  void startScroll(Offset? position, Duration? timeStamp) {
    scrollCapture = _Swipe();
    scrollCapture?.startPosition = position ?? Offset(0, 0);
    scrollCapture?.startTimeStamp = timeStamp ?? Duration();
  }

  void updateScroll(Offset? position, Duration? timeStamp) {
    scrollCapture?.updatePosition = position ?? Offset(0, 0);
    scrollCapture?.updateTimestamp = timeStamp ?? Duration();

    if (scrollCapture != null) {
      final _Swipe swipe = scrollCapture!;

      if (swipe.getUpdatePosition != null && swipe.velocity != null) {
        Connect.isSwiping = true;
      }
    }
  }

  void endScroll(Velocity? velocity) {
    scrollCapture?.velocity =
        velocity ?? Velocity(pixelsPerSecond: Offset(0, 0));
    scrollCapture?.calculateSwipe();

    checkForScroll();
  }

  Future<void> checkForScroll() async {
    if (scrollCapture != null) {
      final _Swipe swipe = scrollCapture!;

      scrollCapture = null;

      if (swipe.getUpdatePosition != null && swipe.velocity != null) {
        final Offset? start = swipe.getStartPosition;
        final Offset? end = swipe.getUpdatePosition;
        final Velocity? velocity = swipe.velocity;
        final String direction = swipe.direction;

        tlLogger.t(
            'Scrollable start timestamp: ${swipe.getStartTimestampString()}');
        tlLogger.t(
            'Scrollable, start: ${start?.dx},${start?.dy}, end: ${end?.dx},${end?.dy}, velocity: $velocity, direction: $direction');

        logWidgetTree().then((result) async {
          // TODO: missing context?
          // var touchedTarget = findTouchedWidget(context, details.position);

          if (ConnectHelper.captureScreen) {
            await PluginConnect.onTlGestureEvent(
                gesture: 'swipe',
                id: '../Scrollable',
                target: 'Scrollable',
                data: <String, dynamic>{
                  'pointer1': {
                    'dx': start?.dx,
                    'dy': start?.dy,
                    'ts': swipe.getStartTimestampString()
                  },
                  'pointer2': {
                    'dx': end?.dx,
                    'dy': end?.dy,
                    'ts': swipe.getUpdateTimestampString()
                  },
                  'velocity': {
                    'dx': velocity?.pixelsPerSecond.dx,
                    'dy': velocity?.pixelsPerSecond.dy
                  },
                  'direction': direction,
                },
                layoutParameters: result);
          }
        }).catchError((error) {
          // Handle errors if the async function throws an error
          tlLogger.e('Error: $error');
        });

        // For Cancelling the pointerUp event
        Connect.isSwiping = false;
      } else {
        tlLogger.t('Incomplete scroll before frame');
      }
    }
  }

  void init() {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    binding.addPersistentFrameCallback((timestamp) {
      if (usePostFrame) {
        // tlLogger.v("Frame handling with single PostFrame callbacks");
        handleWithPostFrameCallback(binding, timestamp);
      } else {
        // tlLogger.v("Frame handling with direct persistent callbacks");
        handleScreenUpdate(timestamp);
      }
    });
    binding.addObserver(this);
  }

  void release() {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    binding.removeObserver(this);
    WidgetPath.clear();
  }

  Future<bool?> getMaskingEnabled() async {
    if (maskingEnabled == null) {
      maskingEnabled = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/HasMasking") ??
          false;
      maskIds = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/MaskIdList") ??
          [];
      maskValuePatterns = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/MaskValueList") ??
          [];
    }
    return maskingEnabled;
  }

  //  TODO:  Is this required?  not sure if tlSetEnvironment is necessary since the plugin could get the info
  void logFrameIfChanged(WidgetsBinding binding, Duration timestamp) async {
    // ignore: deprecated_member_use
    final Element? rootViewElement = binding.renderViewElement;

    if (initRapidFrameRate) {
      await getFrameRateConfiguration();
    }

    if (initEnvironment) {
      final RenderObject? rootObject = rootViewElement?.findRenderObject();

      if (rootObject != null) {
        screenWidth = rootObject.paintBounds.width.round();
        screenHeight = rootObject.paintBounds.height.round();

        if (screenWidth != 0 && screenHeight != 0) {
          initEnvironment = false;

          await PluginConnect.tlSetEnvironment(
              screenWidth: screenWidth, screenHeight: screenHeight);

          tlLogger.t('TlBinder, renderView w: $screenWidth, h: $screenHeight');
        }
      }
    }
  }

  void handleWithPostFrameCallback(WidgetsBinding binding, Duration timestamp) {
    binding.addPostFrameCallback((timestamp) => handleScreenUpdate(timestamp));
  }

  void handleScreenUpdate(Duration timestamp) {
    // tlLogger.v(
    //     'Frame callback @$timestamp (widget path map size: ${WidgetPath.size})');

    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    logFrameIfChanged(binding, timestamp);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        scrollCapture = null;
        tlLogger.t("Screenview UNLOAD");
        break;
      case AppLifecycleState.resumed:
        // TODO:
        // FlutterView? fv =
        //     WidgetsBinding.instance.platformDispatcher.views.first;

        // final WidgetsBinding binding =
        //     WidgetsFlutterBinding.ensureInitialized();

        // final RenderView? renderView = binding.renderView;
        // final BuildContext? context = renderView?.attached ?? false ? renderView?.element?.buildContext : null;        // Widget _rootWidget = fv.context.widget;

        tlLogger.t("Screenview LOAD");
        break;
      default:
        tlLogger.t("Screenview: ${state.toString()}");
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> getFrameRateConfiguration() async {
    rapidFrameRateLimitMs =
        await _TlConfiguration().get("GlobalScreenSettings/RapidFrameRate") ??
            160;
    rapidSequenceCompleteMs =
        await _TlConfiguration().get("GlobalScreenSettings/RapidFrameDone") ??
            (2 * rapidSequenceCompleteMs);
    initRapidFrameRate = false;
  }

  Future<String> maskText(String text) async {
    final bool? maskingEnabled = await getMaskingEnabled();
    if (maskingEnabled!) {
      if ((await _TlConfiguration()
                  .get("GlobalScreenSettings/Masking/HasCustomMask") ??
              "")
          .toString()
          .contains("true")) {
        final String? smallCase = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/smallCaseAlphabet");
        final String? capitalCase = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/capitalCaseAlphabet");
        final String? symbol = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/symbol");
        final String? number = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/number");

        // Note: The following r"\p{..} expressions have been flagged erroneously as errors in some versions of the IDE
        //       However, they work fine and also do NOT show up in linter, so they do not break CI/CD

        if (smallCase != null) {
          text = text.replaceAll(RegExp(r"\p{Ll}", unicode: true), smallCase);
        }
        if (capitalCase != null) {
          text = text.replaceAll(RegExp(r"\p{Lu}", unicode: true), capitalCase);
        }
        if (symbol != null) {
          text = text.replaceAll(RegExp(r"\p{P}|\p{S}", unicode: true), symbol);
        }
        if (number != null) {
          text = text.replaceAll(RegExp(r"\p{N}", unicode: true), number);
        }
      }
    }
    return text;
  }

  Map<String, dynamic> createRootLayoutControl() {
    return <String, dynamic>{
      "zIndex": 500,
      "type": "FlutterImageView",
      "subType": "UIView",
      "tlType": "image",
      "id": "[w,0],[v,0],[v,0],[FlutterView,0]",
      "position": <String, dynamic>{
        "y": "0",
        "x": "0",
        "width": "$screenWidth",
        "height": "$screenHeight"
      },
      "idType": -4,
      "style": <String, dynamic>{
        "borderColor": 0,
        ""
            "borderAlpha": 1,
        "borderRadius": 0
      },
      "cssId": "w0v0v0FlutterView0",
      "image": <String, dynamic>{
        // If # items change, update item count checks in native code
        "width": "$screenWidth",
        "height": "$screenHeight",
        "value": "",
        "mimeExtension": "",
        "type": "image",
        "base64Image": ""
      }
    };
  }

  /// Retrieves and processes information about the widgets in the current Flutter
  /// widget tree and returns a list of layout data structures.
  ///
  /// These layout data structures contain information about the position, size,
  /// and other properties of the widgets in the tree.
  ///
  /// Returns:
  /// A list of layout data structures. Each layout data structure is a map.
  Future<List<Map<String, dynamic>>> getAllLayouts() async {
    final List<Map<String, dynamic>> layouts = [];
    final List<dynamic> pathList = WidgetPath.entryList();
    final int pathCount = pathList.length;
    bool hasGestures = false;

    if (createRootLayout) {
      layouts.add(createRootLayoutControl());
    }

    for (dynamic entry in pathList) {
      final MapEntry<int, dynamic> widgetEntry =
          entry as MapEntry<int, dynamic>;
      final int key = widgetEntry.key;
      final WidgetPath wp = widgetEntry.value as WidgetPath;
      final BuildContext? context = wp.context;

      if (context == null) {
        tlLogger.w('Context null for path (removed): ${wp.path}');
        WidgetPath.removePath(key);
        continue;
      }
      final String contextString = context.toString();
      if (contextString.startsWith('State') &&
          contextString.endsWith('(DEFUNCT)(no widget)')) {
        tlLogger
            .t("Deleting obsolete path item: $key, context: $contextString");
        WidgetPath.removePath(key);
        continue;
      }
      final Widget widget = context.widget;
      final Map<String, dynamic> args = wp.parameters;
      final String? type = args['type'] ?? '';
      final String? subType = args['subType'] ?? '';

      wp.usedInLayout = true;

      if (type != null && type.compareTo("GestureDetector") == 0) {
        hasGestures = true;
      } else if (subType != null) {
        final String path = wp.widgetPath();
        final dynamic getData = args['data'];
        Map<String, dynamic>? aStyle;
        Map<String, dynamic>? font;
        Map<String, dynamic>? image;
        String? text;

        Map<String, dynamic>? accessibility = args['accessibility'];
        bool? maskingEnabled = await getMaskingEnabled();
        bool masked = maskingEnabled! &&
            (maskIds!.contains(path) || maskIds!.contains(wp.widgetDigest()));

        if (subType.compareTo("ImageView") == 0) {
          image = await getData(widget);
          if (image == null) {
            tlLogger.t("Image is empty!");
            continue;
          }
          tlLogger.t('Image is available: ${widget.runtimeType.toString()}');
        } else if (subType.compareTo("TextView") == 0) {
          text = getData(widget) ?? '';

          final TextStyle style = args['style'] ?? TextStyle();
          final TextAlign align = args['align'] ?? TextAlign.left;

          if (maskingEnabled && !masked && maskValuePatterns != null) {
            for (final String pattern in maskValuePatterns!) {
              if (text!.contains(RegExp(pattern))) {
                masked = true;
                tlLogger.t(
                    'Masking matched content with RE: $pattern, text: $text');
                break;
              }
            }
          }
          if (masked) {
            try {
              text = await maskText(text!);
            } on ConnectException catch (te) {
              tlLogger.t('Unable to mask text. ${te.getMsg}');
            }

            tlLogger.t(
                "Text Layout masked text: $text, Widget: ${widget.runtimeType.toString()}, "
                "Digest for MASKING: ${wp.widgetDigest()}");
          } else {
            tlLogger.t(
                "Text Layout text: $text, Widget: ${widget.runtimeType.toString()}");
          }

          font = {
            'family': style.fontFamily,
            'size': style.fontSize.toString(),
            'bold': (FontWeight.values.indexOf(style.fontWeight!) >
                    FontWeight.values.indexOf(FontWeight.normal))
                .toString(),
            'italic': (style.fontStyle == FontStyle.italic).toString()
          };

          double top = 0, bottom = 0, left = 0, right = 0;

          if (wp.parent!.widget is Padding) {
            final Padding padding = wp.parent!.widget as Padding;
            if (padding.padding is EdgeInsets) {
              final EdgeInsets eig = padding.padding as EdgeInsets;
              top = eig.top;
              bottom = eig.bottom;
              left = eig.left;
              right = eig.right;
            }
          }

          if (subType.compareTo("TextField") == 0) {
            var textField = widget as TextField;
            var controller = textField.controller;
            controller?.addListener(() {});
          }

          aStyle = {
            'textColor': (style.color!.value & 0xFFFFFF).toString(),
            'textAlphaColor': (style.color?.alpha ?? 0).toString(),
            'textAlphaBGColor': (style.backgroundColor?.alpha ?? 0).toString(),
            'textAlign': align.toString().split('.').last,
            'paddingBottom': bottom.toInt().toString(),
            'paddingTop': top.toInt().toString(),
            'paddingLeft': left.toInt().toString(),
            'paddingRight': right.toInt().toString(),
            'hidden': (style.color!.opacity == 1.0).toString(),
            'colorPrimary': (style.foreground?.color ?? 0).toString(),
            'colorPrimaryDark': 0.toString(), // TBD: Dark theme??
            'colorAccent': (style.decorationColor?.value ?? 0)
                .toString(), // TBD: are this the same??
          };
        }

        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset position = box.localToGlobal(Offset.zero);

        if (image != null) {
          tlLogger.t("Adding image to layouts....");
        }
        tlLogger.t(
            '--> Layout Flutter -- x: ${position.dx}, y: ${position.dy}, width: ${box.size.width.toInt()}, text: $text');

        layouts.add(<String, dynamic>{
          'id': path,
          'cssId': wp.widgetDigest(),
          'idType': (-4).toString(),
          'tlType': (image != null)
              ? 'image'
              : (text != null && text.contains('\n') ? 'textArea' : 'label'),
          'type': type,
          'subType': subType,
          'position': <String, String>{
            'x': position.dx.toInt().toString(),
            'y': position.dy.toInt().toString(),
            'width': box.size.width.toInt().toString(),
            'height': box.size.height.toInt().toString(),
          },
          'zIndex': "501",
          'currState': <String, dynamic>{
            'text': text,
            'placeHolder': "", // TBD??
            'font': font
          },
          if (image != null) 'image': image,
          if (aStyle != null) 'style': aStyle,
          if (accessibility != null) 'accessibility': accessibility,
          'originalId': path.replaceAll("/", ""),
          'masked': '$masked'
        });
      }
    }
    layoutParametersForGestures =
        hasGestures ? List.unmodifiable(layouts) : null;

    tlLogger.t(
        "WigetPath cache size, before: $pathCount, after: ${WidgetPath.size}, # of layouts: ${layouts.length}");

    return layouts;
  }
}

// ignore: unused_element
class _Pinch {
  static const initScale = 1.0;
  final List<String> directions = ['close', 'open'];

  Offset? _startPosition;
  Offset? _updatePosition;
  double _scale = -1;
  int _fingers = 0;

  set startPosition(Offset position) => _startPosition = position;
  set updatePosition(Offset position) => _updatePosition = position;
  set scale(double scale) => _scale = scale;
  set fingers(int gesturePoints) {
    if (_fingers < gesturePoints) {
      _fingers = gesturePoints;
    }
  }

  Offset? get getStartPosition => _startPosition;
  Offset? get getUpdatePosition => _updatePosition;
  double get getScale => _scale;
  int get getMaxFingers => _fingers;

  String pinchResult() {
    if (_startPosition == null ||
        _updatePosition == null ||
        _scale == initScale ||
        _fingers != 2) {
      return "";
    }
    return directions[_scale < initScale ? 0 : 1];
  }
}

class _Swipe {
  final List<String> directions = ['right', 'left', 'down', 'up'];

  Offset? _startPosition;
  Offset? _updatePosition;
  Duration _startTimestamp = Duration();
  Duration _updateTimestamp = Duration();
  Velocity? _velocity = Velocity(pixelsPerSecond: const Offset(0, 0));
  String _direction = "";

  set startPosition(Offset position) => _startPosition = position;
  set startTimeStamp(Duration ts) => _startTimestamp = ts;
  set updatePosition(Offset position) => _updatePosition = position;
  set updateTimestamp(Duration ts) => _updateTimestamp = ts;
  set velocity(Velocity? v) => _velocity = v;
  Offset? get getStartPosition => _startPosition;
  Offset? get getUpdatePosition => _updatePosition;
  Velocity? get velocity => _velocity!;
  String get direction => _direction;
  String getStartTimestampString() => _startTimestamp.inMilliseconds.toString();
  String getUpdateTimestampString() =>
      _updateTimestamp.inMilliseconds.toString();

  String calculateSwipe() {
    if (_startPosition == null || _updatePosition == null) {
      return "";
    }
    final Offset offset = _updatePosition! - _startPosition!;
    return _getSwipeDirection(offset);
  }

  String _getSwipeDirection(Offset offset) {
    final int axis = offset.dx.abs() < offset.dy.abs() ? 2 : 0;
    final int direction =
        (axis == 0) ? (offset.dx < 0 ? 1 : 0) : (offset.dy < 0 ? 1 : 0);
    return (_direction = directions[axis + direction]);
  }
}

/// Represents an accessible position with information about its ID, label, hint, and position coordinates.
///
class AccessiblePosition {
  final double dx;
  final double dy;
  final double width;
  final double height;
  final String? id;
  final String? label;
  final String? hint;

  /// Creates a new instance of `AccessiblePosition` with the specified parameters.
  AccessiblePosition({
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    this.id,
    this.label,
    this.hint,
  });

  /// Converts the `AccessiblePosition` instance to a map representation.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'hint': hint,
      'position': {
        'x': dx,
        'y': dy,
        'width': width,
        'height': height,
      },
    };
  }
}

///
/// Connect static helper methods
///
class ConnectHelper {
  ConnectHelper();

  // static const String _tap = "onTap";
  // static const String _doubleTap = "onDoubleTap";
  // static const String _longPress = "onLongPress";
  // static const String _onPanStart = "onPanStart";
  // static const String _onPanEnd = "onPanEnd";
  // static const String _onPanUpdate = "onPanUpdate";
  static const String _onScaleStart = "onScaleStart";
  static const String _onScaleUpdate = "onScaleUpdate";
  static const String _onScaleEnd = "onScaleEnd";

  // static const String _onVerticalDragStart = "onVerticalDragStart";
  // static const String _onVerticalDragUpdate = "onVerticalDragUpdate";
  // static const String _onVerticalDragEnd = "onVerticalDragEnd";
  // static const String _onHorizontalDragStart = "onHorizontalDragStart";
  // static const String _onHorizontalDragUpdate = "onHorizontalDragUpdate";
  // static const String _onHorizontalDragEnd = "onHorizontalDragEnd";
  static bool captureScreen = true;
  static String currentLogicalPageName = "";

  static Map<String, dynamic> checkForSemantics(WidgetPath? wp) {
    final BuildContext? context = wp!.context;
    final Map<String, dynamic> accessibility = {};
    Semantics? semantics;

    int maxVisit = 10; // TBD: How far up the tree should we look for Semantics?

    context?.visitAncestorElements((ancestor) {
      final Widget parentWidget = ancestor.widget;
      if (parentWidget is Semantics) {
        semantics = parentWidget;
        return false;
      }
      return --maxVisit > 0;
    });

    if (semantics != null) {
      final String? hint = semantics!.properties.hint;
      final String? label = semantics!.properties.label;
      accessibility.addAll({
        'accessibility': {
          'id': '/GestureDetector',
          'label': label ?? '',
          'hint': hint ?? ''
        }
      });
    }
    return accessibility;
  }

  static String getGestureTarget(WidgetPath wp) {
    final dynamic widget = wp.context!.widget;
    String gestureTarget;

    try {
      gestureTarget = widget.child.runtimeType.toString();
    } on NoSuchMethodError {
      gestureTarget = wp.parentWidgetType!;
    }
    return gestureTarget;
  }

  static void gestureHelper({Widget? gesture, String? gestureType}) async {
    if (gesture == null) {
      tlLogger.w(
          'Warning: Gesture is null in gestureHelper, type: ${gestureType ?? "<NONE>"}');
      return;
    }
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wp = WidgetPath.getPath(hashCode);
      final BuildContext? context = wp!.context;
      final String gestureTarget = getGestureTarget(wp);
      final Map<String, dynamic> accessibility = checkForSemantics(wp);

      tlLogger.t(
          '${gestureType!.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');
      tlLogger.t('--> Path: ${wp.widgetPath()}, digest: ${wp.widgetDigest()}');

      if (ConnectHelper.captureScreen) {
        await PluginConnect.onTlGestureEvent(
            gesture: gestureType,
            id: wp.widgetPath(),
            target: gestureTarget,
            data: accessibility.isNotEmpty ? accessibility : null,
            layoutParameters: TlBinder.layoutParametersForGestures);
      }
    } else {
      tlLogger.t(
          "ERROR: ${gesture.runtimeType.toString()} gesture not found for hashcode: $hashCode");
    }
  }

  static void pointerEventHelper(String action, PointerEvent pe) {
    final String json = jsonEncode(pe, toEncodable: encodeJsonPointerEvent);
    final Map<String, dynamic> fields = jsonDecode(json);

    tlLogger.t("My PointerEvent $action TRAP!");

    if (fields.containsKey('timestamp')) {
      fields['timestamp'] = fields['timestamp'].toString();
    }
    fields['action'] = action;
    PluginConnect.onTlPointerEvent(fields: fields);
  }

  static Map<String, dynamic> errorDetailsHelper(
      FlutterErrorDetails fed, String type) {
    final Map<String, dynamic> data = {};
    final String errorString = fed.exception.runtimeType.toString();

    data["name"] = errorString;
    data["message"] = fed.toStringShort();
    data["stacktrace"] = fed.stack.toString();
    data["handled"] = true;

    tlLogger.t(
        "!!! Flutter exception, type: $type, class: $errorString, hash: ${fed.exception.hashCode}");

    return data;
  }

  static Object? encodeJsonPointerEvent(Object? value) {
    Map<String, dynamic> map = {};

    if (value != null && value is PointerEvent) {
      final PointerEvent pointerEvent = value;

      map['position'] = {
        'dx': pointerEvent.position.dx,
        'dy': pointerEvent.position.dy
      };
      map['localPosition'] = {
        'dx': pointerEvent.localPosition.dx,
        'dy': pointerEvent.localPosition.dy
      };
      map['down'] = pointerEvent.down;
      map['kind'] = pointerEvent.kind.index;
      map['buttons'] = pointerEvent.buttons;
      map['embedderId'] = pointerEvent.embedderId;
      map['pressure'] = pointerEvent.pressure;
      map['timestamp'] = pointerEvent.timeStamp.inMicroseconds;
    }

    return map;
  }

  static void pinchGestureHelper(
      {required Widget? gesture,
      required String onType,
      Offset? offset,
      double? scale,
      Velocity? velocity,
      int fingers = 0}) async {
    if (gesture == null) {
      tlLogger.w('Warning: Gesture is null in pinchGestureHelper');
      return;
    }
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wp = WidgetPath.getPath(hashCode);
      final BuildContext? context = wp!.context;
      final String gestureTarget = getGestureTarget(wp);
      final Map<String, dynamic> accessibility = checkForSemantics(wp);

      tlLogger.t(
          '${onType.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');

      switch (onType) {
        case _onScaleStart:
          {
            final _Pinch pinch = _Pinch();
            pinch.startPosition = offset!;
            wp.addParameters(<String, dynamic>{'pinch': pinch});
            break;
          }
        case _onScaleUpdate:
          {
            if (wp.parameters.containsKey('pinch')) {
              final _Pinch pinch = wp.parameters['pinch'];
              pinch.updatePosition = offset!;
              pinch.scale = scale!;
              pinch.fingers = fingers;
            }
            break;
          }
        case _onScaleEnd:
          {
            if (wp.parameters.containsKey('pinch')) {
              final _Pinch pinch = wp.parameters['pinch'];
              pinch.fingers = fingers;
              final String direction = pinch.pinchResult();
              tlLogger.t(
                  '--> Pinch, fingers: ${pinch.getMaxFingers}, direction: $direction');

              if (direction.isNotEmpty) {
                final Offset start = pinch.getStartPosition!;
                final Offset end = pinch.getUpdatePosition!;
                wp.parameters.clear();

                if (ConnectHelper.captureScreen) {
                  await PluginConnect.onTlGestureEvent(
                      gesture: 'pinch',
                      id: wp.widgetPath(),
                      target: gestureTarget,
                      data: <String, dynamic>{
                        'pointer1': {'dx': start.dx, 'dy': start.dy},
                        'pointer2': {'dx': end.dx, 'dy': end.dy},
                        'direction': direction,
                        'velocity': {
                          'dx': velocity?.pixelsPerSecond.dx,
                          'dy': velocity?.pixelsPerSecond.dy
                        },
                        ...accessibility,
                      },
                      layoutParameters: TlBinder.layoutParametersForGestures);
                }
              }
            }
            break;
          }
        default:
          break;
      }
    } else {
      tlLogger.t(
          "ERROR: ${gesture.runtimeType.toString()} not found for hashcode: $hashCode");
    }
  }

  /// Asks the native layer if it can capture the screen with the given
  /// [screenName].
  /// [jsonString].
  ///
  /// This is done by looking up the AutoLayout configuration for the given
  /// screen name. If the screen is found, its 'ScreenChange' property is
  /// returned. If the screen is not found, the 'GlobalScreenSettings' is
  /// used as a fallback.
  ///
  /// Returns `false` if the screen name is not found in the AutoLayout
  /// configuration.
  static bool canCaptureScreen(String screenName, String jsonString) {
    if (jsonString.isEmpty) {
      return false;
    }

    // Decode JSON
    final Map<String, dynamic> jsonConfig = jsonDecode(jsonString);

    if (jsonConfig.containsKey(screenName)) {
      captureScreen = jsonConfig[screenName]['ScreenChange'] ?? false;
      return captureScreen;
    } else if (jsonConfig.containsKey('GlobalScreenSettings')) {
      captureScreen =
          jsonConfig['GlobalScreenSettings']['ScreenChange'] ?? false;
      return captureScreen;
    }

    return false;
  }
}
