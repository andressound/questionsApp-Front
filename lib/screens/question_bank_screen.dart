import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'new_question_screen.dart';

/// Banco de preguntas del profesor: tabla de 5 en 5 y alta de preguntas nuevas.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key, required this.user});
  final AuthUser user;

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  int page = 1;
  late Future<QuestionPage> pageFuture = apiClient.questionBank(page: page);

  /// Última página recibida; mantiene el total de páginas mientras carga la siguiente.
  QuestionPage? lastPage;

  void _open(int target) => setState(() {
        page = target;
        pageFuture = apiClient.questionBank(page: page);
      });

  Future<void> _addQuestion() async {
    final created = await Navigator.push<BankQuestion>(context, MaterialPageRoute(builder: (_) => const NewQuestionScreen()));
    if (created == null || !mounted) return;
    _open(1);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta agregada')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      TeacherBar(user: widget.user),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.page, Gap.page, Gap.xl),
          children: [
            PushButton(label: 'Agregar pregunta', icon: Icons.add_rounded, onPressed: _addQuestion),
            const SizedBox(height: 18),
            FutureBuilder<QuestionPage>(
              future: pageFuture,
              builder: (context, snapshot) {
                final loading = snapshot.connectionState == ConnectionState.waiting;
                if (snapshot.hasData) lastPage = snapshot.data;
                final totalPages = lastPage?.totalPages ?? 1;

                final Widget body;
                if (loading) {
                  body = const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                } else if (snapshot.hasError) {
                  body = StatusMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Preguntas no disponibles',
                    message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'No se pudo cargar. Comprueba tu conexión.',
                    actionLabel: 'Reintentar',
                    onAction: () => _open(page),
                  );
                } else if (snapshot.data!.questions.isEmpty) {
                  body = const StatusMessage(icon: Icons.quiz_rounded, title: 'Sin preguntas', message: 'Agrega la primera pregunta del banco.');
                } else {
                  body = _QuestionTable(questions: snapshot.data!.questions);
                }

                return NightCard(
                  padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle(
                      'Banco de preguntas',
                      trailing: lastPage == null ? null : Text('${lastPage!.total} en total', style: theme.textTheme.bodySmall),
                    ),
                    const SizedBox(height: Gap.md),
                    body,
                    const SizedBox(height: Gap.lg),
                    Row(children: [
                      Expanded(child: PushButton(label: 'Anterior', tone: ButtonTone.blue, height: 44, onPressed: !loading && page > 1 ? () => _open(page - 1) : null)),
                      const SizedBox(width: Gap.md),
                      Expanded(child: PushButton(label: 'Siguiente', tone: ButtonTone.blue, height: 44, onPressed: !loading && page < totalPages ? () => _open(page + 1) : null)),
                    ]),
                    const SizedBox(height: Gap.md),
                    Text('Página $page de $totalPages', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Barra superior con el usuario de la sesión.
class TeacherBar extends StatelessWidget {
  const TeacherBar({super.key, required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.line, width: 2))),
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: Row(children: [
            UserAvatar(initials: user.initials, size: 36),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Profesor'),
                Text(user.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tabla de una página: número, enunciado y respuesta correcta. Al tocar una fila se ven todas las opciones.
class _QuestionTable extends StatelessWidget {
  const _QuestionTable({required this.questions});
  final List<BankQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final header = theme.textTheme.labelSmall!.copyWith(color: tokens.textMuted, fontWeight: FontWeight.w900, letterSpacing: 1);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Row(children: [
          SizedBox(width: 40, child: Text('#', style: header)),
          Expanded(flex: 3, child: Text('ENUNCIADO', style: header)),
          const SizedBox(width: Gap.md),
          Expanded(flex: 2, child: Text('CORRECTA', style: header)),
        ]),
      ),
      for (final question in questions) ...[
        const Divider(height: 1),
        InkWell(
          onTap: () => showDialog<void>(context: context, builder: (_) => _QuestionDetail(question: question)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 40, child: Text('${question.id}', style: theme.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w800))),
              Expanded(flex: 3, child: Text(question.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: Gap.md),
              Expanded(
                flex: 2,
                child: Text(question.correctOption?.text ?? '—', maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium!.copyWith(color: tokens.greenText, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _QuestionDetail extends StatelessWidget {
  const _QuestionDetail({required this.question});
  final BankQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text('Pregunta ${question.id}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question.text, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Gap.lg),
        for (final (index, option) in question.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(children: [
              OptionLetter(letter: String.fromCharCode(65 + index), highlighted: option.isCorrect),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(option.text, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: option.isCorrect ? tokens.greenText : null)),
              ),
              if (option.isCorrect) Icon(Icons.check_rounded, color: tokens.green, semanticLabel: 'Correcta'),
            ]),
          ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
