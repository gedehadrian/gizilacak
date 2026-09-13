import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'recipes_page.dart';

/// Apa yang dipilih staf sebelum batch dibuat.
class NewBatchDraft {
  const NewBatchDraft({
    required this.portions,
    this.recipeId,
    this.portionsByComponent,
  });

  final int portions;
  final String? recipeId;

  /// Porsi tiap komponen menu, berkunci id `recipe_components`. Kosong berarti
  /// seluruh komponen memakai [portions].
  final Map<String, int>? portionsByComponent;
}

/// Menu mana yang dimasak, dan berapa porsi tiap komponennya. Menu itu yang
/// membawa gizi ke batch, lalu ke halaman scan siswa.
class NewBatchSheet extends StatefulWidget {
  const NewBatchSheet({super.key});

  @override
  State<NewBatchSheet> createState() => _NewBatchSheetState();
}

class _NewBatchSheetState extends State<NewBatchSheet> {
  final portions = TextEditingController(text: '100');
  final Map<String, TextEditingController> perComponent = {};
  List<Map<String, dynamic>> menus = const [];
  List<Map<String, dynamic>> components = const [];
  String? recipeId;
  bool loading = true;
  bool loadingComponents = false;

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

  @override
  void dispose() {
    portions.dispose();
    _clearComponents();
    super.dispose();
  }

