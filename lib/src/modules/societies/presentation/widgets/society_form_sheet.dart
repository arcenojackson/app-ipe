import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/societies_repository.dart';
import '../../models/society.dart';
import '../../../../shared/utils/app_toast.dart';

class SocietyFormSheet extends StatefulWidget {
  const SocietyFormSheet({super.key, this.society});

  final SocietyModel? society;

  @override
  State<SocietyFormSheet> createState() => _SocietyFormSheetState();
}

class _SocietyFormSheetState extends State<SocietyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  int _selectedColor = 0xFF2F4F2F; // Cor padrão (verde escuro)

  // Cores predefinidas para seleção
  static const List<int> _predefinedColors = [
    0xFF2F4F2F, // DarkOliveGreen
    0xFF6B8E23, // OliveDrab
    0xFF8B4513, // SaddleBrown
    0xFF556B2F, // DarkOliveGreen
    0xFF2E8B57, // SeaGreen
    0xFF4682B4, // SteelBlue
    0xFF5F9EA0, // CadetBlue
    0xFF9370DB, // MediumPurple
    0xFFCD5C5C, // IndianRed
    0xFFD2691E, // Chocolate
    0xFFB8860B, // DarkGoldenrod
    0xFF8B008B, // DarkMagenta
  ];

  @override
  void initState() {
    super.initState();
    final society = widget.society;
    if (society != null) {
      _nameController.text = society.name;
      _descriptionController.text = society.description;
      _selectedColor = society.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.society == null ? 'Nova sociedade' : 'Editar sociedade';

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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Nome da sociedade',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o nome da sociedade';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Descrição da sociedade',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a descrição da sociedade';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Cor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _predefinedColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(color).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = context.read<SocietiesRepository>();
      if (widget.society == null) {
        await repository.createSociety(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Sociedade criada com sucesso!');
        }
      } else {
        await repository.updateSociety(
          id: widget.society!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'Sociedade atualizada com sucesso!');
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar sociedade. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

