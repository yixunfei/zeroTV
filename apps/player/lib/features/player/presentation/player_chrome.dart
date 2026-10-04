import 'package:flutter/material.dart';

/// Consistent contrast for controls placed over video, in either app theme.
ThemeData playerTheme(ThemeData base) => base.copyWith(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xff70c5ff),
    onPrimary: Color(0xff082335),
    surface: Color(0xff171a20),
  ),
  textTheme: base.textTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  iconTheme: const IconThemeData(color: Colors.white70),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white30,
      minimumSize: const Size(48, 48),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xff171a20),
    surfaceTintColor: Colors.transparent,
    textStyle: const TextStyle(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

/// A lightweight translucent toolbar; avoids blurring every video frame.
class PlayerControlSurface extends StatelessWidget {
  /// Creates a toolbar that respects all device safe areas.
  const PlayerControlSurface({
    required this.child,
    this.top = false,
    super.key,
  });

  /// Toolbar contents.
  final Widget child;

  /// Whether this is the top toolbar (otherwise the bottom toolbar).
  final bool top;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: top,
    bottom: !top,
    minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Theme(
      data: playerTheme(Theme.of(context)),
      child: Material(
        color: const Color(0xff101318).withValues(alpha: .82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: child,
        ),
      ),
    ),
  );
}

/// Shows a player menu with a bounded width and consistent dark styling.
Future<T?> showPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: const Color(0xff171a20),
  barrierColor: Colors.black54,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => Theme(
    data: playerTheme(Theme.of(context)),
    child: SafeArea(top: false, child: Builder(builder: builder)),
  ),
);
