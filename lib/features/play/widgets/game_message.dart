import 'package:flutter/material.dart';

/// The room kept under the board for a message (game and Pass & Play): a
/// one-line notice with its button fits whole, so it never has to scroll in
/// a sliver.
const messageMinHeight = 66.0;

/// The app's text button, compact enough for a notice under the board: still
/// a 44 px target.
TextButtonThemeData compactActionTheme(BuildContext context) => TextButtonThemeData(
  style: TextButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ).merge(Theme.of(context).textButtonTheme.style),
);
