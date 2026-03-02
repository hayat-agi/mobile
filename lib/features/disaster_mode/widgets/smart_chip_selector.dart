import 'package:flutter/material.dart';

/// A titled section of selectable [FilterChip]s for disaster-mode inputs.
///
/// Generic over the chip enum type [T]. The caller provides:
///   - [title]        — section heading
///   - [chips]        — all available chip values
///   - [selected]     — currently selected set
///   - [labelOf]      — display label for each chip
///   - [iconOf]       — leading icon for each chip
///   - [accentColor]  — tint colour for selected state
///   - [onToggle]     — called when user taps a chip
class SmartChipSelector<T> extends StatelessWidget {
  final String title;
  final List<T> chips;
  final Set<T> selected;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final Color accentColor;
  final ValueChanged<T> onToggle;

  const SmartChipSelector({
    super.key,
    required this.title,
    required this.chips,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) {
            final isSelected = selected.contains(chip);
            return FilterChip(
              label: Text(
                labelOf(chip),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              avatar: Icon(
                iconOf(chip),
                size: 18,
                color: isSelected ? Colors.black54 : Colors.white38,
              ),
              selected: isSelected,
              onSelected: (_) => onToggle(chip),
              selectedColor: accentColor,
              backgroundColor: Colors.grey.shade900,
              checkmarkColor: Colors.black,
              side: BorderSide(
                color:
                    isSelected ? accentColor : Colors.grey.shade700,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}
