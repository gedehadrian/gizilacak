part of 'apple.dart';

Future<T?> showGlDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool useRootNavigator = true,
}) => _showGlModal<T>(
  context: context,
  builder: builder,
  sheet: false,
  barrierDismissible: barrierDismissible,
  useRootNavigator: useRootNavigator,
);

Future<T?> showGlSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) => _showGlModal<T>(
  context: context,
  builder: builder,
  sheet: true,
  barrierDismissible: barrierDismissible,
  useRootNavigator: useRootNavigator,
);

Future<T?> _showGlModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool sheet,
  required bool barrierDismissible,
  required bool useRootNavigator,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Tutup',
    barrierColor: Gl.ink.withValues(alpha: .38),
    transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 200),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) => Align(
            alignment: sheet ? Alignment.bottomCenter : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 430,
                maxHeight: constraints.maxHeight,
              ),
              child: DefaultTextStyle(style: Gl.body, child: builder(ctx)),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: Offset(0, sheet ? .07 : .025), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    ),
  );
}

class GlDialog extends StatelessWidget {
  const GlDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    var primary = actions.lastIndexWhere(
      (a) => a is GlDialogAction && a.isDefaultAction,
    );
    if (primary < 0) primary = actions.length - 1;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Gl.surface,
          borderRadius: BorderRadius.circular(Gl.rCard),
          boxShadow: Gl.lift,
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Semantics(
                  namesRoute: true,
                  header: true,
                  child: DefaultTextStyle(
                    style: Gl.largeTitle.copyWith(fontSize: 22),
                    child: title!,
                  ),
                ),
              if (content != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  child: DefaultTextStyle(
                    style: Gl.body.copyWith(color: Gl.secondary),
                    child: content!,
                  ),
                ),
              if (content == null) const SizedBox(height: 20),
              if (primary >= 0) _action(actions[primary], true),
              for (var i = 0; i < actions.length; i++)
                if (i != primary)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _action(actions[i], false),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(Widget action, bool primary) =>
      action is GlDialogAction ? action.button(primary) : action;
}

class GlDialogAction extends StatelessWidget {
  const GlDialogAction({
    super.key,
    required this.child,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  Widget button(bool primary) => _GlActionButton(
    onPressed: onPressed,
    filled: primary,
    destructive: isDestructiveAction,
    child: child,
  );
  @override
  Widget build(BuildContext context) => button(isDefaultAction);
}

class _GlActionButton extends StatelessWidget {
  const _GlActionButton({
    required this.child,
    this.onPressed,
    this.filled = false,
    this.destructive = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool filled;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? Gl.red : Gl.primary;
    return _Press(
      onTap: onPressed,
      builder: (down) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: filled
              ? (onPressed == null ? Gl.tertiary : color)
              : (down ? Gl.fill : Gl.surface),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle(
          style: Gl.headline.copyWith(color: filled ? Gl.surface : color),
          textAlign: TextAlign.center,
          child: child,
        ),
      ),
    );
  }
}

class GlSheet extends StatelessWidget {
  const GlSheet({
    super.key,
    this.title,
    this.message,
    this.actions,
    this.cancelButton,
  });
  final Widget? title;
  final Widget? message;
  final List<Widget>? actions;
  final Widget? cancelButton;
  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Gl.surface,
        borderRadius: BorderRadius.circular(Gl.rCard),
        boxShadow: Gl.lift,
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Gl.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (title != null)
              Semantics(
                header: true,
                namesRoute: true,
                child: DefaultTextStyle(
                  style: Gl.largeTitle.copyWith(fontSize: 22),
                  child: title!,
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DefaultTextStyle(
                  style: Gl.body.copyWith(color: Gl.secondary),
                  child: message!,
                ),
              ),
            const SizedBox(height: 20),
            for (final action in actions ?? <Widget>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: action is GlSheetAction && actions!.length == 1
                    ? _GlActionButton(
                        onPressed: action.onPressed,
                        filled: true,
                        destructive: action.isDestructiveAction,
                        child: action.child,
                      )
                    : action,
              ),
            if (cancelButton != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: cancelButton is GlSheetAction
                    ? _GlActionButton(
                        onPressed: (cancelButton! as GlSheetAction).onPressed,
                        child: (cancelButton! as GlSheetAction).child,
                      )
                    : cancelButton!,
              ),
          ],
        ),
      ),
    ),
  );
}

