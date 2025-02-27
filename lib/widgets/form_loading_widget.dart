import 'package:flutter/material.dart';

class FormLoading extends StatefulWidget {
  const FormLoading({super.key, required this.child, required this.isLoading});

  final Widget child;
  final bool isLoading;

  @override
  State<FormLoading> createState() => _FormLoadingState();
}

class _FormLoadingState extends State<FormLoading> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !widget.isLoading, // Prevent back navigation if loading
        child: Stack(children: [
          widget.child,
          if (widget.isLoading)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Prevent interactions
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ]));
  }
}
