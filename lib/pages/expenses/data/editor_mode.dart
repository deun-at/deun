/// The two top-level layouts of the expense editor.
///
/// The app distinguishes these by entry count: a single entry renders the
/// Quick view (amount entered at the expense level), while multiple entries
/// render the Itemized view (per-item cards). The [EditorMode.itemized]
/// override lets the Quick/Itemized segmented toggle force the itemized layout
/// even while only one entry exists, without inventing a parallel data model.
enum EditorMode { quick, itemized }

/// Resolves which layout to render from the current entry count and the
/// explicit toggle override. More than one entry is always itemized.
EditorMode resolveEditorMode({
  required int entryCount,
  required bool itemizedOverride,
}) {
  if (entryCount > 1 || itemizedOverride) {
    return EditorMode.itemized;
  }
  return EditorMode.quick;
}

/// Whether the editor should render the single-entry Quick layout — i.e. the
/// existing `_isSingleEntry` condition, now also gated by the toggle override.
bool isSingleEntryQuick({
  required int entryCount,
  required bool itemizedOverride,
}) =>
    resolveEditorMode(
      entryCount: entryCount,
      itemizedOverride: itemizedOverride,
    ) ==
    EditorMode.quick;
