// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/gallery_localizations.dart';
import 'package:gallery/custom_widgets/eg_text_input_tealeaf_widget.dart';
import 'package:gallery/data/gallery_options.dart';
import 'package:gallery/layout/adaptive.dart';
import 'package:gallery/layout/image_placeholder.dart';
import 'package:gallery/layout/letter_spacing.dart';
import 'package:gallery/layout/text_scale.dart';
import 'package:gallery/studies/shrine/app.dart';
import 'package:gallery/studies/shrine/theme.dart';

const _horizontalPadding = 24.0;

// Custom input formatter for uppercase text
class UpperCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

double desktopLoginScreenMainAreaWidth({required BuildContext context}) {
  return min(
    360 * reducedTextScale(context),
    MediaQuery.of(context).size.width - 2 * _horizontalPadding,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Dummy data for form fields
  String _iban = '';
  String _bic = '';
  String _alias = '';
  bool _isValidateInputIban = false;
  bool _ibanEdited = false;
  bool _aliasEdited = false;
  final bool _showError = false;
  final bool _canShowBic = true;
  bool _isButtonEnabled = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDisplayDesktop(context);

    return ApplyTextOptions(
      child: isDesktop
          ? LayoutBuilder(
              builder: (context, constraints) => Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SizedBox(
                      width: desktopLoginScreenMainAreaWidth(context: context),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ShrineLogo(),
                          SizedBox(height: 40),
                          _UsernameTextField(),
                          SizedBox(height: 16),
                          _PasswordTextField(),
                          SizedBox(height: 24),
                          _CancelAndNextButtons(),
                          SizedBox(height: 62),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: Semantics(
                  label: 'mask_label',
                  child: const Text('Enhanced Login Page'),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  restorationId: 'login_list_view',
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  children: [
                    const SizedBox(height: 20),
                    const _ShrineLogo(),
                    const SizedBox(height: 30),
                    const _UsernameTextField(),
                    const SizedBox(height: 12),
                    const _PasswordTextField(),
                    const SizedBox(height: 20),
                    // Add DPM-style form fields
                    _buildIbanField(),
                    const SizedBox(height: 16),
                    _buildBicField(),
                    const SizedBox(height: 16),
                    _buildAliasField(),
                    const SizedBox(height: 30),

                    // Custom widgets from client for testing
                    const Text('Custom EGTextInputTealeafWidget for testing'),
                    const SizedBox(height: 12),
                    EGTextInputTealeafWidget(
                      textFieldAccessibilityLabel: 'mask_label',
                      controller: TextEditingController(),
                      hintText: 'EG Enter email',
                      label: 'EG Email label',
                    ),
                    const SizedBox(height: 16),
                    EGTextInputTealeafWidget(
                      textFieldAccessibilityLabel: 'mask_label',
                      controller: TextEditingController(),
                      hintText: 'EG Enter password',
                      label: 'EG Password label',
                    ),

                    const SizedBox(height: 16),
                    const _CancelAndNextButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomNavigationBar(),
            ),
    );
  }

  Widget _buildIbanField() {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isValidateInputIban = hasFocus;
        });
      },
      child: Semantics(
        label: 'IBAN - Tealeaf masking label',
        hint: 'IBAN - Tealeaf test hint',
        excludeSemantics: true,
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'IBAN',
            hintText: 'Enter your IBAN number',
          ),
          keyboardType: TextInputType.text,
          inputFormatters: [UpperCaseInputFormatter()],
          onChanged: (value) {
            setState(() {
              _iban = value;
              _ibanEdited = true;
              _updateButtonState();
            });
          },
          autovalidateMode: _isValidateInputIban
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (_) {
            if (!_ibanEdited) return null;
            if (_iban.isEmpty) return 'Cannot be empty';
            if (_iban.length > 24) return 'IBAN too long';
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildBicField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'BIC',
            hintText: 'Enter your BIC code',
          ),
          keyboardType: TextInputType.text,
          inputFormatters: [UpperCaseInputFormatter()],
          onChanged: (value) {
            setState(() {
              _bic = value;
              _updateButtonState();
            });
          },
          autovalidateMode: _showError
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          enabled: _canShowBic,
          validator: (_) {
            if (_bic.isEmpty) return 'Cannot be empty';
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Only for inter-account transfers',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildAliasField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Account Alias',
        hintText: 'Enter a friendly name for this account',
      ),
      keyboardType: TextInputType.text,
      onChanged: (value) {
        setState(() {
          _alias = value;
          _aliasEdited = true;
          _updateButtonState();
        });
      },
      autovalidateMode: _showError
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      validator: (_) {
        if (!_aliasEdited) return null;
        if (_alias.isEmpty) return 'Cannot be empty';
        return null;
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _isButtonEnabled
                ? () {
                    // Dummy save action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Account saved successfully!')),
                    );
                  }
                : null,
            child: const Text('Save Changes'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _iban.isNotEmpty && _alias.isNotEmpty;
    });
  }
}

class _ShrineLogo extends StatelessWidget {
  const _ShrineLogo();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        children: [
          const FadeInImagePlaceholder(
            image: AssetImage('packages/shrine_images/diamond.png'),
            placeholder: SizedBox(
              width: 34,
              height: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            semanticsLabel: 'Hello, world!',
            'SHRINE',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Semantics(
            label: 'Shrine - Connect masking label',
            hint: 'Shrine - Connect test hint',
            child: const Text('Shrine - Connect Accessibility Label'),
          ),
        ],
      ),
    );
  }
}

class _UsernameTextField extends StatelessWidget {
  const _UsernameTextField();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      // label: 'username',
      child: TextField(
        textInputAction: TextInputAction.next,
        restorationId: 'username_text_field',
        cursorColor: colorScheme.onSurface,
        decoration: InputDecoration(
          labelText: GalleryLocalizations.of(context)!.shrineLoginUsernameLabel,
          labelStyle: TextStyle(
            letterSpacing: letterSpacingOrNone(mediumLetterSpacing),
          ),
        ),
      ),
    );
  }
}

class _PasswordTextField extends StatelessWidget {
  const _PasswordTextField();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
        label: 'mask_label',
        child: TextField(
          restorationId: 'password_text_field',
          cursorColor: colorScheme.onSurface,
          obscureText: true,
          decoration: InputDecoration(
            labelText:
                GalleryLocalizations.of(context)!.shrineLoginPasswordLabel,
            labelStyle: TextStyle(
              letterSpacing: letterSpacingOrNone(mediumLetterSpacing),
            ),
          ),
        ));
  }
}

class _CancelAndNextButtons extends StatelessWidget {
  const _CancelAndNextButtons();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDesktop = isDisplayDesktop(context);

    final buttonTextPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
        : EdgeInsets.zero;

    return Padding(
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(8),
      child: OverflowBar(
        spacing: isDesktop ? 0 : 8,
        alignment: MainAxisAlignment.end,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
            ),
            onPressed: () {
              // The login screen is immediately displayed on top of
              // the Shrine home screen using onGenerateRoute and so
              // rootNavigator must be set to true in order to get out
              // of Shrine completely.
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: Padding(
              padding: buttonTextPadding,
              child: Text(
                GalleryLocalizations.of(context)!.shrineCancelButtonCaption,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 8,
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
            ),
            onPressed: () {
              Navigator.of(context).restorablePushNamed(ShrineApp.homeRoute);
            },
            child: Padding(
              padding: buttonTextPadding,
              child: Text(
                GalleryLocalizations.of(context)!.shrineNextButtonCaption,
                style: TextStyle(
                    letterSpacing: letterSpacingOrNone(largeLetterSpacing)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
