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
    ColorScheme colorScheme = themeData.colorScheme;

    Color textColor = themeData.brightness == Brightness.light
        ? colorScheme.primaryContainer
        : colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: () {
        GoRouter.of(context).push("/group/details", extra: {'group': widget.group});
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
                    style: GoogleFonts.robotoSerif(
                        textStyle: Theme.of(context)
                            .textTheme
                            .headlineSmall!
                            .copyWith(fontWeight: FontWeight.w900, color: textColor)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            GroupShareWidget(group: widget.group, textColor: textColor),
          ],
        ),
      ),
    );
  }
}
