// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:dual_screen/dual_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/gallery_localizations.dart';
import 'package:gallery/codeviewer/code_displayer.dart';
import 'package:gallery/codeviewer/code_style.dart';
import 'package:gallery/constants.dart';
import 'package:gallery/data/demos.dart';
import 'package:gallery/data/gallery_options.dart';
import 'package:gallery/feature_discovery/feature_discovery.dart';
import 'package:gallery/layout/adaptive.dart';
import 'package:gallery/pages/splash.dart';
import 'package:gallery/themes/gallery_theme_data.dart';
import 'package:gallery/themes/material_demo_theme_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _demoViewedCountKey = 'demoViewedCountKey';

enum _DemoState {
  normal,
  options,
  info,
  code,
  fullscreen,
}

class DemoPage extends StatefulWidget {
  const DemoPage({
    super.key,
    required this.slug,
  });

  static const String baseRoute = '/demo';
  final String? slug;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late Map<String?, GalleryDemo> slugToDemoMap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // To make sure that we do not rebuild the map for every update to the demo
    // page, we save it in a variable. The cost of running `slugToDemo` is
    // still only close to constant, as it's just iterating over all of the
    // demos.
    slugToDemoMap = Demos.asSlugToDemoMap(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slug == null || !slugToDemoMap.containsKey(widget.slug)) {
      // Return to root if invalid slug.
      Navigator.of(context).pop();
    }
    return ScaffoldMessenger(
        child: GalleryDemoPage(
      restorationId: widget.slug!,
      demo: slugToDemoMap[widget.slug]!,
    ));
  }
}

class GalleryDemoPage extends StatefulWidget {
  const GalleryDemoPage({
    super.key,
    required this.restorationId,
    required this.demo,
  });

  final String restorationId;
  final GalleryDemo demo;

  @override
  State<GalleryDemoPage> createState() => _GalleryDemoPageState();
}

