import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';
import 'common.dart';

/// Lienzo de login y registro: contenido arriba y acciones pegadas abajo,
/// con scroll cuando aparece el teclado.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.page), child: child)),
              ),
            ),
          ),
        ),
      );
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
  });
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow(label),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 20), suffixIcon: suffixIcon),
        ),
      ]);
}

class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({super.key, required this.hidden, required this.onPressed});
  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      );
}

class FooterPrompt extends StatelessWidget {
  const FooterPrompt({super.key, required this.prompt, required this.action, required this.onPressed});
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(prompt, style: Theme.of(context).textTheme.bodySmall),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Gap.sm), minimumSize: const Size(0, 44)),
          child: Text(action),
        ),
      ]);
}
