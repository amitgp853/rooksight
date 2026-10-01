import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/scan/domain/low_light.dart';

void main() {
  group('LowLightDetector', () {
    test('turns dark only after two dark readings in a row', () {
      final light = LowLightDetector();
      expect(light.update(30), isFalse);
      expect(light.update(120), isFalse);
      expect(light.update(30), isFalse);
      expect(light.update(30), isTrue);
    });

    test('turns bright again only above the upper threshold', () {
      final light = LowLightDetector()
        ..update(30)
        ..update(30);
      // Between the thresholds: stays dark, no flicker.
      for (var i = 0; i < 5; i++) {
        expect(light.update(65), isTrue);
      }
      expect(light.update(90), isTrue);
      expect(light.update(90), isFalse);
    });

    test('a room on the edge never shows the hint', () {
      final light = LowLightDetector();
      for (var i = 0; i < 10; i++) {
        expect(light.update(i.isEven ? 60 : 70), isFalse);
      }
    });

    test('reset starts over', () {
      final light = LowLightDetector()
        ..update(10)
        ..update(10);
      expect(light.isDark, isTrue);
      light.reset();
      expect(light.isDark, isFalse);
    });
  });

  group('luma', () {
    test('reads a Y plane, skipping row padding', () {
      const width = 64, height = 48, stride = 80;
      final bytes = Uint8List(stride * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < stride; x++) {
          bytes[y * stride + x] = x < width ? 40 : 255;
        }
      }
      expect(lumaOfYPlane(bytes, width: width, height: height, rowStride: stride), 40);
    });

    test('reads a BGRA frame', () {
      const width = 32, height = 32, stride = width * 4 + 16;
      final bytes = Uint8List(stride * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final i = y * stride + x * 4;
          bytes[i] = 100;
          bytes[i + 1] = 100;
          bytes[i + 2] = 100;
          bytes[i + 3] = 255;
        }
      }
      expect(
        lumaOfBgra(bytes, width: width, height: height, rowStride: stride),
        closeTo(100, 0.01),
      );
    });

    test('an empty frame has no reading', () {
      expect(lumaOfYPlane(Uint8List(0), width: 0, height: 0, rowStride: 0), isNull);
    });
  });
}
