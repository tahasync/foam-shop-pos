import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search\u2026',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: ac.inkFaint, fontSize: 12.5),
          filled: true,
          fillColor: cs.surfaceContainerLowest,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: ac.inkFaint),
          suffixIcon: onClear != null && controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: ac.saleTint, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 12, color: ac.saleFg),
                  ),
                )
              : null,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
