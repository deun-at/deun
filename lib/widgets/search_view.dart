import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  final ValueNotifier<String> searchQueryNotifier;
  final Iterable<Widget> suggestions;

  const SearchView({
    required this.searchQueryNotifier,
    required this.suggestions,
    super.key,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Keep the controller and notifier in sync
    _controller.addListener(() {
      widget.searchQueryNotifier.value = _controller.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: widget.searchQueryNotifier,
        builder: (context, query, child) {
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(children: widget.suggestions.toList()),
          );
        });
  }
}
