import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../constants.dart';
import '../data/group_model.dart';
import 'group_member_search.dart';

class GroupEdit extends ConsumerStatefulWidget {
  const GroupEdit({super.key, this.group});

  final Group? group;

  @override
  ConsumerState<GroupEdit> createState() => _GroupEditState();
}

class _GroupEditState extends ConsumerState<GroupEdit> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _isSaving = false;

  bool get _isEdit => widget.group != null;

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    setState(() => _isSaving = true);

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    void showMessage(String message) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }

    Group? newGroup;
    try {
      String groupInsertId =
          await GroupRepository.saveAll(context, widget.group?.id, _formKey.currentState!.value);
      newGroup = await GroupRepository.fetchDetail(groupInsertId);
      showMessage(l10n.groupCreateSuccess);
    } catch (e) {
      showMessage(l10n.groupCreateError);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (context.mounted && newGroup != null) {
          GoRouter.of(context).go("/group");
          unawaited(GoRouter.of(context).push("/group/details", extra: {'group': newGroup}));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ThemeBuilder(
      colorValue: widget.group?.colorValue ?? kGroupColorPalette.first.toARGB32(),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          body: Column(
            children: [
              DeunHeader(
                title: _isEdit ? l10n.groupEditTitle : l10n.groupCreateTitle,
                leadingIcon: Icons.close,
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: FormBuilder(
                          key: _formKey,
                          clearValueOnUnregister: true,
                          initialValue: widget.group?.toJson() ?? {},
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            children: <Widget>[
                              _NameAndColorCard(formKey: _formKey),
                              const SizedBox(height: 24),
                              SectionLabel(l10n.groupMemberSectionTitle),
                              const SizedBox(height: 8),
                              FormBuilderField(
                                name: "group_members",
                                builder: (FormFieldState<dynamic> field) {
                                  return GroupMemberSearch(field: field);
                                },
                              ),
                              const SizedBox(height: 24),
                              SectionLabel(l10n.groupTrackingModeTitle),
                              const SizedBox(height: 8),
                              _TrackingModeField(group: widget.group),
                              if (_isEdit) ...[
                                const SizedBox(height: 24),
                                _buildGroupActions(context),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _StickyFooter(
                        label: _isEdit ? l10n.save : l10n.createGroup,
                        isBusy: _isSaving,
                        onPressed: _save,
                        background: colorScheme.surface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SoftCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.groupInviteTitle),
            onTap: () {
              GoRouter.of(context).push("/group/share", extra: {'group': widget.group});
            },
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            textColor: colorScheme.error,
            iconColor: colorScheme.error,
            leading: const Icon(Icons.delete),
            title: Text(l10n.groupDeleteItemTitle),
            onTap: () => _showDeleteDialog(context),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext modalContext) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.groupDeleteItemTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          PrimaryButton(
            compact: true,
            background: Theme.of(context).colorScheme.error,
            foreground: Theme.of(context).colorScheme.onError,
            label: AppLocalizations.of(context)!.delete,
            onPressed: () async {
              try {
                await GroupRepository.delete(widget.group!.id);
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.groupDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.groupDeleteError);
                }
              } finally {
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(modalContext);
                  Navigator.pop(modalContext);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Group name input plus the color swatch row, sharing a single retinted icon
/// preview. Both the preview tint and the swatch ring follow the currently
/// selected `color_value` form field.
class _NameAndColorCard extends StatelessWidget {
  const _NameAndColorCard({required this.formKey});

  final GlobalKey<FormBuilderState> formKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormBuilderField(
      name: "color_value",
      builder: (FormFieldState<dynamic> colorField) {
        final selectedIndex = selectedGroupSwatchIndex(colorField.value as int?);
        final selectedColor = kGroupColorPalette[selectedIndex];

        // v3: icon tile + name field + colour picker sit UNBOXED on the page
        // background. Only the group-name field carries its own white surface.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // v3: centered icon tile above a full-width group-name field.
            Center(
              child: Column(
                children: [
                  // Retinted group-icon preview reflecting the chosen color.
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.groups_rounded, color: selectedColor, size: 32),
                  ),
                  const SizedBox(height: 14),
                  // Only the name field sits on white (its own input surface).
                  SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    borderRadius: 16,
                    child: FormBuilderField(
                      name: "name",
                      validator: FormBuilderValidators.required(
                        errorText: l10n.groupNameValidationEmpty,
                      ),
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: l10n.groupNameHint,
                          errorText: field.errorText,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.groupColorLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < kGroupColorPalette.length; i++)
                  _ColorSwatch(
                    color: kGroupColorPalette[i],
                    selected: i == selectedIndex,
                    onTap: () => colorField.didChange(kGroupColorPalette[i].toARGB32()),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A single selectable color circle. The selected swatch gets a ring and a
/// check mark; others are plain filled circles.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: colorScheme.surfaceContainerLowest, width: 3)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

/// Simplified ↔ Detailed tracking-mode selector bound to the
/// `simplified_expenses` form field. Two selectable cards sit SIDE BY SIDE
/// (v3 prototype), each with a title + radio indicator and a short description.
///
/// The field-level [FormBuilderField.initialValue] always wins over the parent
/// [FormBuilder.initialValue] map, so the create-vs-edit default MUST be
/// resolved here: a NEW group defaults to Simplified (`true`); an EXISTING
/// group initialises from its persisted `simplifiedExpenses`.
class _TrackingModeField extends StatelessWidget {
  const _TrackingModeField({this.group});

  final Group? group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FormBuilderField<bool>(
      name: "simplified_expenses",
      initialValue: group?.simplifiedExpenses ?? true,
      builder: (FormFieldState<bool> field) {
        final simplified = field.value ?? true;
        // IntrinsicHeight so both cards match the taller one; stretch alone
        // would force unbounded height inside the ListView.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TrackingModeOption(
                  title: l10n.groupTrackingModeSimplifiedTitle,
                  subtitle: l10n.groupTrackingModeSimplifiedSubtitle,
                  selected: simplified,
                  onTap: () => field.didChange(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingModeOption(
                  title: l10n.groupTrackingModeDetailedTitle,
                  subtitle: l10n.groupTrackingModeDetailedSubtitle,
                  selected: !simplified,
                  onTap: () => field.didChange(false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackingModeOption extends StatelessWidget {
  const _TrackingModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: SoftCard(
        padding: EdgeInsets.zero,
        color: selected ? accent.withValues(alpha: 0.10) : null,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? accent : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? accent : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width primary Create/Save button pinned to the bottom of the screen.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.label,
    required this.isBusy,
    required this.onPressed,
    required this.background,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: PrimaryButton(
        onPressed: isBusy ? null : onPressed,
        label: label,
        loading: isBusy,
      ),
    );
  }
}
