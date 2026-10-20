import 'dart:math' as math;

class Game {
  double energy = 0;
  double lifetime = 0;
  int taps = 0;
  int powerLevel = 0;
  int droneLevel = 0;
  int reactorLevel = 0;

  int get power => 1 + powerLevel;
  int get perSecond => droneLevel * (1 + reactorLevel);
  int get level => 1 + (math.sqrt(lifetime / 40)).floor();
  double get levelStart => math.pow(level - 1, 2) * 40.0;
  double get levelEnd => math.pow(level, 2) * 40.0;
  double get progress =>
      ((lifetime - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0).toDouble();
  int cost(int item) => switch (item) {
        0 => (15 * math.pow(1.55, powerLevel)).ceil(),
        1 => (40 * math.pow(1.6, droneLevel)).ceil(),
        _ => (150 * math.pow(1.8, reactorLevel)).ceil(),
      };

  void earn(double amount) {
    energy += amount;
    lifetime += amount;
  }

  int tap(int combo) {
    taps++;
    final amount = power * combo;
    earn(amount.toDouble());
    return amount;
  }

  bool buy(int item) {
    if (item < 0 || item > 2 || energy < cost(item)) return false;
    if (item == 2 && droneLevel == 0) return false;
    energy -= cost(item);
    switch (item) {
      case 0:
        powerLevel++;
        break;
      case 1:
        droneLevel++;
        break;
      case 2:
        reactorLevel++;
        break;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'energy': energy, 'lifetime': lifetime, 'taps': taps,
        'power': powerLevel, 'drone': droneLevel, 'reactor': reactorLevel,
      };

  static Game fromJson(Map<String, dynamic> data) {
    double number(String key, double cap) {
      final value = data[key];
      if (value is! num || !value.isFinite) return 0;
      return value.toDouble().clamp(0.0, cap).toDouble();
    }

    return Game()
      ..energy = number('energy', 1e100)
      ..lifetime = math.max(number('lifetime', 1e100), number('energy', 1e100))
      ..taps = number('taps', 1e15).toInt()
      ..powerLevel = number('power', 300).toInt()
      ..droneLevel = number('drone', 300).toInt()
      ..reactorLevel = number('reactor', 300).toInt();
  }
}

String compact(num value) {
  if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(1)}T';
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
  return value.floor().toString();
}
