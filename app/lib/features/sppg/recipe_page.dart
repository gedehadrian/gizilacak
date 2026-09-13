import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class RecipePage extends StatefulWidget {
  const RecipePage({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  Map<String, dynamic>? recipe;
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
      final data = await session.api.recipe(session.current!.id, widget.recipeId);
      if (mounted) {
        setState(() {
          recipe = data;
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

  List<Map<String, dynamic>> get comps {
    final rows =
        List<Map<String, dynamic>>.from((recipe?['recipe_components'] as List?) ?? const []);
    rows.sort((a, b) =>
        ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    return rows;
  }

  Future<void> _editComponent([Map<String, dynamic>? component]) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: component == null,
        builder: (_) => ComponentEditorPage(
          recipeId: widget.recipeId,
          component: component,
          position: component == null ? comps.length : null,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _rename() async {
    final name = TextEditingController(text: recipe?['name'] as String? ?? '');
    final description =
        TextEditingController(text: recipe?['description'] as String? ?? '');
    final confirmed = await showGlDialog<bool>(
      context: context,
      builder: (ctx) => GlDialog(
        title: const Text('Ubah menu'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              GlInput(controller: name, placeholder: 'Nama menu'),
              const SizedBox(height: 8),
              GlInput(controller: description, placeholder: 'Keterangan'),
            ],
          ),
        ),
        actions: [
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = SessionScope.of(context);
    try {
      await session.api.updateRecipe(
        tenantId: session.current!.id,
        id: widget.recipeId,
        name: name.text,
        description: description.text,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _toggleArchive() async {
    final session = SessionScope.of(context);
    final archived = recipe?['archived_at'] != null;
    try {
      await session.api.updateRecipe(
        tenantId: session.current!.id,
        id: widget.recipeId,
        name: recipe?['name'] as String? ?? '',
        description: recipe?['description'] as String?,
        archived: !archived,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = recipe?['archived_at'] != null;
    final totalKcal = comps.fold<double>(
      0,
      (sum, c) => sum + ((c['kcal'] as num?)?.toDouble() ?? 0),
    );
    final complete = comps.isNotEmpty && comps.every((c) => c['kcal'] != null);

    return GlDetail(
      title: recipe?['name'] as String? ?? 'Menu',
      subtitle: recipe?['description'] as String?,
      loading: loading && recipe == null,
      trailing: GlCircleButton(
        icon: LucideIcons.plus,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: () => _editComponent(),
      ),
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Energi per porsi',
          value: totalKcal == 0 ? '—' : totalKcal.toStringAsFixed(0),
          unit: totalKcal == 0 ? null : 'kkal',
          footer: complete
              ? 'Data ini ikut tersalin ke setiap batch yang memakai menu ini.'
              : 'Lengkapi gizi tiap komponen agar halaman scan siswa tidak kosong.',
          chips: [
            GlHeroChip(label: 'komponen', value: '${comps.length}'),
            if (archived) const GlHeroChip(label: 'diarsipkan'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        if (comps.isEmpty)
          GlEmpty(
            icon: LucideIcons.clipboardList,
            message: 'Menu ini belum punya komponen. Tambahkan minimal satu — '
                'misalnya "Nasi + ayam kecap".',
            actionLabel: 'Tambah komponen',
            onAction: () => _editComponent(),
          )
        else ...[
          const GlSectionHead('Komponen'),
          for (final c in comps)
            GlTile(
              leading: GlGlyph(
                icon: LucideIcons.flame,
                tint: c['kcal'] == null ? Gl.amber : Gl.mint,
                foreground: c['kcal'] == null ? Gl.amberInk : Gl.mintInk,
              ),
              title: c['name'] as String? ?? 'Komponen',
              subtitle: _summary(c),
              trailing: c['kcal'] == null
                  ? const StatusChip('Gizi kosong', tone: ChipTone.warn)
                  : null,
              chevron: true,
              onTap: () => _editComponent(c),
            ),
          const SizedBox(height: Gl.stack - Gl.gap),
        ],
        GlSection(
          footer: 'Menu yang diarsipkan tidak muncul saat membuat batch, tapi batch '
              'lama yang sudah memakainya tidak berubah.',
          children: [
            GlRow(
              leading: const GlGlyph(icon: LucideIcons.pencil),
              title: 'Ubah nama & keterangan',
              onTap: _rename,
            ),
            GlActionRow(
              label: archived ? 'Aktifkan kembali' : 'Arsipkan menu',
              tone: archived ? Gl.primary : Gl.red,
              onTap: _toggleArchive,
            ),
          ],
        ),
      ],
    );
  }

  static String _summary(Map<String, dynamic> c) {
    final parts = <String>[];
    if (c['portion_grams'] != null) parts.add('${_n(c['portion_grams'])} g');
    if (c['kcal'] != null) parts.add('${_n(c['kcal'])} kkal');
    if (c['protein_g'] != null) parts.add('P ${_n(c['protein_g'])}');
    if (c['allergen_state'] == 'known') {
      final allergens = (c['allergens'] as List?)?.length ?? 0;
      parts.add(allergens == 0 ? 'tanpa alergen' : '$allergens alergen');
    }
    return parts.isEmpty ? 'Belum ada data gizi' : parts.join(' · ');
  }

  static String _n(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(1);
  }
}

/// Form satu komponen resep: gizi, bahan, dan alergen.
class ComponentEditorPage extends StatefulWidget {
  const ComponentEditorPage({
    super.key,
    required this.recipeId,
    this.component,
    this.position,
  });

  final String recipeId;
  final Map<String, dynamic>? component;
  final int? position;

  @override
  State<ComponentEditorPage> createState() => _ComponentEditorPageState();
}

class _ComponentEditorPageState extends State<ComponentEditorPage> {
  late final name = TextEditingController(text: _text('name'));
  late final grams = TextEditingController(text: _num('portion_grams'));
  late final kcal = TextEditingController(text: _num('kcal'));
  late final protein = TextEditingController(text: _num('protein_g'));
  late final carbs = TextEditingController(text: _num('carbs_g'));
  late final fat = TextEditingController(text: _num('fat_g'));
  late final ingredients = TextEditingController(text: _list('ingredients'));
  late final allergens = TextEditingController(text: _list('allergens'));
  late final source = TextEditingController(text: _text('nutrition_source'));
  late bool allergensChecked = widget.component?['allergen_state'] == 'known';
  bool busy = false;

  String _text(String key) => widget.component?[key] as String? ?? '';

  String _num(String key) {
    final value = widget.component?[key] as num?;
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  String _list(String key) {
    final value = widget.component?[key] as List?;
    if (value == null || value.isEmpty) return '';
    return value.join(', ');
  }

  @override
  void dispose() {
    name.dispose();
    grams.dispose();
    kcal.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    ingredients.dispose();
    allergens.dispose();
    source.dispose();
    super.dispose();
  }

  List<String> _split(TextEditingController c) => c.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  num? _parse(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final session = SessionScope.of(context);
    try {
      await session.api.saveRecipeComponent(
        tenantId: session.current!.id,
        recipeId: widget.recipeId,
        id: widget.component?['id'] as String?,
        name: name.text,
        portionGrams: _parse(grams),
        kcal: _parse(kcal),
        proteinG: _parse(protein),
        carbsG: _parse(carbs),
        fatG: _parse(fat),
        ingredients: _split(ingredients),
        allergens: _split(allergens),
        allergensChecked: allergensChecked,
        nutritionSource: source.text,
        position: widget.position ??
            ((widget.component?['position'] as num?)?.toInt() ?? 0),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showGlSheet<bool>(
      context: context,
      builder: (ctx) => GlSheet(
        title: const Text('Hapus komponen'),
        message: const Text('Batch yang sudah dibuat tidak ikut berubah.'),
        actions: [
          GlSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = SessionScope.of(context);
    try {
      await session.api.deleteRecipeComponent(
        tenantId: session.current!.id,
        id: widget.component!['id'] as String,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlDetail(
      title: widget.component == null ? 'Komponen baru' : 'Ubah komponen',
      bottomBar: GlButton(
        label: 'Simpan komponen',
        onPressed: busy ? null : _save,
        busy: busy,
      ),
      children: [
        GlSection(
          children: [
            GlTextRow(controller: name, placeholder: 'Nama komponen'),
          ],
        ),
        GlSection(
          header: 'Gizi per porsi',
          footer: 'Boleh dikosongkan, tapi baris yang kosong akan muncul sebagai '
              '"belum tersedia" di halaman scan siswa.',
          children: [
            GlFormRow(
              label: 'Berat',
              controller: grams,
              keyboardType: TextInputType.number,
              placeholder: '0',
              suffix: 'g',
            ),
            GlFormRow(
              label: 'Energi',
              controller: kcal,
              keyboardType: TextInputType.number,
              placeholder: '0',
              suffix: 'kkal',
            ),
            GlFormRow(
              label: 'Protein',
              controller: protein,
              keyboardType: TextInputType.number,
              placeholder: '0',
              suffix: 'g',
            ),
            GlFormRow(
              label: 'Karbohidrat',
              controller: carbs,
              keyboardType: TextInputType.number,
              placeholder: '0',
              suffix: 'g',
            ),
            GlFormRow(
              label: 'Lemak',
              controller: fat,
              keyboardType: TextInputType.number,
              placeholder: '0',
              suffix: 'g',
            ),
          ],
        ),
        GlSection(
          header: 'Bahan & alergen',
          footer: 'Pisahkan dengan koma. Tandai sudah diperiksa hanya kalau daftar '
              'alergennya benar-benar sudah dicek — kalau tidak, halaman scan akan '
              'menulis "belum tersedia", dan itu lebih jujur.',
          children: [
            GlTextRow(
              controller: ingredients,
              placeholder: 'Bahan: beras, ayam, kecap',
            ),
            GlTextRow(
              controller: allergens,
              placeholder: 'Alergen: kedelai, telur',
            ),
            GlRow(
              title: 'Alergen sudah diperiksa',
              chevron: false,
              trailing: GlToggle(
                value: allergensChecked,
                activeTrackColor: Gl.primary,
                onChanged: (v) => setState(() => allergensChecked = v),
              ),
            ),
          ],
        ),
        GlSection(
          header: 'Sumber data gizi',
          footer: 'Misalnya "TKPI 2019" atau hasil hitung ahli gizi.',
          children: [
            GlTextRow(controller: source, placeholder: 'Sumber'),
          ],
        ),
        if (widget.component != null)
          GlSection(
            children: [
              GlActionRow(label: 'Hapus komponen', tone: Gl.red, onTap: _delete),
            ],
          ),
      ],
    );
  }
}
