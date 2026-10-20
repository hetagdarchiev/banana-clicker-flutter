import 'package:flutter_test/flutter_test.dart';
import 'package:statefulclickcounter/game.dart';

void main() {
  test('Cannot buy without energy, purchases deduct exact cost', () {
    final game = Game();
    expect(game.buy(0), false);
    game.earn(15);
    expect(game.buy(0), true);
    expect(game.energy, 0);
    expect(game.power, 2);
    expect(game.lifetime, 15);
  });
  test('Reactor requires a drone and improves its output', () {
    final game = Game()..earn(1000);
    expect(game.buy(2), false);
    expect(game.buy(1), true);
    expect(game.perSecond, 1);
    expect(game.buy(2), true);
    expect(game.perSecond, 2);
  });
  test('Combo applies to taps and lifetime survives spending', () {
    final game = Game();
    expect(game.tap(5), 5);
    expect(game.taps, 1);
    expect(game.lifetime, 5);
    game.earn(35);
    expect(game.level, 2);
    expect(game.progress, 0);
    game.buy(0);
    expect(game.level, 2);
  });
  test('Save round trip preserves progression', () {
    final game = Game()..earn(300);
    game.buy(1);
    final loaded = Game.fromJson(game.toJson());
    expect(loaded.toJson(), game.toJson());
  });
  test('Malformed fields do not create negative or nonfinite balances', () {
    final game = Game.fromJson({'energy': -5, 'lifetime': double.nan, 'power': 'bad'});
    expect(game.energy, 0);
    expect(game.lifetime, 0);
    expect(game.power, 1);
  });
}
