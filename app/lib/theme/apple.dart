import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
export 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;
import 'package:intl/intl.dart';

part 'interactions.dart';

/// Design tokens and widgets for GiziLacak.
///
/// The visual language is lifted from the fintech template: a light grey page,
/// a royal-blue gradient hero holding the one number that matters, bold dark
/// section heads, and feeds built from white tiles with a tinted leading glyph
/// and a strong right-hand value.
///
/// One rule survives from the product brief and is not negotiable here: the
/// verification surfaces stay sober. Consumption-window wording goes through
/// [consumptionWindow], chips are small, and nothing about food status is ever
/// rendered as a celebration.
class Gl {
  Gl._();

  // Surfaces.
  static const bg = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFECEEF0);
  static const pressed = Color(0xFFF0F1F3);

  /// Older name kept so call sites reading "card" still make sense.
  static const card = surface;
  static const sep = line;
  static const fill = Color(0xFFF2F3F5);

  // Ink.
  static const ink = Color(0xFF23303B);
  static const secondary = Color(0xFF5A646C);
  static const tertiary = Color(0xFF9AA3AB);
  static const chevron = Color(0xFFB9C0C6);
  static const label = ink;

  // Accents.
  static const primary = Color(0xFF456EFE);
  static const heroA = Color(0xFF4F7FFC);
  static const heroB = Color(0xFF3F63F5);
  static const blue = primary;

  static const mint = Color(0xFFDCF7F0);
  static const mintInk = Color(0xFF0E9E7E);
  static const blush = Color(0xFFFFE8E8);
  static const blushInk = Color(0xFFE05252);
  static const amber = Color(0xFFFFF3DD);
  static const amberInk = Color(0xFFB87A00);
  static const lilac = Color(0xFFE9EEFF);

  static const green = mintInk;
  static const orange = amberInk;
  static const red = blushInk;

  static const font = 'Inter';

  static const rCard = 16.0;
  static const rTile = 14.0;
  static const rHero = 20.0;

  /// Page margin, and the padding inside a tile.
  static const gutter = 16.0;

  /// Gap between tiles in a feed, and below a finished block.
  static const gap = 10.0;
  static const stack = 24.0;

  /// Template cards float on a very soft shadow rather than sitting flush.
  static const List<BoxShadow> lift = [
    BoxShadow(color: Color(0x0F1B2733), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const display = TextStyle(
    fontFamily: font,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: surface,
    height: 1.1,
  );

  static const largeTitle = TextStyle(
    fontFamily: font,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.18,
  );

  static const title = largeTitle;

  /// Bold dark section head, the template's "Quick Actions" treatment.
  static const section = TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  static const headline = TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );

  static const body = TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.35,
  );

  /// Right-hand amount on a tile.
  static const amount = TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  static const value = TextStyle(
    fontFamily: font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: secondary,
  );

  static const footnote = TextStyle(
    fontFamily: font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontFamily: font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: secondary,
    height: 1.3,
  );
}

/// Keeps the app one phone wide on desktop and web.
class GlPhone extends StatelessWidget {
  const GlPhone({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: child,
      ),
    );
  }
}

/// Tap target that dims briefly while held.
class _Press extends StatefulWidget {
  const _Press({required this.builder, this.onTap});

  final Widget Function(bool down) builder;
  final VoidCallback? onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;
  bool _focused = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: enabled ? () => _set(false) : null,
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _focused ? Border.all(color: Gl.primary, width: 2) : null,
            ),
            child: AnimatedScale(
              scale: _down ? 0.985 : 1,
              duration: const Duration(milliseconds: 90),
              child: widget.builder(_down),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used in the top bar, as in the template.
class GlCircleButton extends StatelessWidget {
  const GlCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      builder: (down) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: down ? Gl.pressed : (tint ?? Gl.surface),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: foreground ?? Gl.ink),
      ),
    );
  }
}

/// Compact centred header. The template never uses a large iOS title.
class GlTopBar extends StatelessWidget {
  const GlTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Two-letter monogram shown in the leading circle on tab roots.
  final String? badge;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = onBack != null
        ? GlCircleButton(icon: LucideIcons.chevronLeft, onTap: onBack)
        : (badge == null
              ? null
              : Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Gl.lilac,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontFamily: Gl.font,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Gl.primary,
                    ),
                  ),
                ));

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gl.gutter, 6, Gl.gutter, 10),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(width: 38, child: leading),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: Gl.font,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Gl.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Gl.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 38,
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient card carrying the single number that matters on a screen.
class GlHero extends StatelessWidget {
  const GlHero({
    super.key,
    required this.caption,
    required this.value,
    this.unit,
    this.footer,
    this.chips = const [],
  });

