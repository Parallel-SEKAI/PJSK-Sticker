part of '../sticker.dart';

extension _StickerPageLayers on _StickerPageState {
  Future<void> _resetPreferences() async {
    // 删除自定义底图文件
    if (_customBgPath != null) {
      try {
        final file = File(_customBgPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) print('Failed to delete custom background: $e');
      }
    }

    _update(() {
      _character = "emu";
      _selectedCharacter = "emu";
      _selectedSticker = 12;
      _layers = [TextLayer(content: "わんだほーい")];
      _currentLayerId = _layers.first.id;
      _contextController.text = _currentLayer.content;
      _customBgPath = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customBgPath');
    _createSticker();
  }

  void _addLayer() {
    _update(() {
      final newLayer = TextLayer(content: S.of(context).newLayerContent);
      _layers.add(newLayer);
      _currentLayerId = newLayer.id;
      _contextController.text = _currentLayer.content;
    });
    _createSticker();
  }

  void _toggleLayerVisibility(String id) {
    _update(() {
      final index = _layers.indexWhere((l) => l.id == id);
      if (index == -1) {
        if (kDebugMode) print('Layer with id $id not found');
        return;
      }
      _layers[index].visible = !_layers[index].visible;
    });
    _createSticker();
  }

  void _toggleLayerLock(String id) {
    _update(() {
      final index = _layers.indexWhere((l) => l.id == id);
      if (index == -1) {
        if (kDebugMode) print('Layer with id $id not found');
        return;
      }
      _layers[index].locked = !_layers[index].locked;
    });
  }

  void _duplicateLayer(int index) {
    if (index < 0 || index >= _layers.length) {
      if (kDebugMode) print('Invalid layer index: $index');
      return;
    }

    _update(() {
      final originalLayer = _layers[index];
      // 由于 copyWith 会保留原 id，需要创建一个新的 TextLayer
      final duplicatedLayer = TextLayer(
        content: "${originalLayer.content}${S.of(context).copyLayerSuffix}",
        pos: originalLayer.pos,
        lean: originalLayer.lean,
        fontSize: originalLayer.fontSize,
        edgeSize: originalLayer.edgeSize,
        font: originalLayer.font,
        useCustomColor: originalLayer.useCustomColor,
        customColor: originalLayer.customColor,
        opacity: originalLayer.opacity,
        visible: originalLayer.visible,
        locked: originalLayer.locked,
        bendCurvature: originalLayer.bendCurvature,
        bendSpacing: originalLayer.bendSpacing,
      );
      _layers.insert(index + 1, duplicatedLayer);
      _currentLayerId = duplicatedLayer.id;
      _contextController.text = _currentLayer.content;
    });
    _createSticker();
  }

  void _reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _layers.length) {
      if (kDebugMode) print('Invalid old layer index: $oldIndex');
      return;
    }
    if (newIndex < 0 || newIndex > _layers.length) {
      if (kDebugMode) print('Invalid new layer index: $newIndex');
      return;
    }

    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (oldIndex == adjustedNewIndex) {
      return;
    }

    _update(() {
      final layer = _layers.removeAt(oldIndex);
      _layers.insert(adjustedNewIndex, layer);
      _contextController.text = _currentLayer.content;
    });
    _createSticker();
  }

  void _removeLayer(int index) {
    if (_layers.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).atLeastOneLayer)));
      return;
    }

    // 添加锁定检查
    if (_layers[index].locked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).layerLocked)));
      return;
    }

    final layerToRemove = _layers[index];
    final layerText = layerToRemove.content;
    final displayName =
        layerText.isEmpty
            ? S.of(context).layerDefault(index + 1)
            : (layerText.length > 10
                ? "${layerText.substring(0, 10)}..."
                : layerText);

    showAdaptiveDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).deleteLayer),
            content: Text(S.of(context).confirmDeleteLayer(displayName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  _update(() {
                    _layers.removeAt(index);
                    if (_currentLayerId == layerToRemove.id) {
                      _currentLayerId = _layers.first.id;
                    }
                    _contextController.text = _currentLayer.content;
                  });
                  _createSticker();
                  Navigator.pop(context);
                },
                child: Text(
                  S.of(context).confirmDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  void _selectLayer(String id) {
    _update(() {
      _currentLayerId = id;
      _contextController.text = _currentLayer.content;
    });
  }

  void _showResetDialog() {
    showAdaptiveDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).resetAllParams),
            content: Text(S.of(context).resetAllParamsDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  _resetPreferences();
                  Navigator.pop(context);
                },
                child: Text(
                  S.of(context).confirmReset,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  void _pickColor() {
    Color selected = _currentLayer.customColor;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).pickColor),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: selected,
                enableAlpha: false,
                onColorChanged: (c) => selected = c,
                pickerAreaHeightPercent: 0.8,
                hexInputBar: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  _update(() {
                    _currentLayer.useCustomColor = true;
                    _currentLayer.customColor = selected;
                  });
                  _createSticker();
                  Navigator.pop(context);
                },
                child: Text(S.of(context).confirm),
              ),
            ],
          ),
    );
  }
}
