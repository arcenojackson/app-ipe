import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/musics/models/music.dart';
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

    test('converte "avaliar" corretamente', () {
      expect(MusicStatus.fromString('avaliar'), MusicStatus.avaliar);
    });

    test('value e label estão corretos para cada status', () {
      expect(MusicStatus.emAvaliacao.value, 'em_avaliacao');
      expect(MusicStatus.emAvaliacao.label, 'Em avaliação');
      expect(MusicStatus.aprovada.value, 'aprovada');
      expect(MusicStatus.reprovada.value, 'reprovada');
    });
  });

  group('MusicModel.fromJson — campo status', () {
    Map<String, dynamic> baseJson() => {
      'id': 'music-1',
      'title': 'Santo',
      'artist': 'Ministério Ipiranga',
      'cipher': '',
      'tone': 'C',
    };

    test('status ausente → avaliar (migração lazy)', () {
      final music = MusicModel.fromJson(baseJson());
      expect(music.status, MusicStatus.avaliar);
    });

    test('status "em_avaliacao" → emAvaliacao', () {
      final json = baseJson()..['status'] = 'em_avaliacao';
      final music = MusicModel.fromJson(json);
      expect(music.status, MusicStatus.emAvaliacao);
    });

    test('status "aprovada" → aprovada', () {
      final json = baseJson()..['status'] = 'aprovada';
      final music = MusicModel.fromJson(json);
      expect(music.status, MusicStatus.aprovada);
    });

    test('toJson inclui campo status com valor correto', () {
      final json = baseJson()..['status'] = 'reprovada';
      final music = MusicModel.fromJson(json);
      expect(music.toJson()['status'], 'reprovada');
    });

    test('copyWith preserva status se não informado', () {
      final json = baseJson()..['status'] = 'aprovada';
      final music = MusicModel.fromJson(json);
      final copy = music.copyWith(title: 'Novo título');
      expect(copy.status, MusicStatus.aprovada);
    });

    test('copyWith substitui status quando informado', () {
      final json = baseJson()..['status'] = 'aprovada';
      final music = MusicModel.fromJson(json);
      final copy = music.copyWith(status: MusicStatus.reprovada);
      expect(copy.status, MusicStatus.reprovada);
    });
  });
}