  final String caption;
  final String value;
  final String? unit;
  final String? footer;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gl.rHero),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Gl.heroA, Gl.heroB],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33456EFE),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: const TextStyle(
              fontFamily: Gl.font,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xCCFFFFFF),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Gl.display),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontFamily: Gl.font,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(
              footer!,
              style: const TextStyle(
                fontFamily: Gl.font,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xB3FFFFFF),
                height: 1.35,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

/// Translucent pill sitting on the hero.
class GlHeroChip extends StatelessWidget {
  const GlHeroChip({super.key, required this.label, this.value});

  final String label;

  /// Optional leading number. Without it the chip is just a quiet caption.
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              value!,
              style: const TextStyle(
                fontFamily: Gl.font,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Gl.surface,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: Gl.font,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bold section head with an optional trailing text action.
class GlSectionHead extends StatelessWidget {
  const GlSectionHead(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Gl.section)),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: Gl.font,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Gl.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded tinted square holding a glyph — the template's list iconography.
class GlGlyph extends StatelessWidget {
  const GlGlyph({
    super.key,
    required this.icon,
    this.tint = Gl.lilac,
    this.foreground = Gl.primary,
    this.size = 40,
  });

  final IconData icon;
  final Color tint;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.46, color: foreground),
    );
  }
}

/// White feed row: tinted glyph, two lines of text, a value or chip on the
/// right. Tiles stack with a gap rather than sharing a hairline.
class GlTile extends StatelessWidget {
  const GlTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.chevron,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? chevron;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final showChevron = chevron ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.gap),
      child: _Press(
        onTap: onTap,
        builder: (down) => Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: down ? Gl.pressed : Gl.surface,
            borderRadius: BorderRadius.circular(Gl.rTile),
            boxShadow: Gl.lift,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Gl.headline),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: Gl.footnote),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    value!,
                    style: valueColor == null
                        ? Gl.amount
                        : Gl.amount.copyWith(color: valueColor),
                  ),
                ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: trailing!,
                ),
              if (showChevron)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: Gl.chevron,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square shortcut tile: glyph above, short label below.
class GlQuickTile extends StatelessWidget {
  const GlQuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = Gl.lilac,
    this.foreground = Gl.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      builder: (down) => Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: down ? Gl.pressed : Gl.surface,
          borderRadius: BorderRadius.circular(Gl.rTile),
          boxShadow: Gl.lift,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlGlyph(icon: icon, tint: tint, foreground: foreground, size: 38),
            const SizedBox(height: 10),
            Text(
              label,
              style: Gl.caption.copyWith(
                color: Gl.ink,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of shortcuts.
class GlQuickRow extends StatelessWidget {
  const GlQuickRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.stack),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: Gl.gap),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    );
  }
}

/// Small pastel stat card, used in pairs.
class GlStatPill extends StatelessWidget {
  const GlStatPill({
    super.key,
    required this.label,
    required this.value,
    this.tint = Gl.mint,
    this.foreground = Gl.mintInk,
  });

  final String label;
  final String value;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Gl.rTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: Gl.font,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: foreground.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: Gl.font,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner-bracket frame around the QR label, taken from the template scanner.
class GlQrFrame extends StatelessWidget {
  const GlQrFrame({super.key, required this.child, this.size = 220});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 44,
      height: size + 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final corner in _Corner.values) _Bracket(corner: corner),
          SizedBox(width: size, height: size, child: child),
        ],
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner});

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const thickness = 3.0;
    const arm = 28.0;
    const side = BorderSide(color: Gl.ink, width: thickness);
    final top = corner == _Corner.topLeft || corner == _Corner.topRight;
    final left = corner == _Corner.topLeft || corner == _Corner.bottomLeft;

    return Align(
      alignment: Alignment(left ? -1 : 1, top ? -1 : 1),
      child: Container(
        width: arm,
        height: arm,
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
          borderRadius: BorderRadius.only(
            topLeft: corner == _Corner.topLeft
                ? const Radius.circular(10)
                : Radius.zero,
            topRight: corner == _Corner.topRight
                ? const Radius.circular(10)
                : Radius.zero,
            bottomLeft: corner == _Corner.bottomLeft
                ? const Radius.circular(10)
                : Radius.zero,
            bottomRight: corner == _Corner.bottomRight
                ? const Radius.circular(10)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped rows. Kept for settings and forms, where the template also falls back
// to a plain stack of rows.
// ---------------------------------------------------------------------------

class GlHairline extends StatelessWidget {
  const GlHairline({super.key, this.indent = 52});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: SizedBox(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        child: const ColoredBox(color: Gl.line),
      ),
    );
  }
}

/// White rounded block of rows.
class GlSection extends StatelessWidget {
  const GlSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const GlHairline());
      rows.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.stack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) GlSectionHead(header!),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Gl.surface,
              borderRadius: BorderRadius.circular(Gl.rCard),
              boxShadow: Gl.lift,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Gl.rCard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: Gl.footnote),
            ),
        ],
      ),
    );
  }
}