class _GalleryDemoPageState extends State<GalleryDemoPage>
    with RestorationMixin, TickerProviderStateMixin {
  final RestorableInt _demoStateIndex = RestorableInt(_DemoState.normal.index);
  final RestorableInt _configIndex = RestorableInt(0);

  bool? _isDesktop;
  bool _showFeatureHighlight = true;
  int _demoViewedCount = 0;

  late AnimationController _codeBackgroundColorController;

  @override
  String get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_demoStateIndex, 'demo_state');
    registerForRestoration(_configIndex, 'configuration_index');
  }

  GalleryDemoConfiguration get _currentConfig {
    return widget.demo.configurations[_configIndex.value];
  }

  bool get _hasOptions => widget.demo.configurations.length > 1;

  bool get _isSupportedSharedPreferencesPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Only show the feature highlight on Android/iOS, in mobile layout, non-test
  // mode, and only on the first and fourth time the demo page is viewed.
  bool _showFeatureHighlightForPlatform(BuildContext context) {
    return _showFeatureHighlight &&
        _isSupportedSharedPreferencesPlatform &&
        !isDisplayDesktop(context) &&
        !GalleryOptions.of(context).isTestMode &&
        (_demoViewedCount == 0 || _demoViewedCount == 3);
  }

  @override
  void initState() {
    super.initState();
    _codeBackgroundColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    SharedPreferences.getInstance().then((preferences) {
      setState(() {
        _demoViewedCount = preferences.getInt(_demoViewedCountKey) ?? 0;
        preferences.setInt(_demoViewedCountKey, _demoViewedCount + 1);
      });
    });
  }

  @override
  void dispose() {
    _demoStateIndex.dispose();
    _configIndex.dispose();
    _codeBackgroundColorController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDesktop ??= isDisplayDesktop(context);
  }

  /// Sets state and updates the background color for code.
  void setStateAndUpdate(VoidCallback callback) {
    setState(() {
      callback();
      if (_demoStateIndex.value == _DemoState.code.index) {
        _codeBackgroundColorController.forward();
      } else {
        _codeBackgroundColorController.reverse();
      }
    });
  }

  void _handleTap(_DemoState newState) {
    var newStateIndex = newState.index;

    // Do not allow normal state for desktop.
    if (_demoStateIndex.value == newStateIndex && isDisplayDesktop(context)) {
      if (_demoStateIndex.value == _DemoState.fullscreen.index) {
        setStateAndUpdate(() {
          _demoStateIndex.value =
              _hasOptions ? _DemoState.options.index : _DemoState.info.index;
        });
      }
      return;
    }

    setStateAndUpdate(() {
      _demoStateIndex.value = _demoStateIndex.value == newStateIndex
          ? _DemoState.normal.index
          : newStateIndex;
    });
  }

  Future<void> _showDocumentation(BuildContext context) async {
    final url = _currentConfig.documentationUrl;

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(GalleryLocalizations.of(context)!.demoInvalidURL),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(url),
              ),
            ],
          );
        },
      );
    }
  }

  void _resolveState(BuildContext context) {
    final isDesktop = isDisplayDesktop(context);
    final isFoldable = isDisplayFoldable(context);
    if (_DemoState.values[_demoStateIndex.value] == _DemoState.fullscreen &&
        !isDesktop) {
      // Do not allow fullscreen state for mobile.
      _demoStateIndex.value = _DemoState.normal.index;
    } else if (_DemoState.values[_demoStateIndex.value] == _DemoState.normal &&
        (isDesktop || isFoldable)) {
      // Do not allow normal state for desktop.
      _demoStateIndex.value =
          _hasOptions ? _DemoState.options.index : _DemoState.info.index;
    } else if (isDesktop != _isDesktop) {
      _isDesktop = isDesktop;
      // When going from desktop to mobile, return to normal state.
      if (!isDesktop) {
        _demoStateIndex.value = _DemoState.normal.index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFoldable = isDisplayFoldable(context);
    final isDesktop = isDisplayDesktop(context);
    _resolveState(context);

    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurface;
    final selectedIconColor = colorScheme.primary;
    final appBarPadding = isDesktop ? 20.0 : 0.0;
    final currentDemoState = _DemoState.values[_demoStateIndex.value];
    final localizations = GalleryLocalizations.of(context)!;

    final appBar = AppBar(
      backgroundColor: Colors.transparent,
      leading: Padding(
        padding: EdgeInsetsDirectional.only(start: appBarPadding),
        child: IconButton(
          key: const ValueKey('Back'),
          icon: const BackButtonIcon(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
      ),
      actions: [
        if (_hasOptions)
          IconButton(
            icon: FeatureDiscovery(
              title: localizations.demoOptionsFeatureTitle,
              description: localizations.demoOptionsFeatureDescription,
              showOverlay: _showFeatureHighlightForPlatform(context),
              color: colorScheme.primary,
              onDismiss: () {
                setState(() {
                  _showFeatureHighlight = false;
                });
              },
              onTap: () {
                setState(() {
                  _showFeatureHighlight = false;
                });
              },
              child: Icon(
                Icons.tune,
                color: currentDemoState == _DemoState.options ||
                        _showFeatureHighlightForPlatform(context)
                    ? selectedIconColor
                    : iconColor,
              ),
            ),
            tooltip: localizations.demoOptionsTooltip,
            onPressed: () => _handleTap(_DemoState.options),
          ),
        IconButton(
          icon: const Icon(Icons.info),
          tooltip: localizations.demoInfoTooltip,
          color: currentDemoState == _DemoState.info
              ? selectedIconColor
              : iconColor,
          onPressed: () => _handleTap(_DemoState.info),
        ),
        IconButton(
          icon: const Icon(Icons.code),
          tooltip: localizations.demoCodeTooltip,
          color: currentDemoState == _DemoState.code
              ? selectedIconColor
              : iconColor,
          onPressed: () => _handleTap(_DemoState.code),
        ),
        IconButton(
          icon: const Icon(Icons.library_books),
          tooltip: localizations.demoDocumentationTooltip,
          color: iconColor,
          onPressed: () => _showDocumentation(context),
        ),
        if (isDesktop)
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: localizations.demoFullscreenTooltip,
            color: currentDemoState == _DemoState.fullscreen
                ? selectedIconColor
                : iconColor,
            onPressed: () => _handleTap(_DemoState.fullscreen),
          ),
        SizedBox(width: appBarPadding),
      ],
    );

    final mediaQuery = MediaQuery.of(context);
    final bottomSafeArea = mediaQuery.padding.bottom;
    final contentHeight = mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom -
        appBar.preferredSize.height;
    final maxSectionHeight = isDesktop ? contentHeight : contentHeight - 64;
    final horizontalPadding = isDesktop ? mediaQuery.size.width * 0.12 : 0.0;
    const maxSectionWidth = 420.0;

    Widget section;
    switch (currentDemoState) {
      case _DemoState.options:
        section = _DemoSectionOptions(
          maxHeight: maxSectionHeight,
          maxWidth: maxSectionWidth,
          configurations: widget.demo.configurations,
          configIndex: _configIndex.value,
          onConfigChanged: (index) {
            setStateAndUpdate(() {
              _configIndex.value = index;
              if (!isDesktop) {
                _demoStateIndex.value = _DemoState.normal.index;
              }
            });
          },
        );
        break;
      case _DemoState.info:
        section = _DemoSectionInfo(
          maxHeight: maxSectionHeight,
          maxWidth: maxSectionWidth,
          title: _currentConfig.title,
          description: _currentConfig.description,
        );
        break;
      case _DemoState.code:
        final codeTheme = GoogleFonts.robotoMono(
          fontSize: 12 * GalleryOptions.of(context).textScaleFactor(context),
        );
        section = CodeStyle(
          baseStyle: codeTheme.copyWith(color: const Color(0xFFFAFBFB)),
          numberStyle: codeTheme.copyWith(color: const Color(0xFFBD93F9)),
          commentStyle: codeTheme.copyWith(color: const Color(0xFF808080)),
          keywordStyle: codeTheme.copyWith(color: const Color(0xFF1CDEC9)),
          stringStyle: codeTheme.copyWith(color: const Color(0xFFFFA65C)),
          punctuationStyle: codeTheme.copyWith(color: const Color(0xFF8BE9FD)),
          classStyle: codeTheme.copyWith(color: const Color(0xFFD65BAD)),
          constantStyle: codeTheme.copyWith(color: const Color(0xFFFF8383)),
          child: _DemoSectionCode(
            maxHeight: maxSectionHeight,
            codeWidget: CodeDisplayPage(
              _currentConfig.code,
            ),
          ),
        );
        break;
      default:
        section = Container();
        break;
    }

    Widget body;
    Widget demoContent = ScaffoldMessenger(
      child: DemoWrapper(
        height: contentHeight,
        buildRoute: _currentConfig.buildRoute,
      ),
    );
    if (isDesktop) {
      final isFullScreen = currentDemoState == _DemoState.fullscreen;
      final Widget sectionAndDemo = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFullScreen) Expanded(child: section),
          SizedBox(width: !isFullScreen ? 48.0 : 0),
          Expanded(child: demoContent),
        ],
      );

      body = SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: sectionAndDemo,
        ),
      );
    } else if (isFoldable) {
      body = Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: TwoPane(
          startPane: demoContent,
          endPane: section,
        ),
      );
    } else {
      section = AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        curve: Curves.easeIn,
        child: section,
      );

      final isDemoNormal = currentDemoState == _DemoState.normal;
      // Add a tap gesture to collapse the currently opened section.
      demoContent = Semantics(
        label:
            '${GalleryLocalizations.of(context)!.demo}, ${widget.demo.title}',
        child: MouseRegion(
          cursor: isDemoNormal ? MouseCursor.defer : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isDemoNormal
                ? null
                : () {
                    setStateAndUpdate(() {
                      _demoStateIndex.value = _DemoState.normal.index;
                    });
                  },
            child: Semantics(
              excludeSemantics: !isDemoNormal,
              child: demoContent,
            ),
          ),
        ),
      );

      body = SafeArea(
        bottom: false,
        child: ListView(
          // Use a non-scrollable ListView to enable animation of shifting the
          // demo offscreen.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            section,
            demoContent,
            // Fake the safe area to ensure the animation looks correct.
            SizedBox(height: bottomSafeArea),
          ],
        ),
      );
    }

    Widget page;

    if (isDesktop || isFoldable) {
      page = AnimatedBuilder(
          animation: _codeBackgroundColorController,
          builder: (context, child) {
            Brightness themeBrightness;

            switch (GalleryOptions.of(context).themeMode) {
              case ThemeMode.system:
                themeBrightness = MediaQuery.of(context).platformBrightness;
                break;
              case ThemeMode.light:
                themeBrightness = Brightness.light;
                break;
              case ThemeMode.dark:
                themeBrightness = Brightness.dark;
                break;
            }

            Widget contents = Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ApplyTextOptions(
                child: Scaffold(
                  appBar: appBar,
                  body: body,
                  backgroundColor: Colors.transparent,
                ),
              ),
            );

            if (themeBrightness == Brightness.light) {
              // If it is currently in light mode, add a
              // dark background for code.
              Widget codeBackground = SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(top: 56),
                  child: Container(
                    color: ColorTween(
                      begin: Colors.transparent,
                      end: GalleryThemeData.darkThemeData.canvasColor,
                    ).animate(_codeBackgroundColorController).value,
                  ),
                ),
              );

              contents = Stack(
                children: [
                  codeBackground,
                  contents,
                ],
              );
            }

            return Container(
              color: colorScheme.surface,
              child: contents,
            );
          });
    } else {
      page = Container(
        color: colorScheme.surface,
        child: ApplyTextOptions(
          child: Scaffold(
            appBar: appBar,
            body: body,
            resizeToAvoidBottomInset: false,
          ),
        ),
      );
    }

    // Add the splash page functionality for desktop.
    if (isDesktop) {
      page = MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: SplashPage(
          child: page,
        ),
      );
    }

    return FeatureDiscoveryController(page);
  }
}

