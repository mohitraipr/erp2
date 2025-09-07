import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_login_app/models/fabric_roll.dart';

void main() {
  test('FabricRoll.fromJson parses string weight', () {
    final roll = FabricRoll.fromJson({
      'roll_no': '001',
      'unit': 'kg',
      'per_roll_weight': '12.5',
      'vendor_name': 'Vendor',
    });

    expect(roll.perRollWeight, 12.5);
  });

  test('FabricRoll.fromJson handles invalid weight', () {
    final roll = FabricRoll.fromJson({
      'roll_no': '001',
      'unit': 'kg',
      'per_roll_weight': 'invalid',
      'vendor_name': 'Vendor',
    });

    expect(roll.perRollWeight, 0.0);
  });
}