/// Row inside a [GlSection].
class GlRow extends StatelessWidget {
  const GlRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.leading,
    this.trailing,
    this.strong = false,
    this.chevron,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final Widget? leading;
  final Widget? trailing;
  final bool strong;
  final bool? chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showChevron = chevron ?? (onTap != null);
    return _Press(
      onTap: onTap,
      builder: (down) => ColoredBox(
        color: down ? Gl.pressed : Gl.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: strong ? Gl.headline : Gl.body),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: Gl.footnote),
                      ],
                    ],
                  ),
                ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      value!,
                      style: valueColor == null
                          ? Gl.value
                          : Gl.value.copyWith(
                              color: valueColor,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: trailing!,
                  ),
                if (showChevron)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: Gl.chevron,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred action inside a section.
class GlActionRow extends StatelessWidget {
  const GlActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = Gl.primary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onTap != null;
    return _Press(
      onTap: enabled ? onTap : null,
      builder: (down) => ColoredBox(
        color: down ? Gl.pressed : Gl.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Center(
            child: busy
                ? const GlSpinner()
                : Text(
                    label,
                    style: Gl.headline.copyWith(
                      color: enabled ? tone : Gl.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Row that is a text field: label left, entry right.
class GlFormRow extends StatelessWidget {
  const GlFormRow({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.suffix,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? suffix;

  /// Dipanggil tiap ketikan, untuk layar yang menjumlahkan beberapa baris.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(label, style: Gl.body),
            Expanded(
              child: GlInput(
                controller: controller,
                placeholder: placeholder,
                keyboardType: keyboardType,
                onChanged: onChanged,
                textAlign: TextAlign.right,
                decoration: const BoxDecoration(),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                style: Gl.amount,
                placeholderStyle: Gl.body.copyWith(color: Gl.tertiary),
              ),
            ),
            if (suffix != null) Text(suffix!, style: Gl.value),
          ],
        ),
      ),
    );
  }
}

/// Full-width field row with only a placeholder.
class GlTextRow extends StatelessWidget {
  const GlTextRow({
    super.key,
    required this.controller,
    required this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<String>? autofill;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GlInput(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofill,
          decoration: const BoxDecoration(),
          prefix: prefixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(prefixIcon, size: 18, color: Gl.tertiary),
                ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          style: Gl.body,
          placeholderStyle: Gl.body.copyWith(color: Gl.tertiary),
        ),
      ),
    );
  }
}

/// Full-width primary button.
class GlButton extends StatelessWidget {
  const GlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.filled = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Gl.red : Gl.primary;
    final enabled = !busy && onPressed != null;

    if (!filled) {
      return _Press(
        onTap: enabled ? onPressed : null,
        builder: (_) => SizedBox(
          height: 46,
          child: Center(
            child: busy
                ? const GlSpinner()
                : Text(
                    label,
                    style: Gl.headline.copyWith(
                      color: enabled ? color : Gl.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      );
    }

    return _Press(
      onTap: enabled ? onPressed : null,
      builder: (down) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? (down ? Gl.heroB : color) : Gl.tertiary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: busy
            ? const GlSpinner(color: CupertinoColors.white)
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: Gl.font,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                ),
              ),
      ),
    );
  }
}

/// Plain white panel.
class GlCard extends StatelessWidget {
  const GlCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.stack),
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(Gl.gutter),
        decoration: BoxDecoration(
          color: Gl.surface,
          borderRadius: BorderRadius.circular(Gl.rCard),
          boxShadow: Gl.lift,
        ),
        child: child,
      ),
    );
  }
}

