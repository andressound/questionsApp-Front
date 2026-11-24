import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'question_bank_screen.dart';

/// Inicio del profesor: la clasificación de los estudiantes, de 10 en 10.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key, required this.user});
  final AuthUser user;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int page = 1;
  late Future<RankingPage> pageFuture = apiClient.rankingPage(page: page);

  /// Última página recibida; mantiene el total de páginas mientras carga la siguiente.
  RankingPage? lastPage;

  void _open(int target) => setState(() {
        page = target;
        pageFuture = apiClient.rankingPage(page: page);
      });

  Future<void> _refresh() async {
    _open(page);
    try {
      await pageFuture;
    } catch (_) {
      // La tarjeta muestra el error; aquí solo se espera para cerrar el indicador.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      TeacherBar(user: widget.user),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.page, Gap.page, Gap.xl),
            children: [
              FutureBuilder<RankingPage>(
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
                      icon: Icons.leaderboard_rounded,
                      title: 'Clasificación no disponible',
                      message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'No se pudo cargar. Comprueba tu conexión.',
                      actionLabel: 'Reintentar',
                      onAction: () => _open(page),
                    );
                  } else if (snapshot.data!.entries.isEmpty) {
                    body = const StatusMessage(icon: Icons.leaderboard_rounded, title: 'Aún no hay clasificación', message: 'Cuando tus estudiantes respondan retos aparecerán aquí.');
                  } else {
                    body = Leaderboard(entries: snapshot.data!.entries, currentUserId: widget.user.id);
                  }

                  return NightCard(
                    padding: const EdgeInsets.fromLTRB(18, Gap.lg, 18, Gap.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle(
                        'Clasificación',
                        trailing: lastPage == null ? null : Text('${lastPage!.total} ${lastPage!.total == 1 ? 'estudiante' : 'estudiantes'}', style: theme.textTheme.bodySmall),
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
      ),
    ]);
  }
}
