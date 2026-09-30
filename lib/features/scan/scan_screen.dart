import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/llm/gemini_client.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/display_settings.dart';
import '../../core/theme/app_theme.dart';
import 'domain/board_reader.dart';
import 'domain/scan_photo.dart';
import 'scan_check_screen.dart';
import 'widgets/scan_camera_view.dart';
import 'widgets/scan_crop_view.dart';
import 'widgets/scan_error_view.dart';
import 'widgets/scan_reading_view.dart';

/// Reads board photos with the player's Gemini key. Override in tests.
final boardReaderProvider = Provider<BoardReader>(
  (ref) => BoardReader(ref.watch(llmClientProvider)),
);

/// Picks a photo from the gallery, behind an interface so tests can use a
/// fake.
abstract interface class PhotoPicker {
  /// The picked file's bytes, or null if the player backed out.
  Future<Uint8List?> pick();
}

class GalleryPhotoPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Only the bytes in memory are used; drop the picker's copy.
    unawaited(File(file.path).delete().then((_) {}, onError: (_) {}));
    return bytes;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => GalleryPhotoPicker());

sealed class _Stage {
  const _Stage();
}

class _Camera extends _Stage {
  const _Camera();
}

class _Crop extends _Stage {
  const _Crop(this.photo, {this.busy = false});
  final ScanPhoto photo;
  final bool busy;
}

class _Reading extends _Stage {
  const _Reading(this.photo, this.cropped, this.steps);
  final ScanPhoto photo;
  final Uint8List cropped;
  final List<ScanStep> steps;
}

class _Failed extends _Stage {
  const _Failed(this.failure, {this.photo, this.cropped});
  final ScanFailure failure;
  final ScanPhoto? photo;
  final Uint8List? cropped;
}

