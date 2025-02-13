import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class DebugOnlyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level == Level.error;
    }
    return (event.level == Level.debug ||
        event.level == Level.trace ||
        event.level == Level.error);
  }
}

// ignore: non_constant_identifier_names
int logMethodCount = 0;

class ConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

final dynamic _prettyPrinter = PrettyPrinter(
  methodCount: logMethodCount, // number of method calls to be displayed
  errorMethodCount: 8, // number of method calls if stacktrace is provided
  lineLength: 140, // width of the output
  colors: false, // Colorful log messages
  printEmojis: false, // Print an emoji for each log message
);

final dynamic _verbosePrinter =
    io.Platform.isIOS ? _prettyPrinter : SimplePrinter();

final Logger tlLogger = Logger(
  filter: DebugOnlyFilter(),
  printer: HybridPrinter(_prettyPrinter, trace: _verbosePrinter),
  output: ConsoleOutput(),
);
