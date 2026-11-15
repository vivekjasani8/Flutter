import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/engine/economy.dart';

void main() {
  group('formatNumber', () {
    test('keeps the documented formats', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(950), '950');
      expect(formatNumber(12500), '12.5K');
      expect(formatNumber(2000000), '2.0M');
      expect(formatNumber(3.2e9), '3.2B');
      expect(formatNumber(7e12), '7.0T');
    });

    test('small values show up to 2 decimals, whole numbers none', () {
      expect(formatNumber(0.05), '0.05');
      expect(formatNumber(0.29), '0.29',
          reason: 'float noise must not drop it');
      expect(formatNumber(2.5), '2.50');
      expect(formatNumber(5), '5');
      expect(formatNumber(5.001), '5');
    });

    test('rounds down so the balance never looks bigger than it is', () {
      expect(formatNumber(99.5), '99');
      expect(formatNumber(99.99), '99');
      expect(formatNumber(9.999), '9.99');
      expect(formatNumber(12960), '12.9K');
      expect(formatNumber(999960), '999.9K', reason: 'no "1000.0K"');
    });

    test('a balance just under a price never reads as that price', () {
      for (final price in [50.0, 58.0, 100.0, 400.0, 3000.0, 25000.0]) {
        expect(formatNumber(price - 0.01), isNot(formatNumber(price)),
            reason: '$price');
      }
    });

    test('negatives and bad input', () {
      expect(formatNumber(-12500), '-12.5K');
      expect(formatNumber(double.nan), '0');
      expect(formatNumber(double.infinity), '0');
    });
  });
}