/// Scan a board (spec: `ScanAnalysisSpec.dc.html`): camera → crop → the
/// reading, step by step → Check the position (its own screen) → the
/// analysis board. Failures get their own screen with a way on; when the AI
/// can't run, the same editor opens empty to set the position up by hand.
///
/// The photo lives only in memory while this screen is open.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.photo});

  /// Starts at the crop with this photo (skipping the camera).
  final ScanPhoto? photo;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late _Stage _stage = widget.photo == null ? const _Camera() : _Crop(widget.photo!);

  /// Bumped to abandon a reading that's still running.
  int _run = 0;
  bool _loading = false;

  void _go(_Stage stage) {
    if (mounted) setState(() => _stage = stage);
  }

  Future<void> _usePhoto(Uint8List raw) async {
    setState(() => _loading = true);
    final photo = await ScanPhoto.fromBytes(raw);
    if (!mounted) return;
    setState(() => _loading = false);
    if (photo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('That file isn’t a photo we can read.')));
      return;
    }
    _go(_Crop(photo));
  }

  Future<void> _gallery() async {
    final Uint8List? raw;
    try {
      raw = await ref.read(photoPickerProvider).pick();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn’t open your photos.')));
      }
      return;
    }
    if (raw != null) await _usePhoto(raw);
  }

  Future<void> _rotate(ScanPhoto photo, {required bool clockwise}) async {
    _go(_Crop(photo, busy: true));
    _go(_Crop(await photo.rotated(clockwise: clockwise)));
  }

  Future<void> _scan(ScanPhoto photo, Rect crop) async {
    if (!ref.read(llmConfiguredProvider)) {
      _go(_Failed(const ScanFailure(ScanFailureKind.noKey), photo: photo));
      return;
    }
    _go(_Crop(photo, busy: true));
    final cropped = await photo.crop(crop);
    await _read(photo, cropped);
  }

  Future<void> _read(ScanPhoto photo, Uint8List cropped) async {
    final run = ++_run;
    bool stale() => !mounted || run != _run;
    _go(_Reading(photo, cropped, const []));
    try {
      final result = await ref
          .read(boardReaderProvider)
          .read(
            cropped,
            onSteps: (steps) {
              if (!stale()) _go(_Reading(photo, cropped, steps));
            },
            isCancelled: stale,
          );
      if (result == null || stale()) return;
      // A moment on "Position ready" before the board opens.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted || stale()) return;
      _go(_Crop(photo));
      await context.push(
        Routes.scanCheck,
        extra: ScanCheckArgs(result: result, photo: cropped),
      );
    } on ScanFailure catch (failure) {
      if (!stale()) _go(_Failed(failure, photo: photo, cropped: cropped));
    }
  }

  void _cancelReading(ScanPhoto photo) {
    _run++;
    _go(_Crop(photo));
  }

  void _close() => context.pop();

  void _byHand() => context.push(Routes.scanCheck, extra: const ScanCheckArgs(edit: true));

  Future<void> _addKey(_Failed failed) async {
    ref.read(developerModeProvider.notifier).set(true);
    await context.push(Routes.settings);
    if (!mounted || !ref.read(llmConfiguredProvider)) return;
    // Key added: carry on with the photo.
    final photo = failed.photo;
    final cropped = failed.cropped;
    if (photo != null && cropped != null) {
      await _read(photo, cropped);
    } else if (photo != null) {
      _go(_Crop(photo));
    }
  }

  (ScanAction, ScanAction) _actions(_Failed failed) {
    final retake = (label: 'Try again', onPressed: () => _go(const _Camera()));
    final upload = (label: 'Upload a photo', onPressed: _gallery);
    final byHand = (label: 'Set up the position by hand', onPressed: _byHand);
    final again = (
      label: 'Try again',
      onPressed: () {
        final (photo, cropped) = (failed.photo, failed.cropped);
        if (photo != null && cropped != null) {
          unawaited(_read(photo, cropped));
        } else {
          _go(photo == null ? const _Camera() : _Crop(photo));
        }
      },
    );
    return switch (failed.failure.kind) {
      ScanFailureKind.noBoard || ScanFailureKind.blurry => (retake, upload),
      ScanFailureKind.illegal => (
        (
          label: 'Edit position',
          onPressed: () => context.push(
            Routes.scanCheck,
            extra: ScanCheckArgs(result: failed.failure.result, photo: failed.cropped, edit: true),
          ),
        ),
        (label: 'Scan again', onPressed: () => _go(const _Camera())),
      ),
      ScanFailureKind.offline => (byHand, again),
      ScanFailureKind.noKey || ScanFailureKind.invalidKey => (
        (label: 'Add key in Settings', onPressed: () => _addKey(failed)),
        byHand,
      ),
      ScanFailureKind.limit => (byHand, (label: 'OK', onPressed: _close)),
      ScanFailureKind.failed => (again, byHand),
    };
  }

  /// Back steps back through the flow before leaving it.
  void _back() {
    switch (_stage) {
      case _Camera():
        _close();
      case _Crop():
        _go(const _Camera());
      case _Reading(:final photo):
        _cancelReading(photo);
      case _Failed(:final photo):
        _go(photo == null ? const _Camera() : _Crop(photo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = shouldReduceMotion(context, ref);
    final stage = _stage;
    final dark = Theme.of(context).brightness == Brightness.dark ? Theme.of(context) : _darkTheme;

    final Widget body = switch (stage) {
      _Camera() => Theme(
        data: dark,
        child: Scaffold(
          backgroundColor: const Color(0xFF050709),
          body: Stack(
            children: [
              ScanCameraView(onPhoto: _usePhoto, onGallery: _gallery, onClose: _close),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
      _Crop(:final photo, :final busy) => Theme(
        data: dark,
        child: Scaffold(
          backgroundColor: const Color(0xFF0B0F13),
          body: ScanCropView(
            photo: photo,
            busy: busy,
            onRetake: () => _go(const _Camera()),
            onRotate: ({required clockwise}) => _rotate(photo, clockwise: clockwise),
            onScan: (crop) => _scan(photo, crop),
          ),
        ),
      ),
      _Reading(:final photo, :final cropped, :final steps) => Theme(
        data: dark,
        child: ScanReadingView(photo: cropped, steps: steps, onCancel: () => _cancelReading(photo)),
      ),
      _Failed() => Builder(
        builder: (context) {
          final (primary, secondary) = _actions(stage);
          return ScanErrorView(
            failure: stage.failure,
            photo: stage.cropped ?? stage.photo?.bytes,
            primary: primary,
            secondary: secondary,
            onClose: _close,
          );
        },
      ),
    };

    return PopScope(
      canPop: stage is _Camera,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnimatedSwitcher(
        // Photo slides into the crop view; reduced motion crossfades.
        duration: Duration(milliseconds: reduce ? 150 : 280),
        child: KeyedSubtree(key: ValueKey(stage.runtimeType), child: body),
      ),
    );
  }
}

/// The camera, crop and reading steps are always dark.
final _darkTheme = AppTheme.dark();
