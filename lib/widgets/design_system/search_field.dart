import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'elevation.dart';

/// Search field matching `.search-bar`: rounded 15px, surface fill, outline
/// border, search icon.
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search\u2026',
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ac.outline, width: 1.5),
        boxShadow: appElevationShadows(context),
      ),
      foregroundDecoration: darkTopEdgeHighlight(context),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13.5, color: ac.ink),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 13.5, color: ac.inkFaint),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          prefixIcon: Icon(Icons.search_rounded, size: 17, color: ac.inkFaint),
          prefixIconConstraints: const BoxConstraints(minWidth: 26),
        ),
      ),
    );
  }
}

/// Form field matching `.field`: uppercase label + 13px input.
class AppField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? initialValue;
  final TextInputType keyboardType;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ac.inkSoft, letterSpacing: 0.03),
            ),
          ),
          TextField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            onChanged: onChanged,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: TextStyle(fontSize: 13.5, color: ac.ink),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 13.5, color: ac.inkFaint),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
