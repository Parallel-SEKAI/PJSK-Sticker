import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjsk_sticker/image_text_overlay.dart';
import 'package:pjsk_sticker/sticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageTextOverlay Tests', () {
    late Uint8List testImageBytes;
    late Uint8List testFontBytes;

    setUpAll(() async {
      testImageBytes = await File('assets/icon.png').readAsBytes();
      // Create a minimal valid font bytes for testing
      // This is a minimal valid TTF header (first 12 bytes of a basic TTF file)
      testFontBytes = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
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
            bendCurvature: 0.0,
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

    group('bendCurvature and bendSpacing rendering tests', () {
      test(
        'bendCurvature = 0 and bendSpacing > 0 should generate valid PNG',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Test Text",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.blue,
                fontSize: 30,
                lean: 0,
                pos: const Offset(50, 50),
                edgeSize: 3,
                bendCurvature: 0.0,
                bendSpacing: 5.0,
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );

      test(
        'bendCurvature > 0 (positive curvature) should generate valid PNG',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Curved Text",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.green,
                fontSize: 35,
                lean: 5,
                pos: const Offset(100, 100),
                edgeSize: 4,
                bendCurvature: 0.01, // 半径 100 -> 曲率 0.01
                bendSpacing: 2.0,
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );

      test(
        'bendCurvature < 0 (negative curvature) should generate valid PNG',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Inverted Curve",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.purple,
                fontSize: 32,
                lean: -10,
                pos: const Offset(80, 120),
                edgeSize: 3,
                bendCurvature: -0.0125, // 半径 -80 -> 曲率 -0.0125
                bendSpacing: 3.0,
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );

      test(
        'bendCurvature + bendSpacing + lean combination should generate valid PNG',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Complex\nMultiline",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.orange,
                fontSize: 28,
                lean: 15,
                pos: const Offset(60, 80),
                edgeSize: 5,
                bendCurvature: 0.00833, // 半径 120 -> 曲率 ~0.00833
                bendSpacing: 4.0,
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );

      test(
        'negative bendSpacing should not crash or reverse characters',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Tight Text",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.cyan,
                fontSize: 30,
                lean: 0,
                pos: const Offset(70, 90),
                edgeSize: 3,
                bendCurvature: 0.01, // 半径 100 -> 曲率 0.01
                bendSpacing: -5.0, // 负间距
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );

      test(
        'very large bendCurvature should be clamped to minimum radius',
        () async {
          final result = await ImageTextOverlay.generateStickerFromBytes(
            imageBytes: testImageBytes,
            layers: [
              TextOverlayLayer(
                content: "Small Radius",
                fontFamilyName: "TestFont",
                fontBytes: testFontBytes,
                color: Colors.pink,
                fontSize: 25,
                lean: 5,
                pos: const Offset(40, 60),
                edgeSize: 2,
                bendCurvature: 0.2, // 半径 5 -> 曲率 0.2，会被 clamp 到最小半径 20
                bendSpacing: 2.0,
              ),
            ],
          );

          expect(result, isNotNull);
          expect(result.isNotEmpty, true);
          // 验证 PNG 文件头
          expect(result[0], 0x89);
          expect(result[1], 0x50);
          expect(result[2], 0x4E);
          expect(result[3], 0x47);
        },
      );
    });

    group('TextLayer JSON compatibility tests', () {
      test('fromJson without bc/br should default to 0.0', () {
        final json = {
          'i': 'test-id',
          'c': 'Test Content',
          'x': 10.0,
          'y': 20.0,
          'r': 15.0,
          's': 50.0,
          'e': 4,
          'f': 1,
          'u': false,
          'clr': 0xFFDDAACC,
          'o': 1.0,
          'v': true,
          'l': false,
          // bc 和 bs 缺失
        };

        final layer = TextLayer.fromJson(json);

        expect(layer.bendCurvature, 0.0);
        expect(layer.bendSpacing, 0.0);
        expect(layer.content, 'Test Content');
        expect(layer.fontSize, 50.0);
      });

      test('toJson/fromJson should preserve bc (bendCurvature) values', () {
        final originalLayer = TextLayer(
          content: 'Preserved Text',
          pos: const Offset(30, 40),
          lean: 12.0,
          fontSize: 45.0,
          edgeSize: 3,
          font: 2,
          bendCurvature: 0.01, // 曲率 0.01
          bendSpacing: 6.5,
        );

        final json = originalLayer.toJson();
        final restoredLayer = TextLayer.fromJson(json);

        expect(restoredLayer.bendCurvature, originalLayer.bendCurvature);
        expect(restoredLayer.bendSpacing, originalLayer.bendSpacing);
        expect(restoredLayer.content, originalLayer.content);
        expect(restoredLayer.lean, originalLayer.lean);
        expect(restoredLayer.fontSize, originalLayer.fontSize);
        expect(restoredLayer.edgeSize, originalLayer.edgeSize);
      });

      test(
        'fromJson with legacy br (bendRadius) should convert to curvature',
        () {
          final json = {
            'i': 'legacy-id',
            'c': 'Legacy Content',
            'x': 15.0,
            'y': 25.0,
            'r': 10.0,
            's': 40.0,
            'e': 5,
            'f': 0,
            'u': true,
            'clr': 0xFF123456,
            'o': 0.8,
            'v': true,
            'l': false,
            'br': 100.0, // 旧半径字段：100 -> 曲率 0.01
            'bs': 3.5,
          };

          final layer = TextLayer.fromJson(json);

          expect(
            layer.bendCurvature,
            closeTo(0.01, 0.0001),
          ); // 100 -> 1/100 = 0.01
          expect(layer.bendSpacing, 3.5);
        },
      );

      test(
        'fromJson with legacy bendRadius (full key) should convert to curvature',
        () {
          final json = {
            'i': 'legacy-id-2',
            'c': 'Legacy Content 2',
            'x': 15.0,
            'y': 25.0,
            'r': 10.0,
            's': 40.0,
            'e': 5,
            'f': 0,
            'u': true,
            'clr': 0xFF123456,
            'o': 0.8,
            'v': true,
            'l': false,
            'bendRadius': -200.0, // 旧半径字段：-200 -> 曲率 -0.005
            'bendSpacing': 3.5,
          };

          final layer = TextLayer.fromJson(json);

          expect(
            layer.bendCurvature,
            closeTo(-0.005, 0.0001),
          ); // -200 -> 1/-200 = -0.005
          expect(layer.bendSpacing, 3.5);
        },
      );

      test('fromJson with br=0 should result in curvature=0', () {
        final json = {
          'i': 'zero-radius-id',
          'c': 'Zero Radius',
          'x': 10.0,
          'y': 20.0,
          'r': 0.0,
          's': 50.0,
          'e': 4,
          'f': 1,
          'u': false,
          'clr': 0xFFDDAACC,
          'o': 1.0,
          'v': true,
          'l': false,
          'br': 0.0, // 半径 0 -> 曲率 0
        };

        final layer = TextLayer.fromJson(json);

        expect(layer.bendCurvature, 0.0);
      });

      test('toJson should include bc (bendCurvature) field', () {
        final layer = TextLayer(
          content: 'JSON Test',
          bendCurvature: 0.005, // 曲率 0.005
          bendSpacing: 7.0,
        );

        final json = layer.toJson();

        expect(json.containsKey('bc'), true);
        expect(json.containsKey('bs'), true);
        expect(json['bc'], 0.005);
        expect(json['bs'], 7.0);
      });

      test('fromJson should prioritize bc over br when both present', () {
        final json = {
          'i': 'priority-test',
          'c': 'Priority Test',
          'x': 10.0,
          'y': 20.0,
          'r': 0.0,
          's': 50.0,
          'e': 4,
          'f': 1,
          'u': false,
          'clr': 0xFFDDAACC,
          'o': 1.0,
          'v': true,
          'l': false,
          'bc': 0.02, // 新曲率字段
          'br': 100.0, // 旧半径字段（应被忽略）
        };

        final layer = TextLayer.fromJson(json);

        expect(layer.bendCurvature, 0.02); // 应使用 bc 而非 br
      });
    });

    group('Curvature layout math tests', () {
      test('calculateCircleCenter with positive curvature', () {
        // 正曲率：圆心在文字下方
        final center = ImageTextOverlay.calculateCircleCenter(
          bendCurvature: 0.01, // 半径 100
          textWidth: 100.0,
          textHeight: 20.0,
        );

        expect(center.dx, closeTo(50.0, 0.01)); // textWidth / 2
        expect(
          center.dy,
          closeTo(110.0, 0.01),
        ); // textHeight / 2 + radius = 10 + 100
      });

      test('calculateCircleCenter with negative curvature', () {
        // 负曲率：圆心在文字上方
        final center = ImageTextOverlay.calculateCircleCenter(
          bendCurvature: -0.01, // 半径 -100
          textWidth: 100.0,
          textHeight: 20.0,
        );

        expect(center.dx, closeTo(50.0, 0.01)); // textWidth / 2
        expect(
          center.dy,
          closeTo(-90.0, 0.01),
        ); // textHeight / 2 + (-100) = 10 - 100
      });

      test('calculateCharLayout with positive curvature', () {
        // 正曲率测试
        final circleCenter = Offset(50.0, 110.0);
        final layout = ImageTextOverlay.calculateCharLayout(
          bendCurvature: 0.01,
          circleCenter: circleCenter,
          lineSignedRadius: 100.0,
          charArcCenter: 0.0, // 字符在圆弧中心
          charWidth: 10.0,
          charHeight: 20.0,
        );

        // 验证基本属性
        expect(layout.lineRadius, 100.0);
        expect(
          layout.theta,
          closeTo(0.0, 0.01),
        ); // arcCenter / radius = 0 / 100

        // 正曲率时，anchor 应在圆心下方
        expect(layout.anchor.dx, closeTo(circleCenter.dx, 0.1));
        expect(layout.anchor.dy, closeTo(circleCenter.dy - 100.0, 0.1));

        // paintOffset 应该是 (-charWidth/2, -charHeight)
        expect(layout.paintOffset.dx, closeTo(-5.0, 0.01));
        expect(layout.paintOffset.dy, closeTo(-20.0, 0.01));

        // rotation 应该等于 theta
        expect(layout.rotation, closeTo(layout.theta, 0.01));
      });

      test('calculateCharLayout with negative curvature', () {
        // 负曲率测试
        final circleCenter = Offset(50.0, -90.0);
        final layout = ImageTextOverlay.calculateCharLayout(
          bendCurvature: -0.01,
          circleCenter: circleCenter,
          lineSignedRadius: -100.0,
          charArcCenter: 0.0, // 字符在圆弧中心
          charWidth: 10.0,
          charHeight: 20.0,
        );

        // 验证基本属性
        expect(layout.lineRadius, -100.0);
        expect(layout.theta, closeTo(0.0, 0.01));

        // 负曲率时，anchor 应在圆心上方
        expect(layout.anchor.dx, closeTo(circleCenter.dx, 0.1));
        expect(layout.anchor.dy, closeTo(circleCenter.dy + 100.0, 0.1));

        // paintOffset 应该是 (-charWidth/2, 0)
        expect(layout.paintOffset.dx, closeTo(-5.0, 0.01));
        expect(layout.paintOffset.dy, closeTo(0.0, 0.01));

        // rotation 应该是 -theta
        expect(layout.rotation, closeTo(-layout.theta, 0.01));
      });

      test('calculateCharLayout with minimum radius clamping', () {
        // 测试最小半径保护
        final circleCenter = Offset(50.0, 60.0);
        final layout = ImageTextOverlay.calculateCharLayout(
          bendCurvature: 0.2, // 半径 5，应被 clamp 到 20
          circleCenter: circleCenter,
          lineSignedRadius: 5.0, // 小于最小半径 20
          charArcCenter: 0.0,
          charWidth: 10.0,
          charHeight: 20.0,
        );

        // 验证半径被 clamp 到最小值 20
        expect(layout.lineRadius, 20.0);
      });

      test('calculateCharLayout with negative minimum radius clamping', () {
        // 测试负曲率最小半径保护
        final circleCenter = Offset(50.0, 5.0);
        final layout = ImageTextOverlay.calculateCharLayout(
          bendCurvature: -0.2, // 半径 -5，应被 clamp 到 -20
          circleCenter: circleCenter,
          lineSignedRadius: -5.0, // 绝对值小于最小半径 20
          charArcCenter: 0.0,
          charWidth: 10.0,
          charHeight: 20.0,
        );

        // 验证半径被 clamp 到最小值 -20（保持符号）
        expect(layout.lineRadius, -20.0);
      });
    });
  });
}
