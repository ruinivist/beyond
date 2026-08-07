import 'package:flutter/material.dart';

class TextBlockModel {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class TextBlock extends StatelessWidget {
  const TextBlock({required this.model, super.key});

  final TextBlockModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: model.controller,
          focusNode: model.focusNode,
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Type something',
          ),
          style: const TextStyle(fontSize: 20, height: 1.3),
        ),
      ),
    );
  }
}
