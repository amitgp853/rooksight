// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/settings/display_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'features/splash/intro.dart';

class RooksightApp extends ConsumerWidget {
  const RooksightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Rooksight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => IntroGate(child: UpdateGate(child: child!)),
    );
  }
}
