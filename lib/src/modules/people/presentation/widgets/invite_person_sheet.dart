import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/utils/app_toast.dart';

class InvitePersonSheet extends StatefulWidget {
  const InvitePersonSheet({super.key});

  @override
  State<InvitePersonSheet> createState() => _InvitePersonSheetState();
}

class _InvitePersonSheetState extends State<InvitePersonSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _whatsappController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  String _getAppStoreLink() {
    if (Platform.isIOS) {
      return 'https://apps.apple.com/app/app-ipe/id123456789'; // TODO: Ajustar com o ID correto
    } else if (Platform.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=com.ipe.app'; // TODO: Ajustar com o package correto
    }
    return 'https://apps.apple.com/app/app-ipe'; // Fallback
  }

  Future<void> _invitePerson() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final whatsapp = _whatsappController.text.trim();

      // Remove caracteres não numéricos do WhatsApp
      final cleanWhatsapp = whatsapp.replaceAll(RegExp(r'[^\d]'), '');

      // Valida se tem pelo menos 10 dígitos (formato mínimo)
      if (cleanWhatsapp.length < 10) {
        if (mounted) {
          showErrorToast(context, 'Número de WhatsApp inválido.');
        }
        setState(() => _isSubmitting = false);
        return;
      }

      // Formata o número para o formato internacional (assumindo Brasil +55)
      String formattedNumber = cleanWhatsapp;
      
      // Se já começa com 55, mantém
      if (formattedNumber.startsWith('55')) {
        // Já está no formato internacional
      } else if (formattedNumber.startsWith('0')) {
        // Remove o zero inicial e adiciona 55
        formattedNumber = '55${formattedNumber.substring(1)}';
      } else {
        // Adiciona código do país (Brasil: 55)
        formattedNumber = '55$formattedNumber';
      }

      // Mensagem padrão
      final appStoreLink = _getAppStoreLink();
      final message = 'Olá $name! Você está sendo convidado a participar do App IPE.\n\n'
          'Baixe o app na sua loja:\n'
          '$appStoreLink';

      // URL do WhatsApp
      final whatsappUrl = 'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}';

      // Tenta abrir o WhatsApp
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessToast(context, 'WhatsApp aberto com sucesso!');
        }
      } else {
        if (mounted) {
          showErrorToast(context, 'Não foi possível abrir o WhatsApp.');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao abrir WhatsApp: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final headerHeight = 100.0;
    final topPadding = safeAreaTop + headerHeight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
        left: 16,
        right: 16,
        top: topPadding,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Convidar pessoa',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Nome da pessoa',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da pessoa';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'Número de WhatsApp',
                  hintText: '(11) 99999-9999',
                  helperText: 'Digite apenas números ou com formatação',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o número de WhatsApp';
                  }
                  final cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (cleanNumber.length < 10) {
                    return 'Número de WhatsApp inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _invitePerson,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Convidar pessoa'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

