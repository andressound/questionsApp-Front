import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'app_shell.dart';
import 'custom_challenges_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'question_bank_screen.dart';
import 'teacher_home_screen.dart';

/// Ventana de los profesores: clasificación, banco de preguntas, retos personalizados y perfil.
class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, required this.user});
  final AuthUser user;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int selectedIndex = 0;
  late AuthUser currentUser = widget.user;

  void _updateUser(AuthUser user) => setState(() => currentUser = user);

  Future<void> _logout() async {
    await apiClient.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _select(int index) => setState(() => selectedIndex = index);

  List<Widget> get pages => [
        TeacherHomeScreen(user: currentUser),
        QuestionBankScreen(user: currentUser),
        CustomChallengesScreen(user: currentUser),
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
            (Icons.quiz_outlined, Icons.quiz_rounded, 'Preguntas'),
            (Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Retos'),
            (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
          ],
        ),
      );
}
