// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/config/app_info.dart';
import 'package:rooksight/core/config/remote_config.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/core/update/app_update.dart';
import 'package:rooksight/core/update/update_gate.dart';

void main() {
  const info = UpdateInfo(latestBuild: 12, minBuild: 9);

  test('below the minimum must update; below the latest may', () {
    expect(appUpdateFor(8, info), isA<UpdateRequired>());
    expect(appUpdateFor(9, info), isA<UpdateAvailable>());
    expect(appUpdateFor(11, info), isA<UpdateAvailable>());
    expect(appUpdateFor(12, info), isA<UpToDate>());
    expect(appUpdateFor(13, info), isA<UpToDate>());
  });

  test('no config, or an unknown build, is never told to update', () {
    expect(appUpdateFor(1, null), isA<UpToDate>());
    expect(appUpdateFor(0, info), isA<UpToDate>());
  });

  test('the store page falls back to Google Play on Android only', () {
    expect(storeUrlFor(info, TargetPlatform.android), AppInfo.playStoreUrl);
    expect(storeUrlFor(info, TargetPlatform.iOS), isNull);
    const ios = UpdateInfo(latestBuild: 2, minBuild: 1, storeUrl: 'https://apps.apple.com/x');
    expect(storeUrlFor(ios, TargetPlatform.iOS), 'https://apps.apple.com/x');
  });

  String config(int latest, int min) => jsonEncode({
    'schema': 1,
    'update': {
      'android': {'latestBuild': latest, 'minBuild': min},
    },
  });

  ProviderContainer containerAt(int build, SettingsStore store, String body) {
    final container = ProviderContainer(
      overrides: [
        appBuildProvider.overrideWithValue(build),
        settingsStoreProvider.overrideWithValue(store),
        remoteConfigFetchProvider.overrideWithValue(() async => body),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('"Later" hides the offer until a newer build is out', () async {
    final store = SettingsStore.inMemory();
    final container = containerAt(10, store, config(12, 1));
    await container.read(remoteConfigProvider.notifier).refresh();
    expect(container.read(updateOfferProvider)?.latestBuild, 12);

    container.read(updateOfferProvider.notifier).dismiss();
    expect(container.read(updateOfferProvider), isNull);

    // Next launch: still dismissed. Then build 13 comes out.
    final next = containerAt(10, store, config(13, 1));
    expect(next.read(updateOfferProvider), isNull);
    await next.read(remoteConfigProvider.notifier).refresh(force: true);
    expect(next.read(updateOfferProvider)?.latestBuild, 13);
  });

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const UpdateGate(
        child: Scaffold(body: Column(children: [Text('Home'), UpdateCard()])),
      ),
    ),
  );

  testWidgets('the app opens at once, then a fetched minimum blocks it', (tester) async {
    final container = containerAt(5, SettingsStore.inMemory(), config(12, 9));
    await tester.pumpWidget(app(container));
    expect(find.text('Home'), findsOneWidget);

    await tester.pumpAndSettle(); // The fetch after the first frame.
    expect(find.text('Home'), findsNothing);
    expect(find.text('Time to update'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
  });

  testWidgets('a newer build shows the card, and Later hides it', (tester) async {
    final container = containerAt(10, SettingsStore.inMemory(), config(12, 9));
    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('Update available'), findsNothing);
  });
}
