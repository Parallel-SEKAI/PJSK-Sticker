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
                value.round().toString(),
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
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLayerBar(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            S.of(context).layerManagement,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(S.of(context).add),
                  onPressed: _addLayer,
                ),
              ),
              ...List.generate(_layers.length, (index) {
                final layer = _layers[index];
                final isSelected = _currentLayerId == layer.id;
                final text = layer.content;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onLongPress: () => _removeLayer(index),
                    child: ChoiceChip(
                      label: Text(
                        text.isEmpty
                            ? S.of(context).layerDefault(index + 1)
                            : (text.length > 8
                                ? "${text.substring(0, 8)}..."
                                : text),
                      ),
                      selected: isSelected,
                      onSelected: (_) => _selectLayer(layer.id),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStyleExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(S.of(context).textStyle),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int>(
            key: ValueKey("font_${layer.id}_${PjskGenerator.fonts.length}"),
            decoration: InputDecoration(labelText: S.of(context).font),
            initialValue: layer.font.clamp(0, PjskGenerator.fonts.length - 1),
            items: [
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
            onChanged: (v) {
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
      children: [
        _buildSliderTile(
          label: S.of(context).xOffset,
          value: layer.pos.dx,
          min: -100,
          max: 300,
          divisions: 400,
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
      children: [
        _buildSliderTile(
          label: S.of(context).strokeWidth,
          value: layer.edgeSize.toDouble(),
          min: 0,
          max: 20,
          divisions: 20,
          onChanged: (v) {
            _update(() => layer.edgeSize = v.round());
            _debouncedCreateSticker();
          },
        ),
        SwitchListTile(
          title: Text(S.of(context).customColor),
          subtitle: Text(S.of(context).customColorHint),
          secondary: const Icon(Icons.format_color_fill),
          value: layer.useCustomColor,
          onChanged: (v) {
            _update(() => layer.useCustomColor = v);
            _debouncedCreateSticker();
          },
        ),
        ListTile(
          enabled: layer.useCustomColor,
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
