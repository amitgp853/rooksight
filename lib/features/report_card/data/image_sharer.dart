import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands an image to the system share sheet. Behind an interface so tests
/// can use a fake.
abstract interface class ImageSharer {
  /// Shares [png] as [fileName]. [origin] anchors the sheet on iPad.
  Future<void> sharePng(Uint8List png, {required String fileName, Rect? origin});
}

class SharePlusSharer implements ImageSharer {
  @override
  Future<void> sharePng(Uint8List png, {required String fileName, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
  }
}

final imageSharerProvider = Provider<ImageSharer>((ref) => SharePlusSharer());

/// The widget under [boundary] as a PNG [width] pixels wide, whatever size
/// it's shown at.
Future<Uint8List> capturePng(GlobalKey boundary, {required double width}) async {
  final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: width / render.size.width);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
