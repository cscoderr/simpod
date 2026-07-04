/// Screen-edge a touch begins from, for edge-swipe gestures (e.g. swipe up from
/// the bottom for Home). [value] is the integer sent in the `hid_input`
/// WebSocket payload and maps to the helper's `HIDInput.TouchEdge`.
enum SimpodTouchEdge {
  none(0),
  left(1),
  top(2),
  bottom(3),
  right(4);

  const SimpodTouchEdge(this.value);

  final int value;
}
