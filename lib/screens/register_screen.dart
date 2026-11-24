import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../theme/app_tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';
import 'app_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool obscureTeacherCode = true;
  bool submitting = false;

  /// El rol no se elige: el profesor escribe el código secreto que le da la institución.
  bool teacherMode = false;
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final teacherCodeController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    teacherCodeController.dispose();
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
            const SizedBox(height: Gap.sm),
            IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Volver', style: IconButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft), icon: const Icon(Icons.arrow_back)),
            const SizedBox(height: Gap.lg),
            Text('Crea tu cuenta', style: textTheme.displaySmall),
            const SizedBox(height: Gap.sm),
            Text('Responde los retos diarios, suma puntos y escala en la clasificación.', style: textTheme.bodyMedium!.copyWith(color: AppTokens.of(context).textMuted)),
            const SizedBox(height: Gap.xl),
            NightCard(
              lifted: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(teacherMode ? 'Cuenta de profesor' : 'Nueva partida', style: textTheme.titleLarge),
                const SizedBox(height: Gap.lg),
                LabeledField(label: 'Nombre de usuario', hint: 'Cómo te verán los demás', icon: Icons.person_outline, controller: usernameController, autofillHints: const [AutofillHints.newUsername]),
                const SizedBox(height: Gap.lg),
                LabeledField(label: 'Correo electrónico', hint: 'nombre@correo.com', icon: Icons.mail_outline, controller: emailController, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email]),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Contraseña',
                  hint: 'Al menos 8 caracteres',
                  icon: Icons.lock_outline,
                  controller: passwordController,
                  obscureText: obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  suffixIcon: PasswordVisibilityButton(hidden: obscurePassword, onPressed: () => setState(() => obscurePassword = !obscurePassword)),
                ),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Repite la contraseña',
                  hint: 'La misma de arriba',
                  icon: Icons.lock_outline,
                  controller: confirmationController,
                  obscureText: obscureConfirmation,
                  textInputAction: teacherMode ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: teacherMode ? null : (_) => _register(context),
                  suffixIcon: PasswordVisibilityButton(hidden: obscureConfirmation, onPressed: () => setState(() => obscureConfirmation = !obscureConfirmation)),
                ),
                if (teacherMode) ...[
                  const SizedBox(height: Gap.lg),
                  LabeledField(
                    label: 'Código de profesor',
                    hint: 'Te lo da la institución',
                    icon: Icons.key_outlined,
                    controller: teacherCodeController,
                    obscureText: obscureTeacherCode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(context),
                    suffixIcon: PasswordVisibilityButton(hidden: obscureTeacherCode, onPressed: () => setState(() => obscureTeacherCode = !obscureTeacherCode)),
                  ),
                ],
              ]),
            ),
            Align(
              child: TextButton(
                onPressed: () => setState(() {
                  teacherMode = !teacherMode;
                  if (!teacherMode) teacherCodeController.clear();
                }),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(teacherMode ? 'Soy estudiante' : '¿Eres profesor?'),
              ),
            ),
            const Spacer(),
            const SizedBox(height: Gap.xl),
            PushButton(label: 'Crear cuenta', busy: submitting, onPressed: () => _register(context)),
            const SizedBox(height: Gap.sm),
            FooterPrompt(prompt: '¿Ya tienes cuenta?', action: 'Inicia sesión', onPressed: () => Navigator.pop(context)),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
  }

  Future<void> _register(BuildContext context) async {
    if (submitting) return;
    if (usernameController.text.trim().isEmpty
        || emailController.text.trim().isEmpty
        || passwordController.text.length < 8) {
      _showError('Completa usuario y correo, y usa una contraseña de al menos 8 caracteres');
      return;
    }
    if (passwordController.text != confirmationController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }
    final teacherCode = teacherMode ? teacherCodeController.text.trim() : null;
    if (teacherCode != null && teacherCode.isEmpty) {
      _showError('Escribe el código de profesor');
      return;
    }
    setState(() => submitting = true);
    try {
      final user = await apiClient.register(
        usernameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
        teacherCode: teacherCode,
      );
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => shellFor(user)), (_) => false);
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
