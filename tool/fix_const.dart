// Outil ponctuel : retire le `const` le plus proche au-dessus de chaque
// erreur "invalid_constant" remontée par flutter analyze (stdin).
// Usage: flutter analyze 2>&1 | dart tool/fix_const.dart
import 'dart:convert';
import 'dart:io';

void main() async {
  final re = RegExp(
      r'error - Invalid constant value - (.+\.dart):(\d+):(\d+) - invalid_constant');
  // file -> list of (line, col)
  final errors = <String, List<(int, int)>>{};
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final m = re.firstMatch(line);
    if (m == null) continue;
    final file = m.group(1)!.replaceAll('\\', '/');
    errors.putIfAbsent(file, () => []).add(
        (int.parse(m.group(2)!), int.parse(m.group(3)!)));
  }

  var fixed = 0;
  for (final entry in errors.entries) {
    final f = File(entry.key);
    if (!f.existsSync()) {
      stderr.writeln('skip (not found): ${entry.key}');
      continue;
    }
    final lines = f.readAsLinesSync();
    // Traite de bas en haut pour ne pas invalider les positions
    final errs = entry.value..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (lineNo, col) in errs) {
      final idx = lineNo - 1;
      if (idx < 0 || idx >= lines.length) continue;
      // 1) const avant la colonne sur la même ligne
      final prefix = lines[idx].substring(
          0, col - 1 <= lines[idx].length ? col - 1 : lines[idx].length);
      final constRe = RegExp(r'\bconst ');
      final inLine = constRe.allMatches(prefix).toList();
      if (inLine.isNotEmpty) {
        final last = inLine.last;
        lines[idx] = lines[idx].substring(0, last.start) +
            lines[idx].substring(last.start + 6);
        fixed++;
        continue;
      }
      // 2) sinon, remonte jusqu'à 6 lignes pour trouver le const englobant
      var done = false;
      for (var up = idx - 1; up >= 0 && up >= idx - 6 && !done; up--) {
        final all = constRe.allMatches(lines[up]).toList();
        if (all.isNotEmpty) {
          final last = all.last;
          lines[up] = lines[up].substring(0, last.start) +
              lines[up].substring(last.start + 6);
          fixed++;
          done = true;
        }
      }
      if (!done) stderr.writeln('unfixed: ${entry.key}:$lineNo:$col');
    }
    f.writeAsStringSync('${lines.join('\n')}\n');
  }
  stdout.writeln('fixed: $fixed');
}
