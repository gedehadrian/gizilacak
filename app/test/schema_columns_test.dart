import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kolom tiap tabel, dibaca dari berkas migrasi SQL.
Map<String, Set<String>> _schema() {
  final dir = Directory('../web/supabase/migrations');
  final tables = <String, Set<String>>{};
  final table = RegExp(
    r'create table if not exists public\.(\w+)\s*\((.*?)\n\);',
    dotAll: true,
  );
  final column = RegExp(
    r'^(\w+)\s+(uuid|text|int|bigint|numeric|boolean|timestamptz|date|jsonb)',
  );

  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    for (final match in table.allMatches(file.readAsStringSync())) {
      final cols = tables.putIfAbsent(match.group(1)!, () => <String>{});
      for (final line in match.group(2)!.split('\n')) {
        final hit = column.firstMatch(line.trim());
        if (hit != null) cols.add(hit.group(1)!);
      }
    }
  }
  return tables;
}

/// Memecah isi `.select(...)` PostgREST menjadi potongan-potongan di tingkat
/// teratas, menghormati tanda kurung bersarang seperti
/// `delivery_items(id, batch_components(name))`.
List<String> _topLevelParts(String select) {
  final parts = <String>[];
  var depth = 0;
  var buffer = StringBuffer();
  for (final rune in select.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(buffer.toString().trim());
      buffer = StringBuffer();
      continue;
    }
    buffer.write(ch);
  }
  if (buffer.isNotEmpty) parts.add(buffer.toString().trim());
  return parts.where((p) => p.isNotEmpty).toList();
}

void main() {
  // Regresi nyata: `invoices` dipilih dengan kolom `period_start`/`period_end`
  // yang sebenarnya milik `subscriptions`. Database menolak dengan
  //   column invoices.period_start does not exist (42703)
  // dan layar Langganan menampilkan galat mentah ke pengguna. Salah ketik
  // seperti ini tidak terlihat oleh analyzer karena select hanyalah teks.
  test('setiap kolom di .select() benar-benar ada di skema', () {
    final schema = _schema();
    expect(schema, isNotEmpty, reason: 'Berkas migrasi tidak terbaca');

    final source = File('lib/data/api.dart').readAsStringSync();
    final call = RegExp(r"\.from\('(\w+)'\)\s*\.select\(([^;]*?)\)\s*\n");
    final literal = RegExp(r"'([^']*)'");
    final problems = <String>[];

    void verify(String table, String select) {
      final cols = schema[table];
      if (cols == null) {
        problems.add('tabel tidak dikenal: $table');
        return;
      }
      for (final part in _topLevelParts(select)) {
        final relation = RegExp(r'^(\w+)(?:!\w+)?\((.*)\)$', dotAll: true)
            .firstMatch(part);
        if (relation != null) {
          verify(relation.group(1)!, relation.group(2)!);
          continue;
        }
        if (part == '*') continue;
        if (!cols.contains(part)) problems.add('$table.$part TIDAK ADA');
      }
    }

    for (final match in call.allMatches(source)) {
      // Dart menyambung literal yang berdampingan; gabungkan dulu.
      final select = literal
          .allMatches(match.group(2)!)
          .map((m) => m.group(1)!)
          .join();
      if (select.trim().isEmpty) continue;
      verify(match.group(1)!, select);
    }

    expect(problems.toSet().toList(), isEmpty);
  });
}
