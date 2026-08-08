import 'dart:math' as math;

import 'package:flutter/material.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: math.min(560.0, math.max(0.0, viewport.width - 32)),
        height: math.min(360.0, math.max(0.0, viewport.height - 32)),
        child: Row(
          children: [
            SizedBox(
              width: 152,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    selected: true,
                    selectedTileColor: Colors.grey.shade100,
                    leading: const Icon(Icons.info_outline, size: 20),
                    title: const Text('About'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: Colors.grey.shade200),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('plane - dev build'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
