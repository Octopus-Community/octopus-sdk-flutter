import 'package:flutter/material.dart';
import '../design.dart';

/// A simple labelled-rows card used by the Home dashboard and scenario
/// live-state panels.
class KeyValueCard extends StatelessWidget {
  final String? title;
  final List<(String, String)> rows;

  const KeyValueCard({super.key, this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SampleSection(
      title: title ?? 'Live state',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            SampleKeyValue(row.$1, row.$2),
          ],
        ],
      ),
    );
  }
}
