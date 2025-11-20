import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSignUp = false;

  static const _darkBackground = Color(0xFF0B0F19);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLoading = appState.isLoading;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final error = appState.error;
      if (error != null && mounted) {
        showErrorToast(context, error);
        context.read<AppState>().clearError();
      }
    });

    return Scaffold(
      backgroundColor: _darkBackground,
      body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                const SizedBox(height: 60),
                // Logo do app (ícone circular)
                              Container(
                  width: 112,
                  height: 112,
                                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                // Título "Bem-vindo(a)!"
                const Text(
                  'Bem-vindo(a)!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtítulo
                Text(
                  'Entre ou crie sua conta para começar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 40),
                // Campo de Email
          TextFormField(
                  controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: const TextStyle(color: Colors.white),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe o e-mail';
              }
              final emailRegex = RegExp(
                r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                caseSensitive: false,
              );
              if (!emailRegex.hasMatch(value)) {
                return 'E-mail inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
                // Campo de Senha
          TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Senha',
                    hintStyle: const TextStyle(color: Colors.white),
                    prefixIcon: Icon(
                      Icons.lock_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe a senha';
              }
                    if (value.length < 6) {
                      return 'Senha deve ter 6 caracteres ou mais';
              }
              return null;
            },
          ),
                const SizedBox(height: 24),
                // Botão Entrar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            if (_isSignUp) {
                              _onSubmitSignUp(context);
                            } else {
                              _onSubmitSignIn(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Criar conta' : 'Entrar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Botão Criar conta (outline)
                if (!_isSignUp)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = true;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Criar conta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Botão para voltar ao login (quando em modo signup)
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = false;
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: Text(
                      'Já tem uma conta? Entrar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                // Separador "ou"
                if (!_isSignUp) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.2),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ou',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.2),
                          thickness: 1,
                        ),
          ),
        ],
      ),
                  const SizedBox(height: 24),
                  // Botão Continuar com Google
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () => _onSignInWithGoogle(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo do Google simplificado
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Stack(
        children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [
                                        Color(0xFF4285F4), // azul
                                        Color(0xFFEA4335), // vermelho
                                        Color(0xFFFBBC05), // amarelo
                                        Color(0xFF34A853), // verde
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continuar com Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                // Texto de termos
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Ao continuar, você concorda com nossos\nTermos de Uso e Política de Privacidade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmitSignIn(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await context.read<AppState>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
      );
    } catch (_) {
      // O AppState já trata a mensagem de erro através do SnackBar.
    }
  }

  Future<void> _onSubmitSignUp(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      // Para criar conta, vamos precisar adicionar um campo de nome
      // Por enquanto, usando o email como nome
      await context.read<AppState>().signUp(
            name: _emailController.text.trim().split('@').first,
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      setState(() {
        _isSignUp = false;
      });
    } catch (_) {
      // O AppState já trata a mensagem de erro através do SnackBar.
    }
  }

  Future<void> _onSignInWithGoogle(BuildContext context) async {
    FocusScope.of(context).unfocus();
    try {
      await context.read<AppState>().signInWithGoogle();
    } catch (_) {
      // O AppState já trata a mensagem de erro através do SnackBar.
    }
  }
}

