import 'package:flutter/material.dart';

class EmptyListWidget extends StatefulWidget {
  const EmptyListWidget({super.key, required this.label, required this.onRefresh});

  final String label;
  final Function onRefresh;

  @override
  State<EmptyListWidget> createState() => _EmptyListWidgetState();
}

class _EmptyListWidgetState extends State<EmptyListWidget> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        onRefresh: () => widget.onRefresh(),
        child: ListView(
            // physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(
                  child: Text(
                widget.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ))
            ]));
  }
}
