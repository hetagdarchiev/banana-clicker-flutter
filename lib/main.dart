import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'tropical.dart';

const mint = Color(0xFF886010);
const violet = Color(0xFF23765B);
const muted = Color(0xFF526F62);
const panel = Color(0xFFFFFCED);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Banana Bay · Банановый кликер',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFEAF5D7),
          colorScheme: const ColorScheme.light(primary: mint, secondary: violet, surface: panel, onSurface: Color(0xFF243E31)),
          useMaterial3: true,
          fontFamily: 'sans-serif',
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF245E4C),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
        ),
        home: const ClickerPage(),
      );
}

class ClickerPage extends StatefulWidget {
  const ClickerPage({super.key});
  @override
  State<ClickerPage> createState() => _ClickerPageState();
}

class _ClickerPageState extends State<ClickerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final prefs = SharedPreferencesAsync();
  Game game = Game();
  late final AnimationController orbit;
  late final AnimationController press;
  Timer? tick;
  Timer? autosave;
  Timer? comboTimer;
  Future<void> saveQueue = Future.value();
  final particles = <({int id, int amount, double x})>[];
  int particleId = 0;
  int streak = 0;
  bool ready = false;
  bool active = true;
  bool haptics = true;
  bool saveFailed = false;
  int tab = 0;
  int get multiplier => 1 + (streak ~/ 10).clamp(0, 4).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    orbit = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
    press = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    load();
  }

  Future<void> load() async {
    var failed = false;
    try {
      final raw = await prefs.getString('nova_save_v1');
      if (raw != null) game = Game.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      haptics = await prefs.getBool('nova_haptics') ?? true;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => ready = true);
    if (failed) {
      message('Не удалось загрузить сохранение. Новая сессия начата.');
    }
    tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (active && game.perSecond > 0 && mounted) {
        setState(() => game.earn(game.perSecond / 10));
      }
    });
    autosave = Timer.periodic(const Duration(seconds: 2), (_) => save());
  }

  Future<void> save() {
    if (!ready) return Future.value();
    final snapshot = jsonEncode(game.toJson());
    final vibration = haptics;
    saveQueue = saveQueue.then((_) async {
      try {
        await prefs.setString('nova_save_v1', snapshot);
        await prefs.setBool('nova_haptics', vibration);
        if (mounted && saveFailed) setState(() => saveFailed = false);
      } catch (_) {
        if (mounted && !saveFailed) {
          setState(() => saveFailed = true);
          message('Сохранение недоступно. Прогресс пока хранится в памяти.');
        }
      }
    });
    return saveQueue;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (!active) {
      streak = 0;
      save();
    }
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  void tap() {
    if (!ready) return;
    final oldLevel = game.level;
    setState(() {
      streak++;
      final earned = game.tap(multiplier);
      if (particles.length >= 18) particles.removeAt(0);
      particles.add((id: particleId++, amount: earned, x: math.Random().nextDouble()));
    });
    press.forward(from: 0);
    if (haptics) HapticFeedback.lightImpact();
    comboTimer?.cancel();
    comboTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => streak = 0);
    });
    if (game.level > oldLevel) message('Новый остров! Уровень ${game.level} ✨');
  }

  void buy(int item) {
    setState(() {
      if (game.buy(item)) {
        if (haptics) HapticFeedback.mediumImpact();
        message('Улучшение установлено ✨');
      }
    });
    save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tick?.cancel();
    autosave?.cancel();
    comboTimer?.cancel();
    orbit.dispose();
    press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(animation: orbit, builder: (_, __) => CustomPaint(painter: TropicalBackground(reduceMotion ? 0 : orbit.value))),
          ),
        ),
        SafeArea(
          child: !ready
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1150),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      children: [
                        header(),
                        const SizedBox(height: 32),
                        LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 780;
                          final play = playArea(reduceMotion);
                          final shop = sidePanel();
                          return wide
                              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(flex: 6, child: play),
                                  const SizedBox(width: 40),
                                  Expanded(flex: 5, child: shop),
                                ])
                              : Column(children: [play, const SizedBox(height: 28), shop]);
                        }),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            saveFailed
                                ? 'Прогресс в памяти · сохранение недоступно'
                                : 'Море, солнце и ещё один банан.',
                            style: const TextStyle(color: muted, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget header() => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: mint.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)),
          child: const BananaIcon(size: 28),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BANANA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 5)),
          Text('BAY · TROPICAL CLICKER', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 2)),
        ])),
        IconButton(
          tooltip: haptics ? 'Выключить вибрацию' : 'Включить вибрацию',
          onPressed: () {
            setState(() => haptics = !haptics);
            save();
          },
          icon: Icon(haptics ? Icons.vibration : Icons.phone_android, color: muted),
        ),
        pill('LVL ${game.level}', violet),
      ]);

  Widget playArea(bool reduceMotion) => Column(children: [
        const Text('ТВОЙ БАНАНОВЫЙ УРОЖАЙ',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2.3, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Semantics(
          label: 'Бананы ${game.energy.floor()}',
          child: FittedBox(
            child: Text(compact(game.energy),
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -3, height: 1.1)),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          pill('+${compact(game.power * multiplier)} / клик', mint),
          const SizedBox(width: 8),
          pill('+${compact(game.perSecond)} / сек', violet),
        ]),
        SizedBox(
          height: 330,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = math.min(320.0, constraints.maxWidth);
            return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              IgnorePointer(
                child: SizedBox(
                  width: size, height: size,
                  child: AnimatedBuilder(
                    animation: orbit,
                    builder: (_, __) => CustomPaint(
                      painter: TropicalAura(reduceMotion ? 0 : orbit.value),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: press,
                builder: (_, child) => Transform.scale(
                  scale: reduceMotion ? 1 : 1 - math.sin(press.value * math.pi) * .09,
                  child: child,
                ),
                child: Semantics(
                  button: true,
                  label: 'Собрать бананы',
                  child: SizedBox(
                    width: size * .59, height: size * .59,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-.4, -.5),
                          colors: [Color(0xFFFFFEDE), Color(0xFFFFF0A0), Color(0xFFFFDE63), Color(0xFFF2BD44)],
                          stops: [0, .35, .72, 1],
                        ),
                        boxShadow: [
                          BoxShadow(color: mint.withValues(alpha: .25), blurRadius: 55, spreadRadius: 6),
                          BoxShadow(color: violet.withValues(alpha: .18), blurRadius: 85, spreadRadius: 12),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: tap,
                          child: const Center(child: BananaIcon(size: 145)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final p in particles)
                Positioned(
                  left: (constraints.maxWidth * .25) + p.x * constraints.maxWidth * .4,
                  top: 100,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(p.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: reduceMotion ? 250 : 850),
                      onEnd: () {
                        if (mounted) setState(() => particles.removeWhere((item) => item.id == p.id));
                      },
                      builder: (_, value, __) => Opacity(
                        opacity: 1 - value,
                        child: Transform.translate(
                          offset: Offset(0, reduceMotion ? 0 : -85 * value),
                          child: Text('+${p.amount}',
                              style: const TextStyle(color: mint, fontSize: 27, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    streak > 0 ? 'КОМБО ×$multiplier  ·  $streak кликов' : 'НАЖМИ НА БАНАН',
                    key: ValueKey(multiplier * 100000 + (streak == 0 ? 1 : 0)),
                    style: TextStyle(color: streak > 0 ? mint : muted, fontSize: 11, letterSpacing: 2),
                  ),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(height: 18),
        box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.beach_access_rounded, color: violet, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Остров ${game.level}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${(game.progress * 100).floor()}%', style: const TextStyle(color: muted, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: game.progress, minHeight: 6,
              backgroundColor: violet.withValues(alpha: .10),
              color: violet,
            ),
          ),
          const SizedBox(height: 10),
          Text('Ещё ${compact(game.levelEnd - game.lifetime)} бананов до нового острова',
              style: const TextStyle(color: muted, fontSize: 11)),
        ])),
      ]);

  Widget sidePanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Жизнь в стиле банана.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8)),
        const SizedBox(height: 8),
        const Text('Собирай урожай. Обустрой свой тропический рай.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 24),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Улучшения'), icon: Icon(Icons.tune_rounded)),
            ButtonSegment(value: 1, label: Text('Достижения'), icon: Icon(Icons.stars_rounded)),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => tab = value.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: tab == 0
              ? Column(key: const ValueKey('shop'), children: [
                  upgrade(0, 'Спелая гроздь', '+1 банан за клик', Icons.eco_rounded, mint, game.powerLevel),
                  upgrade(1, 'Банановая плантация', '+${1 + game.reactorLevel} бананов в секунду', Icons.park_rounded, violet, game.droneLevel),
                  upgrade(2, 'Тропический полив',
                      game.droneLevel == 0 ? 'Сначала купи плантацию' : '+${game.droneLevel} бананов в секунду',
                      Icons.water_drop_outlined, const Color(0xFF197D92), game.reactorLevel),
                ])
              : Column(key: const ValueKey('achievements'), children: [
                  achievement('Первый урожай', 'Сделай 10 кликов', game.taps, 10),
                  achievement('Банановый магнат', 'Собери 1 000 бананов за всё время', game.lifetime, 1000),
                  achievement('Хозяин острова', 'Купи 5 банановых плантаций', game.droneLevel, 5),
                  achievement('Король тропиков', 'Собери 100 000 бананов за всё время', game.lifetime, 100000),
                ]),
        ),
        const SizedBox(height: 6),
        box(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.waves_rounded, color: Color(0xFF197D92), size: 22),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Поймай банановую волну', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 6),
            Text('Каждые 10 быстрых кликов усиливают комбо до ×5. Пауза в 1,5 секунды сбрасывает серию.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6)),
          ])),
        ])),
      ]);

  Widget upgrade(int id, String title, String subtitle, IconData icon, Color color, int level) {
    final available = game.energy >= game.cost(id) && (id != 2 || game.droneLevel > 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          ])),
          Text('$level', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: available ? () => buy(id) : null,
            style: FilledButton.styleFrom(
              backgroundColor: color.withValues(alpha: .15),
              foregroundColor: color,
              disabledBackgroundColor: violet.withValues(alpha: .05),
              disabledForegroundColor: muted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Улучшить  ·  ${compact(game.cost(id))} 🍌'),
          ),
        ),
      ])),
    );
  }

  Widget achievement(String title, String subtitle, num current, int target) {
    final unlocked = current >= target;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: box(Row(children: [
        Icon(unlocked ? Icons.verified_rounded : Icons.lock_outline, color: unlocked ? mint : muted),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 8),
          Text(unlocked ? 'Открыто!' : '${compact(current)} / ${compact(target)}',
              style: TextStyle(color: unlocked ? mint : violet, fontSize: 11)),
        ])),
      ])),
    );
  }

  Widget pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(30)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget box(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: violet.withValues(alpha: .10)),
          boxShadow: [BoxShadow(color: violet.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: child,
      );
}

