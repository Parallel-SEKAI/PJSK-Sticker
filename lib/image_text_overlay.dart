import "dart:math";
import "dart:ui" as ui;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:pjsk_sticker/font_manager.dart";

class TextOverlayLayer {
  final String content;
  final String fontFamilyName;
  final Uint8List fontBytes;
  final Offset pos;
  final double lean;
  final double fontSize;
  final int edgeSize;
  final Color color;
  final double opacity;
  final double bendCurvature;
  final double bendSpacing;

  TextOverlayLayer({
    required this.content,
    required this.fontFamilyName,
    required this.fontBytes,
    required this.pos,
    required this.lean,
    required this.fontSize,
    required this.edgeSize,
    required this.color,
    this.opacity = 1.0,
    this.bendCurvature = 0.0,
    this.bendSpacing = 0.0,
  });
}

class ImageTextOverlay {
  static final Map<String, Future<void>> _fontLoadFutures = {};
  static final Set<String> _loadedFonts = {};

  static Future<Uint8List> generateStickerFromBytes({
    required Uint8List imageBytes,
    required List<TextOverlayLayer> layers,
  }) async {
    final bgImage = await _decodeImageFromBytes(imageBytes);

    // 预加载所有唯一的字体
    final Map<String, Uint8List> uniqueFonts = {};
    for (var layer in layers) {
      if (layer.fontBytes.isNotEmpty) {
        uniqueFonts[layer.fontFamilyName] = layer.fontBytes;
      }
    }

    for (var entry in uniqueFonts.entries) {
      await _loadFontFromBytes(entry.value, entry.key);
    }

    List<TextPainter> textPainters = [];
    for (var layer in layers) {
      final textPainter = await _createTextPainter(
        content: layer.content,
        fontSize: layer.fontSize,
        edgeSize: layer.edgeSize,
        fontFamilyName: layer.fontFamilyName,
        color: layer.color,
        letterSpacing: layer.bendSpacing,
      );
      textPainters.add(textPainter);
    }

    final image = await _compositeImages(bgImage, textPainters, layers);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<ui.Image> _decodeImageFromBytes(Uint8List imageData) async {
    return decodeImageFromList(imageData);
  }

  static Future<void> _loadFontFromBytes(
    Uint8List fontBytes,
    String fontFamilyName,
  ) async {
    // 如果已经被 FontManager 或本类注册过，跳过
    if (_loadedFonts.contains(fontFamilyName)) return;
    if (FontManager.instance.isFontRegistered(fontFamilyName)) {
      _loadedFonts.add(fontFamilyName);
      return;
    }

    if (_fontLoadFutures.containsKey(fontFamilyName)) {
      return _fontLoadFutures[fontFamilyName];
    }

    final future = Future(() async {
      try {
        final byteData = ByteData.view(
          fontBytes.buffer,
          fontBytes.offsetInBytes,
          fontBytes.lengthInBytes,
        );
        final fontProvider = FontLoader(fontFamilyName)
          ..addFont(Future.value(byteData));
        await fontProvider.load();
        _loadedFonts.add(fontFamilyName);
      } finally {
        _fontLoadFutures.remove(fontFamilyName);
      }
    });

    _fontLoadFutures[fontFamilyName] = future;
    return future;
  }

  /// 创建统一的 TextStyle，用于整体文字和单字符文字
  static TextStyle _buildTextStyle({
    required String fontFamilyName,
    required double fontSize,
    required int edgeSize,
    required Color color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamilyName,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      shadows:
          getOffsets(360)
              .map(
                (offset) => Shadow(
                  color: Colors.white,
                  offset: offset * edgeSize.toDouble(),
                  blurRadius: 0,
                ),
              )
              .toList(),
    );
  }

  /// 创建单字符 TextPainter，用于弯曲文字绘制
  static TextPainter _createSingleCharPainter({
    required String char,
    required String fontFamilyName,
    required double fontSize,
    required int edgeSize,
    required Color color,
  }) {
    final textStyle = _buildTextStyle(
      fontFamilyName: fontFamilyName,
      fontSize: fontSize,
      edgeSize: edgeSize,
      color: color,
      letterSpacing: null,
    );
    final painter = TextPainter(
      text: TextSpan(text: char, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  }

  static Future<TextPainter> _createTextPainter({
    required String content,
    required double fontSize,
    required int edgeSize,
    required String fontFamilyName,
    required Color color,
    double? letterSpacing,
  }) async {
    final textStyle = _buildTextStyle(
      fontFamilyName: fontFamilyName,
      fontSize: fontSize,
      edgeSize: edgeSize,
      color: color,
      letterSpacing: letterSpacing,
    );

    final lines = content.split("\n");
    double maxWidth = 0;

    for (final line in lines) {
      final textSpan = TextSpan(text: line, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      maxWidth = maxWidth > textPainter.width ? maxWidth : textPainter.width;
    }

    final painter = TextPainter(
      text: TextSpan(text: content, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);

    return painter;
  }

  static Future<ui.Image> _compositeImages(
    ui.Image bgImage,
    List<TextPainter> textPainters,
    List<TextOverlayLayer> layers,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(bgImage, Offset.zero, Paint());

    for (int i = 0; i < textPainters.length; i++) {
      final textPainter = textPainters[i];
      final layer = layers[i];

      canvas.save();

      // 创建带透明度的 Paint
      final paint =
          Paint()..color = Color.fromRGBO(255, 255, 255, layer.opacity);

      // 使用 saveLayer 应用透明度到整个文字图层
      canvas.saveLayer(null, paint);

      // 1. 先位移到目标位置（基于原始坐标系，不受旋转影响）
      canvas.translate(layer.pos.dx, layer.pos.dy);

      // 判断是否使用弯曲绘制（曲率模式）
      final useCurvature = layer.bendCurvature.abs() > 1e-6;

      if (!useCurvature) {
        // 直线模式：保持原有逻辑，bendSpacing 通过 letterSpacing 生效
        final halfWidth = textPainter.width / 2;
        final halfHeight = textPainter.height / 2;

        // lean 围绕直线文字中心旋转
        canvas.translate(halfWidth, halfHeight);
        canvas.rotate(-layer.lean * pi / 180);
        canvas.translate(-halfWidth, -halfHeight);

        textPainter.paint(canvas, Offset.zero);
      } else {
        // 曲率模式：逐字符绘制
        _drawCurvedText(canvas: canvas, layer: layer, textPainter: textPainter);
      }

      canvas.restore(); // 恢复 saveLayer
      canvas.restore(); // 恢复 save
    }

    final picture = recorder.endRecording();
    return await picture.toImage(bgImage.width, bgImage.height);
  }

  /// 绘制曲率模式文字
  static void _drawCurvedText({
    required Canvas canvas,
    required TextOverlayLayer layer,
    required TextPainter textPainter,
  }) {
    // 计算圆心和半径
    final signedRadius = 1.0 / layer.bendCurvature;
    final circleCenter = Offset(
      textPainter.width / 2,
      textPainter.height / 2 + signedRadius,
    );

    // 应用整体 lean 旋转，围绕 circleCenter
    canvas.translate(circleCenter.dx, circleCenter.dy);
    canvas.rotate(-layer.lean * pi / 180);
    canvas.translate(-circleCenter.dx, -circleCenter.dy);

    final lines = layer.content.split("\n");
    final lineHeight = textPainter.height / lines.length;

    double currentY = 0;

    for (final line in lines) {
      if (line.isEmpty) {
        currentY += lineHeight;
        continue;
      }

      // 计算当前行的圆心偏移
      final lineCenterY = currentY + lineHeight / 2;
      final lineDelta = lineCenterY - textPainter.height / 2;
      final lineSignedRadius = signedRadius + lineDelta;

      // 保护最小半径（保持符号）
      final minRadius = 20.0;
      final lineRadius =
          lineSignedRadius.abs() < minRadius
              ? (lineSignedRadius >= 0 ? minRadius : -minRadius)
              : lineSignedRadius;

      // 使用 runes 拆分字符
      final chars = line.runes.map((r) => String.fromCharCode(r)).toList();

      // 测量每个字符的宽度和高度
      final charPainters = <TextPainter>[];
      final charWidths = <double>[];
      final charHeights = <double>[];

      for (final char in chars) {
        final painter = _createSingleCharPainter(
          char: char,
          fontFamilyName: layer.fontFamilyName,
          fontSize: layer.fontSize,
          edgeSize: layer.edgeSize,
          color: layer.color,
        );
        charPainters.add(painter);
        charWidths.add(painter.width);
        charHeights.add(painter.height);
      }

      // 计算总弧长（负 bendSpacing 做 clamp）
      double totalArcLength = 0;
      for (int j = 0; j < chars.length; j++) {
        final charWidth = charWidths[j];
        totalArcLength += charWidth;
        if (j < chars.length - 1) {
          // clamp spacing 不小于 -charWidth * 0.8
          final clampedSpacing = max(layer.bendSpacing, -charWidth * 0.8);
          totalArcLength += clampedSpacing;
        }
      }

      // 字符总弧长居中排布
      double arcCursor = -totalArcLength / 2;

      // 逐字符绘制
      for (int j = 0; j < chars.length; j++) {
        final charPainter = charPainters[j];
        final charWidth = charWidths[j];
        final charHeight = charHeights[j];

        // 字符中心弧长
        final charArcCenter = arcCursor + charWidth / 2;

        // 计算角度
        final absRadius = lineRadius.abs();
        final theta = charArcCenter / absRadius;

        canvas.save();

        // 根据曲率正负计算 anchor 和 rotation
        final Offset anchor;
        final Offset paintOffset;
        final double rotation;

        if (lineRadius > 0) {
          // 正曲率：圆心在下方
          anchor = Offset(
            circleCenter.dx + absRadius * sin(theta),
            circleCenter.dy - absRadius * cos(theta),
          );
          paintOffset = Offset(-charWidth / 2, -charHeight);
          rotation = theta;
        } else {
          // 负曲率：圆心在上方
          anchor = Offset(
            circleCenter.dx + absRadius * sin(theta),
            circleCenter.dy + absRadius * cos(theta),
          );
          paintOffset = Offset(-charWidth / 2, 0);
          rotation = -theta;
        }

        // 移动到 anchor 点
        canvas.translate(anchor.dx, anchor.dy);

        // 旋转
        canvas.rotate(rotation);

        // 绘制字符
        charPainter.paint(canvas, paintOffset);

        canvas.restore();

        // 更新弧长游标
        arcCursor += charWidth;
        if (j < chars.length - 1) {
          final clampedSpacing = max(layer.bendSpacing, -charWidth * 0.8);
          arcCursor += clampedSpacing;
        }
      }

      currentY += lineHeight;
    }
  }

  static List<Offset> getOffsets(int precision) {
    assert(precision > 0);
    List<Offset> offsets = [];
    for (int i = 0; i < precision; i++) {
      final angle = 2 * pi * i / precision;
      final x = cos(angle);
      final y = sin(angle);
      offsets.add(Offset(x, y));
    }
    return offsets;
  }

  /// 测试辅助：计算曲率模式的圆心
  @visibleForTesting
  static Offset calculateCircleCenter({
    required double bendCurvature,
    required double textWidth,
    required double textHeight,
  }) {
    final signedRadius = 1.0 / bendCurvature;
    return Offset(textWidth / 2, textHeight / 2 + signedRadius);
  }

  /// 测试辅助：计算单个字符的布局信息
  @visibleForTesting
  static CharLayoutInfo calculateCharLayout({
    required double bendCurvature,
    required Offset circleCenter,
    required double lineSignedRadius,
    required double charArcCenter,
    required double charWidth,
    required double charHeight,
  }) {
    // 保护最小半径
    final minRadius = 20.0;
    final lineRadius =
        lineSignedRadius.abs() < minRadius
            ? (lineSignedRadius >= 0 ? minRadius : -minRadius)
            : lineSignedRadius;

    final absRadius = lineRadius.abs();
    final theta = charArcCenter / absRadius;

    final Offset anchor;
    final Offset paintOffset;
    final double rotation;

    if (lineRadius > 0) {
      // 正曲率
      anchor = Offset(
        circleCenter.dx + absRadius * sin(theta),
        circleCenter.dy - absRadius * cos(theta),
      );
      paintOffset = Offset(-charWidth / 2, -charHeight);
      rotation = theta;
    } else {
      // 负曲率
      anchor = Offset(
        circleCenter.dx + absRadius * sin(theta),
        circleCenter.dy + absRadius * cos(theta),
      );
      paintOffset = Offset(-charWidth / 2, 0);
      rotation = -theta;
    }

    return CharLayoutInfo(
      anchor: anchor,
      paintOffset: paintOffset,
      rotation: rotation,
      theta: theta,
      lineRadius: lineRadius,
    );
  }
}

/// 测试辅助：字符布局信息
@visibleForTesting
class CharLayoutInfo {
  final Offset anchor;
  final Offset paintOffset;
  final double rotation;
  final double theta;
  final double lineRadius;

  CharLayoutInfo({
    required this.anchor,
    required this.paintOffset,
    required this.rotation,
    required this.theta,
    required this.lineRadius,
  });
}
