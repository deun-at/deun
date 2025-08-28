import 'package:flutter/material.dart';

class CardListView extends StatefulWidget {
  const CardListView({super.key, required this.label, required this.onRefresh});

  final String label;
  final Function onRefresh;

  @override
  State<CardListView> createState() => _CardListViewState();
}

class _CardListViewState extends State<CardListView> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => widget.onRefresh(),
      child: ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