  void _clearComponents() {
    for (final controller in perComponent.values) {
      controller.dispose();
    }
    perComponent.clear();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    try {
      final rows = await session.api.recipes(session.current!.id);
      if (!mounted) return;
      setState(() {
        menus = rows.where((r) => r['archived_at'] == null).toList();
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      await showGlError(context, e.message);
    }
  }

  /// Memuat komponen menu supaya porsinya bisa diatur satu per satu.
  Future<void> _loadComponents(String id) async {
    final session = SessionScope.of(context);
    setState(() => loadingComponents = true);
    try {
      final menu = await session.api.recipe(session.current!.id, id);
      final rows = List<Map<String, dynamic>>.from(
        (menu['recipe_components'] as List?) ?? const [],
      );
      rows.sort((a, b) =>
          ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
      if (!mounted) return;
      final fallback = portions.text.trim();
      setState(() {
        components = rows;
        _clearComponents();
        for (final row in rows) {
          perComponent[row['id'] as String] =
              TextEditingController(text: fallback);
        }
        loadingComponents = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loadingComponents = false);
      await showGlError(context, e.message);
    }
  }

  Map<String, dynamic>? get selected {
    for (final menu in menus) {
      if (menu['id'] == recipeId) return menu;
    }
    return null;
  }

  int get total => components.isEmpty
      ? (int.tryParse(portions.text.trim()) ?? 0)
      : perComponent.values.fold<int>(
          0,
          (sum, c) => sum + (int.tryParse(c.text.trim()) ?? 0),
        );

  Future<void> _pickMenu() async {
    final picked = await showGlSheet<String>(
      context: context,
      builder: (ctx) => GlSheet(
        title: const Text('Menu yang dimasak'),
        message: const Text(
          'Gizi dan alergen dari menu ini disalin ke batch, lalu tampil saat '
          'siswa memindai QR.',
        ),
        actions: [
          for (final menu in menus)
            GlSheetAction(
              onPressed: () => Navigator.pop(ctx, menu['id'] as String),
              child: Text(menu['name'] as String? ?? 'Menu'),
            ),
          GlSheetAction(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Tanpa menu'),
          ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    if (picked.isEmpty) {
      setState(() {
        recipeId = null;
        components = const [];
        _clearComponents();
      });
      return;
    }
    setState(() => recipeId = picked);
    await _loadComponents(picked);
  }

  Future<void> _openMenus() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const RecipesPage()),
    );
    await _load();
    final id = recipeId;
    if (id != null && mounted) await _loadComponents(id);
  }

  Future<void> _submit() async {
    if (components.isEmpty) {
      final n = int.tryParse(portions.text.trim()) ?? 0;
      if (n <= 0) {
        await showGlError(context, 'Porsi harus lebih dari 0.');
        return;
      }
      if (mounted) {
        Navigator.pop(context, NewBatchDraft(portions: n, recipeId: recipeId));
      }
      return;
    }

    final map = <String, int>{};
    for (final row in components) {
      final id = row['id'] as String;
      final n = int.tryParse(perComponent[id]?.text.trim() ?? '') ?? 0;
      if (n <= 0) {
        await showGlError(
          context,
          'Porsi ${row['name'] ?? 'komponen'} harus lebih dari 0.',
        );
        return;
      }
      map[id] = n;
    }
    if (mounted) {
      Navigator.pop(
        context,
        NewBatchDraft(
          portions: map.values.first,
          recipeId: recipeId,
          portionsByComponent: map,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = selected;

    return CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlTopBar(
              title: 'Batch baru',
              trailing: GlCircleButton(
                icon: LucideIcons.x,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: loading
                  ? const GlLoading()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Gl.gutter, 4, Gl.gutter, 28),
                      children: [
                        GlSection(
                          header: 'Yang dimasak',
                          footer: menu == null
                              ? 'Tanpa menu, batch hanya berisi "Komponen utama" dan '
                                  'halaman scan siswa menampilkan "belum tersedia" di '
                                  'semua baris gizi.'
                              : 'Gizi dan alergen dari menu ini ikut tersalin ke batch.',
                          children: [
                            GlRow(
                              leading: GlGlyph(
                                icon: LucideIcons.clipboardList,
                                tint: menu == null ? Gl.amber : Gl.lilac,
                                foreground: menu == null ? Gl.amberInk : Gl.primary,
                              ),
                              title: menu?['name'] as String? ?? 'Tanpa menu',
                              subtitle: menu == null
                                  ? 'Ketuk untuk memilih menu'
                                  : '${components.length} komponen',
                              onTap: menus.isEmpty ? null : _pickMenu,
                              chevron: menus.isNotEmpty,
                              trailing: menu == null
                                  ? const StatusChip('Gizi kosong', tone: ChipTone.warn)
                                  : null,
                            ),
                            const GlRow(
                              title: 'Tanggal produksi',
                              value: 'Hari ini',
                              chevron: false,
                            ),
                          ],
                        ),
                        if (loadingComponents)
                          const GlLoading()
                        else if (components.isEmpty)
                          GlSection(
                            header: 'Porsi',
                            footer: 'Waktu matang dicatat setelah memasak. Batas waktu '
                                'konsumsi dihitung dari waktu matang itu.',
                            children: [
                              GlFormRow(
                                label: 'Porsi',
                                controller: portions,
                                keyboardType: TextInputType.number,
                                placeholder: '0',
                                suffix: 'porsi',
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          )
                        else ...[
                          GlSection(
                            header: 'Porsi tiap komponen',
                            footer: 'Jumlahnya boleh berbeda — misalnya nasi untuk semua '
                                'siswa, sementara dua jenis lauk dibagi dua.',
                            children: [
                              for (final row in components)
                                GlFormRow(
                                  label: row['name'] as String? ?? 'Komponen',
                                  controller: perComponent[row['id'] as String]!,
                                  keyboardType: TextInputType.number,
                                  placeholder: '0',
                                  suffix: 'porsi',
                                  onChanged: (_) => setState(() {}),
                                ),
                            ],
                          ),
                          GlSection(
                            children: [
                              GlRow(
                                title: 'Total porsi diproduksi',
                                value: '$total porsi',
                                chevron: false,
                              ),
                            ],
                          ),
                        ],
                        if (menus.isEmpty)
                          GlSection(
                            footer: 'Belum ada menu sama sekali. Buat satu agar gizi '
                                'tampil di halaman scan siswa.',
                            children: [
                              GlActionRow(label: 'Kelola menu', onTap: _openMenus),
                            ],
                          ),
                        GlButton(label: 'Buat batch', onPressed: _submit),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
