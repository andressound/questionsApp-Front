import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../theme/app_tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';
import 'app_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool submitting = false;
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Gap.xxl + Gap.lg),
            const Center(child: AppMark()),
            const SizedBox(height: Gap.xl),
            Center(child: Text('QuestionsApp', style: textTheme.displayMedium)),
            const SizedBox(height: Gap.xs),
            Center(child: Text('Entra, responde rápido y suma puntos.', textAlign: TextAlign.center, style: textTheme.bodyMedium!.copyWith(color: AppTokens.of(context).textMuted))),
            const SizedBox(height: Gap.xxl),
            NightCard(
              lifted: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Continuar partida', style: textTheme.titleLarge),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Usuario o correo',
                  hint: 'tu_usuario o nombre@correo.com',
                  icon: Icons.person_outline,
                  controller: usernameController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                ),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Contraseña',
                  hint: 'Tu contraseña',
                  icon: Icons.lock_outline,
                  obscureText: obscurePassword,
                  controller: passwordController,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(context),
                  suffixIcon: PasswordVisibilityButton(hidden: obscurePassword, onPressed: () => setState(() => obscurePassword = !obscurePassword)),
                ),
              ]),
            ),
            const Spacer(),
            const SizedBox(height: Gap.xl),
            PushButton(label: 'Iniciar sesión', busy: submitting, onPressed: () => _login(context)),
            const SizedBox(height: Gap.sm),
            FooterPrompt(
              prompt: '¿No tienes cuenta?',
              action: 'Regístrate',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context) async {
    if (submitting) return;
    if (usernameController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showError('Escribe tu usuario o correo y tu contraseña');
      return;
    }
    setState(() => submitting = true);
    try {
      final user = await apiClient.login(usernameController.text.trim(), passwordController.text);
      if (!context.mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => shellFor(user)));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('No se pudo conectar con el servidor. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
