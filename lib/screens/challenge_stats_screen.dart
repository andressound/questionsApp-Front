import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';

/// Resultados de un reto personalizado: cuántos estudiantes eligieron cada opción.
class ChallengeStatsScreen extends StatefulWidget {
  const ChallengeStatsScreen({super.key, required this.challenge});
  final CustomChallenge challenge;

  @override
  State<ChallengeStatsScreen> createState() => _ChallengeStatsScreenState();
}

class _ChallengeStatsScreenState extends State<ChallengeStatsScreen> {
  late Future<ChallengeStats> statsFuture = apiClient.customChallengeStats(widget.challenge.id);

  void _reload() => setState(() => statsFuture = apiClient.customChallengeStats(widget.challenge.id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
            child: Row(children: [
              SquareIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Volver', size: 48, color: tokens.textSoft, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('Resultados'),
                  Text(widget.challenge.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                ]),
              ),
              SquareIconButton(icon: Icons.refresh_rounded, tooltip: 'Actualizar', size: 48, color: tokens.textSoft, onPressed: _reload),
            ]),
          ),
          Expanded(
            child: FutureBuilder<ChallengeStats>(
              future: statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) {
                  return Center(
                    child: StatusMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Resultados no disponibles',
                      message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'No se pudo cargar. Comprueba tu conexión.',
                      actionLabel: 'Reintentar',
                      onAction: _reload,
                    ),
                  );
                }
                final stats = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xl),
                  children: [
                    Text(
                      stats.students == 0
                          ? 'Aún no ha jugado ningún estudiante.'
                          : '${stats.students} ${stats.students == 1 ? 'estudiante ha jugado' : 'estudiantes han jugado'} este reto.',
                      style: theme.textTheme.bodySmall!.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: Gap.lg),
                    for (final question in stats.questions) ...[
                      QuestionResults(question: question),
                      const SizedBox(height: Gap.lg),
                    ],
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Barras de una pregunta; al tocar el número de una opción se ve quiénes la eligieron.
class QuestionResults extends StatelessWidget {
  const QuestionResults({super.key, required this.question});
  final QuestionStats question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final answers = question.answers;
    double share(int count) => answers == 0 ? 0 : count / answers;

    Widget row({required Widget leading, required String title, required String label, required int count, required List<String> students, required Color color, Color? labelColor}) {
      final VoidCallback? showStudents = count == 0 ? null : () => showDialog<void>(context: context, builder: (_) => _StudentsDialog(title: title, label: label, students: students));
      return Padding(
        padding: const EdgeInsets.only(top: Gap.md),
        child: Semantics(
          label: '$label: $count ${count == 1 ? 'estudiante' : 'estudiantes'}',
          hint: showStudents == null ? null : 'Ver estudiantes',
          onTap: showStudents,
          excludeSemantics: true,
          child: Row(children: [
            leading,
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(label, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: Gap.xs),
                ProgressTrack(value: share(count), color: color),
              ]),
            ),
            const SizedBox(width: Gap.md),
            _CountButton(text: '$count · ${(share(count) * 100).round()}%', onPressed: showStudents),
          ]),
        ),
      );
    }

    return NightCard(
      padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Eyebrow('Pregunta ${question.position}'),
        const SizedBox(height: Gap.xs),
        Text(question.text, style: theme.textTheme.titleMedium),
        for (final (index, option) in question.options.indexed)
          row(
            leading: OptionLetter(letter: String.fromCharCode(65 + index), highlighted: option.isCorrect),
            title: 'Opción ${String.fromCharCode(65 + index)}${option.isCorrect ? ' (correcta)' : ''}',
            label: option.text,
            count: option.count,
            students: option.students,
            color: option.isCorrect ? tokens.green : tokens.blue,
            labelColor: option.isCorrect ? tokens.greenText : null,
          ),
        row(
          leading: SizedBox(width: 36, child: Icon(Icons.timer_off_rounded, color: tokens.textMuted)),
          title: 'Sin responder',
          label: 'Sin responder (tiempo agotado)',
          count: question.timedOut,
          students: question.timedOutStudents,
          color: tokens.danger,
        ),
      ]),
    );
  }
}

/// Número de estudiantes de una opción; si hay alguno, se puede tocar.
class _CountButton extends StatelessWidget {
  const _CountButton({required this.text, required this.onPressed});
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final enabled = onPressed != null;
    final label = Text(
      text,
      textAlign: TextAlign.right,
      style: theme.textTheme.bodySmall!.copyWith(
        fontWeight: FontWeight.w800,
        color: enabled ? tokens.blue : null,
        decoration: enabled ? TextDecoration.underline : null,
        decorationColor: tokens.blue,
      ),
    );
    return SizedBox(
      width: 72,
      child: !enabled
          ? label
          : Tooltip(
              message: 'Ver estudiantes',
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(Corner.chip),
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Align(alignment: Alignment.centerRight, child: label)),
              ),
            ),
    );
  }
}

/// Ventana con los estudiantes que eligieron una opción (o se quedaron sin tiempo).
class _StudentsDialog extends StatelessWidget {
  const _StudentsDialog({required this.title, required this.label, required this.students});
  final String title;
  final String label;
  final List<String> students;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Gap.xs),
        Text('${students.length} ${students.length == 1 ? 'estudiante' : 'estudiantes'}', style: theme.textTheme.bodySmall!.copyWith(color: tokens.textMuted)),
        const SizedBox(height: Gap.lg),
        for (final student in students)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(children: [
              UserAvatar(initials: initialsOf(student), size: 32),
              const SizedBox(width: Gap.md),
              Expanded(child: Text(student, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
            ]),
          ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
