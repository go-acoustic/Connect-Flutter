import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';

class TlTextFieldListener {
  static void setupFocusListener(GlobalKey widgetKey, bool focused){
    RenderBox renderbox = widgetKey.currentContext!.findRenderObject() as RenderBox;
    Offset globalPosition = renderbox.localToGlobal(Offset.zero); 
    
    // Perform hit-testing
    final BoxHitTestResult result = BoxHitTestResult();
    renderbox.hitTest(result, position: globalPosition);
    String jsonString = "";

    // Analyze the hit result to find the widget that was touched.
    for (HitTestEntry entry in result.path) {
      if (entry is! BoxHitTestEntry || entry is SliverHitTestEntry) {
        final targetWidget = entry.target;

        final widgetString = targetWidget.toString();
        jsonString = jsonEncode(widgetString);

        break;
      }
    }

    var widgetId = jsonString == "" ? "FlutterSurfaceView" : jsonString;
    double x = globalPosition.dx;
    double y = globalPosition.dy;

    PluginConnect.tlFocusChanged(widgetId, x, y, focused);
  }
}
