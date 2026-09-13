import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class CreateOrgPage extends StatefulWidget {
  const CreateOrgPage({super.key, required this.kind});

  final OrgKind kind;

  @override
  State<CreateOrgPage> createState() => _CreateOrgPageState();
}

class _CreateOrgPageState extends State<CreateOrgPage> {
  final name = TextEditingController();
  final code = TextEditingController();
  final address = TextEditingController();
  final billing = TextEditingController();
  bool busy = false;

  bool get tenant => widget.kind == OrgKind.tenant;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    address.dispose();
    billing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final session = SessionScope.of(context);
    try {
      if (tenant) {
        await session.api.onboardTenant(
          name: name.text.trim(),
          code: code.text.trim(),
          address: address.text.trim(),
          billingEmail: billing.text.trim(),
        );
      } else {
        await session.api.onboardSchool(
          name: name.text.trim(),
          code: code.text.trim(),
          address: address.text.trim(),
        );
      }
      await session.refreshMemberships();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlDetail(
      title: tenant ? 'SPPG baru' : 'Sekolah baru',
      bottomBar: GlButton(label: 'Simpan', onPressed: busy ? null : _save, busy: busy),
      children: [
        GlSection(
          footer: tenant
              ? 'Kode SPPG harus unik. Email penagihan dipakai untuk invoice di situs web.'
              : 'Kode sekolah harus unik. Guru UKS menerima kiriman dari akun sekolah ini.',
          children: [
            GlTextRow(
              controller: name,
              placeholder: tenant ? 'Nama SPPG' : 'Nama sekolah',
            ),
            GlTextRow(
              controller: code,
              placeholder: tenant ? 'Kode SPPG' : 'Kode sekolah',
            ),
            GlTextRow(controller: address, placeholder: 'Alamat'),
            if (tenant)
              GlTextRow(
                controller: billing,
                placeholder: 'Email penagihan',
                keyboardType: TextInputType.emailAddress,
              ),
          ],
        ),
      ],
    );
  }
}
