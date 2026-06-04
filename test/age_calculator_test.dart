import 'package:flutter_test/flutter_test.dart';
import 'package:vitalshield_ai/core/utils/age_calculator.dart';

void main() {
  group('Age Category Classification Tests', () {
    test('Ria (7) → Child classification', () {
      final category = AgeCalculator.getCategory(7);
      expect(category, AgeCategory.child);
      expect(category.label, 'Child');
    });

    test('Sarah (25) → Adult classification', () {
      final category = AgeCalculator.getCategory(25);
      expect(category, AgeCategory.adult);
      expect(category.label, 'Adult');
    });

    test('Mary (68) → Senior Citizen classification', () {
      final category = AgeCalculator.getCategory(68);
      expect(category, AgeCategory.seniorCitizen);
      expect(category.label, 'Senior Citizen');
    });
  });
}