class GlSheetAction extends StatelessWidget {
  const GlSheetAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  @override
  Widget build(BuildContext context) => _Press(
    onTap: onPressed,
    builder: (down) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: down || isDefaultAction ? Gl.lilac : Gl.fill,
        borderRadius: BorderRadius.circular(Gl.rTile),
      ),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: Gl.headline.copyWith(
                color: isDestructiveAction ? Gl.red : Gl.ink,
              ),
              child: child,
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.chevronRight, color: Gl.tertiary, size: 18),
        ],
      ),
    ),
  );
}

class GlSpinner extends StatefulWidget {
  const GlSpinner({super.key, this.color = Gl.primary, this.radius = 10});
  final Color color;
  final double radius;
  @override
  State<GlSpinner> createState() => _GlSpinnerState();
}

class _GlSpinnerState extends State<GlSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat',
    liveRegion: true,
    child: SizedBox.square(
      dimension: widget.radius * 2,
      child: RotationTransition(
        turns: _animation,
        child: CustomPaint(painter: _GlSpinnerPainter(widget.color)),
      ),
    ),
  );
}

class _GlSpinnerPainter extends CustomPainter {
  _GlSpinnerPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(2);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(bounds, pen..color = color.withValues(alpha: .16));
    canvas.drawArc(bounds, -.8, 4.2, false, pen..color = color);
  }

  @override
  bool shouldRepaint(_GlSpinnerPainter oldDelegate) =>
      color != oldDelegate.color;
}

class GlInput extends StatelessWidget {
  const GlInput({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.onChanged,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
    this.autofillHints,
    this.prefix,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    this.style,
    this.placeholderStyle,
    this.decoration,
    this.autofocus = false,
    this.maxLines = 1,
  });
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final Widget? prefix;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final BoxDecoration? decoration;
  final bool autofocus;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    delegates: const [m.DefaultMaterialLocalizations.delegate],
    child: m.Theme(
      data: m.ThemeData(
        useMaterial3: true,
        fontFamily: Gl.font,
        platform: TargetPlatform.android,
        colorScheme: const m.ColorScheme.light(
          primary: Gl.primary,
          surface: Gl.surface,
        ),
        textSelectionTheme: m.TextSelectionThemeData(
          cursorColor: Gl.primary,
          selectionColor: Gl.primary.withValues(alpha: .2),
          selectionHandleColor: Gl.primary,
        ),
      ),
      child: m.Material(
        color: Gl.surface,
        child: m.TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          textAlign: textAlign,
          obscureText: obscureText,
          autofillHints: autofillHints,
          autofocus: autofocus,
          maxLines: maxLines,
          style: style ?? Gl.body,
          cursorColor: Gl.primary,
          decoration: m.InputDecoration(
            hintText: placeholder,
            hintStyle: placeholderStyle ?? Gl.body.copyWith(color: Gl.tertiary),
            filled: true,
            fillColor: Gl.fill,
            contentPadding: padding,
            prefixIcon: prefix,
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            enabledBorder: m.OutlineInputBorder(
              borderRadius: BorderRadius.circular(Gl.rTile),
              borderSide: const BorderSide(color: Gl.line),
            ),
            focusedBorder: m.OutlineInputBorder(
              borderRadius: BorderRadius.circular(Gl.rTile),
              borderSide: const BorderSide(color: Gl.primary, width: 1.5),
            ),
          ),
        ),
      ),
    ),
  );
}

