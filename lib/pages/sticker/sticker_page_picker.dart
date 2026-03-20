part of '../sticker.dart';

extension _StickerPagePicker on _StickerPageState {
  Future<void> _selectCharacter1() async {
    if (_character == _StickerPageState.kRandom) {
      _selectedGroup = _StickerPageState.kRandom;
      _selectedCharacter = null;
    } else if (PjskGenerator.groups.contains(_character)) {
      _selectedGroup = _character;
      _selectedCharacter = PjskGenerator.groupMembers[_character]?.first;
    } else {
      String display = _character;
      if (PjskGenerator.characterList.contains(_character)) {
        try {
          display =
              PjskGenerator.characterMap.entries
                  .firstWhere((e) => e.value == _character)
                  .key;
        } catch (_) {}
      }
      _selectedCharacter = display;
      _selectedGroup = _findGroupForCharacter(display);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModalState) => _buildPickerContent(ctx, setModalState),
          ),
    );
  }

  Widget _buildPickerContent(BuildContext ctx, StateSetter setModalState) {
    final String? group =
        (_selectedGroup?.isNotEmpty ?? false) ? _selectedGroup : null;
    final String? character = _selectedCharacter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (character != null && _characterKeys.containsKey(character)) {
        final key = _characterKeys[character];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      }
      if (character != null && _selectedSticker != -1) {
        final stickerKey =
            "${PjskGenerator.characterMap[character] ?? ""}_$_selectedSticker";
        final key = _stickerKeys[stickerKey];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.3,
          );
        }
      }
    });

    return Container(
      height: MediaQuery.of(ctx).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _buildGroupTabs(group, setModalState, ctx),
          const Divider(height: 16),
          if (group != null && group != _StickerPageState.kRandom) ...[
            _buildCharacterTabs(group, character, setModalState, ctx),
            const Divider(height: 16),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (group == _StickerPageState.kRandom || group == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shuffle),
                        label: Text(S.of(ctx).confirmRandomCharacter),
                        onPressed: () {
                          _update(() => _character = _StickerPageState.kRandom);
                          _createSticker();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  )
                else if (character != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(ctx).selectSticker,
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      TextButton(
                        onPressed: () {
                          _update(() {
                            _character = character;
                            _selectedSticker = -1;
                          });
                          _createSticker();
                          Navigator.pop(ctx);
                        },
                        child: Text(S.of(ctx).random),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStickerGrid(character, setModalState),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTabs(
    String? group,
    StateSetter setModalState,
    BuildContext ctx,
  ) {
    final List<String> all = [
      _StickerPageState.kRandom,
      ...PjskGenerator.groups,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _groupKeys[group ?? _StickerPageState.kRandom];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children:
            all.map((g) {
              final isSelected =
                  (g == _StickerPageState.kRandom && group == null) ||
                  (g == group);
              final color =
                  g == _StickerPageState.kRandom
                      ? Theme.of(ctx).colorScheme.primary
                      : PjskGenerator.groupColor[g]!;
              return Padding(
                key: _groupKeys[g],
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    g == _StickerPageState.kRandom ? S.of(ctx).random : g,
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setModalState(() {
                      _selectedGroup = g;
                      if (g != _StickerPageState.kRandom) {
                        _selectedCharacter =
                            PjskGenerator.groupMembers[g]!.first;
                      }
                    });
                    _update(() {
                      _selectedGroup = g;
                      if (g != _StickerPageState.kRandom) {
                        _selectedCharacter =
                            PjskGenerator.groupMembers[g]!.first;
                      }
                    });
                  },
                  selectedColor: color.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: isSelected ? color : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCharacterTabs(
    String group,
    String? character,
    StateSetter setModalState,
    BuildContext ctx,
  ) {
    final List<String> members = PjskGenerator.groupMembers[group] ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(S.of(ctx).teamRandom),
              backgroundColor: (PjskGenerator.groupColor[group] ??
                      Theme.of(ctx).colorScheme.primary)
                  .withValues(alpha: 0.1),
              onPressed: () {
                _update(() {
                  _character = group;
                  _selectedSticker = -1;
                });
                _createSticker();
                Navigator.pop(ctx);
              },
            ),
          ),
          ...members.map((char) {
            final String internal = PjskGenerator.characterMap[char] ?? "";
            final isSelected = character == char || character == internal;
            final color = PjskGenerator.characterColor[internal] ?? Colors.grey;
            return Padding(
              key: _characterKeys[char],
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(char),
                selected: isSelected,
                selectedColor: color.withValues(alpha: 0.2),
                onSelected:
                    (_) => setModalState(() {
                      _selectedCharacter = char;
                      _selectedSticker = -1;
                    }),
                labelStyle: TextStyle(
                  color: isSelected ? color : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(String character, StateSetter setModalState) {
    final String name = PjskGenerator.characterMap[character] ?? "miku";
    final List<String> stickers = PjskGenerator.characterStickers[name] ?? [];
    if (stickers.isEmpty) {
      return Center(child: Text(S.of(context).stickerNotFound));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final String file = stickers[index];
        final int stickerIndex =
            int.tryParse(file.replaceAll(name, '').split('.')[0]) ?? -1;
        final bool isSelected = _selectedSticker == stickerIndex;
        final key = _stickerKeys.putIfAbsent(
          "${name}_$stickerIndex",
          () => GlobalKey(),
        );

        return InkWell(
          key: key,
          onTap: () {
            _update(() {
              _character = character;
              _selectedSticker = stickerIndex;
            });
            _createSticker();
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/characters/$name/$file',
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}
