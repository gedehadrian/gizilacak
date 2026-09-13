import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pasangan tabel yang punya foreign key di antaranya, arah mana pun.
/// PostgREST hanya bisa menyematkan relasi lewat FK; tanpa itu ia menolak
/// dengan PGRST200 saat aplikasi berjalan.
Set<String> _relations() => _read().$2;

/// Kolom tiap tabel, dibaca dari berkas migrasi SQL.
Map<String, Set<String>> _schema() => _read().$1;

(Map<String, Set<String>>, Set<String>) _read() {
  final dir = Directory('../web/supabase/migrations');
  final tables = <String, Set<String>>{};
  final edges = <String>{};
  final reference = RegExp(r'references\s+public\.(\w+)');
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
      for (final fk in reference.allMatches(match.group(2)!)) {
        final pair = [match.group(1)!, fk.group(1)!]..sort();
        edges.add(pair.join('~'));
      }
    }
  }
  return (tables, edges);
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

/// Mengambil isi `.select(...)` beserta tabel asalnya. Kurung dihitung
/// berpasangan dan kurung di dalam literal string diabaikan, sehingga
/// bentuk `var q = sb.from('x').select('a, b(c)');` ikut terbaca — versi
/// regex sebelumnya melewatkannya diam-diam.
List<(String, String)> _selects(String source) {
  final found = <(String, String)>[];
  final head = RegExp(r"\.from\('(\w+)'\)\s*\.select\(");
  for (final m in head.allMatches(source)) {
    var depth = 1;
    var inString = false;
    final buffer = StringBuffer();
    for (var i = m.end; i < source.length && depth > 0; i++) {
      final ch = source[i];
      if (ch == "'") {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (ch == '(') depth++;
        if (ch == ')') depth--;
        continue;
      }
      buffer.write(ch);
    }
    final select = buffer.toString().trim();
    if (select.isNotEmpty) found.add((m.group(1)!, select));
  }
  return found;
}

void main() {
  // Regresi nyata: `invoices` dipilih dengan kolom `period_start`/`period_end`
  // yang sebenarnya milik `subscriptions`. Database menolak dengan
  //   column invoices.period_start does not exist (42703)
  // dan layar Langganan menampilkan galat mentah ke pengguna. Salah ketik
  // seperti ini tidak terlihat oleh analyzer karena select hanyalah teks.
  test('setiap kolom di .select() benar-benar ada di skema', () {
    final schema = _schema();
    final relations = _relations();
    expect(schema, isNotEmpty, reason: 'Berkas migrasi tidak terbaca');

    final source = File('lib/data/api.dart').readAsStringSync();
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
          final child = relation.group(1)!;
          final pair = [table, child]..sort();
          if (!relations.contains(pair.join('~'))) {
            problems.add(
              '$table tidak punya foreign key ke $child, '
              'jadi penyematan $child(...) akan ditolak PGRST200',
            );
          }
          verify(child, relation.group(2)!);
          continue;
        }
        if (part == '*') continue;
        if (!cols.contains(part)) problems.add('$table.$part TIDAK ADA');
      }
    }

    for (final (table, select) in _selects(source)) {
      verify(table, select);
    }

    expect(problems.toSet().toList(), isEmpty);
  });
}
