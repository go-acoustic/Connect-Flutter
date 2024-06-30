import 'logger.dart';

///
/// Class to time a section of AOP code
///
/// TBD: Add comments and make debug message generic
///
class TimeIt {
  final String label;
  final List<int> durations = [];

  TimeIt({this.label = "Timed function: "});

  dynamic execute(Function function, {String? label}) {
    final DateTime start = DateTime.now();
    final String prefix = label ?? this.label;
    final dynamic result = function();
    durations.add(
        DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch);
    tlLogger.v('$prefix required ${durations.last} ms');
    return result;
  }

  int elapsed() => durations.isNotEmpty ? durations.first : 0;
  int diff() => durations.length == 2 ? (durations[1] - durations[0]) : 0;

  void showResults() => tlLogger.v(
      '$label. AOP part: ${diff()} ms, injected function part: ${elapsed()} ms');
}