class GlSegments<T extends Object> extends StatelessWidget {
  const GlSegments({
    super.key,
    required this.children,
    required this.onValueChanged,
    this.groupValue,
  });
  final Map<T, Widget> children;
  final ValueChanged<T?>? onValueChanged;
  final T? groupValue;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Gl.fill,
      borderRadius: BorderRadius.circular(14),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in children.entries)
            Semantics(
              selected: groupValue == entry.key,
              child: _Press(
                onTap: onValueChanged == null
                    ? null
                    : () => onValueChanged!(entry.key),
                builder: (_) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: groupValue == entry.key ? Gl.surface : Gl.fill,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: groupValue == entry.key ? Gl.lift : null,
                  ),
                  child: DefaultTextStyle(
                    style: Gl.headline.copyWith(
                      color: groupValue == entry.key
                          ? Gl.primary
                          : Gl.secondary,
                    ),
                    child: entry.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Keeps CupertinoTabScaffold's controller and preserved tabs; only paints a new bar.
class GlTabBar extends CupertinoTabBar {
  const GlTabBar({
    super.key,
    required super.items,
    super.onTap,
    super.currentIndex,
    super.backgroundColor = Gl.bg,
    super.activeColor = Gl.primary,
    super.inactiveColor = Gl.tertiary,
    super.iconSize = 22,
    super.height = 84,
    super.border = null,
  });
  @override
  bool opaque(BuildContext context) => true;
  @override
  GlTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) => GlTabBar(
    key: key ?? this.key,
    items: items ?? this.items,
    onTap: onTap ?? this.onTap,
    currentIndex: currentIndex ?? this.currentIndex,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    activeColor: activeColor ?? this.activeColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    iconSize: iconSize ?? this.iconSize,
    height: height ?? this.height,
    border: border ?? this.border,
  );
  @override
  Widget build(BuildContext context) => Container(
    color: Gl.bg,
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      10 + MediaQuery.viewPaddingOf(context).bottom,
    ),
    child: Container(
      height: height - 18,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Gl.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Gl.lift,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == currentIndex,
                label: items[i].label,
                child: _Press(
                  onTap: () => onTap?.call(i),
                  builder: (_) => AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: i == currentIndex ? Gl.lilac : Gl.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconTheme(
                          data: IconThemeData(
                            size: iconSize,
                            color: i == currentIndex ? Gl.primary : Gl.tertiary,
                          ),
                          child: items[i].icon,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Gl.caption.copyWith(
                            fontSize: 10,
                            fontWeight: i == currentIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == currentIndex
                                ? Gl.primary
                                : Gl.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class GlToggle extends StatelessWidget {
  const GlToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor = Gl.primary,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeTrackColor;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: _Press(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      builder: (_) => SizedBox(
        height: 48,
        width: 52,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 46,
            height: 28,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: onChanged == null
                  ? Gl.line
                  : value
                  ? activeTrackColor
                  : Gl.tertiary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Gl.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GlChoicePicker extends StatefulWidget {
  const GlChoicePicker({
    super.key,
    required this.children,
    required this.onSelectedItemChanged,
    required this.itemExtent,
    this.scrollController,
  });
  final List<Widget> children;
  final ValueChanged<int> onSelectedItemChanged;
  final double itemExtent;
  final FixedExtentScrollController? scrollController;
  @override
  State<GlChoicePicker> createState() => _GlChoicePickerState();
}

class _GlChoicePickerState extends State<GlChoicePicker> {
  late int selected = widget.scrollController?.initialItem ?? 0;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          IntrinsicWidth(
            child: Semantics(
              selected: selected == i,
              child: _Press(
                onTap: () {
                  setState(() => selected = i);
                  widget.onSelectedItemChanged(i);
                },
                builder: (_) => Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == i ? Gl.lilac : Gl.fill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
