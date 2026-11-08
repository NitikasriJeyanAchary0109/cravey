import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "Good evening, Nitika": by the hour, and by the first name when there is one.
String greetingFor(DateTime now, String? name) {
  final hello = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
  final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? hello : '$hello, $first';
}

/// The top of the home screen: a quiet greeting and the question the whole screen answers. [trailing] is the role switcher.
class HomeHeader extends StatelessWidget {
  final String? name;
  final Widget? trailing;
  final DateTime Function() now;

  const HomeHeader({super.key, this.name, this.trailing, this.now = DateTime.now});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.scaffoldBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greetingFor(now(), name), key: const ValueKey('home-greeting'), style: const TextStyle(fontSize: 13.5, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('What are you craving?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textDark, fontSize: 26, letterSpacing: -0.3)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
