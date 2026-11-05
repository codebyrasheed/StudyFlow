import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

// ───────────────────────── helpers ─────────────────────────
const kExam = Color(0xFFFF6B8A);
const kAssign = Color(0xFF5CB8FF);
const kHabit = Color(0xFF4ADE80);
const kAccent = Color(0xFF8B5CF6);

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
Color typeColor(String t) => t == 'Exam' ? kExam : kAssign;
bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color onSurf(BuildContext c) => Theme.of(c).colorScheme.onSurface;

String rel(DateTime d) {
  final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 0) return 'in $diff days';
  return '${-diff} days ago';
}

int streak(Habit h) {
  var d = DateTime.now();
  if (!h.days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (h.days.contains(dayKey(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

// ───────────────────────── models ─────────────────────────
class Assignment {
  String id, title, subject, type;
  DateTime date;
  bool done;
  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.date,
    this.done = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'type': type,
        'date': date.millisecondsSinceEpoch,
        'done': done,
      };
  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'],
        title: j['title'],
        subject: j['subject'] ?? '',
        type: j['type'] ?? 'Assignment',
        date: DateTime.fromMillisecondsSinceEpoch(j['date']),
        done: j['done'] ?? false,
      );
}

class Habit {
  String id, name, emoji;
  List<String> days;
  Habit({required this.id, required this.name, required this.emoji, List<String>? days})
      : days = days ?? [];
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'emoji': emoji, 'days': days};
  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'] ?? '✨',
        days: List<String>.from(j['days'] ?? []),
      );
}

// ───────────────────────── store ─────────────────────────
class Store extends ChangeNotifier {
  List<Assignment> assignments = [];
  List<Habit> habits = [];
  ThemeMode mode = ThemeMode.dark;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final a = _p!.getString('assignments');
      final h = _p!.getString('habits');
      if (a != null) {
        assignments = (jsonDecode(a) as List)
            .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (h != null) {
        habits = (jsonDecode(h) as List)
            .map((e) => Habit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      mode = _p!.getString('mode') == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {}
  }

  void _save() {
    _p?.setString('assignments', jsonEncode(assignments.map((e) => e.toJson()).toList()));
    _p?.setString('habits', jsonEncode(habits.map((e) => e.toJson()).toList()));
    _p?.setString('mode', mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  List<Assignment> get sorted =>
      [...assignments]..sort((a, b) => a.date.compareTo(b.date));

  List<Assignment> get upcoming {
    final t = dateOnly(DateTime.now());
    return sorted.where((a) => !a.done && !dateOnly(a.date).isBefore(t)).toList();
  }

  void toggleMode() {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _save();
  }

  void addAssignment(Assignment a) {
    assignments.add(a);
    _save();
  }

  void updateAssignment(Assignment a) => _save();

  void deleteAssignment(String id) {
    assignments.removeWhere((a) => a.id == id);
    _save();
  }

  void addHabit(Habit h) {
    habits.add(h);
    _save();
  }

  void deleteHabit(String id) {
    habits.removeWhere((h) => h.id == id);
    _save();
  }

  void toggleHabit(Habit h, DateTime day) {
    final k = dayKey(day);
    if (h.days.contains(k)) {
      h.days.remove(k);
    } else {
      h.days.add(k);
    }
    _save();
  }
}

final store = Store();

// ───────────────────────── app ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const StudyFlowApp());
}

ThemeData buildTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: b),
      dialogBackgroundColor: b == Brightness.dark ? const Color(0xFF1B1636) : Colors.white,
    );

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) => MaterialApp(
        title: 'StudyFlow',
        debugShowCheckedModeBanner: false,
        themeMode: store.mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

// ───────────────────────── glass widgets ─────────────────────────
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final double? opacity;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    final o = opacity ?? (d ? 0.10 : 0.65);
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(o), Colors.white.withOpacity(o * 0.45)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(d ? 0.16 : 0.85)),
          ),
          child: child,
        ),
      ),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}

