import "dart:math";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class TextOverlayLayer {
  final String content;
  final String fontFamilyName;
  final Uint8List fontBytes;
  final Offset pos;
  final double lean;
  final double fontSize;
  final int edgeSize;
  final Color color;

  TextOverlayLayer({
    required this.content,
    required this.fontFamilyName,
    required this.fontBytes,
    required this.pos,
    required this.lean,
    required this.fontSize,
    required this.edgeSize,
    required this.color,
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
    if (_loadedFonts.contains(fontFamilyName)) return;

    if (_fontLoadFutures.containsKey(fontFamilyName)) {
      return _fontLoadFutures[fontFamilyName];
    }

    final future = Future(() async {
      try {
        final fontProvider = FontLoader(fontFamilyName)
          ..addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await fontProvider.load();
        _loadedFonts.add(fontFamilyName);
      } finally {
        _fontLoadFutures.remove(fontFamilyName);
      }
    });

    _fontLoadFutures[fontFamilyName] = future;
    return future;
  }

  static Future<TextPainter> _createTextPainter({
    required String content,
    required double fontSize,
    required int edgeSize,
    required String fontFamilyName,
    required Color color,
  }) async {
    final textStyle = TextStyle(
      fontFamily: fontFamilyName,
      fontSize: fontSize,
      color: color,
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

      // 1. 先位移到目标位置（基于原始坐标系，不受旋转影响）
      canvas.translate(layer.pos.dx, layer.pos.dy);

      // 2. 以文字中心为基准进行旋转
      final halfWidth = textPainter.width / 2;
      final halfHeight = textPainter.height / 2;

      canvas.translate(halfWidth, halfHeight);
      canvas.rotate(-layer.lean * pi / 180);
      canvas.translate(-halfWidth, -halfHeight);

      // 3. 绘制文字
      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    }

    final picture = recorder.endRecording();
    return await picture.toImage(bgImage.width, bgImage.height);
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
}
