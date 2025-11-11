import 'dart:convert';

import 'package:aurora_login_app/models/api_lot.dart';
import 'package:aurora_login_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiService.fetchMyLots', () {
    test('falls back to alternate endpoints when /api/lots returns 404', () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);

        if (request.url.path.endsWith('/api/lots')) {
          return http.Response('Not Found', 404);
        }

        final body = jsonEncode([
          {
            'id': 1,
            'lotNumber': 'LOT-001',
            'sku': 'SKU-123',
            'fabricType': 'Cotton',
          }
        ]);

        return http.Response(body, 200);
      });

      final api = ApiService(client: client);
      final lots = await api.fetchMyLots();

      expect(requestedPaths, containsAllInOrder(['/api/lots', '/api/my-lots']));
      expect(lots, hasLength(1));
      expect(lots.first, isA<ApiLotSummary>());
      expect(lots.first.lotNumber, 'LOT-001');
    });

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

      final api = ApiService(client: client);
      final lots = await api.fetchMyLots();

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

      final api = ApiService(client: client);
      final lots = await api.fetchMyLots();

      expect(lots, hasLength(2));
      expect(lots.map((e) => e.lotNumber), containsAllInOrder(['LOT-042', 'LOT-099']));
    });
  });

  group('ApiService.fetchFilters', () {
    test('returns gender and category lists from the server payload', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/filters');
        final body = jsonEncode({
          'genders': ['Men', 'Women'],
          'categories': ['Shirts', 'Pants'],
        });
        return http.Response(body, 200);
      });

      final api = ApiService(client: client);
      final filters = await api.fetchFilters();

      expect(filters.genders, ['Men', 'Women']);
      expect(filters.categories, ['Shirts', 'Pants']);
    });
  });
}
