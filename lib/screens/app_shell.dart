import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import 'challenges_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'teacher_shell.dart';

/// Pantalla principal tras iniciar sesión: los profesores van al banco de preguntas.
Widget shellFor(AuthUser user) => user.isTeacher ? TeacherShell(user: user) : AppShell(user: user);

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});
  final AuthUser user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  late AuthUser currentUser = widget.user;

  void _updateProgress(AnswerResult result) {
    setState(() => currentUser = currentUser.copyWith(
          points: result.points,
          completedChallenges: result.completedChallenges,
          streak: result.streak,
          bestStreak: result.bestStreak,
        ));
  }

  void _updateUser(AuthUser user) => setState(() => currentUser = user);

  Future<void> _logout() async {
    await apiClient.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _select(int index) => setState(() => selectedIndex = index);

  List<Widget> get pages => [
        HomeScreen(user: currentUser, onOpenChallenges: () => _select(1), onProgressChanged: _updateProgress),
        ChallengesScreen(user: currentUser, onProgressChanged: _updateProgress),
        ProfileScreen(user: currentUser, onUserChanged: _updateUser, onLogout: _logout),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(bottom: false, child: pages[selectedIndex]),
        bottomNavigationBar: AppTabBar(
          selectedIndex: selectedIndex,
          onSelected: _select,
          items: const [
            (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
            (Icons.track_changes_rounded, Icons.track_changes_rounded, 'Retos'),
            (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
          ],
        ),
      );
}

/// Barra inferior solo con iconos; la sección actual va sobre una pastilla.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.selectedIndex, required this.onSelected, required this.items});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Icono normal, icono elegido y nombre de cada sección.
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.night, border: Border(top: BorderSide(color: tokens.line, width: 2))),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: SizedBox(
          height: 74,
          child: Row(children: [
            for (final (index, (icon, selectedIcon, label)) in items.indexed)
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: label,
                    child: Semantics(
                      button: true,
                      selected: index == selectedIndex,
                      label: label,
                      excludeSemantics: true,
                      child: Material(
                        color: index == selectedIndex ? tokens.raised : Colors.transparent,
                        borderRadius: BorderRadius.circular(Corner.chip),
                        child: InkWell(
                          onTap: () => onSelected(index),
                          borderRadius: BorderRadius.circular(Corner.chip),
                          child: SizedBox(
                            width: 64,
                            height: 48,
                            child: Icon(index == selectedIndex ? selectedIcon : icon, size: 26, color: index == selectedIndex ? tokens.amberText : tokens.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
