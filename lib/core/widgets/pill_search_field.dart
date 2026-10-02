// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The rounded search field (Chats, Games): search icon, a clear button once
/// there's text.
class PillSearchField extends StatelessWidget {
  const PillSearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: colors.border),
    );
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: type.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: type.body.copyWith(color: colors.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textTertiary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: controller.clear,
                  color: colors.textTertiary,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: colors.bgRaised,
          contentPadding: EdgeInsets.zero,
          border: pill,
          enabledBorder: pill,
          focusedBorder: pill.copyWith(borderSide: BorderSide(color: colors.focus)),
        ),
      ),
    );
  }
}
