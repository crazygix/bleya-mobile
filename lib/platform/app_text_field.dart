import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui_platform.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final bool enabled;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final bool? enableInteractiveSelection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? cursorColor;
  final EdgeInsetsGeometry? contentPadding;
  final BoxDecoration? decoration;

  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.style,
    this.placeholderStyle,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.enableInteractiveSelection,
    this.onChanged,
    this.onSubmitted,
    this.cursorColor,
    this.contentPadding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    if (isIosPlatform(context)) {
      return CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        style: style,
        placeholderStyle: placeholderStyle,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        enabled: enabled,
        obscureText: obscureText,
        maxLines: maxLines,
        maxLength: maxLength,
        enableInteractiveSelection: enableInteractiveSelection ?? true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: cursorColor,
        padding: contentPadding ?? EdgeInsets.zero,
        decoration:
            decoration ?? const BoxDecoration(color: Colors.transparent),
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      enableInteractiveSelection: enableInteractiveSelection ?? true,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: cursorColor,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: placeholderStyle,
        border: InputBorder.none,
        isDense: true,
        contentPadding: contentPadding,
        counterText: '',
      ),
    );
  }
}
