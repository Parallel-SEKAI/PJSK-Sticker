part of '../sticker.dart';

extension _StickerPageSections on _StickerPageState {
  // Helper: 资源选择器 Tile
  Widget _buildAssetPickerTile(ColorScheme colorScheme, Color themeColor) {
    return ListTile(
      leading:
          _customBgPath != null
              ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(_customBgPath!),
                  key: ValueKey(_customBgPath),
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  cacheWidth: 48,
                  cacheHeight: 48,
                  errorBuilder:
                      (ctx, err, st) => const SizedBox(width: 24, height: 24),
                ),
              )
              : Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
      title: Text(
        _customBgPath != null
            ? S.of(context).customBackground
            : S.of(context).characterSelect,
      ),
      subtitle: Text(
        _customBgPath != null
            ? S.of(context).customBackgroundHint
            : (_character == _StickerPageState.kRandom
                ? S.of(context).random
                : _character),
      ),
      trailing:
          _customBgPath != null
              ? IconButton(
                icon: Icon(Icons.close, color: colorScheme.error),
                tooltip: S.of(context).clearCustomBackground,
                onPressed: _clearCustomBackground,
              )
              : const Icon(Icons.chevron_right),
      onTap: _selectCharacter1,
    );
  }

  // 卡片 1: 资源与图层
  Widget _buildResourceCard(ColorScheme colorScheme, Color themeColor) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssetPickerTile(colorScheme, themeColor),
            const Divider(height: 16),
            _buildLayerBar(colorScheme),
          ],
        ),
      ),
    );
  }

  // 卡片 2: 文本内容
  Widget _buildTextInputCard(ColorScheme colorScheme, TextLayer currentLayer) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  S.of(context).editText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextController,
              enabled: !currentLayer.locked,
              decoration: InputDecoration(
                hintText: S.of(context).editText,
                prefixIcon: const Icon(Icons.edit),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed:
                      currentLayer.locked
                          ? null
                          : () {
                            _contextController.clear();
                            _update(() {
                              currentLayer.content = "";
                            });
                            _debouncedCreateSticker();
                          },
                ),
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
              onChanged: (v) {
                _update(() {
                  currentLayer.content = v;
                });
                _debouncedCreateSticker();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 卡片 3: 常用调整
  Widget _buildCommonAdjustCard(ColorScheme colorScheme, TextLayer layer) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  S.of(context).textStyle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (layer.locked) ...[
              const SizedBox(height: 8),
              Text(
                S.of(context).layerLocked,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey("font_${layer.id}_${PjskGenerator.fonts.length}"),
              decoration: InputDecoration(
                labelText: S.of(context).font,
                border: const OutlineInputBorder(),
              ),
              initialValue:
                  PjskGenerator.fonts.isEmpty
                      ? 0
                      : layer.font.clamp(0, PjskGenerator.fonts.length - 1),
              items:
                  PjskGenerator.fonts.isEmpty
                      ? [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(S.of(context).systemDefault),
                        ),
                      ]
                      : [
                        for (int i = 0; i < PjskGenerator.fonts.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              PjskGenerator.fonts[i] ==
                                      FontManager.systemFontName
                                  ? S.of(context).systemDefault
                                  : PjskGenerator.fonts[i],
                            ),
                          ),
                      ],
              onChanged:
                  layer.locked
                      ? null
                      : (v) {
                        _update(() => layer.font = v!);
                        _debouncedCreateSticker();
                      },
            ),
            const SizedBox(height: 8),
            _buildSliderTile(
              label: S.of(context).fontSize,
              value: layer.fontSize,
              min: 0,
              max: 100,
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.fontSize = v);
                _debouncedCreateSticker();
              },
            ),
            _buildSliderTile(
              label: S.of(context).opacity,
              value: layer.opacity * 100,
              min: 0,
              max: 100,
              divisions: 100,
              showAsPercentage: true,
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.opacity = v / 100);
                _debouncedCreateSticker();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 卡片 4: 精细调整
  Widget _buildAdvancedCard(ColorScheme colorScheme, TextLayer layer) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：高级样式 + 锁定状态 badge
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context).advancedStyle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (layer.locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock,
                          size: 12,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          S.of(context).layerLocked,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 分组一：位置调整
            Row(
              children: [
                Icon(Icons.open_with, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  S.of(context).positionAdjust,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // X/Y 偏移：响应式双列/单列
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth > 400;
                if (useTwoColumns) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildCompactSlider(
                          label: S.of(context).xOffset,
                          value: layer.pos.dx,
                          min: -100,
                          max: 300,
                          divisions: 400,
                          enabled: !layer.locked,
                          onChanged: (v) {
                            _update(() => layer.pos = Offset(v, layer.pos.dy));
                            _debouncedCreateSticker();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactSlider(
                          label: S.of(context).yOffset,
                          value: layer.pos.dy,
                          min: -100,
                          max: 300,
                          divisions: 400,
                          enabled: !layer.locked,
                          onChanged: (v) {
                            _update(() => layer.pos = Offset(layer.pos.dx, v));
                            _debouncedCreateSticker();
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildCompactSlider(
                        label: S.of(context).xOffset,
                        value: layer.pos.dx,
                        min: -100,
                        max: 300,
                        divisions: 400,
                        enabled: !layer.locked,
                        onChanged: (v) {
                          _update(() => layer.pos = Offset(v, layer.pos.dy));
                          _debouncedCreateSticker();
                        },
                      ),
                      const SizedBox(height: 4),
                      _buildCompactSlider(
                        label: S.of(context).yOffset,
                        value: layer.pos.dy,
                        min: -100,
                        max: 300,
                        divisions: 400,
                        enabled: !layer.locked,
                        onChanged: (v) {
                          _update(() => layer.pos = Offset(layer.pos.dx, v));
                          _debouncedCreateSticker();
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 4),
            // 旋转角度：单列显示，数值带 °
            _buildCompactSlider(
              label: S.of(context).rotationAngle,
              value: layer.lean,
              min: -180,
              max: 180,
              divisions: 360,
              suffix: '°',
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.lean = v);
                _debouncedCreateSticker();
              },
            ),
            const Divider(height: 24),
            // 分组二：弯曲效果
            Row(
              children: [
                Icon(Icons.architecture, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  S.of(context).bendEffect,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 弯曲曲率
            _buildCompactSlider(
              label: S.of(context).bendCurvature,
              value: layer.bendCurvature,
              min: -0.05,
              max: 0.05,
              divisions: 1000,
              valueFormatter: (v) {
                // 显示 4 位小数，接近 0 时显示 0
                if (v.abs() < 0.00001) return '0';
                return v.toStringAsFixed(4);
              },
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.bendCurvature = v);
                _debouncedCreateSticker();
              },
            ),
            const SizedBox(height: 4),
            // 字符间距
            _buildCompactSlider(
              label: S.of(context).bendSpacing,
              value: layer.bendSpacing,
              min: -10,
              max: 50,
              divisions: 600,
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.bendSpacing = v);
                _debouncedCreateSticker();
              },
            ),
            const Divider(height: 24),
            // 分组三：颜色/描边
            Row(
              children: [
                Icon(Icons.format_paint, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  S.of(context).customColor,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 描边粗细
            _buildCompactSlider(
              label: S.of(context).strokeWidth,
              value: layer.edgeSize.toDouble(),
              min: 0,
              max: 20,
              enabled: !layer.locked,
              onChanged: (v) {
                _update(() => layer.edgeSize = v.round());
                _debouncedCreateSticker();
              },
            ),
            const SizedBox(height: 8),
            // 自定义颜色开关
            SwitchListTile(
              title: Text(S.of(context).customColor),
              subtitle: Text(S.of(context).customColorHint),
              contentPadding: EdgeInsets.zero,
              value: layer.useCustomColor,
              onChanged:
                  layer.locked
                      ? null
                      : (v) {
                        _update(() => layer.useCustomColor = v);
                        _debouncedCreateSticker();
                      },
            ),
            const SizedBox(height: 4),
            // 颜色选择入口：现代化圆角容器行
            Opacity(
              opacity: (layer.useCustomColor && !layer.locked) ? 1.0 : 0.5,
              child: InkWell(
                onTap:
                    (layer.useCustomColor && !layer.locked) ? _pickColor : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 色块
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: layer.customColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 文字颜色标签
                      Text(
                        S.of(context).textColor,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      // 颜色值
                      Text(
                        '#${layer.customColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // chevron
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(ColorScheme colorScheme) {
    return Expanded(
      flex: 2,
      child: Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child:
              _byteData != null
                  ? GestureDetector(
                    onTap: _handleImageTap,
                    child: Card(
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        key: ValueKey(_byteData.hashCode),
                        _byteData!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                  : const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    int divisions = 100,
    required ValueChanged<double> onChanged,
    bool showAsPercentage = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                showAsPercentage
                    ? '${value.round()}%'
                    : value.round().toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  // 紧凑 slider helper(用于高级样式卡片)
  Widget _buildCompactSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    String suffix = '',
    String Function(double value)? valueFormatter,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    // 默认格式化器：整数 + 后缀
    final formatter = valueFormatter ?? (v) => '${v.round()}$suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                formatter(value),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLayerBar(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).layerManagement,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              FilledButton.tonalIcon(
                onPressed: _addLayer,
                icon: const Icon(Icons.add, size: 18),
                label: Text(S.of(context).add),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          buildDefaultDragHandles: false,
          itemCount: _layers.length,
          onReorder: _reorderLayer,
          itemBuilder: (context, index) {
            final layer = _layers[index];
            final isSelected = _currentLayerId == layer.id;
            return _buildLayerItem(index, layer, isSelected, colorScheme);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLayerItem(
    int index,
    TextLayer layer,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final text = layer.content;
    final displayText =
        text.isEmpty ? S.of(context).layerDefault(index + 1) : text;
    final fontName =
        PjskGenerator.fonts.isEmpty
            ? S.of(context).systemDefault
            : (layer.font >= 0 && layer.font < PjskGenerator.fonts.length
                ? (PjskGenerator.fonts[layer.font] == FontManager.systemFontName
                    ? S.of(context).systemDefault
                    : PjskGenerator.fonts[layer.font])
                : S.of(context).systemDefault);
    final opacityPercent = (layer.opacity * 100).round();

    return Padding(
      key: ValueKey(layer.id),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        elevation: isSelected ? 2 : 0,
        color:
            isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              isSelected
                  ? BorderSide(color: colorScheme.primary, width: 2)
                  : BorderSide.none,
        ),
        child: Opacity(
          opacity: !layer.visible ? 0.4 : (layer.locked ? 0.7 : 1.0),
          child: InkWell(
            onTap: () => _selectLayer(layer.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 拖拽滑柄
                  Semantics(
                    label: S.of(context).reorderLayerHandle,
                    button: true,
                    child: Tooltip(
                      message: S.of(context).reorderLayerHandle,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle,
                          size: 22,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 左侧指示条
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            layer.locked
                                ? colorScheme.error
                                : colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  if (isSelected) const SizedBox(width: 12),
                  // 主要内容区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 图层序号 + 文字内容
                        Row(
                          children: [
                            if (!layer.visible) ...[
                              Icon(
                                Icons.visibility_off,
                                size: 14,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (layer.locked) ...[
                              Icon(
                                Icons.lock,
                                size: 14,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                '${index + 1}. $displayText',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                  color:
                                      isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 次要信息：字体 + 透明度
                        Text(
                          '$fontName · $opacityPercent%',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                isSelected
                                    ? colorScheme.onPrimaryContainer.withValues(
                                      alpha: 0.7,
                                    )
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 操作按钮区
                  _buildLayerActions(index, layer, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerActions(
    int index,
    TextLayer layer,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 可见性按钮
        IconButton(
          icon: Icon(
            layer.visible ? Icons.visibility : Icons.visibility_off,
            size: 18,
          ),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact,
          onPressed: () => _toggleLayerVisibility(layer.id),
          tooltip:
              layer.visible
                  ? S.of(context).layerVisible
                  : S.of(context).layerHidden,
          color:
              layer.visible
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.outline,
        ),
        // 锁定按钮
        IconButton(
          icon: Icon(layer.locked ? Icons.lock : Icons.lock_open, size: 18),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact,
          onPressed: () => _toggleLayerLock(layer.id),
          tooltip:
              layer.locked
                  ? S.of(context).layerLocked
                  : S.of(context).layerUnlocked,
          color:
              layer.locked ? colorScheme.error : colorScheme.onSurfaceVariant,
        ),
        // 更多菜单按钮
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: S.of(context).layerInfo,
          onSelected: (value) {
            if (value == 'duplicate') {
              _duplicateLayer(index);
            } else if (value == 'delete') {
              _removeLayer(index);
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(S.of(context).duplicateLayer),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !layer.locked && _layers.length > 1,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 18,
                        color:
                            (!layer.locked && _layers.length > 1)
                                ? colorScheme.error
                                : colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.of(context).deleteLayer,
                        style: TextStyle(
                          color:
                              (!layer.locked && _layers.length > 1)
                                  ? colorScheme.onSurface
                                  : colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ],
    );
  }
}
