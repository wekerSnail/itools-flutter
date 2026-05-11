/// Animation duration constants
class AnimationDuration {
  // Fast animation - 100ms
  static const fast = Duration(milliseconds: 100);

  // Normal animation - 200ms
  static const normal = Duration(milliseconds: 200);

  // Slower animation - 300ms
  static const slow = Duration(milliseconds: 300);

  // Extra slow - 400ms
  static const extraSlow = Duration(milliseconds: 400);

  // Component specific
  static const button = fast;
  static const pageTransition = slow;
  static const hoverEffect = normal;
  static const stagger = Duration(
    milliseconds: 50,
  ); // delay between stagger items
}
