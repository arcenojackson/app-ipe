import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/musics/models/music_status.dart';

void main() {
  group('MusicStatus.fromString', () {
    test('retorna avaliar para null (migração lazy)', () {
      expect(MusicStatus.fromString(null), MusicStatus.avaliar);
    });

    test('retorna avaliar para string desconhecida', () {
      expect(MusicStatus.fromString('xpto'), MusicStatus.avaliar);
    });

    test('converte "em_avaliacao" corretamente', () {
      expect(MusicStatus.fromString('em_avaliacao'), MusicStatus.emAvaliacao);
    });

    test('converte "aprovada" corretamente', () {
      expect(MusicStatus.fromString('aprovada'), MusicStatus.aprovada);
    });

    test('converte "reprovada" corretamente', () {
      expect(MusicStatus.fromString('reprovada'), MusicStatus.reprovada);
    });

    test('value e label estão corretos para cada status', () {
      expect(MusicStatus.emAvaliacao.value, 'em_avaliacao');
      expect(MusicStatus.emAvaliacao.label, 'Em avaliação');
      expect(MusicStatus.aprovada.value, 'aprovada');
      expect(MusicStatus.reprovada.value, 'reprovada');
    });
  });
}
