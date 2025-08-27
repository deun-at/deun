import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../provider.dart';
import 'group_model.dart';
import 'group_share_widget.dart';

class GroupListItem extends ConsumerStatefulWidget {
  const GroupListItem({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _GroupListItemState();
}

class _GroupListItemState extends ConsumerState<GroupListItem> {
  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    Color colorSeedValue = Color(widget.group.colorValue);

    return Theme(
      data: themeData.copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: colorSeedValue, brightness: themeData.brightness)),
      child: Builder(
        builder: (context) {
          ThemeData themeData = Theme.of(context);
          ColorScheme colorScheme = themeData.colorScheme;

          Color cardColor = themeData.brightness == Brightness.light
              ? colorScheme.primary
              : colorScheme.primaryContainer;
          Color textColor = themeData.brightness == Brightness.light
              ? colorScheme.primaryContainer
              : colorScheme.primary;

          return Card(
            elevation: 0,
            color: cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.0),
              onTap: () {
                ref
                    .read(themeColorProvider.notifier)
                    .setColor(Color(widget.group.colorValue));
                GoRouter.of(context)
                    .push("/group/details", extra: {'group': widget.group}).then(
                  (value) async {
                    ref.read(themeColorProvider.notifier).resetColor();
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.group.name,
                            style: GoogleFonts.notoSerif(
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .headlineMedium!
                                    .copyWith(
                                        fontWeight: FontWeight.w900, color: textColor)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    GroupShareWidget(group: widget.group, textColor: textColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
