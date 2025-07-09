import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EGTextInputTealeafWidget extends StatefulWidget {
  const EGTextInputTealeafWidget({
    super.key,
    this.initialValue,
    this.label,
    this.bottomLabel,
    this.onChanged,
    this.inputType = TextInputType.text,
    this.onTap,
    this.onSuffixWidgetPressed,
    this.forceSuffixIcon = false,
    this.controller,
    this.readOnly = false,
    this.obscureText = false,
    this.prefixIconPath,
    this.suffixIconPath,
    this.prefixIconColor,
    this.suffixIconColor,
    this.autovalidate = false,
    this.showCursor = true,
    this.validator,
    this.canShowValidatorIcon = false,
    this.enabled = true,
    this.hintText = '',
    this.maxLines = 1,
    this.hintStyle,
    this.contentPadding,
    this.inputFormatters,
    this.borderRadius,
    this.backgroundColor,
    this.positive = false,
    this.textInputAction,
    this.focusNode,
    this.canCopyPaste = false,
    this.suffixIconSemanticLabel,
    this.suffixSelected,
    this.suffixNotSelected,
    this.autocorrect,
    this.borderColor,
    this.useSameBorderColor = false,
    this.textFieldAccessibilityLabel = '',
    this.labelAccessibilityLabel = '',
  });

  final String? initialValue;
  final String? label;
  final String? bottomLabel;
  final ValueChanged<String>? onChanged;
  final TextInputType inputType;
  final VoidCallback? onTap;
  final VoidCallback? onSuffixWidgetPressed;
  final bool forceSuffixIcon;
  final TextEditingController? controller;
  final bool readOnly;
  final bool obscureText;
  final String? prefixIconPath;
  final String? suffixIconPath;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final bool autovalidate;
  final bool showCursor;
  final String? Function(String?)? validator;
  final bool canShowValidatorIcon;
  final bool enabled;
  final String hintText;
  final TextStyle? hintStyle;
  final int? maxLines;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool positive;
  final String? suffixIconSemanticLabel;
  final String? suffixSelected;
  final String? suffixNotSelected;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool canCopyPaste;
  final bool? autocorrect;
  final Color? borderColor;
  final bool useSameBorderColor;
  final String textFieldAccessibilityLabel;
  final String labelAccessibilityLabel;

  @override
  State<EGTextInputTealeafWidget> createState() =>
      _EGTextInputTealeafWidgetState();
}

class _EGTextInputTealeafWidgetState extends State<EGTextInputTealeafWidget> {
  late ValueNotifier<bool> obscureTextNotifier;

  @override
  void initState() {
    obscureTextNotifier = ValueNotifier<bool>(widget.obscureText);
    super.initState();
  }

