import '../../musics/models/music.dart';
import 'evaluation_form.dart';
import 'evaluation_response.dart';

class MusicWithEvaluations {
  const MusicWithEvaluations({
    required this.music,
    required this.forms,
    required this.responses,
  });

  final MusicModel music;
  final List<EvaluationFormModel> forms;
  final List<EvaluationResponseModel> responses;

  /// Respostas agrupadas por formId
  Map<String, List<EvaluationResponseModel>> get responsesByForm {
    final map = <String, List<EvaluationResponseModel>>{};
    for (final r in responses) {
      map.putIfAbsent(r.formId, () => []).add(r);
    }
    return map;
  }
}
