import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';

void main() {
  test('título padrão inclui sociedade e ano', () {
    expect(defaultElectionTitle('UMP', 2026), 'Eleição da diretoria UMP 2026');
    expect(defaultElectionTitle('', 2026), 'Eleição da diretoria 2026');
  });
}
