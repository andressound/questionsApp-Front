import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';
import 'weekly_run_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key, required this.user, required this.onProgressChanged});
  final AuthUser user;
  final ValueChanged<AnswerResult> onProgressChanged;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late Future<List<Question>> questionsFuture;
  late Future<List<Question>> weeklyFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    questionsFuture = apiClient.dailyQuestions();
    weeklyFuture = apiClient.weeklyQuestions();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await Future.wait([questionsFuture, weeklyFuture]);
    } catch (_) {
      // Los FutureBuilder muestran el error.
    }
  }

  Future<void> _openWeekly(List<Question> questions) async {
    final result = await Navigator.push<AnswerResult>(context, MaterialPageRoute(builder: (_) => WeeklyRunScreen(questions: questions, user: widget.user)));
    if (result != null) widget.onProgressChanged(result);
    if (mounted) setState(_reload);
  }

  Future<void> _openQuiz(Question question) async {
    final result = await Navigator.push<AnswerResult>(context, MaterialPageRoute(builder: (_) => QuizScreen(question: question, user: widget.user)));
    if (result != null) widget.onProgressChanged(result);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: questionsFuture,
      builder: (context, snapshot) {
        final Widget body;
        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError || !snapshot.hasData) {
          body = NightCard(
            child: StatusMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Retos no disponibles',
              message: 'No se pudieron cargar los retos de hoy. Comprueba tu conexión.',
              actionLabel: 'Reintentar',
              onAction: () => setState(() => questionsFuture = apiClient.dailyQuestions()),
            ),
          );
        } else if (snapshot.data!.isEmpty) {
          body = const NightCard(child: StatusMessage(icon: Icons.event_available_rounded, title: 'Hoy no hay retos', message: 'Vuelve mañana para jugar los nuevos.'));
        } else {
          body = ChallengeTrail(questions: snapshot.data!, initials: widget.user.initials, onPlay: _openQuiz);
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
            children: [
              FutureBuilder<List<Question>>(
                future: weeklyFuture,
                builder: (context, weekly) => WeeklyChallengeCard(
                  questions: weekly.data,
                  loading: weekly.connectionState == ConnectionState.waiting,
                  failed: weekly.hasError,
                  onPlay: () => _openWeekly(weekly.data!),
                  onRetry: () => setState(() => weeklyFuture = apiClient.weeklyQuestions()),
                ),
              ),
              const SizedBox(height: Gap.xl),
              const Padding(padding: EdgeInsets.symmetric(horizontal: Gap.xs), child: Eyebrow('Retos diarios')),
              const SizedBox(height: Gap.sm),
              body,
            ],
          ),
        );
      },
    );
  }
}

/// Reto semanal: progreso de la semana y botón para jugar las pendientes seguidas.
class WeeklyChallengeCard extends StatelessWidget {
  const WeeklyChallengeCard({super.key, required this.questions, required this.loading, required this.failed, required this.onPlay, required this.onRetry});
  final List<Question>? questions;
  final bool loading;
  final bool failed;
  final VoidCallback onPlay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);

    if (failed) {
      return NightCard(
        lifted: true,
        child: StatusMessage(icon: Icons.cloud_off_rounded, title: 'Reto semanal no disponible', message: 'No se pudo cargar. Comprueba tu conexión.', actionLabel: 'Reintentar', onAction: onRetry),
      );
    }

    final total = questions?.length ?? 0;
    final done = questions?.where((question) => question.completed).length ?? 0;
    final finished = total > 0 && done == total;
    final title = loading
        ? 'Cargando…'
        : total == 0
            ? 'Sin reto esta semana'
            : finished
                ? '¡Completado!'
                : '$done de $total preguntas';

    return NightCard(
      lifted: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Gap.md),
      child: Row(children: [
        Expanded(
          child: Semantics(
            label: loading ? 'Cargando el reto semanal' : 'Reto semanal, $title. ${weeklyDeadline()}',
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Eyebrow('Reto semanal'),
              Text(title, style: theme.textTheme.titleLarge!.copyWith(color: finished ? tokens.greenText : null)),
              const SizedBox(height: 6),
              ProgressTrack(value: total == 0 ? 0 : done / total, color: finished ? tokens.green : tokens.blue),
              if (!loading && total > 0) ...[
                const SizedBox(height: 6),
                Text(finished ? 'Vuelve el lunes a por el siguiente.' : '${weeklyDeadline()} · 15 s por pregunta', style: theme.textTheme.bodySmall!.copyWith(fontSize: 13)),
              ],
            ]),
          ),
        ),
        if (!loading && total > 0 && !finished) ...[
          const SizedBox(width: Gap.md),
          PushButton(label: done == 0 ? 'Empezar' : 'Seguir', tone: ButtonTone.blue, onPressed: onPlay, expand: false, height: 46),
        ],
      ]),
    );
  }
}

