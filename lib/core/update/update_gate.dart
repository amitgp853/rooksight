import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../config/remote_config.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/logo_mark.dart';
import 'app_update.dart';

/// Keeps the remote config fresh (at launch and when the app comes back to
/// the front) and, when this build is no longer supported, shows
/// [UpdateRequiredScreen] in place of the app.
///
/// Nothing here waits for the network: the app opens on the saved config and
/// the fetch runs alongside.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    // After the first frame, so the fetch never competes with launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() => ref.read(remoteConfigProvider.notifier).refresh();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(appUpdateProvider)) {
      UpdateRequired(:final info) => UpdateRequiredScreen(info: info),
      _ => widget.child,
    };
  }
}

/// Opens the store page for [info]. False if there's none or it won't open.
Future<bool> openStore(UpdateInfo info) async {
  final url = storeUrlFor(info, defaultTargetPlatform);
  if (url == null) return false;
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
}

/// "Update required": this build is too old to use. Not in the design;
/// follows the Night Study style. Shown above the router, so it has no back.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final message = info.message;
    final canOpen = storeUrlFor(info, defaultTargetPlatform) != null;
    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: LogoMark(size: 56)),
              const SizedBox(height: AppSpacing.s6),
              Text(
                'Time to update',
                textAlign: TextAlign.center,
                style: type.title.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                canOpen
                    ? 'This version of ${AppInfo.name} is no longer supported. Update to keep '
                          'playing. Your games and settings stay on this phone.'
                    : 'This version of ${AppInfo.name} is no longer supported. Update it from '
                          'the store you installed it from. Your games and settings stay on '
                          'this phone.',
                textAlign: TextAlign.center,
                style: type.body.copyWith(color: colors.textSecondary),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: type.body.copyWith(fontSize: 14, color: colors.textSecondary),
                ),
              ],
              const Spacer(),
              if (canOpen)
                FilledButton(onPressed: () => openStore(info), child: const Text('Update')),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Update available" on Home, with Update and Later. Hidden when up to date
/// or after Later for this build. Not in the design; follows its card style.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateOfferProvider);
    if (info == null) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.type;
    final light = Theme.of(context).brightness == Brightness.light;
    final canOpen = storeUrlFor(info, defaultTargetPlatform) != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Material(
        color: colors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: light ? BorderSide(color: colors.border) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 10,
                children: [
                  Icon(Icons.system_update_rounded, color: colors.focus, size: 22),
                  Expanded(
                    child: Text(
                      'Update available',
                      style: type.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                info.message ?? 'A new version of ${AppInfo.name} is ready.',
                style: type.body.copyWith(fontSize: 14, color: colors.textSecondary),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: ref.read(updateOfferProvider.notifier).dismiss,
                    child: const Text('Later'),
                  ),
                  if (canOpen)
                    TextButton(onPressed: () => openStore(info), child: const Text('Update')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
