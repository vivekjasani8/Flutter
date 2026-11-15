import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardrail from the roadmap: lib/engine must stay pure Dart so it can be
/// unit-tested and ported to the M4 Cloud Function.
void main() {
  test('lib/engine has no Flutter imports', () {
    final files = Directory('lib/engine')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final forbidden = RegExp(r'''import\s+['"](package:flutter|dart:ui)''');
    for (final f in files) {
      expect(forbidden.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });
}