/// Camino serpenteante con los retos del día y el cofre al final. Se juegan en
/// orden: solo el siguiente está abierto y los posteriores quedan bloqueados.
class ChallengeTrail extends StatelessWidget {
  const ChallengeTrail({super.key, required this.questions, required this.initials, required this.onPlay});
  final List<Question> questions;
  final String initials;
  final ValueChanged<Question> onPlay;

  static const _step = 104.0;
  static const _top = 100.0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sorted = [...questions]..sort((a, b) => a.position.compareTo(b.position));
    final current = sorted.indexWhere((question) => !question.completed);
    final finished = current == -1;
    final n = sorted.length;
    final height = _top + n * _step + 40;

    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        // El camino baja haciendo eses; la última parada es el cofre.
        Offset center(int i) => Offset(width / 2 + math.sin(i * 1.1) * width * 0.24, _top + i * _step);
        final points = [for (var i = 0; i <= n; i++) center(i)];

        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _SkyPainter(star: tokens.textSoft, cloud: const Color(0xFF16203C)))),
          Positioned.fill(child: CustomPaint(painter: TrailPainter(points: points, color: tokens.path))),
          for (final (i, question) in sorted.indexed)
            _place(
              center(i),
              size: i == current ? 80 : 68,
              child: TrailNode(
                number: question.position,
                size: i == current ? 80 : 68,
                state: question.completed ? TrailState.done : (i == current ? TrailState.current : TrailState.locked),
                onPressed: question.completed
                    ? null
                    : i == current
                        ? () => onPlay(question)
                        : () => _showLocked(context, sorted[current]),
                semanticLabel: question.completed
                    ? 'Reto ${question.position} respondido'
                    : i == current
                        ? 'Jugar reto ${question.position}, ${question.points} ${question.points == 1 ? 'punto' : 'puntos'}'
                        : 'Reto ${question.position} bloqueado. Responde antes el reto ${sorted[current].position}',
              ),
            ),
          if (!finished)
            Positioned(left: center(current).dx + 22, top: center(current).dy - 92, child: _AvatarPin(initials: initials)),
          Positioned(
            left: points.last.dx - 35,
            top: points.last.dy - 25,
            child: AppMark(pixel: 5, locked: !finished),
          ),
        ]);
      }),
    );
  }

  void _showLocked(BuildContext context, Question next) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Bloqueado. Responde antes el reto ${next.position}.')));
  }

  Widget _place(Offset center, {required double size, required Widget child}) =>
      Positioned(left: center.dx - size / 2, top: center.dy - size / 2, child: child);
}

/// Chincheta con las iniciales del jugador junto al reto que le toca.
class _AvatarPin extends StatelessWidget {
  const _AvatarPin({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -math.pi / 4,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.blue,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22), bottomRight: Radius.circular(22), bottomLeft: Radius.circular(4)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 10)],
          ),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Text(initials, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900, fontSize: 14, color: tokens.onBlue)),
          ),
        ),
      ),
    );
  }
}

/// Cielo de fondo: algunas estrellas y nubes oscuras, repartidas a lo alto.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.star, required this.cloud});
  final Color star;
  final Color cloud;

  // Posiciones relativas al tamaño del camino: x, y, radio.
  static const _stars = [(0.08, 0.02, 1.5), (0.88, 0.08, 1.0), (0.15, 0.3, 1.0), (0.93, 0.42, 1.5), (0.05, 0.62, 1.0), (0.8, 0.75, 1.0), (0.5, 0.93, 1.5)];
  static const _clouds = [(0.25, 0.12, 0.44, 0.17), (0.5, 0.38, 0.46, 0.2), (0.05, 0.66, 0.6, 0.26)];

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = cloud;
    for (final (x, y, w, h) in _clouds) {
      canvas.drawOval(Rect.fromLTWH(x * size.width, y * size.height, w * size.width, h * size.height), cloudPaint);
    }
    final starPaint = Paint()..color = star;
    for (final (x, y, r) in _stars) {
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, starPaint);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.star != star || oldDelegate.cloud != cloud;
}
