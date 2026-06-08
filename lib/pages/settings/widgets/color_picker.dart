import 'package:flutter/material.dart';

class HorizontalColorPicker extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;

  const HorizontalColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<Color> _swatches = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.indigo, Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text("Accent Color", style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _swatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 25),
            itemBuilder: (context, index) {
              final color = _swatches[index];
              final isSelected = color.toARGB32() == selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected 
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                      : null,
                  ),
                ),
              );
            },
          ),
        ),
        
      ],
    );
  }
}