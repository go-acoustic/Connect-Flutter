// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:connect_flutter_plugin/connect_flutter_plugin.dart';
import 'package:connect_flutter_plugin/logger.dart';
import 'package:dual_screen/dual_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_gen/gen_l10n/gallery_localizations.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:gallery/constants.dart';
import 'package:gallery/data/gallery_options.dart';
import 'package:gallery/pages/backdrop.dart';
import 'package:gallery/pages/splash.dart';
import 'package:gallery/routes.dart';
import 'package:gallery/themes/gallery_theme_data.dart';
import 'package:google_fonts/google_fonts.dart';

// import 'firebase_options.dart';
import 'layout/adaptive.dart';

export 'package:gallery/data/demos.dart' show pumpDeferredLibraries;

void main() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  if (defaultTargetPlatform != TargetPlatform.linux &&
      defaultTargetPlatform != TargetPlatform.windows) {
    WidgetsFlutterBinding.ensureInitialized();
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    // FlutterError.onError = (errorDetails) {
    //   FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    // };
    // // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Tealeaf
    // PlatformDispatcher.instance.onError = (error, stack) {
    //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    //   return true;
    // };
  }

  ///
  /// Add Connect Wrapper for auto instrumentation
  ///
  runApp(Connect(child: const GalleryApp()));

  /// Sample Connect Plugin APIs for SDK configurable properties
  await _loadConfigItems();
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({
    super.key,
    this.initialRoute,
    this.isTestMode = false,
  });

  final String? initialRoute;
  final bool isTestMode;

  @override
  Widget build(BuildContext context) {
    return ModelBinding(
      initialModel: GalleryOptions(
        themeMode: ThemeMode.system,
        textScaleFactor: systemTextScaleFactorOption,
        customTextDirection: CustomTextDirection.localeBased,
        locale: null,
        timeDilation: timeDilation,
        platform: defaultTargetPlatform,
        isTestMode: isTestMode,
      ),
      child: Builder(
        builder: (context) {
          final options = GalleryOptions.of(context);
          final hasHinge = MediaQuery.of(context).hinge?.bounds != null;
          return MaterialApp(
            ///
            /// Add the required Connect loggingNavigatorObserver to the navigatorObservers list
            ///
            navigatorObservers: [Connect.loggingNavigatorObserver],
            // showSemanticsDebugger: true,

            restorationScopeId: 'rootGallery',
            title: 'Flutter Gallery',
            debugShowCheckedModeBanner: false,
            themeMode: options.themeMode,
            theme: GalleryThemeData.lightThemeData.copyWith(
              platform: options.platform,
            ),
            darkTheme: GalleryThemeData.darkThemeData.copyWith(
              platform: options.platform,
            ),
            localizationsDelegates: const [
              ...GalleryLocalizations.localizationsDelegates,
              LocaleNamesLocalizationsDelegate()
            ],
            initialRoute: initialRoute,
            supportedLocales: GalleryLocalizations.supportedLocales,
            locale: options.locale,
            localeListResolutionCallback: (locales, supportedLocales) {
              deviceLocale = locales?.first;
              return basicLocaleListResolution(locales, supportedLocales);
            },
            onGenerateRoute: (settings) =>
                RouteConfiguration.onGenerateRoute(settings, hasHinge),
          );
        },
      ),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ApplyTextOptions(
      child: SplashPage(
        child: Backdrop(
          isDesktop: isDisplayDesktop(context),
        ),
      ),
    );
  }
}

///
/// Sample Plugin API calls to config. SDK items
///
/// Update according to specific SDK configurable properties, and module name
///
Future<void> _loadConfigItems() async {
  // Get boolean config item
  final isEnabled =
      await PluginConnect.getBooleanConfigItemForKey('isEnabled', 'Tealeaf');
  tlLogger.d('PluginConnect getBooleanConfigItemForKey: $isEnabled');

  // Get string config item with default value
  final serverUrl = await PluginConnect.getStringItemForKey(
      'PostMessageURL', 'Tealeaf',
      defaultValue: 'https://default.server.com');
  tlLogger.d('PluginConnect getStringItemForKey: $serverUrl');

  // Get number config item with default value
  final maxRetries = await PluginConnect.getNumberItemForKey(
      'maxRetries', 'Tealeaf',
      defaultValue: 3);
  tlLogger.d('PluginConnect getNumberItemForKey: $maxRetries');

  // Set boolean config item
  final success1 = await PluginConnect.setBooleanConfigItemForKey(
      'isEnabled', true, 'Tealeaf');
  tlLogger.d('PluginConnect setBooleanConfigItemForKey: $success1');

  // Set string config item
  final newServerUrl = await PluginConnect.setStringItemForKey(
      'serverUrl', 'https://new.server.com', 'Tealeaf');
  tlLogger.d('PluginConnect setBooleanConfigItemForKey: $newServerUrl');

  // Set number config item
  final newMaxRetries =
      await PluginConnect.setNumberItemForKey('maxRetries', 5, 'Tealeaf');
  tlLogger.d('PluginConnect setNumberItemForKey: $newMaxRetries');

  // Connect logSignal API sample
  await PluginConnect.logSignal(signalData: {
    'behaviorType': 'orderConfirmation',
    'orderId': '145667',
    'orderSubtotal': 10,
    'orderShip': 10,
    'orderTax': 5.99,
    'orderDiscount': '10%',
    'currency': 'USD',
  });
}
