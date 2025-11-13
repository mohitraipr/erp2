import '../models/api_lot.dart';
import '../models/fabric_roll.dart';
import '../models/filter_options.dart';
import '../models/master.dart';
import '../models/production_flow.dart';
import '../services/api_service.dart';
import 'providers.dart';
import '../state/simple_riverpod.dart';

final fabricRollsProvider = FutureProvider<Map<String, List<FabricRoll>>>((ref) {
  return performApiCall(ref, (repo) => repo.getFabricRolls());
});

final filtersProvider = FutureProvider<FilterOptions>((ref) {
  return performApiCall(ref, (repo) => repo.getFilters());
});

final lotsProvider = FutureProvider<List<ApiLotSummary>>((ref) {
  return performApiCall(ref, (repo) => repo.getLots());
});

final lotDetailProvider = FutureProvider.family<ApiLot, int>((ref, lotId) {
  return performApiCall(ref, (repo) => repo.getLotDetail(lotId));
});

final mastersProvider = FutureProvider<List<MasterRecord>>((ref) {
  return performApiCall(ref, (repo) => repo.getMasters());
});

final productionHistoryProvider = FutureProvider.family<List<ProductionFlowEvent>, String?>(
    (ref, stage) {
  return performApiCall(ref, (repo) => repo.getProductionFlowEvents(stage: stage));
});
