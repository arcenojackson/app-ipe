import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';

void main() {
  test('há cinco cargos de diretoria', () {
    expect(BoardPosition.values.length, 5);
  });

  test('2º Secretário grava a chave "2º secretario(a)"', () {
    expect(BoardPosition.secretario2.label.toLowerCase(), '2º secretario(a)');
  });

  test('fromString resolve o novo cargo pelo nome e pelo rótulo', () {
    expect(BoardPosition.fromString('secretario2'), BoardPosition.secretario2);
    expect(
      BoardPosition.fromString('2º Secretario(a)'),
      BoardPosition.secretario2,
    );
  });

  test('as chaves antigas não mudam', () {
    expect(BoardPosition.secretario.label.toLowerCase(), 'secretario(a)');
    expect(BoardPosition.tesoureiro.label.toLowerCase(), 'tesoureiro(a)');
  });
}
