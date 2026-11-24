import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';

/// Envía la respuesta al backend; `optionId` nulo significa tiempo agotado o abandono.
typedef SubmitAnswer = Future<AnswerResult> Function(int? optionId, int elapsedSeconds);

/// Pantalla de un reto diario: una sola pregunta y vuelta a la lista con el resultado.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key, required this.question, required this.user});
  final Question question;
  final AuthUser user;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: QuestionPlayer(
          question: question,
          submit: (optionId, elapsedSeconds) => apiClient.answerDailyQuestion(questionId: question.id, optionId: optionId, elapsedSeconds: elapsedSeconds),
          onDone: (result) => Navigator.pop(context, result),
          onClose: (result) => Navigator.pop(context, result),
        ),
      );
}

/// Una pregunta con su cuenta atrás, opciones y resultado. No navega: avisa con
/// [onDone] tras mostrar el resultado y con [onClose] si el jugador sale.
class QuestionPlayer extends StatefulWidget {
  const QuestionPlayer({super.key, required this.question, required this.submit, required this.onDone, required this.onClose, this.header, this.confirmExit = false, this.timeLimitSeconds = 15});
  final Question question;
  final SubmitAnswer submit;
  final ValueChanged<AnswerResult?> onDone;
  final ValueChanged<AnswerResult?> onClose;
  final Widget? header;

  /// Permite salir con la pregunta en curso, tras confirmar que contará como fallo.
  final bool confirmExit;

  /// Segundos de la cuenta atrás; los retos personalizados eligen el suyo.
  final int timeLimitSeconds;

  @override
  State<QuestionPlayer> createState() => _QuestionPlayerState();
}

class _QuestionPlayerState extends State<QuestionPlayer> {
  Timer? timer;
  late int secondsLeft = widget.timeLimitSeconds;
  int? selectedOptionId;
  bool? selectedCorrect;
  bool answered = false;
  AnswerResult? result;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || answered) return;
      if (secondsLeft <= 1) {
        setState(() => secondsLeft = 0);
        _answer(null);
      } else {
        setState(() => secondsLeft--);
        if (secondsLeft <= 5) HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  /// Registra la respuesta (o el fallo si [option] es nulo) y devuelve el resultado.
  Future<AnswerResult?> _submit(QuestionOption? option) async {
    timer?.cancel();
    setState(() {
      answered = true;
      selectedOptionId = option?.id;
    });
    try {
      result = await widget.submit(option?.id, widget.timeLimitSeconds - secondsLeft);
      // El backend decide si la opción es correcta; la pregunta no trae la respuesta.
      if (mounted) setState(() => selectedCorrect = result!.correct);
      if (result!.correct) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return result;
  }

  Future<void> _answer(QuestionOption? option) async {
    if (answered) return;
    final result = await _submit(option);
    // Pausa para que se lea el resultado antes de seguir; más larga si también hay aviso de racha.
    await Future<void>.delayed(Duration(milliseconds: (result?.streakBonus ?? 0) > 0 ? 2400 : 1400));
    if (mounted) widget.onDone(result);
  }

  Future<void> _requestExit() async {
    if (answered) {
      widget.onClose(result);
      return;
    }
    if (!widget.confirmExit) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del reto?'),
        content: Text('Lo respondido se guarda, pero esta pregunta contará como fallo.', style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir')),
          PushButton(label: 'Salir', tone: ButtonTone.danger, onPressed: () => Navigator.pop(context, true), expand: false, height: 48),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    // Si el tiempo se agotó con el diálogo abierto, la respuesta ya está enviada.
    if (!answered) await _submit(null);
    if (mounted) widget.onClose(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final question = widget.question;
    final timedOut = answered && selectedOptionId == null;

    return PopScope(
      // La salida pasa siempre por _requestExit para devolver el resultado.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
          children: [
            Row(children: [
              SquareIconButton(icon: Icons.close_rounded, tooltip: 'Salir', size: 48, color: tokens.textSoft, onPressed: answered || widget.confirmExit ? _requestExit : null),
              const SizedBox(width: Gap.md),
              Expanded(child: _TimerBar(secondsLeft: secondsLeft, total: widget.timeLimitSeconds)),
            ]),
            if (widget.header != null) ...[const SizedBox(height: Gap.lg), widget.header!],
            const SizedBox(height: Gap.lg),
            NightCard(
              lifted: true,
              padding: const EdgeInsets.all(Gap.page),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Eyebrow('Reto ${question.position}')),
                  Text('+${question.points} ${question.points == 1 ? 'pt' : 'pts'}', style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900, color: tokens.amberText)),
                ]),
                const SizedBox(height: Gap.sm),
                Text(question.text, style: theme.textTheme.headlineSmall!.copyWith(fontSize: 21, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: Gap.lg),
            if (timedOut)
              const Padding(padding: EdgeInsets.only(bottom: Gap.lg), child: _ResultBanner(correct: false, timedOut: true, points: 0))
            else if (selectedCorrect != null)
              Padding(padding: const EdgeInsets.only(bottom: Gap.lg), child: _ResultBanner(correct: selectedCorrect!, timedOut: false, points: question.points)),
            if ((result?.streakBonus ?? 0) > 0) Padding(padding: const EdgeInsets.only(bottom: Gap.lg), child: _StreakBanner(streak: result!.streak, bonus: result!.streakBonus)),
            for (final (index, option) in question.options.indexed) ...[
              if (index > 0) const SizedBox(height: Gap.md),
              AnswerTile(
                letter: String.fromCharCode(65 + index),
                text: option.text,
                selected: selectedOptionId == option.id,
                selectedCorrect: selectedOptionId == option.id ? selectedCorrect : null,
                enabled: !answered,
                onTap: () => _answer(option),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mensaje de resultado: verde si acertaste, rojo si no.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.correct, required this.timedOut, required this.points});
  final bool correct;
  final bool timedOut;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final message = timedOut
        ? '¡Se acabó el tiempo! Cuenta como fallo.'
        : correct
            ? '¡Correcto! Ganas $points ${points == 1 ? 'punto' : 'puntos'}.'
            : 'Respuesta incorrecta.';
    final (Color fill, Color foreground) = correct ? (tokens.green, tokens.onGreen) : (tokens.danger, tokens.onBlue);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Corner.button + 2),
          boxShadow: [BoxShadow(color: correct ? tokens.greenShadow : const Color(0xFFB9505C), offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          Icon(timedOut ? Icons.timer_off_rounded : (correct ? Icons.check_circle_rounded : Icons.cancel_rounded), color: foreground),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(message, style: theme.textTheme.titleMedium!.copyWith(color: foreground))),
        ]),
      ),
    );
  }
}

