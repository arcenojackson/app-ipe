import 'package:flutter/material.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../../musics/models/music.dart';
import '../../../musics/presentation/widgets/music_selector_sheet.dart';
import '../../../musics/presentation/widgets/tone_selector_sheet.dart';
import '../../models/event.dart';

class StepEditorSheet extends StatefulWidget {
  const StepEditorSheet({
    super.key,
    required this.musics,
    this.initialStep,
    this.isTemplateMode = false,
  });

  final List<MusicModel> musics;
  final EventStepModel? initialStep;
  final bool isTemplateMode;

  @override
  State<StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<StepEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedMusicId;
  String? _musicTone;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStep;
    // Em modo template, sempre forçar tipo 'step'
    _type = widget.isTemplateMode
        ? 'step'
        : (initial?.type == EventStepType.music ? 'music' : 'step');
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _selectedMusicId = initial?.musicId;
    _musicTone = initial?.musicTone ?? '0';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.initialStep == null
                    ? 'Adicionar item'
                    : 'Editar item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!widget.isTemplateMode)
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: const [
                    DropdownMenuItem(value: 'step', child: Text('Etapa')),
                    DropdownMenuItem(value: 'music', child: Text('Música')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Tipo'),
                )
              else
                const Text(
                  'Tipo: Etapa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (_type == 'music' && !widget.isTemplateMode) ...[
                const SizedBox(height: 16),
                MusicSelectorField(
                  musics: widget.musics,
                  selectedId: _selectedMusicId,
                  onSelect: (music) {
                    setState(() {
                      _selectedMusicId = music.id;
                      _titleController.text = music.title;
                      _musicTone = music.tone;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ToneSelectorSheet(
                  selectedTone: _musicTone,
                  onToneSelected: (tone) => setState(() => _musicTone = tone),
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Título da etapa',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Detalhes adicionais',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Salvar'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    EventStepModel step;
    if (_type == 'music' && !widget.isTemplateMode) {
      final musicId = _selectedMusicId;
      if (musicId == null) {
        showErrorToast(context, 'Selecione uma música.');
        return;
      }
      step = EventStepModel(
        title: _titleController.text.trim(),
        description: '',
        type: EventStepType.music,
        musicId: musicId,
        musicTone: _musicTone ?? '0',
      );
    } else {
      step = EventStepModel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: EventStepType.step,
      );
    }
    Navigator.of(context).pop(step);
  }
}