class Orb extends StatelessWidget {
  final Color color;
  final double size;
  const Orb(this.color, this.size, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

class Background extends StatelessWidget {
  const Background({super.key});
  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: d
                ? const [Color(0xFF0A0A18), Color(0xFF15102E), Color(0xFF0B1426)]
                : const [Color(0xFFEDE9FE), Color(0xFFE0ECFF), Color(0xFFFCE7F3)],
          ),
        ),
      ),
      Positioned(top: -90, left: -80, child: Orb(kAccent.withOpacity(d ? 0.55 : 0.40), 320)),
      Positioned(top: 260, right: -140, child: Orb(const Color(0xFF22D3EE).withOpacity(d ? 0.35 : 0.30), 360)),
      Positioned(bottom: -120, left: -60, child: Orb(const Color(0xFFEC4899).withOpacity(d ? 0.35 : 0.28), 340)),
    ]);
  }
}

class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const GlassIconBtn(this.icon, this.onTap, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Glass(
        radius: 16,
        padding: const EdgeInsets.all(11),
        onTap: onTap,
        child: Icon(icon, size: 22, color: color ?? onSurf(context)),
      );
}

class PageHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: on)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 13.5, color: on.withOpacity(0.6))),
          ]),
        ),
        if (action != null) ...[action!, const SizedBox(width: 10)],
        GlassIconBtn(
          isDark(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          store.toggleMode,
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 20, 12),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: onSurf(context))),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyCard extends StatelessWidget {
  final String emoji, text;
  const EmptyCard(this.emoji, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Glass(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onSurf(context).withOpacity(0.65))),
            ]),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

Future<bool> confirmDelete(BuildContext c, String what) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (x) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('Delete "$what"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Delete')),
      ],
    ),
  );
  return r ?? false;
}

InputDecoration deco(BuildContext c, String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: onSurf(c).withOpacity(0.07),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

// ───────────────────────── shell ─────────────────────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    final pages = const [DashboardPage(), AssignmentsPage(), CalendarPage()];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (d ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Stack(children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(idx), child: pages[idx]),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: NavBar(idx: idx, onTap: (i) => setState(() => idx = i)),
            ),
          ),
        ),
      ]),
    );
  }
}

class NavBar extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.idx, required this.onTap});
  @override
  Widget build(BuildContext context) {
    const icons = [Icons.dashboard_rounded, Icons.assignment_rounded, Icons.calendar_month_rounded];
    const labels = ['Dashboard', 'Assignments', 'Calendar'];
    final on = onSurf(context);
    return Glass(
      radius: 28,
      padding: const EdgeInsets.all(6),
      opacity: isDark(context) ? 0.12 : 0.75,
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == idx;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kAccent.withOpacity(0.28) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icons[i], color: sel ? kAccent : on.withOpacity(0.55)),
                  const SizedBox(height: 2),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? kAccent : on.withOpacity(0.55),
                      )),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ───────────────────────── dashboard ─────────────────────────
class StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const StatCard(this.value, this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: onSurf(context).withOpacity(0.65))),
          ]),
        ),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final today = DateTime.now();
        final k = dayKey(today);
        final done = store.habits.where((h) => h.days.contains(k)).length;
        final up = store.upcoming;
        final exams = up.where((a) => a.type == 'Exam').length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            PageHeader(
              title: 'Dashboard',
              subtitle: DateFormat('EEEE, d MMMM').format(today),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: StatCard('$done/${store.habits.length}', 'Habits today', kHabit)),
                const SizedBox(width: 10),
                Expanded(child: StatCard('$exams', 'Upcoming exams', kExam)),
                const SizedBox(width: 10),
                Expanded(child: StatCard('${up.length - exams}', 'Assignments due', kAssign)),
              ]),
            ),
            const SizedBox(height: 14),
            SectionTitle(
              'My Habits',
              trailing: GlassIconBtn(Icons.add_rounded, () => showHabitSheet(c)),
            ),
            if (store.habits.isEmpty)
              const EmptyCard('🌱', 'No habits yet.\nTap + to start tracking one.')
            else
              ...store.habits.map((h) => HabitTile(h: h)),
            const SectionTitle('Coming up'),
            if (up.isEmpty)
              const EmptyCard('🎉', 'Nothing due. Enjoy the free time!')
            else
              ...up.take(3).map((a) => AssignmentTile(a: a)),
          ],
        );
      },
    );
  }
}