/// Aviso de racha al completar el reto diario, con los puntos extra que suma.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.bonus});
  final int streak;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: NightCard(
        radius: Corner.button + 2,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
        child: Row(children: [
          Icon(Icons.local_fire_department_rounded, color: tokens.amberText),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'Racha de $streak ${streak == 1 ? 'día' : 'días'} · +$bonus ${bonus == 1 ? 'punto' : 'puntos'} de bonus',
              style: theme.textTheme.titleMedium!.copyWith(color: tokens.amberText),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Barra de tiempo; en los últimos 5 segundos se pone roja.
class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.secondsLeft, required this.total});
  final int secondsLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final urgent = secondsLeft <= 5;
    return Semantics(
      label: 'Quedan $secondsLeft segundos',
      excludeSemantics: true,
      child: Row(children: [
        Icon(Icons.timer_rounded, size: 22, color: urgent ? tokens.danger : tokens.blue),
        const SizedBox(width: Gap.sm),
        Expanded(child: ProgressTrack(value: secondsLeft / total, color: urgent ? tokens.danger : tokens.green, height: 12)),
        const SizedBox(width: Gap.sm),
        SizedBox(
          width: 36,
          child: Text('${secondsLeft}s', textAlign: TextAlign.right, style: theme.textTheme.titleMedium!.copyWith(color: urgent ? tokens.danger : tokens.text)),
        ),
      ]),
    );
  }
}

/// Opción de respuesta como tarjeta con relieve y su letra en un círculo.
class AnswerTile extends StatelessWidget {
  const AnswerTile({super.key, required this.letter, required this.text, this.selected = false, this.selectedCorrect, this.enabled = true, this.onTap});
  final String letter;
  final String text;
  final bool selected;
  final bool? selectedCorrect;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);

    // Relleno, sombra, color de la letra y del texto según el estado.
    final (Color fill, Color shadow, Color badge, Color onBadge, Color foreground) = switch (selectedCorrect) {
      true => (tokens.green, tokens.greenShadow, tokens.onGreen, tokens.green, tokens.onGreen),
      false => (tokens.danger, const Color(0xFFB9505C), tokens.onBlue, tokens.danger, tokens.onBlue),
      null when selected => (tokens.raised, tokens.cardShadow, tokens.amber, tokens.onAmber, tokens.text),
      null => (tokens.card, tokens.cardShadow, tokens.node, tokens.textSoft, tokens.text),
    };
    final dimmed = !enabled && !selected;

    final Widget trailing = switch (selectedCorrect) {
      _ when !selected => const SizedBox.shrink(),
      null => SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: tokens.amber)),
      true => Icon(Icons.check_rounded, color: foreground, semanticLabel: 'Correcta'),
      false => Icon(Icons.close_rounded, color: foreground, semanticLabel: 'Incorrecta'),
    };

    final radius = BorderRadius.circular(Corner.button + 2);
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Semantics(
        button: enabled,
        label: 'Opción $letter: $text',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: fill,
            borderRadius: radius,
            shadowColor: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: selected && selectedCorrect == null ? Border.all(color: tokens.amber, width: 2) : null,
                boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 4))],
                color: fill,
              ),
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onTap?.call();
                      }
                    : null,
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: badge),
                        child: Text(letter, style: theme.textTheme.titleMedium!.copyWith(color: onBadge)),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(child: Text(text, style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w800, color: foreground))),
                      const SizedBox(width: Gap.sm),
                      trailing,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
