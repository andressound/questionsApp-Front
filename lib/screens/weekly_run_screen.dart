import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';

/// Envía la respuesta de una pregunta del reto (semanal o personalizado).
typedef SubmitWeeklyAnswer = Future<AnswerResult> Function(Question question, int? optionId, int elapsedSeconds);

/// Reto semanal o personalizado: las preguntas pendientes se juegan seguidas y al final hay un resumen.
/// Lo respondido se guarda pregunta a pregunta, así que salir equivale a pausar.
class WeeklyRunScreen extends StatefulWidget {
  const WeeklyRunScreen({super.key, required this.questions, required this.user, this.submit, this.title = 'Reto semanal', this.timeLimitSeconds = 15, this.givesPoints = true});

  /// Todas las preguntas del reto; se juegan solo las no realizadas.
  final List<Question> questions;
  final AuthUser user;

  /// Por defecto responde el reto semanal.
  final SubmitWeeklyAnswer? submit;
  final String title;
  final int timeLimitSeconds;

  /// Si es falso, el resumen no muestra puntos (reto personalizado de práctica).
  final bool givesPoints;

  @override
  State<WeeklyRunScreen> createState() => _WeeklyRunScreenState();
}

class _WeeklyRunScreenState extends State<WeeklyRunScreen> {
  late final List<Question> pending = widget.questions.where((question) => !question.completed).toList()..sort((a, b) => a.position.compareTo(b.position));
  late final int alreadyDone = widget.questions.length - pending.length;
  int index = 0;
  int correctCount = 0;
  int earned = 0;
  AnswerResult? lastResult;

  bool get finished => index >= pending.length;

  Future<AnswerResult> _submit(Question question, int? optionId, int elapsedSeconds) =>
      (widget.submit ?? (question, optionId, elapsedSeconds) => apiClient.answerWeeklyQuestion(questionId: question.id, optionId: optionId, elapsedSeconds: elapsedSeconds))(
          question, optionId, elapsedSeconds);

  void _record(Question question, AnswerResult? result) {
    if (result == null) return;
    lastResult = result;
    if (result.correct) {
      correctCount++;
      earned += question.points;
    }
  }

  void _next(Question question, AnswerResult? result) => setState(() {
        _record(question, result);
        index++;
      });

  void _leave(Question question, AnswerResult? result) {
    _record(question, result);
    Navigator.pop(context, lastResult);
  }

  @override
  Widget build(BuildContext context) {
    if (finished) return _summary(context);
    final question = pending[index];
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final total = widget.questions.length;
    final number = alreadyDone + index + 1;

    return Scaffold(
      body: QuestionPlayer(
        key: ValueKey(question.id),
        question: question,
        confirmExit: true,
        timeLimitSeconds: widget.timeLimitSeconds,
        submit: (optionId, elapsedSeconds) => _submit(question, optionId, elapsedSeconds),
        onDone: (result) => _next(question, result),
        onClose: (result) => _leave(question, result),
        header: Semantics(
          label: '${widget.title}, pregunta $number de $total',
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Eyebrow(widget.title)),
              Text('Pregunta $number/$total', style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900, color: tokens.blue)),
            ]),
            const SizedBox(height: Gap.sm),
            ProgressTrack(value: (number - 1) / total, color: tokens.blue),
          ]),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    void close() => Navigator.pop(context, lastResult);

    return PopScope(
      // Volver atrás también devuelve el resultado para actualizar los puntos.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xxl, Gap.page, Gap.xl),
            children: [
              const SizedBox(height: Gap.xl),
              const Center(child: AppMark(pixel: 8)),
              const SizedBox(height: Gap.xl),
              Text('¡${widget.title} completado!', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              const SizedBox(height: Gap.sm),
              Text(
                alreadyDone > 0 ? 'Resultado de esta partida (${pending.length} preguntas).' : 'Has respondido las ${pending.length} preguntas${widget.title == 'Reto semanal' ? ' de la semana' : ''}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall!.copyWith(fontSize: 15),
              ),
              const SizedBox(height: Gap.xl),
              StatRow(children: [
                StatFigure(value: '$correctCount/${pending.length}', label: 'Aciertos', color: tokens.greenText),
                if (widget.givesPoints) StatFigure(value: '+$earned', label: 'Puntos ganados', color: tokens.amberText),
              ]),
              const SizedBox(height: Gap.xxl),
              PushButton(label: 'Volver', onPressed: close),
            ],
          ),
        ),
      ),
    );
  }
}