class HabitTile extends StatelessWidget {
  final Habit h;
  const HabitTile({super.key, required this.h});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final today = DateTime.now();
    final done = h.days.contains(dayKey(today));
    final s = streak(h);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Glass(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kHabit.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(h.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on)),
              const SizedBox(height: 3),
              Text(s > 0 ? '🔥 $s day streak' : 'Start your streak today',
                  style: TextStyle(fontSize: 12.5, color: on.withOpacity(0.6))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(7, (i) {
                  final d = today.subtract(Duration(days: 6 - i));
                  final onDay = h.days.contains(dayKey(d));
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onDay ? kHabit : on.withOpacity(0.15),
                    ),
                  );
                }),
              ),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, color: on.withOpacity(0.55)),
            onPressed: () async {
              if (await confirmDelete(context, h.name)) store.deleteHabit(h.id);
            },
          ),
          GestureDetector(
            onTap: () => store.toggleHabit(h, today),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? kHabit : Colors.transparent,
                border: Border.all(color: done ? kHabit : on.withOpacity(0.35), width: 2),
              ),
              child: Icon(Icons.check_rounded,
                  size: 22, color: done ? Colors.white : Colors.transparent),
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> showHabitSheet(BuildContext context) {
  final name = TextEditingController();
  String emoji = '💧';
  const options = ['💧', '📚', '🏃', '🧘', '💪', '🥗', '😴', '✍️', '🎧', '🧹', '💻', '🙏'];
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New habit',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onSurf(ctx))),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: deco(ctx, 'Habit name (e.g. Drink water)')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((e) {
                final sel = e == emoji;
                return GestureDetector(
                  onTap: () => set(() => emoji = e),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? kAccent.withOpacity(0.3) : onSurf(ctx).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? kAccent : Colors.transparent, width: 2),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  store.addHabit(Habit(id: newId(), name: name.text.trim(), emoji: emoji));
                  Navigator.pop(ctx);
                },
                child: const Text('Add habit', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}

