import 'package:flutter/cupertino.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class PlanForm extends StatefulWidget {
  const PlanForm({super.key, this.plan});
  final Map<String, dynamic>? plan;
  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  final fields = List.generate(4, (_) => TextEditingController());
  bool active = true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = SessionScope.of(context).api;
      if (widget.plan == null) {
        await api.createPlan(
          code: fields[0].text,
          name: fields[1].text,
          description: fields[2].text,
          active: active,
        );
      } else {
        final values = fields.map((f) => int.tryParse(f.text.trim())).toList();
        if (values.any((v) => v == null)) {
          throw const FormatException(
            'Isi semua angka dengan bilangan bulat tanpa pemisah ribuan.',
          );
        }
        await api.createPlanVersion(
          planId: widget.plan!['id'] as String,
          priceRp: values[0]!,
          staffLimit: values[1]!,
          schoolLimit: values[2]!,
          deliveryLimit: values[3]!,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.plan != null;
    final labels = version
        ? ['Harga rupiah', 'Batas staf', 'Batas sekolah', 'Batas kiriman']
        : ['Kode paket', 'Nama paket', 'Deskripsi'];
    return GlDetail(
      title: version ? 'Versi baru' : 'Buat paket',
      subtitle: version ? '${widget.plan!['name']} · 1 bulan' : null,
      children: [
        if (error != null) GlNotice(error!),
        GlSection(
          children: [
            for (var i = 0; i < labels.length; i++)
              GlTextRow(
                controller: fields[i],
                placeholder: labels[i],
                keyboardType: version
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            if (!version)
              GlRow(
                title: 'Paket aktif',
                chevron: false,
                trailing: GlToggle(
                  value: active,
                  onChanged: busy ? null : (v) => setState(() => active = v),
                ),
              ),
          ],
        ),
        if (version)
          const GlFootnote(
            'Versi disimpan sebagai draf. Periksa harga dan batas sebelum menerbitkan dari daftar paket.',
          ),
        GlButton(
          label: version ? 'Simpan draf versi' : 'Simpan paket',
          busy: busy,
          onPressed: save,
        ),
      ],
    );
  }
}
