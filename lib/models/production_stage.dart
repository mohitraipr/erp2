enum ProductionStage {
  backPocket('back_pocket', displayName: 'Back Pocket', codeLabel: 'Lot number'),
  stitchingMaster('stitching_master',
      displayName: 'Stitching Master', codeLabel: 'Lot number'),
  jeansAssembly('jeans_assembly',
      displayName: 'Jeans Assembly', codeLabel: 'Bundle code'),
  washing('washing', displayName: 'Washing', codeLabel: 'Lot number'),
  washingIn('washing_in', displayName: 'Washing In', codeLabel: 'Piece code'),
  finishing('finishing', displayName: 'Finishing', codeLabel: 'Bundle code');

  final String apiName;
  final String displayName;
  final String codeLabel;

  const ProductionStage(this.apiName,
      {required this.displayName, required this.codeLabel});

  bool get requiresMaster => {
        ProductionStage.backPocket,
        ProductionStage.stitchingMaster,
        ProductionStage.jeansAssembly,
        ProductionStage.finishing,
      }.contains(this);

  bool get supportsRejectedPieces =>
      this == ProductionStage.jeansAssembly || this == ProductionStage.washingIn;

  bool get usesBundleCode =>
      this == ProductionStage.jeansAssembly || this == ProductionStage.finishing;

  bool get usesPieceCode => this == ProductionStage.washingIn;

  bool get usesLotCode =>
      this == ProductionStage.backPocket ||
      this == ProductionStage.stitchingMaster ||
      this == ProductionStage.washing;

  static ProductionStage? fromRole(String role) {
    final normalized = role.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'back_pocket':
        return ProductionStage.backPocket;
      case 'stitching_master':
        return ProductionStage.stitchingMaster;
      case 'jeans_assembly':
        return ProductionStage.jeansAssembly;
      case 'washing':
        return ProductionStage.washing;
      case 'washing_in':
        return ProductionStage.washingIn;
      case 'finishing':
        return ProductionStage.finishing;
      default:
        return null;
    }
  }
}
