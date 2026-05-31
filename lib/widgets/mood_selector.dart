import 'package:flutter/material.dart';

/// 心情 Emoji 映射表
const moodEmojiMap = <String, String>{
  '😊': '开心',
  '🥰': '怀念',
  '😌': '平静',
  '😢': '难过',
  '🎉': '兴奋',
  '💪': '励志',
  '😤': '烦躁',
  '😴': '疲惫',
  '☕': '日常',
};

/// 根据文字标签查找对应的 emoji，找不到返回空
String? emojiFor(String? label) {
  if (label == null) return null;
  final entry = moodEmojiMap.entries.where((e) => e.value == label).firstOrNull;
  return entry?.key;
}

/// 组合 emoji + 文字，如 "😊 开心"
String? composeMood(String? label) {
  if (label == null) return null;
  final emoji = emojiFor(label);
  return emoji != null ? '$emoji $label' : label;
}

/// 心情选择器组件（显示当前心情 + emoji，点击触发覆盖面板）
class MoodSelector extends StatelessWidget {
  final String? selectedMood;
  final ColorScheme colorScheme;
  final void Function(RenderBox box) onTap;
  final VoidCallback onClear;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.colorScheme,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final displayText = composeMood(selectedMood);
    return GestureDetector(
      onTap: () {
        final RenderBox box = context.findRenderObject() as RenderBox;
        onTap(box);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.mood_outlined, size: 18, color: cs.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              displayText ?? '添加心情…',
              style: TextStyle(fontSize: 14,
                  color: displayText != null ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            const Spacer(),
            if (displayText != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
