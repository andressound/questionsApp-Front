import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'weekly_run_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onOpenChallenges, this.onProgressChanged});
  final AuthUser user;
  final VoidCallback onOpenChallenges;

  /// Puntos actualizados tras jugar un reto personalizado.
  final ValueChanged<AnswerResult>? onProgressChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Question>> questionsFuture;
  late Future<List<Question>> weeklyFuture;
  late Future<List<RankingEntry>> rankingFuture;
  late Future<RankingEntry> myRankFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El progreso cambió fuera de esta pantalla: los datos del servidor ya no coinciden.
    if (oldWidget.user.points != widget.user.points || oldWidget.user.completedChallenges != widget.user.completedChallenges) _reload();
  }

  void _reload() {
    questionsFuture = apiClient.dailyQuestions();
    weeklyFuture = apiClient.weeklyQuestions();
    rankingFuture = apiClient.ranking();
    myRankFuture = apiClient.myRanking();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await Future.wait([questionsFuture, weeklyFuture, rankingFuture, myRankFuture]);
    } catch (_) {
      // Los FutureBuilder muestran el error; aquí solo se espera para cerrar el indicador.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FutureBuilder<RankingEntry>(
        future: myRankFuture,
        builder: (context, snapshot) => _StatusBar(user: widget.user, rank: snapshot.data?.position),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.page, Gap.page, Gap.xl),
            children: [
              FutureBuilder<List<Question>>(
                future: questionsFuture,
                builder: (context, snapshot) => DailyProgress(
                  questions: snapshot.data,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  failed: snapshot.hasError,
                  onOpenChallenges: widget.onOpenChallenges,
                  onRetry: () => setState(() => questionsFuture = apiClient.dailyQuestions()),
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<Question>>(
                future: weeklyFuture,
                builder: (context, snapshot) => _WeeklyShortcut(
                  questions: snapshot.data,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  failed: snapshot.hasError,
                  onPressed: widget.onOpenChallenges,
                ),
              ),
              const SizedBox(height: 18),
              CustomChallengeEntry(user: widget.user, onProgressChanged: widget.onProgressChanged),
              const SizedBox(height: 18),
              LeaderboardCard(
                future: rankingFuture,
                currentUserId: widget.user.id,
                onRetry: () => setState(() => rankingFuture = apiClient.ranking()),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

/// Barra superior con el puesto, los puntos, los retos respondidos y el avatar.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.user, required this.rank});
  final AuthUser user;

  /// Puesto en la clasificación completa; null mientras carga o si falla.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.line, width: 2))),
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _StatusItem(icon: Icons.emoji_events_rounded, iconColor: tokens.amber, value: rank == null ? '—' : '$rank.º', valueColor: tokens.amberText, label: 'Puesto'),
            _StatusItem(icon: Icons.star_rounded, iconColor: tokens.amber, value: '${user.points}', valueColor: tokens.amberText, label: 'Puntos'),
            _StatusItem(icon: Icons.check_rounded, iconColor: tokens.green, value: '${user.completedChallenges}', valueColor: tokens.greenText, label: 'Retos respondidos'),
            UserAvatar(initials: user.initials, size: 36),
          ]),
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.iconColor, required this.value, required this.valueColor, required this.label});
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: valueColor)),
        ]),
      );
}

/// Bloque principal de inicio: el camino de los retos del día y el cofre al final.
class DailyProgress extends StatelessWidget {
  const DailyProgress({super.key, required this.questions, required this.loading, required this.failed, required this.onOpenChallenges, required this.onRetry});
  final List<Question>? questions;
  final bool loading;
  final bool failed;
  final VoidCallback onOpenChallenges;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const eyebrow = Eyebrow('Retos de hoy');

