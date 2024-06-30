import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore_for_file:  avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('tap on the floating action button, verify counter',
        (tester) async {
      const GalleryApp();
      await tester.pumpAndSettle();


    });
  });
}