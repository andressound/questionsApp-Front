import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'custom_challenges_screen.dart';
import 'new_question_screen.dart';

/// Alta de un reto personalizado. Devuelve el [CustomChallenge] creado, con su código.
class NewChallengeScreen extends StatefulWidget {
  const NewChallengeScreen({super.key});

  @override
  State<NewChallengeScreen> createState() => _NewChallengeScreenState();
}

class _NewChallengeScreenState extends State<NewChallengeScreen> {
  // Mismos valores que acepta el backend.
  static const timerOptions = [10, 15, 20, 30, 45, 60];
  static const durationOptions = [(1, '1 hora'), (2, '2 horas'), (24, '1 día'), (72, '3 días'), (168, '1 semana')];
  static const maxQuestions = 20;

  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();

  /// Preguntas elegidas, en el orden en que se jugarán.
  final List<BankQuestion> selected = [];
  int seconds = 15;
  bool givesPoints = true;
  int durationHours = 24;

  int page = 1;
  late Future<QuestionPage> pageFuture = apiClient.questionBank(page: page);
  QuestionPage? lastPage;

  bool saving = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  void _open(int target) => setState(() {
        page = target;
        pageFuture = apiClient.questionBank(page: page);
      });

  bool _isSelected(BankQuestion question) => selected.any((item) => item.id == question.id);

  void _toggle(BankQuestion question) => setState(() {
        if (_isSelected(question)) {
          selected.removeWhere((item) => item.id == question.id);
        } else if (selected.length < maxQuestions) {
          selected.add(question);
        }
      });

  /// Crea una pregunta con el formulario de siempre y la deja elegida.
  Future<void> _newQuestion() async {
    final created = await Navigator.push<BankQuestion>(context, MaterialPageRoute(builder: (_) => const NewQuestionScreen()));
    if (created == null || !mounted) return;
    setState(() {
      if (selected.length < maxQuestions) selected.add(created);
      // Las nuevas salen primero en el banco.
      page = 1;
      pageFuture = apiClient.questionBank(page: page);
    });
  }

  Future<void> _save() async {
    final titleValid = formKey.currentState!.validate();
    setState(() => error = selected.isEmpty ? 'Elige al menos una pregunta' : null);
    if (!titleValid || selected.isEmpty) return;

    setState(() => saving = true);
    try {
      final created = await apiClient.createCustomChallenge(
        title: titleController.text.trim(),
        questionIds: [for (final question in selected) question.id],
        secondsPerQuestion: seconds,
        givesPoints: givesPoints,
        durationHours: durationHours,
      );
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _CreatedDialog(challenge: created));
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SquareIconButton(icon: Icons.close_rounded, tooltip: 'Cancelar', size: 48, color: tokens.textSoft, onPressed: saving ? null : () => Navigator.pop(context)),
                const SizedBox(width: Gap.md),
                Expanded(child: Text('Nuevo reto', style: theme.textTheme.titleLarge)),
              ]),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: titleController,
                enabled: !saving,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Título del reto', counterText: ''),
                validator: (value) => (value?.trim() ?? '').isEmpty ? 'Escribe un título' : null,
              ),
              const SizedBox(height: Gap.xl),
              _questionPicker(context),
              const SizedBox(height: Gap.xl),
              const Eyebrow('Cronómetro por pregunta'),
              const SizedBox(height: Gap.sm),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                for (final option in timerOptions)
                  ChoiceChip(label: Text('$option s'), selected: seconds == option, onSelected: saving ? null : (_) => setState(() => seconds = option)),
              ]),
              const SizedBox(height: Gap.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Da puntos'),
                subtitle: Text(givesPoints ? 'Los aciertos suman a la clasificación.' : 'Práctica: no suma puntos ni retos respondidos.', style: theme.textTheme.bodySmall),
                value: givesPoints,
                onChanged: saving ? null : (value) => setState(() => givesPoints = value),
              ),
              const SizedBox(height: Gap.md),
              const Eyebrow('Disponible durante'),
              const SizedBox(height: Gap.sm),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                for (final (hours, label) in durationOptions)
                  ChoiceChip(label: Text(label), selected: durationHours == hours, onSelected: saving ? null : (_) => setState(() => durationHours = hours)),
              ]),
              const SizedBox(height: Gap.xl),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text(error!, style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error)),
                ),
              PushButton(label: 'Crear reto', busy: saving, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }

  /// Banco de preguntas de 5 en 5 con casillas, más el atajo para crear una nueva.
  Widget _questionPicker(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return NightCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Preguntas',
          trailing: Text('${selected.length} ${selected.length == 1 ? 'elegida' : 'elegidas'}', style: theme.textTheme.titleSmall!.copyWith(color: tokens.amberText)),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          Text('Orden: ${selected.map((question) => '#${question.id}').join(', ')}', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: Gap.md),
        PushButton(label: 'Crear pregunta', icon: Icons.add_rounded, tone: ButtonTone.blue, height: 44, onPressed: saving || selected.length >= maxQuestions ? null : _newQuestion),
        const SizedBox(height: Gap.md),
        FutureBuilder<QuestionPage>(
          future: pageFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            if (snapshot.hasData) lastPage = snapshot.data;
            final totalPages = lastPage?.totalPages ?? 1;

            final Widget body;
            if (loading) {
              body = const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasError) {
              body = StatusMessage(icon: Icons.cloud_off_rounded, title: 'Preguntas no disponibles', message: 'No se pudo cargar el banco.', actionLabel: 'Reintentar', onAction: () => _open(page));
            } else {
              body = Column(children: [
                for (final question in snapshot.data!.questions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _isSelected(question),
                    onChanged: saving ? null : (_) => _toggle(question),
                    title: Text('#${question.id} · ${question.text}', maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700)),
                  ),
              ]);
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              body,
              const SizedBox(height: Gap.md),
              Row(children: [
                Expanded(child: PushButton(label: 'Anterior', tone: ButtonTone.blue, height: 44, onPressed: !loading && page > 1 ? () => _open(page - 1) : null)),
                const SizedBox(width: Gap.md),
                Expanded(child: PushButton(label: 'Siguiente', tone: ButtonTone.blue, height: 44, onPressed: !loading && page < totalPages ? () => _open(page + 1) : null)),
              ]),
              const SizedBox(height: Gap.md),
              Text('Página $page de $totalPages', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Aviso con el código que el profesor comparte con sus estudiantes.
class _CreatedDialog extends StatelessWidget {
  const _CreatedDialog({required this.challenge});
  final CustomChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Reto creado'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Comparte este código con tus estudiantes. Lo escriben en Inicio para entrar.', style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.lg),
        ChallengeCode(code: challenge.code),
        const SizedBox(height: Gap.md),
        Text('Disponible hasta ${formatDateTime(challenge.endsAt)}.', style: theme.textTheme.bodySmall),
      ]),
      actions: [PushButton(label: 'Listo', expand: false, height: 48, onPressed: () => Navigator.pop(context))],
    );
  }
}
