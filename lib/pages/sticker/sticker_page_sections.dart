part of '../sticker.dart';

extension _StickerPageSections on _StickerPageState {
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
            size: 20,
          ),
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
          icon: Icon(layer.locked ? Icons.lock : Icons.lock_open, size: 20),
          onPressed: () => _toggleLayerLock(layer.id),
          tooltip:
              layer.locked
                  ? S.of(context).layerLocked
                  : S.of(context).layerUnlocked,
          color:
              layer.locked ? colorScheme.error : colorScheme.onSurfaceVariant,
        ),
        // 复制按钮
        IconButton(
          icon: const Icon(Icons.content_copy, size: 20),
          onPressed: () => _duplicateLayer(index),
          tooltip: S.of(context).duplicateLayer,
          color: colorScheme.onSurfaceVariant,
        ),
        // 删除按钮
        IconButton(
          icon: const Icon(Icons.delete, size: 20),
          onPressed: layer.locked ? null : () => _removeLayer(index),
          tooltip:
              layer.locked
                  ? S.of(context).layerLocked
                  : S.of(context).deleteLayer,
          color:
              layer.locked
                  ? colorScheme.outline.withValues(alpha: 0.5)
                  : colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildStyleExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(S.of(context).textStyle),
      subtitle: layer.locked ? Text(S.of(context).layerLocked) : null,
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int>(
            key: ValueKey("font_${layer.id}_${PjskGenerator.fonts.length}"),
            decoration: InputDecoration(labelText: S.of(context).font),
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
                            PjskGenerator.fonts[i] == FontManager.systemFontName
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
        ),
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
          label: S.of(context).rotationAngle,
          value: layer.lean,
          min: -180,
          max: 180,
          divisions: 360,
          enabled: !layer.locked,
          onChanged: (v) {
            _update(() => layer.lean = v);
            _debouncedCreateSticker();
          },
        ),
      ],
    );
  }

  Widget _buildPositionExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.open_with),
      title: Text(S.of(context).positionAdjust),
      subtitle: layer.locked ? Text(S.of(context).layerLocked) : null,
      children: [
        _buildSliderTile(
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
        _buildSliderTile(
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

  Widget _buildAdvancedExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.tune),
      title: Text(S.of(context).advancedStyle),
      subtitle: layer.locked ? Text(S.of(context).layerLocked) : null,
      children: [
        _buildSliderTile(
          label: S.of(context).strokeWidth,
          value: layer.edgeSize.toDouble(),
          min: 0,
          max: 20,
          divisions: 20,
          enabled: !layer.locked,
          onChanged: (v) {
            _update(() => layer.edgeSize = v.round());
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
        SwitchListTile(
          title: Text(S.of(context).customColor),
          subtitle: Text(S.of(context).customColorHint),
          secondary: const Icon(Icons.format_color_fill),
          value: layer.useCustomColor,
          onChanged:
              layer.locked
                  ? null
                  : (v) {
                    _update(() => layer.useCustomColor = v);
                    _debouncedCreateSticker();
                  },
        ),
        ListTile(
          enabled: layer.useCustomColor && !layer.locked,
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: layer.customColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          title: Text(S.of(context).textColor),
          trailing: Text(
            '#${layer.customColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          onTap: _pickColor,
        ),
      ],
    );
  }
}
