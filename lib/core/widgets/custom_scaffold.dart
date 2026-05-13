import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final bgColor = backgroundColor ?? shad.colorScheme.background;

    return ColoredBox(
      color: bgColor,
      child: Column(
        children: [
          if (appBar != null) appBar!,
          Expanded(child: body),
        ],
      ),
    );
  }
}
