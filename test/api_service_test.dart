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
  });
}
