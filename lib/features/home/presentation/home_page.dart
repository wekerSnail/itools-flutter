import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/tools/tool_descriptor.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/system/window_manager_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.tools;
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: tools.length,
            itemBuilder: (_, i) => _ToolCard(
              tool: tools[i],
              onTap: () => WindowManagerService.instance.openToolWindow(tools[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final ToolDescriptor tool;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? shad.colorScheme.accent : shad.colorScheme.card,
            border: Border.all(
              color: _hovered ? shad.colorScheme.ring : shad.colorScheme.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: shad.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.tool.icon,
                  size: 20,
                  color: shad.colorScheme.secondaryForeground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.tool.title,
                style: shad.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.tool.description,
                style: shad.textTheme.muted.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
