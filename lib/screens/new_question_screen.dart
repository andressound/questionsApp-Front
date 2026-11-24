import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';

/// Alta de una pregunta de 4 opciones. Devuelve la [BankQuestion] creada.
class NewQuestionScreen extends StatefulWidget {
  const NewQuestionScreen({super.key});

  @override
  State<NewQuestionScreen> createState() => _NewQuestionScreenState();
}

class _NewQuestionScreenState extends State<NewQuestionScreen> {
  static const optionCount = 4;

  final formKey = GlobalKey<FormState>();
  final textController = TextEditingController();
  final optionControllers = List.generate(optionCount, (_) => TextEditingController());

  /// Índice de la opción correcta; null hasta que el profesor la elige.
  int? correct;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    textController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Mismas reglas que el backend: enunciado ≤ 500, opciones ≤ 200 y distintas.
  String? _validateText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe el enunciado';
    if (text.length > 500) return 'Máximo 500 caracteres';
    return null;
  }

  String? _validateOption(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe la opción';
    if (text.length > 200) return 'Máximo 200 caracteres';
    return null;
  }

  Future<void> _save() async {
    final fieldsValid = formKey.currentState!.validate();
    final options = [for (final controller in optionControllers) controller.text.trim()];
    String? formError;
    if (fieldsValid && options.map((option) => option.toLowerCase()).toSet().length != optionCount) {
      formError = 'Las opciones no pueden repetirse';
    } else if (correct == null) {
      formError = 'Toca la letra de la opción correcta';
    }
    setState(() => error = formError);
    if (!fieldsValid || formError != null) return;

    setState(() => saving = true);
    try {
      final created = await apiClient.createQuestion(text: textController.text.trim(), options: options, correct: correct!);
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo conectar con el servidor. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: formKey,
          // Column y no ListView: un campo fuera de pantalla debe seguir montado para que validate() lo revise.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SquareIconButton(icon: Icons.close_rounded, tooltip: 'Cancelar', size: 48, color: tokens.textSoft, onPressed: saving ? null : () => Navigator.pop(context)),
                const SizedBox(width: Gap.md),
                Expanded(child: Text('Nueva pregunta', style: theme.textTheme.titleLarge)),
              ]),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: textController,
                enabled: !saving,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Enunciado'),
                validator: _validateText,
              ),
              const SizedBox(height: Gap.lg),
              const Eyebrow('Opciones'),
              const SizedBox(height: Gap.xs),
              Text('Toca la letra de la opción correcta.', style: theme.textTheme.bodySmall),
              const SizedBox(height: Gap.md),
              for (var index = 0; index < optionCount; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.sm),
                      child: Semantics(
                        button: true,
                        selected: correct == index,
                        label: 'Marcar ${String.fromCharCode(65 + index)} como correcta',
                        excludeSemantics: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: saving ? null : () => setState(() => correct = index),
                          child: OptionLetter(letter: String.fromCharCode(65 + index), highlighted: correct == index),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: TextFormField(
                        controller: optionControllers[index],
                        enabled: !saving,
                        maxLength: 200,
                        textInputAction: index == optionCount - 1 ? TextInputAction.done : TextInputAction.next,
                        decoration: InputDecoration(labelText: 'Opción ${String.fromCharCode(65 + index)}', counterText: ''),
                        validator: _validateOption,
                      ),
                    ),
                  ]),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text(error!, style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: Gap.sm),
              PushButton(label: 'Guardar pregunta', busy: saving, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }
}
