/// The horizontal inset of a top-level screen's content — and therefore of its
/// title, which aligns with the cards beneath it.
///
/// One value because three screens each hard-coded their own and drifted apart:
/// the Groups and Friends headers added 16 on top of their list's 16 and landed
/// at 32, while Settings added 4 and landed at 20 — three different left edges
/// for the same thing, none of them lined up with the cards below.
///
/// The rule that keeps them together: **the screen's scroll view owns the
/// gutter.** A header rendered inside that scroll view adds no horizontal
/// padding of its own; a header rendered outside one (the loading and empty
/// branches, which are bare `Column`s) applies this value itself.
const double kScreenGutter = 16;