// ───────────────────────── assignments ─────────────────────────
class AssignmentTile extends StatelessWidget {
  final Assignment a;
  const AssignmentTile({super.key, required this.a});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final c = typeColor(a.type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => showAssignmentSheet(context, a: a),
        child: Row(children: [
          Container(
            width: 54,
            height: 58,
            decoration: BoxDecoration(
              color: c.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(DateFormat('d').format(a.date),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
              Text(DateFormat('MMM').format(a.date).toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: on.withOpacity(a.done ? 0.5 : 1),
                    decoration: a.done ? TextDecoration.lineThrough : null,
                  )),
              if (a.subject.isNotEmpty)
                Text(a.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
              const SizedBox(height: 6),
              Row(children: [
                Pill(a.type, c),
                const SizedBox(width: 8),
                Text(rel(a.date), style: TextStyle(fontSize: 12, color: on.withOpacity(0.6))),
              ]),
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                a.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: a.done ? kHabit : on.withOpacity(0.5),
              ),
              onPressed: () {
                a.done = !a.done;
                store.updateAssignment(a);
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded, color: on.withOpacity(0.55)),
              onPressed: () async {
                if (await confirmDelete(context, a.title)) store.deleteAssignment(a.id);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

Future<void> showAssignmentSheet(BuildContext context, {Assignment? a, DateTime? date}) {
  final title = TextEditingController(text: a?.title ?? '');
  final subject = TextEditingController(text: a?.subject ?? '');
  String type = a?.type ?? 'Assignment';
  DateTime d = a?.date ?? date ?? DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a == null ? 'New entry' : 'Edit entry',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onSurf(ctx))),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: deco(ctx, 'Title (e.g. Maths Final)')),
              const SizedBox(height: 12),
              TextField(controller: subject, decoration: deco(ctx, 'Subject (optional)')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Assignment', label: Text('Assignment'), icon: Icon(Icons.edit_note_rounded)),
                    ButtonSegment(value: 'Exam', label: Text('Exam'), icon: Icon(Icons.school_rounded)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => set(() => type = s.first),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(d)),
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: d,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) set(() => d = p);
                  },
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    if (a == null) {
                      store.addAssignment(Assignment(
                        id: newId(),
                        title: title.text.trim(),
                        subject: subject.text.trim(),
                        type: type,
                        date: d,
                      ));
                    } else {
                      a.title = title.text.trim();
                      a.subject = subject.text.trim();
                      a.type = type;
                      a.date = d;
                      store.updateAssignment(a);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(a == null ? 'Add' : 'Save changes', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});
  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final today = dateOnly(DateTime.now());
        final all = store.sorted.where((a) => filter == 'All' || a.type == filter).toList();
        final overdue = all.where((a) => !a.done && dateOnly(a.date).isBefore(today)).toList();
        final upcoming = all.where((a) => !a.done && !dateOnly(a.date).isBefore(today)).toList();
        final done = all.where((a) => a.done).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            PageHeader(
              title: 'Assignments',
              subtitle: 'Exams & deadlines by date',
              action: GlassIconBtn(Icons.add_rounded, () => showAssignmentSheet(c)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Wrap(
                spacing: 8,
                children: ['All', 'Exam', 'Assignment'].map((f) {
                  return ChoiceChip(
                    label: Text(f == 'All' ? 'All' : '${f}s'),
                    selected: filter == f,
                    selectedColor: kAccent.withOpacity(0.35),
                    onSelected: (_) => setState(() => filter = f),
                  );
                }).toList(),
              ),
            ),
            if (all.isEmpty) const EmptyCard('📚', 'Nothing here yet.\nTap + to add an exam or assignment.'),
            if (overdue.isNotEmpty) ...[
              const SectionTitle('Overdue'),
              ...overdue.map((a) => AssignmentTile(a: a)),
            ],
            if (upcoming.isNotEmpty) ...[
              const SectionTitle('Upcoming'),
              ...upcoming.map((a) => AssignmentTile(a: a)),
            ],
            if (done.isNotEmpty) ...[
              const SectionTitle('Completed'),
              ...done.map((a) => AssignmentTile(a: a)),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── calendar ─────────────────────────
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime focused = DateTime.now();
  DateTime selected = DateTime.now();

  Widget legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 12.5, color: onSurf(context).withOpacity(0.7))),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final on = onSurf(c);
        final dayAssign = store.sorted.where((a) => sameDay(a.date, selected)).toList();
        final dayHabits = store.habits.where((h) => h.days.contains(dayKey(selected))).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            const PageHeader(title: 'Calendar', subtitle: 'Exams, assignments & habits'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                child: TableCalendar<Object>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: focused,
                  rowHeight: 48,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (d) => isSameDay(selected, d),
                  onDaySelected: (s, f) => setState(() {
                    selected = s;
                    focused = f;
                  }),
                  onPageChanged: (f) => focused = f,
                  eventLoader: (day) => <Object>[
                    ...store.assignments.where((a) => sameDay(a.date, day)),
                    ...store.habits.where((h) => h.days.contains(dayKey(day))),
                  ],
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: on, fontSize: 17, fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: on),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: on),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: on.withOpacity(0.6), fontSize: 12),
                    weekendStyle: TextStyle(color: on.withOpacity(0.6), fontSize: 12),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: TextStyle(color: on),
                    weekendTextStyle: TextStyle(color: on.withOpacity(0.85)),
                    todayTextStyle: TextStyle(color: on, fontWeight: FontWeight.w700),
                    todayDecoration: BoxDecoration(
                      color: kAccent.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle:
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    selectedDecoration:
                        const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders<Object>(
                    markerBuilder: (ctx, day, events) {
                      if (events.isEmpty) return null;
                      final exam = events.any((e) => e is Assignment && e.type == 'Exam');
                      final asg = events.any((e) => e is Assignment && e.type != 'Exam');
                      final hab = events.any((e) => e is Habit);
                      Widget dot(Color col) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                          );
                      return Positioned(
                        bottom: 4,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (exam) dot(kExam),
                          if (asg) dot(kAssign),
                          if (hab) dot(kHabit),
                        ]),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 20, 0),
              child: Wrap(spacing: 18, children: [
                legend('Exam', kExam),
                legend('Assignment', kAssign),
                legend('Habit done', kHabit),
              ]),
            ),
            const SizedBox(height: 6),
            SectionTitle(
              DateFormat('EEEE, d MMM').format(selected),
              trailing: GlassIconBtn(Icons.add_rounded, () => showAssignmentSheet(c, date: selected)),
            ),
            if (dayAssign.isEmpty && dayHabits.isEmpty)
              const EmptyCard('🗓️', 'Nothing scheduled for this day.'),
            ...dayAssign.map((a) => AssignmentTile(a: a)),
            ...dayHabits.map((h) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Glass(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Text(h.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(h.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on)),
                      ),
                      const Pill('Completed', kHabit),
                    ]),
                  ),
                )),
          ],
        );
      },
    );
  }
}
