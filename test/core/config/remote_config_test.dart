import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/config/api_keys.dart';
import 'package:rooksight/core/config/remote_config.dart';
import 'package:rooksight/core/llm/gemini_client.dart';
import 'package:rooksight/core/storage/settings_store.dart';

void main() {
  String body({Object? update, Object? llm, int schema = 1}) =>
      jsonEncode({'schema': schema, 'update': ?update, 'llm': ?llm});

  group('parse', () {
    test('reads the update block for the platform and the models', () {
      final config = RemoteConfig.parse(
        body(
          update: {
            'android': {'latestBuild': 12, 'minBuild': 9, 'storeUrl': 'https://play.example'},
            'ios': {'latestBuild': 11, 'minBuild': 8},
            'message': ' Faster reviews. ',
          },
          llm: {
            'model': 'gemini-9-flash',
            'fallbackModel': 'gemini-9-flash-lite',
            'thinkingLevel': '',
          },
        ),
        platform: TargetPlatform.android,
      );
      final update = config.update!;
      expect((update.latestBuild, update.minBuild), (12, 9));
      expect((update.storeUrl, update.message), ('https://play.example', 'Faster reviews.'));
      expect(
        config.models,
        const RemoteModels(
          model: 'gemini-9-flash',
          fallbackModel: 'gemini-9-flash-lite',
          thinkingLevel: '',
        ),
      );

      final ios = RemoteConfig.parse(
        body(
          update: {
            'ios': {'latestBuild': 11, 'minBuild': 8},
          },
        ),
        platform: TargetPlatform.iOS,
      );
      expect((ios.update!.minBuild, ios.update!.storeUrl), (8, null));
    });

    test('drops bad values rather than failing', () {
      final config = RemoteConfig.parse(
        body(
          update: {
            'android': {'latestBuild': 5, 'minBuild': 7, 'storeUrl': 'http://insecure'},
            'message': '  ',
          },
          llm: {'model': 'gpt-5', 'fallbackModel': 3, 'thinkingLevel': 'max'},
        ),
        platform: TargetPlatform.android,
      );
      // A minimum above the latest would lock everyone out.
      expect(config.update!.minBuild, 0);
      expect((config.update!.storeUrl, config.update!.message), (null, null));
      expect(config.models, const RemoteModels());
    });

    test('no update for a platform without a block, or another platform', () {
      final android = body(
        update: {
          'android': {'latestBuild': 2},
        },
      );
      expect(RemoteConfig.parse(android, platform: TargetPlatform.iOS).update, isNull);
      expect(RemoteConfig.parse(android, platform: TargetPlatform.macOS).update, isNull);
    });

    test('rejects a newer schema and anything that isn’t an object', () {
      expect(
        () => RemoteConfig.parse(body(schema: 2), platform: TargetPlatform.android),
        throwsFormatException,
      );
      expect(
        () => RemoteConfig.parse('[]', platform: TargetPlatform.android),
        throwsFormatException,
      );
      expect(
        () => RemoteConfig.parse('not json', platform: TargetPlatform.android),
        throwsFormatException,
      );
    });

    test('the config shipped in the repo parses', () {
      final shipped = File('config/remote.json').readAsStringSync();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final config = RemoteConfig.parse(shipped, platform: platform);
        expect(config.update, isNotNull);
        expect(config.models?.model, isNotNull);
      }
    });
  });

  group('controller', () {
    late SettingsStore store;
    late DateTime now;
    late List<Object> replies; // A body to return, or an error to throw.
    late int fetches;

    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          remoteConfigClockProvider.overrideWithValue(() => now),
          remoteConfigFetchProvider.overrideWithValue(() async {
            fetches++;
            final reply = replies.removeAt(0);
            if (reply is String) return reply;
            throw reply;
          }),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      store = SettingsStore.inMemory();
      now = DateTime(2026, 10, 1, 9);
      replies = [];
      fetches = 0;
    });

    final v12 = body(
      update: {
        'android': {'latestBuild': 12, 'minBuild': 9},
      },
    );

    test('starts on the defaults, then the fetched config, kept for the next launch', () async {
      replies.add(v12);
      final first = container();
      expect(first.read(remoteConfigProvider).update, isNull);

      await first.read(remoteConfigProvider.notifier).refresh();
      expect(first.read(remoteConfigProvider).update?.latestBuild, 12);

      // Next launch, offline: the saved copy, without waiting for anything.
      replies.add(const SocketException('offline'));
      final second = container();
      expect(second.read(remoteConfigProvider).update?.latestBuild, 12);
    });

    test('a failed or malformed fetch keeps the current config', () async {
      replies.addAll([v12, const SocketException('offline'), '{"schema": 1, "update": ']);
      final c = container();
      final notifier = c.read(remoteConfigProvider.notifier);
      await notifier.refresh();
      await notifier.refresh(force: true);
      await notifier.refresh(force: true);
      expect(fetches, 3);
      expect(c.read(remoteConfigProvider).update?.latestBuild, 12);
    });

    test('fetches at most once an hour unless forced; retries soon after a failure', () async {
      replies.addAll([const SocketException('offline'), v12, v12]);
      final notifier = container().read(remoteConfigProvider.notifier);

      await notifier.refresh(); // Failed: not counted as fetched.
      await notifier.refresh();
      expect(fetches, 2);

      now = now.add(const Duration(minutes: 59));
      await notifier.refresh();
      expect(fetches, 2);

      now = now.add(const Duration(minutes: 1));
      await notifier.refresh();
      expect(fetches, 3);
    });

    test('overlapping refreshes share one fetch', () async {
      replies.add(v12);
      final notifier = container().read(remoteConfigProvider.notifier);
      await Future.wait([notifier.refresh(), notifier.refresh(force: true)]);
      expect(fetches, 1);
    });
  });

  group('models', () {
    test('the built-in models without a remote config', () {
      final models = geminiModels(null);
      expect(models.model, ApiKeys.geminiModel);
      expect(models.fallbacks, [ApiKeys.geminiFallbackModel]);
      expect(models.thinkingLevel, ApiKeys.geminiThinkingLevel);
    });

    test('remote models first, the built-in ones kept as fallbacks', () {
      final models = geminiModels(
        const RemoteModels(
          model: 'gemini-9-flash',
          fallbackModel: 'gemini-9-lite',
          thinkingLevel: 'high',
        ),
      );
      expect(models.model, 'gemini-9-flash');
      expect(models.fallbacks, ['gemini-9-lite', ApiKeys.geminiModel, ApiKeys.geminiFallbackModel]);
      expect(models.thinkingLevel, 'high');
    });

    test('no model twice, and never the primary as its own fallback', () {
      final models = geminiModels(
        const RemoteModels(model: ApiKeys.geminiFallbackModel, fallbackModel: ApiKeys.geminiModel),
      );
      expect(models.model, ApiKeys.geminiFallbackModel);
      expect(models.fallbacks, [ApiKeys.geminiModel]);
    });

    test('a new remote model builds a new client', () async {
      final store = SettingsStore.inMemory();
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          remoteConfigFetchProvider.overrideWithValue(
            () async => body(llm: {'model': 'gemini-9-flash'}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final before = container.read(llmClientProvider);
      await container.read(remoteConfigProvider.notifier).refresh();
      final after = container.read(llmClientProvider) as GeminiClient;
      expect(after, isNot(same(before)));
      expect(after.model, 'gemini-9-flash');
    });
  });
}