    if (failed) {
      return NightCard(
        lifted: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          eyebrow,
          const SizedBox(height: Gap.sm),
          StatusMessage(icon: Icons.cloud_off_rounded, title: 'Retos no disponibles', message: 'No se pudieron cargar los retos de hoy. Comprueba tu conexión.', actionLabel: 'Reintentar', onAction: onRetry),
        ]),
      );
    }

    final list = [...?questions]..sort((a, b) => a.position.compareTo(b.position));
    final total = list.length;
    final done = list.where((question) => question.completed).length;
    final remaining = total - done;
    final finished = total > 0 && remaining == 0;

    final title = loading
        ? 'Cargando…'
        : total == 0
            ? 'Hoy no hay retos'
            : finished
                ? '¡Día completado!'
                : remaining == 1
                    ? 'Te queda 1 reto'
                    : 'Te quedan $remaining retos';

    return NightCard(
      lifted: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Semantics(
              label: loading ? 'Cargando los retos de hoy' : 'Retos de hoy: $done de $total respondidos',
              excludeSemantics: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [eyebrow, Text(title, style: theme.textTheme.headlineSmall)]),
            ),
          ),
          AppMark(pixel: 4, locked: !finished),
        ]),
        if (finished) ...[
          const SizedBox(height: Gap.sm),
          Text('Has respondido los $total retos de hoy. Vuelve mañana a por más.', style: theme.textTheme.bodySmall),
        ] else if (!loading && total > 0) ...[
          const SizedBox(height: Gap.lg),
          _TrailStrip(questions: list),
          const SizedBox(height: Gap.lg),
          PushButton(label: done == 0 ? 'Empezar' : 'Continuar', onPressed: onOpenChallenges),
        ],
      ]),
    );
  }
}

/// Versión corta del camino: una fila ondulada de paradas.
class _TrailStrip extends StatelessWidget {
  const _TrailStrip({required this.questions});
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final current = questions.indexWhere((question) => !question.completed);
    const height = 56.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final n = questions.length;
          // Paradas repartidas a lo ancho, cada una algo más arriba o abajo que la anterior.
          Offset center(int i) {
            final x = n == 1 ? constraints.maxWidth / 2 : 20 + i * (constraints.maxWidth - 40) / (n - 1);
            return Offset(x, height / 2 + (i.isEven ? -4 : 4));
          }

          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: CustomPaint(painter: TrailPainter(points: [for (var i = 0; i < n; i++) center(i)], color: tokens.path, width: 3, gap: 10))),
            for (var i = 0; i < n; i++)
              Positioned(
                left: center(i).dx - (i == current ? 20 : 16),
                top: center(i).dy - (i == current ? 20 : 16),
                child: TrailNode(
                  number: questions[i].position,
                  size: i == current ? 40 : 32,
                  state: questions[i].completed ? TrailState.done : (i == current ? TrailState.current : TrailState.locked),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

/// Tarjeta para entrar a un reto personalizado con el código del profesor.
class CustomChallengeEntry extends StatefulWidget {
  const CustomChallengeEntry({super.key, required this.user, this.onProgressChanged});
  final AuthUser user;
  final ValueChanged<AnswerResult>? onProgressChanged;

  @override
  State<CustomChallengeEntry> createState() => _CustomChallengeEntryState();
}

class _CustomChallengeEntryState extends State<CustomChallengeEntry> {
  final codeController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      setState(() => error = 'El código tiene 6 caracteres');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final run = await apiClient.joinCustomChallenge(code);
      if (!mounted) return;
      if (run.questions.every((question) => question.completed)) {
        setState(() => error = 'Ya completaste este reto');
        return;
      }
      final result = await Navigator.push<AnswerResult>(
        context,
        MaterialPageRoute(
          builder: (_) => WeeklyRunScreen(
            questions: run.questions,
            user: widget.user,
            title: run.title,
            timeLimitSeconds: run.secondsPerQuestion,
            givesPoints: run.givesPoints,
            submit: (question, optionId, elapsedSeconds) => apiClient.answerCustomQuestion(code: run.code, questionId: question.id, optionId: optionId, elapsedSeconds: elapsedSeconds),
          ),
        ),
      );
      if (result != null) widget.onProgressChanged?.call(result);
      codeController.clear();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo conectar con el servidor. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return NightCard(
      padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tokens.node, borderRadius: BorderRadius.circular(Corner.icon)),
            child: Icon(Icons.vpn_key_rounded, color: tokens.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reto de tu profesor', style: theme.textTheme.titleMedium),
              Text('Escribe el código que te dio.', style: theme.textTheme.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: Gap.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: codeController,
              enabled: !loading,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              style: theme.textTheme.titleMedium!.copyWith(letterSpacing: 3),
              decoration: InputDecoration(hintText: 'CÓDIGO', counterText: '', errorText: error, errorMaxLines: 2),
              onSubmitted: (_) => _enter(),
            ),
          ),
          const SizedBox(width: Gap.md),
          PushButton(label: 'Entrar', busy: loading, expand: false, height: 52, onPressed: _enter),
        ]),
      ]),
    );
  }
}