  OutlineInputBorder _getDecorationBorder(BuildContext context,
          [Color? borderColor]) =>
      !widget.readOnly
          ? OutlineInputBorder(
              borderSide: BorderSide(
                color: borderColor ??
                    (widget.backgroundColor ?? Theme.of(context).cardColor),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            )
          : const OutlineInputBorder(borderSide: BorderSide.none);

  @override
  Widget build(BuildContext context) {
    final bool autocorrectValue = widget.autocorrect ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Semantics(
            label: widget.labelAccessibilityLabel,
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 14,
                height: 16 / 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ValueListenableBuilder<bool>(
          valueListenable: obscureTextNotifier,
          builder: (context, value, child) {
            return Semantics(
                label: widget.textFieldAccessibilityLabel,
                child: TextFormField(
                  focusNode: widget.focusNode,
                  style: TextStyle(
                    color:
                        widget.enabled ? null : Theme.of(context).disabledColor,
                  ),
                  onChanged: widget.onChanged,
                  keyboardType: widget.inputType,
                  onTap: widget.onTap,
                  readOnly: widget.readOnly,
                  controller: widget.controller,
                  initialValue:
                      widget.controller == null ? widget.initialValue : null,
                  maxLines: widget.maxLines,
                  obscureText: value,
                  showCursor: widget.showCursor,
                  autovalidateMode: widget.autovalidate
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  validator: widget.validator,
                  enabled: widget.enabled,
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    hintStyle:
                        widget.hintStyle ?? TextStyle(color: Colors.grey[400]),
                    hintText: widget.hintText,
                    filled: true,
                    fillColor:
                        widget.backgroundColor ?? Theme.of(context).cardColor,
                    border: _getDecorationBorder(context,
                        widget.positive ? Colors.green : Colors.transparent),
                    focusedBorder: _getDecorationBorder(
                        context, widget.positive ? Colors.green : Colors.black),
                    enabledBorder: _getDecorationBorder(context,
                        widget.positive ? Colors.green : Colors.transparent),
                    disabledBorder:
                        _getDecorationBorder(context, Colors.transparent),
                    prefixIconConstraints: widget.prefixIconPath != null
                        ? const BoxConstraints(minWidth: 52, minHeight: 24)
                        : const BoxConstraints(minWidth: 16, minHeight: 0),
                    prefixIcon: widget.prefixIconPath != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, right: 12),
                            child: Icon(
                              Icons.search, // Placeholder icon
                              size: 24,
                              color: widget.enabled
                                  ? (widget.prefixIconColor ??
                                      Theme.of(context).iconTheme.color)
                                  : Theme.of(context).disabledColor,
                            ),
                          )
                        : const SizedBox.shrink(),
                    suffixIconConstraints: widget.suffixIconPath != null
                        ? const BoxConstraints(minWidth: 42, minHeight: 14)
                        : const BoxConstraints(minWidth: 16, minHeight: 0),
                    suffixIcon: (widget.obscureText && !widget.forceSuffixIcon)
                        ? SuffixIconTealeafWidget(
                            value: value,
                            suffixIconSemanticsLabel:
                                widget.suffixIconSemanticLabel,
                            suffixNotSelected: widget.suffixNotSelected,
                            suffixSelected: widget.suffixSelected,
                            onPressed: () {
                              obscureTextNotifier.value = !value;
                            },
                            enabled: widget.enabled,
                          )
                        : (widget.suffixIconPath != null &&
                                widget.onSuffixWidgetPressed != null)
                            ? SuffixIconTealeafWidget(
                                suffixIconPath: widget.suffixIconPath,
                                suffixIconColor: widget.suffixIconColor,
                                value: value,
                                onPressed: widget.onSuffixWidgetPressed!,
                                enabled: widget.autovalidate,
                                suffixIconSemanticsLabel:
                                    widget.suffixIconSemanticLabel,
                                suffixNotSelected: widget.suffixNotSelected,
                                suffixSelected: widget.suffixSelected,
                              )
                            : (widget.enabled &&
                                    widget.autovalidate &&
                                    widget.canShowValidatorIcon)
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 16),
                                    child: Icon(
                                      Icons.warning,
                                      size: 14,
                                      color: widget.enabled
                                          ? Colors.red
                                          : Theme.of(context).disabledColor,
                                    ),
                                  )
                                : (widget.enabled &&
                                        widget.positive &&
                                        widget.autovalidate &&
                                        !widget.canShowValidatorIcon)
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                            left: 12, right: 16),
                                        child: Icon(
                                          Icons.check,
                                          size: 14,
                                          color: widget.enabled
                                              ? Colors.green
                                              : Theme.of(context).disabledColor,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    errorMaxLines: 3,
                    isDense: true,
                  ),
                  inputFormatters: widget.inputFormatters,
                  cursorHeight: 24,
                  textInputAction: widget.textInputAction,
                  autocorrect: autocorrectValue,
                  enableInteractiveSelection: true,
                  toolbarOptions: ToolbarOptions(
                    paste: widget.canCopyPaste,
                    cut: widget.canCopyPaste,
                    copy: widget.canCopyPaste,
                    selectAll: true,
                  ),
                ));
          },
        ),
        if (widget.bottomLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.bottomLabel!,
            style: TextStyle(
              color: widget.enabled
                  ? Colors.grey[400]
                  : Theme.of(context).disabledColor,
              fontSize: 14,
              height: 16 / 14,
            ),
          ),
        ],
      ],
    );
  }
}

class SuffixIconTealeafWidget extends StatelessWidget {
  const SuffixIconTealeafWidget({
    super.key,
    this.suffixIconPath,
    this.suffixIconColor,
    required this.value,
    required this.onPressed,
    required this.enabled,
    this.suffixIconSemanticsLabel,
    this.suffixSelected,
    this.suffixNotSelected,
  });

  final String? suffixIconPath;
  final Color? suffixIconColor;
  final bool value;
  final VoidCallback onPressed;
  final bool enabled;
  final String? suffixIconSemanticsLabel;
  final String? suffixSelected;
  final String? suffixNotSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: suffixIconSemanticsLabel,
      hint: value ? suffixNotSelected : suffixSelected,
      child: GestureDetector(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 16),
          child: Icon(
            suffixIconPath != null
                ? Icons.search // Placeholder for custom icon
                : (value ? Icons.visibility : Icons.visibility_off),
            size: 20,
            color: enabled
                ? (suffixIconColor ?? Theme.of(context).primaryColor)
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}
