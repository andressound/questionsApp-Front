import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/app_tokens.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, required this.onUserChanged, required this.onLogout});
  final AuthUser user;
  final ValueChanged<AuthUser> onUserChanged;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Question>> questionsFuture;
  late Future<List<Question>> weeklyFuture;
  late Future<RankingEntry> myRankFuture;

  AuthUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.points != user.points || oldWidget.user.completedChallenges != user.completedChallenges || oldWidget.user.streak != user.streak) _reload();
  }

  void _reload() {
    // El profesor no juega retos ni sale en la clasificación: su perfil no los pide.
    if (user.isTeacher) return;
    questionsFuture = apiClient.dailyQuestions();
    weeklyFuture = apiClient.weeklyQuestions();
    myRankFuture = apiClient.myRanking();
  }

  Future<void> _edit(ProfileFieldType field) async {
    final updated = await showDialog<AuthUser>(context: context, builder: (_) => EditProfileDialog(user: user, field: field));
    if (updated == null) return;
    widget.onUserChanged(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(field == ProfileFieldType.email ? 'Correo actualizado' : 'Nombre de usuario actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, Gap.xl, 18, Gap.xl),
      children: [
        Row(children: [
          UserAvatar(initials: user.initials, size: 84, glow: true),
          const SizedBox(width: Gap.lg + 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineMedium),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall!.copyWith(fontSize: 15)),
              if (user.isTeacher) ...[
                const SizedBox(height: Gap.xs),
                const Eyebrow('Profesor'),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: Gap.xl),
        if (!user.isTeacher) ...[
          FutureBuilder<RankingEntry>(
            future: myRankFuture,
            builder: (context, snapshot) {
              final rank = snapshot.data?.position;
              return StatRow(children: [
                StatFigure(value: '${user.points}', label: 'Puntos', color: tokens.amberText),
                StatFigure(value: '${user.streak}', label: 'Racha', color: tokens.amberText),
                StatFigure(value: '${user.completedChallenges}', label: 'Retos', color: tokens.greenText),
                StatFigure(value: rank == null ? '—' : '$rank.º', label: 'Puesto', color: tokens.blue),
              ]);
            },
          ),
          if (user.bestStreak > 0) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Mejor racha: ${user.bestStreak} ${user.bestStreak == 1 ? 'día' : 'días'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall!.copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: Gap.lg),
          FutureBuilder<List<List<Question>>>(
            future: Future.wait([questionsFuture, weeklyFuture]),
            builder: (context, snapshot) => _TodayTrail(daily: snapshot.data?[0], weekly: snapshot.data?[1], failed: snapshot.hasError),
          ),
          const SizedBox(height: Gap.lg),
        ],
        NightCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(children: [
              ProfileField(label: 'Nombre de usuario', value: user.username, onEdit: () => _edit(ProfileFieldType.username)),
              const Divider(),
              ProfileField(label: 'Correo', value: user.email, onEdit: () => _edit(ProfileFieldType.email)),
            ]),
          ),
        ),
        const SizedBox(height: Gap.lg),
        PushButton(label: 'Cerrar sesión', tone: ButtonTone.danger, height: 52, onPressed: widget.onLogout),
      ],
    );
  }
}

/// Recorrido de hoy en pequeño: una parada por reto unidas por una línea.
class _TodayTrail extends StatelessWidget {
  const _TodayTrail({required this.daily, required this.weekly, required this.failed});
  final List<Question>? daily;
  final List<Question>? weekly;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final list = [...?daily]..sort((a, b) => a.position.compareTo(b.position));
    final done = list.where((question) => question.completed).length;
    final current = list.indexWhere((question) => !question.completed);
    final weeklyDone = weekly?.where((question) => question.completed).length ?? 0;
    final weeklyTotal = weekly?.length ?? 0;

    final caption = failed
        ? 'No se pudo cargar el recorrido.'
        : daily == null
            ? 'Cargando…'
            : list.isEmpty
                ? 'Hoy no hay retos.'
                : '$done de ${list.length} retos${weeklyTotal > 0 ? ' · reto semanal $weeklyDone/$weeklyTotal' : ''}';

    Widget dot(int i) {
      final color = list[i].completed ? tokens.green : (i == current ? tokens.amber : tokens.node);
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: i == current ? [BoxShadow(color: tokens.amber.withValues(alpha: 0.7), blurRadius: 12)] : null,
        ),
      );
    }

    return NightCard(
      radius: 22,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Recorrido de hoy', style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900)),
        if (list.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          ExcludeSemantics(
            child: Row(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: tokens.path, borderRadius: BorderRadius.circular(2)))),
                dot(i),
              ],
            ]),
          ),
        ],
        const SizedBox(height: Gap.md),
        Text(caption, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class ProfileField extends StatelessWidget {
  const ProfileField({super.key, required this.label, required this.value, this.onEdit});
  final String label;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Semantics(
      button: true,
      label: 'Editar $label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onEdit,
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.lg, right: Gap.md),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Eyebrow(label),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                ]),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tokens.raised, borderRadius: BorderRadius.circular(Corner.icon)),
                child: Icon(Icons.edit_rounded, size: 18, color: tokens.amberText),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

enum ProfileFieldType { username, email }

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.user, required this.field});
  final AuthUser user;
  final ProfileFieldType field;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final formKey = GlobalKey<FormState>();
  late final valueController = TextEditingController(text: isEmail ? widget.user.email : widget.user.username);
  final passwordController = TextEditingController();
  bool saving = false;
  String? error;

  bool get isEmail => widget.field == ProfileFieldType.email;

  @override
  void dispose() {
    valueController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateValue(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo obligatorio';
    if (text.length > 100) return 'Máximo 100 caracteres';
    if (isEmail && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return 'Correo no válido';
    return null;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final value = valueController.text.trim().toLowerCase();
    final current = isEmail ? widget.user.email : widget.user.username;
    if (value == current) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await apiClient.updateProfile(
        user: widget.user,
        username: isEmail ? null : value,
        email: isEmail ? value : null,
        password: passwordController.text,
      );
      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo conectar con el servidor. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(isEmail ? 'Cambiar correo' : 'Cambiar nombre de usuario'),
      content: Form(
        key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Confirma el cambio con tu contraseña actual.', style: theme.textTheme.bodySmall),
          const SizedBox(height: Gap.lg),
          TextFormField(controller: valueController, autofocus: true, enabled: !saving, keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: isEmail ? 'Correo electrónico' : 'Nombre de usuario'), validator: _validateValue),
          const SizedBox(height: Gap.md),
          TextFormField(controller: passwordController, enabled: !saving, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual'), validator: (value) => (value == null || value.isEmpty) ? 'Escribe tu contraseña actual' : null, onFieldSubmitted: (_) => _save()),
          if (error != null) Padding(padding: const EdgeInsets.only(top: Gap.md), child: Text(error!, style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error))),
        ]),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        PushButton(label: 'Guardar', busy: saving, onPressed: _save, expand: false, height: 48),
      ],
    );
  }
}
