import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Material Design window size classes.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double contentMaxWidth = 1200;
  static const double formMaxWidth = 480;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  WindowSizeClass get windowSizeClass {
    final width = screenWidth;
    if (width < AppBreakpoints.compact) return WindowSizeClass.compact;
    if (width < AppBreakpoints.medium) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  bool get isCompact => windowSizeClass == WindowSizeClass.compact;
  bool get isMedium => windowSizeClass == WindowSizeClass.medium;
  bool get isExpanded => windowSizeClass == WindowSizeClass.expanded;
  bool get useNavigationRail => !isCompact;
}

/// Centers content and caps width on tablet/desktop.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Switches between single- and multi-column layouts by breakpoint.
class ResponsiveColumns extends StatelessWidget {
  final List<Widget> children;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveColumns({
    super.key,
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 2,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final columns = switch (context.windowSizeClass) {
      WindowSizeClass.compact => compactColumns,
      WindowSizeClass.medium => mediumColumns,
      WindowSizeClass.expanded => expandedColumns,
    };

    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runSpacing),
            children[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

/// Bottom sheet on phone, centered dialog on tablet/desktop.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color barrierColor = const Color(0x99000000),
  double maxWidth = AppBreakpoints.formMaxWidth,
}) {
  if (context.useNavigationRail) {
    return showDialog<T>(
      context: context,
      barrierColor: barrierColor,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: builder(dialogContext),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// Enables mouse drag scrolling on web/desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
