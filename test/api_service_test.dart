import 'dart:convert';

import 'package:aurora_login_app/models/api_lot.dart';
import 'package:aurora_login_app/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient.fetchLots', () {
    test('parses nested lot collections from server payloads', () async {
      final client = MockClient((request) async {
        final body = jsonEncode({
          'data': {
            'lots': [
              {
                'id': 7,
                'lot_number': 'LOT-007',
                'sku': 'SKU-789',
                'fabric_type': 'Polyester',
              }
            ]
          }
        });

        return http.Response(body, 200);
      });

      final api = ApiClient(baseUrl: 'http://localhost', client: client);
      final lots = await api.fetchLots();

      expect(lots, hasLength(1));
      expect(lots.single.lotNumber, 'LOT-007');
      expect(lots.single.fabricType, 'Polyester');
    });

    test('extracts lots from deeply nested payloads without duplication', () async {
      final client = MockClient((request) async {
        final body = jsonEncode({
          'meta': {'status': 'ok'},
          'data': {
            'result': {
              'items': [
                {
                  'lotID': '42',
                  'lot_no': 'LOT-042',
                  'sku': 'SKU-420',
                  'fabric_type': 'Denim',
                },
                {
                  'lot_id': 99,
                  'lotNo': 'LOT-099',
                  'sku': 'SKU-990',
                  'fabricType': 'Linen',
                },
              ],
              'pagination': {'page': 1, 'size': 25},
            },
            'summary': {
              'count': 2,
              'lots': [
                {
                  // Duplicate of LOT-042 should be ignored by fingerprint.
                  'lotID': '42',
                  'lot_no': 'LOT-042',
                  'sku': 'SKU-420',
                  'fabric_type': 'Denim',
                }
              ],
            },
          },
        });

        return http.Response(body, 200);
      });

      final api = ApiClient(baseUrl: 'http://localhost', client: client);
      final lots = await api.fetchLots();

      expect(lots, hasLength(2));
      expect(lots.map((e) => e.lotNumber), containsAllInOrder(['LOT-042', 'LOT-099']));
    });
  });

  group('ApiClient.fetchFilters', () {
    test('returns gender and category lists from the server payload', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/filters');
        final body = jsonEncode({
          'genders': ['Men', 'Women'],
          'categories': ['Shirts', 'Pants'],
        });
        return http.Response(body, 200);
      });

      final api = ApiClient(baseUrl: 'http://localhost', client: client);
      final filters = await api.fetchFilters();

      expect(filters.genders, ['Men', 'Women']);
      expect(filters.categories, ['Shirts', 'Pants']);
    });
  });
}
