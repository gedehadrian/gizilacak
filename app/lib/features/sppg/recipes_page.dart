import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'recipe_page.dart';

/// Daftar menu. Menu inilah yang membawa data gizi ke batch, lalu ke halaman
/// scan siswa — tanpa menu, semua baris gizi di sana kosong.
class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  List<Map<String, dynamic>> items = const [];
  bool loading = true;
  String? error;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope dibaca di dalam _load(), dan InheritedWidget
    // baru boleh dibaca setelah initState selesai.
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await session.api.recipes(session.current!.id);
      if (mounted) {
        setState(() {
          items = data;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => RecipePage(recipeId: id)),
    );
    await _load();
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Menu baru'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: name,
            placeholder: 'Nama menu',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = SessionScope.of(context);
    try {
      final id = await session.api.createRecipe(
        tenantId: session.current!.id,
        userId: session.user!.id,
        name: name.text,
      );
      if (!mounted) return;
      await _open(id);
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = items.where((r) => r['archived_at'] == null).toList();
    final archived = items.where((r) => r['archived_at'] != null).toList();

    return GlDetail(
      title: 'Menu',
      trailing: GlCircleButton(
        icon: CupertinoIcons.add,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _create,
      ),
      loading: loading && items.isEmpty,
      children: [
        if (error != null) GlNotice(error!),
        if (items.isEmpty && !loading)
          GlEmpty(
            icon: CupertinoIcons.square_list,
            message: 'Belum ada menu. Menu menyimpan gizi dan alergen, lalu ikut '
                'tersalin ke setiap batch yang memakainya.',
            actionLabel: 'Buat menu pertama',
            onAction: _create,
          )
        else ...[
          for (final recipe in active) _RecipeTile(recipe: recipe, onTap: _open),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: Gl.stack - Gl.gap),
            const GlSectionHead('Diarsipkan'),
            for (final recipe in archived) _RecipeTile(recipe: recipe, onTap: _open),
          ],
        ],
      ],
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.onTap});

  final Map<String, dynamic> recipe;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final count = (recipe['recipe_components'] as List?)?.length ?? 0;
    final archived = recipe['archived_at'] != null;

    return GlTile(
      leading: GlGlyph(
        icon: CupertinoIcons.square_list,
        tint: archived ? Gl.fill : Gl.lilac,
        foreground: archived ? Gl.tertiary : Gl.primary,
      ),
      title: recipe['name'] as String? ?? 'Menu',
      subtitle: count == 0
          ? 'Belum ada komponen'
          : '$count komponen',
      trailing: count == 0
          ? const StatusChip('Gizi kosong', tone: ChipTone.warn)
          : null,
      chevron: true,
      onTap: () => onTap(recipe['id'] as String),
    );
  }
}