/// One sentence, at most one action.
class GlEmpty extends StatelessWidget {
  const GlEmpty({
    super.key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Column(
        children: [
          if (icon != null) ...[
            GlGlyph(icon: icon!, size: 52),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            style: Gl.body.copyWith(color: Gl.secondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GlButton(label: actionLabel!, onPressed: onAction),
            ),
        ],
      ),
    );
  }
}

class GlLoading extends StatelessWidget {
  const GlLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: GlSpinner()),
    );
  }
}

class GlNotice extends StatelessWidget {
  const GlNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.gap),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Gl.blush,
          borderRadius: BorderRadius.circular(Gl.rTile),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.circleAlert, size: 18, color: Gl.blushInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Gl.footnote.copyWith(color: Gl.blushInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlFootnote extends StatelessWidget {
  const GlFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, Gl.stack),
      child: Text(text, style: Gl.footnote),
    );
  }
}

/// A row whose whole content is one chip, so the long consumption-window
/// wording is never truncated.
class GlChipRow extends StatelessWidget {
  const GlChipRow({super.key, required this.chip, this.caption});

  final Widget chip;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: chip),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(caption!, style: Gl.footnote),
            ],
          ],
        ),
      ),
    );
  }
}

/// Root-of-a-tab screen: compact top bar, then a scrolling body.
class GlSliver extends StatelessWidget {
  const GlSliver({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final List<Widget> children;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          GlTopBar(
            title: title,
            subtitle: subtitle,
            badge: badge,
            trailing: trailing,
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (onRefresh != null)
                  CupertinoSliverRefreshControl(
                    onRefresh: onRefresh,
                    builder: (context, mode, pulled, trigger, extent) =>
                        mode == RefreshIndicatorMode.inactive
                        ? const SizedBox.shrink()
                        : const Center(child: GlSpinner()),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    Gl.gutter,
                    4,
                    Gl.gutter,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(children),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushed screen: circular back button, centred title.
class GlDetail extends StatelessWidget {
  const GlDetail({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.loading = false,
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final bool loading;

  /// Sticky primary action, as the template does on its transfer flow.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            // Saat berpindah halaman, Flutter web sempat mengukur halaman ini
            // pada tinggi mendekati nol. Bar atas tingginya tetap, jadi Column
            // meluap dan galat tercatat untuk sesuatu yang tak pernah terlihat.
            // Lebih baik tidak menggambar apa pun pada ukuran sekecil itu.
            if (box.maxHeight.isFinite && box.maxHeight < 120) {
              return const SizedBox.shrink();
            }
            return _body(context);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      children: [
        GlTopBar(
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onBack: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: loading
              ? const GlLoading()
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    Gl.gutter,
                    4,
                    Gl.gutter,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: children,
                ),
        ),
        if (bottomBar != null)
          Container(
            padding: EdgeInsets.fromLTRB(
              Gl.gutter,
              12,
              Gl.gutter,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Gl.surface,
              border: Border(top: BorderSide(color: Gl.line)),
            ),
            child: bottomBar,
          ),
      ],
    );
  }
}

/// Small state pill. Quiet by design — status is reported, never celebrated.
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.tone = ChipTone.neutral});

  final String text;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (tone) {
      case ChipTone.good:
        fg = Gl.mintInk;
        bg = Gl.mint;
      case ChipTone.warn:
        fg = Gl.amberInk;
        bg = Gl.amber;
      case ChipTone.bad:
        fg = Gl.blushInk;
        bg = Gl.blush;
      case ChipTone.neutral:
        fg = Gl.secondary;
        bg = Gl.fill;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: Gl.font,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

enum ChipTone { good, warn, bad, neutral }

ChipTone toneForStatus(String status) {
  switch (status) {
    case 'ready':
    case 'dispatched':
    case 'completed':
    case 'active':
    case 'paid':
      return ChipTone.good;
    case 'draft':
    case 'pending':
    case 'open':
      return ChipTone.warn;
    case 'canceled':
    case 'expired':
    case 'failed':
      return ChipTone.bad;
    default:
      return ChipTone.neutral;
  }
}

/// Nama paket untuk layar demo — jangan tampilkan kode/lingkungan uji.
String displayPlanName(String? name, String? code) {
  final raw = '${name ?? ''} ${code ?? ''}'.toLowerCase();
  if (raw.contains('sandbox') ||
      raw.contains('contoh') ||
      raw.contains('lingkungan uji')) {
    return 'GiziLacak Standar';
  }
  final n = name?.trim() ?? '';
  return n.isEmpty ? 'Paket' : n;
}

String? displayPlanDescription(String? description) {
  final raw = (description ?? '').toLowerCase();
  if (raw.contains('sandbox') ||
      raw.contains('lingkungan uji') ||
      raw.contains('bukan keputusan')) {
    return 'Langganan bulanan untuk produksi, kiriman sekolah, dan verifikasi penerimaan.';
  }
  final d = description?.trim() ?? '';
  return d.isEmpty ? null : d;
}

String statusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'Draf';
    case 'ready':
      return 'Siap kirim';
    case 'dispatched':
      return 'Dalam perjalanan';
    case 'completed':
      return 'Selesai diterima';
    case 'pending':
      return 'Menunggu konfirmasi';
    case 'active':
      return 'Aktif';
    case 'canceled':
      return 'Dibatalkan';
    default:
      return status;
  }
}

/// Glyph used for a delivery or batch status in feeds.
IconData iconForStatus(String status) {
  switch (status) {
    case 'draft':
      return LucideIcons.squarePen;
    case 'ready':
      return LucideIcons.circleCheck;
    case 'dispatched':
      return LucideIcons.send;
    case 'completed':
      return LucideIcons.inbox;
    case 'canceled':
      return LucideIcons.circleX;
    default:
      return LucideIcons.circle;
  }
}

({Color tint, Color ink}) tintForTone(ChipTone tone) {
  switch (tone) {
    case ChipTone.good:
      return (tint: Gl.mint, ink: Gl.mintInk);
    case ChipTone.warn:
      return (tint: Gl.amber, ink: Gl.amberInk);
    case ChipTone.bad:
      return (tint: Gl.blush, ink: Gl.blushInk);
    case ChipTone.neutral:
      return (tint: Gl.lilac, ink: Gl.primary);
  }
}

/// How the consumption window reads in the UI. Never "aman" — the app reports
/// the window, not a verdict on the food.
({String text, ChipTone tone}) consumptionWindow(
  DateTime? consumeBy, {
  int warningMinutes = 60,
  DateTime? now,
}) {
  if (consumeBy == null) {
    return (text: 'Data belum dapat diverifikasi', tone: ChipTone.neutral);
  }
  final left = consumeBy.difference(now ?? DateTime.now());
  if (left.isNegative) {
    return (text: 'Melewati batas waktu konsumsi', tone: ChipTone.bad);
  }
  if (left.inMinutes <= warningMinutes) {
    return (text: 'Mendekati batas waktu', tone: ChipTone.warn);
  }
  return (text: 'Masih dalam batas waktu konsumsi', tone: ChipTone.good);
}

Future<void> showGlError(BuildContext context, String message) {
  return showGlDialog<void>(
    context: context,
    builder: (ctx) => GlDialog(
      title: const Text('Tidak bisa dilanjutkan'),
      content: Text(message),
      actions: [
        GlDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Dates.
// ---------------------------------------------------------------------------

String dayLabel(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  final distance = today.difference(day).inDays;
  if (distance == 0) return 'Hari ini';
  if (distance == 1) return 'Kemarin';
  if (day.year == today.year) {
    return DateFormat('EEEE, d MMMM', 'id').format(day);
  }
  return DateFormat('d MMMM yyyy', 'id').format(day);
}

String dateLabel(DateTime when) => DateFormat('d MMMM yyyy', 'id').format(when);

String timeLabel(DateTime when) => DateFormat('HH.mm', 'id').format(when);

String dateTimeLabel(DateTime when) =>
    DateFormat('d MMM, HH.mm', 'id').format(when);

DateTime? parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// Two-letter monogram for the leading circle in the top bar.
String monogram(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '··';
  if (words.length == 1) {
    final word = words.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// Splits rows into day buckets, keeping the order the API returned.
List<({String label, List<Map<String, dynamic>> rows})> groupByDay(
  List<Map<String, dynamic>> rows,
  String field, {
  bool toLocal = false,
}) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  final order = <String>[];
  for (final row in rows) {
    var when = parseDate(row[field]);
    if (when != null && toLocal) when = when.toLocal();
    final key = when == null ? 'Tanpa tanggal' : dayLabel(when);
    final bucket = buckets.putIfAbsent(key, () {
      order.add(key);
      return <Map<String, dynamic>>[];
    });
    bucket.add(row);
  }
  return [for (final key in order) (label: key, rows: buckets[key]!)];
}