class _DemoSectionOptions extends StatelessWidget {
  const _DemoSectionOptions({
    required this.maxHeight,
    required this.maxWidth,
    required this.configurations,
    required this.configIndex,
    required this.onConfigChanged,
  });

  final double maxHeight;
  final double maxWidth;
  final List<GalleryDemoConfiguration> configurations;
  final int configIndex;
  final ValueChanged<int> onConfigChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 24,
                top: 12,
                end: 24,
              ),
              child: Text(
                GalleryLocalizations.of(context)!.demoOptionsTooltip,
                style: textTheme.headlineMedium!.apply(
                  color: colorScheme.onSurface,
                  fontSizeDelta:
                      isDisplayDesktop(context) ? desktopDisplay1FontDelta : 0,
                ),
              ),
            ),
            Divider(
              thickness: 1,
              height: 16,
              color: colorScheme.onSurface,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final configuration in configurations)
                    _DemoSectionOptionsItem(
                      title: configuration.title,
                      isSelected: configuration == configurations[configIndex],
                      onTap: () {
                        onConfigChanged(configurations.indexOf(configuration));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DemoSectionOptionsItem extends StatelessWidget {
  const _DemoSectionOptionsItem({
    required this.title,
    required this.isSelected,
    this.onTap,
  });

  final String title;
  final bool isSelected;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colorScheme.surface : null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: double.infinity),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium!.apply(
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}

class _DemoSectionInfo extends StatelessWidget {
  const _DemoSectionInfo({
    required this.maxHeight,
    required this.maxWidth,
    required this.title,
    required this.description,
  });

  final double maxHeight;
  final double maxWidth;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: 24,
          top: 12,
          end: 24,
          bottom: 32,
        ),
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                title,
                style: textTheme.headlineMedium!.apply(
                  color: colorScheme.onSurface,
                  fontSizeDelta:
                      isDisplayDesktop(context) ? desktopDisplay1FontDelta : 0,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                description,
                style: textTheme.bodyMedium!.apply(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoWrapper extends StatelessWidget {
  const DemoWrapper({
    super.key,
    required this.height,
    required this.buildRoute,
  });

  final double height;
  final WidgetBuilder buildRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      height: height,
      child: ClipRRect(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(10.0),
          bottom: Radius.circular(2.0),
        ),
        child: Theme(
          data: MaterialDemoThemeData.themeData.copyWith(
            platform: GalleryOptions.of(context).platform,
          ),
          child: CupertinoTheme(
            data: const CupertinoThemeData()
                .copyWith(brightness: Brightness.light),
            child: ApplyTextOptions(
              child: Builder(builder: buildRoute),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoSectionCode extends StatelessWidget {
  const _DemoSectionCode({
    this.maxHeight,
    this.codeWidget,
  });

  final double? maxHeight;
  final Widget? codeWidget;

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDisplayDesktop(context);

    return Theme(
      data: GalleryThemeData.darkThemeData,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          color: isDesktop ? null : GalleryThemeData.darkThemeData.canvasColor,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: maxHeight,
          child: codeWidget,
        ),
      ),
    );
  }
}

class CodeDisplayPage extends StatelessWidget {
  const CodeDisplayPage(this.code, {super.key});

  final CodeDisplayer code;

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDisplayDesktop(context);

    final richTextCode = code(context);
    final plainTextCode = richTextCode.toPlainText();

    void showSnackBarOnCopySuccess(dynamic result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            GalleryLocalizations.of(context)!
                .demoCodeViewerCopiedToClipboardMessage,
          ),
        ),
      );
    }

    void showSnackBarOnCopyFailure(Object exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            GalleryLocalizations.of(context)!
                .demoCodeViewerFailedToCopyToClipboardMessage(exception),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: isDesktop
              ? const EdgeInsets.only(bottom: 8)
              : const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: plainTextCode))
                  .then(showSnackBarOnCopySuccess)
                  .catchError(showSnackBarOnCopyFailure);
            },
            child: Text(
              GalleryLocalizations.of(context)!.demoCodeViewerCopyAll,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText.rich(
                richTextCode,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
