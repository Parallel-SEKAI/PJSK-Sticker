import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjsk_sticker/image_text_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageTextOverlay Tests', () {
    late Uint8List testFontBytes;
    late Uint8List testImageBytes;

    setUpAll(() async {
      // 在测试环境中，读取文件的路径相对于项目根目录
      testFontBytes = await File('Fonts/YurukaStd.ttf').readAsBytes();
      testImageBytes = await File('assets/icon.png').readAsBytes();
    });

    test('generateStickerFromBytes should return valid PNG bytes', () async {
      final result = await ImageTextOverlay.generateStickerFromBytes(
        imageBytes: testImageBytes,
        layers: [
          TextOverlayLayer(
            content: "测试文字\nTest Line 2",
            fontFamilyName: "TestFont",
            fontBytes: testFontBytes,
            color: Colors.red,
            fontSize: 40,
            lean: 10,
            pos: const Offset(10, 10),
            edgeSize: 4,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result.isNotEmpty, true);

      // 验证 PNG 文件头
      expect(result[0], 0x89);
      expect(result[1], 0x50); // P
      expect(result[2], 0x4E); // N
      expect(result[3], 0x47); // G
    });

    test('getOffsets should return correct number of offsets', () {
      const precision = 8;
      final offsets = ImageTextOverlay.getOffsets(precision);
      
      expect(offsets.length, precision);
      expect(offsets[0].dx, closeTo(1.0, 0.001));
      expect(offsets[0].dy, closeTo(0.0, 0.001));
    });
  });
}