/// Fila que resume el reto semanal y lleva a la pestaña de retos.
class _WeeklyShortcut extends StatelessWidget {
  const _WeeklyShortcut({required this.questions, required this.loading, required this.failed, required this.onPressed});
  final List<Question>? questions;
  final bool loading;
  final bool failed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final total = questions?.length ?? 0;
    final done = questions?.where((question) => question.completed).length ?? 0;
    final caption = loading
        ? 'Cargando…'
        : failed
            ? 'No se pudo cargar'
            : total == 0
                ? 'Esta semana no hay reto'
                : done == total
                    ? '¡Completado! · $done/$total'
                    : '$done/$total · ${weeklyDeadline()}';

    return Semantics(
      button: true,
      label: 'Reto semanal, $caption',
      excludeSemantics: true,
      child: Material(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Corner.card),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Corner.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tokens.node, borderRadius: BorderRadius.circular(Corner.icon)),
                child: Icon(Icons.schedule_rounded, color: tokens.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Reto semanal', style: theme.textTheme.titleMedium),
                  Text(caption, style: theme.textTheme.bodySmall),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Clasificación" con sus estados de carga, error y lista vacía.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({
    super.key,
    required this.future,
    required this.currentUserId,
    required this.onRetry,
  });
  final Future<List<RankingEntry>> future;
  final int currentUserId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RankingEntry>>(
        future: future,
        builder: (context, snapshot) {
          final Widget body;
          if (snapshot.connectionState == ConnectionState.waiting) {
            body = const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasError || !snapshot.hasData) {
            body = StatusMessage(
              icon: Icons.leaderboard_rounded,
              title: 'Clasificación no disponible',
              message: 'No se pudo cargar. Comprueba tu conexión.',
              actionLabel: 'Reintentar',
              onAction: onRetry,
            );
          } else if (snapshot.data!.isEmpty) {
            body = const StatusMessage(icon: Icons.leaderboard_rounded, title: 'Aún no hay clasificación', message: 'Responde un reto para aparecer aquí.');
          } else {
            body = Leaderboard(entries: snapshot.data!, currentUserId: currentUserId);
          }
          return NightCard(
            padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Clasificación'),
              const SizedBox(height: Gap.md),
              body,
            ]),
          );
        },
      );
}

/// Clasificación; tu fila va resaltada.
class Leaderboard extends StatelessWidget {
  const Leaderboard({super.key, required this.entries, required this.currentUserId});
  final List<RankingEntry> entries;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => a.position.compareTo(b.position));
    return Column(children: [
      for (final (index, entry) in sorted.indexed) ...[
        if (index > 0) const SizedBox(height: Gap.xs),
        _RankRow(entry: entry, isCurrent: entry.id == currentUserId),
      ],
    ]);
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isCurrent});
  final RankingEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final (Color badge, Color onBadge) = isCurrent
        ? (tokens.blue, tokens.onBlue)
        : entry.position == 1
            ? (tokens.amber, tokens.onAmber)
            : (tokens.node, tokens.textSoft);

    return Semantics(
      label: 'Puesto ${entry.position}, ${entry.username}${isCurrent ? ' (tú)' : ''}, ${entry.points} puntos',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 6),
        decoration: isCurrent ? BoxDecoration(color: tokens.raised, borderRadius: BorderRadius.circular(Corner.chip)) : null,
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: badge),
            child: Text('${entry.position}', style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900, color: onBadge)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(isCurrent ? '${entry.username} (tú)' : entry.username,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall!.copyWith(fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w800)),
          ),
          const SizedBox(width: Gap.sm),
          Text('${entry.points}', style: theme.textTheme.titleSmall!.copyWith(fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w800, color: isCurrent ? tokens.amberText : tokens.textMuted)),
        ]),
      ),
    );
  }
}
