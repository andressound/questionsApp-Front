import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'challenge_stats_screen.dart';
import 'new_challenge_screen.dart';
import 'question_bank_screen.dart';

/// Retos personalizados del profesor: crearlos, ver su código y sus resultados.
class CustomChallengesScreen extends StatefulWidget {
  const CustomChallengesScreen({super.key, required this.user});
  final AuthUser user;

  @override
  State<CustomChallengesScreen> createState() => _CustomChallengesScreenState();
}

class _CustomChallengesScreenState extends State<CustomChallengesScreen> {
  late Future<List<CustomChallenge>> challengesFuture = apiClient.customChallenges();

  void _reload() => setState(() => challengesFuture = apiClient.customChallenges());

  Future<void> _create() async {
    final created = await Navigator.push<CustomChallenge>(context, MaterialPageRoute(builder: (_) => const NewChallengeScreen()));
    if (created != null && mounted) _reload();
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await challengesFuture;
    } catch (_) {
      // El FutureBuilder muestra el error; aquí solo se espera para cerrar el indicador.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TeacherBar(user: widget.user),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.page, Gap.page, Gap.xl),
            children: [
              PushButton(label: 'Crear reto', icon: Icons.add_rounded, onPressed: _create),
              const SizedBox(height: 18),
              FutureBuilder<List<CustomChallenge>>(
                future: challengesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return NightCard(
                      child: StatusMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Retos no disponibles',
                        message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'No se pudo cargar. Comprueba tu conexión.',
                        actionLabel: 'Reintentar',
                        onAction: _reload,
                      ),
                    );
                  }
                  final challenges = snapshot.data!;
                  if (challenges.isEmpty) {
                    return const NightCard(
                      child: StatusMessage(icon: Icons.emoji_events_rounded, title: 'Aún no hay retos', message: 'Crea un reto y comparte su código con tus estudiantes.'),
                    );
                  }
                  return Column(children: [
                    for (final challenge in challenges) ...[
                      _ChallengeCard(challenge: challenge),
                      const SizedBox(height: Gap.lg),
                    ],
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});
  final CustomChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final details = [
      '${challenge.questionCount} ${challenge.questionCount == 1 ? 'pregunta' : 'preguntas'}',
      '${challenge.secondsPerQuestion} s por pregunta',
      challenge.givesPoints ? 'Da puntos' : 'Sin puntos',
    ].join(' · ');

    return NightCard(
      padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(challenge.title, style: theme.textTheme.titleLarge)),
          Eyebrow(challenge.active ? 'Activo' : 'Terminado', color: challenge.active ? tokens.greenText : tokens.textMuted),
        ]),
        const SizedBox(height: Gap.xs),
        Text(details, style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.md),
        ChallengeCode(code: challenge.code),
        const SizedBox(height: Gap.md),
        Text(
          '${challenge.active ? 'Disponible hasta' : 'Terminó el'} ${formatDateTime(challenge.endsAt)} · '
          '${challenge.students} ${challenge.students == 1 ? 'estudiante' : 'estudiantes'}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.md),
        PushButton(
          label: 'Ver resultados',
          icon: Icons.bar_chart_rounded,
          tone: ButtonTone.blue,
          height: 48,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeStatsScreen(challenge: challenge))),
        ),
      ]),
    );
  }
}

/// Código del reto en grande; al tocarlo se copia.
class ChallengeCode extends StatelessWidget {
  const ChallengeCode({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Semantics(
      button: true,
      label: 'Código $code. Toca para copiarlo',
      excludeSemantics: true,
      child: Material(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(Corner.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(Corner.button),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
            child: Row(children: [
              const Eyebrow('Código'),
              const SizedBox(width: Gap.md),
              Expanded(child: Text(code, style: theme.textTheme.headlineMedium!.copyWith(color: tokens.amberText, letterSpacing: 4))),
              Icon(Icons.copy_rounded, size: 20, color: tokens.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fecha corta en hora local: "28/10 14:05".
String formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
}
