import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The screen header: a flat title bar on the canvas, with an optional back button, trailing widget and (taller) child.
/// The name is from an earlier gradient design; [height] only applies when a [child] needs the room.
class CitrusHeader extends StatelessWidget {
  final double height;
  final String? title;
  final bool showBackButton;
  final Widget? trailing;
  final Widget? child;

  const CitrusHeader({
    super.key,
    this.height = 200,
    this.title,
    this.showBackButton = false,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.scaffoldBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 8),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textDark, fontSize: 24),
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              if (child != null) ...[
                SizedBox(height: height > 120 ? 12 : 4),
                Padding(padding: const EdgeInsets.only(left: 8), child: child!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
