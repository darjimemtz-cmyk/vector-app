class ItemVenta {
  final String id;
  final String descripcion;
  final double precioUnitario;
  int cantidad;
  int stock;
  final bool gravaIeps;
  final bool manejaStock;

  ItemVenta({
    required this.id,
    required this.descripcion,
    required this.precioUnitario,
    this.cantidad = 1,
    this.stock = 10,
    this.gravaIeps = true,
    this.manejaStock = true,
  });

  double get importe => cantidad * precioUnitario;
  double get montoIeps => gravaIeps ? (importe * 0.08) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'descripcion': descripcion,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
        'stock': stock,
        'gravaIeps': gravaIeps,
        'manejaStock': manejaStock,
      };

  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta(
        id: map['id'],
        descripcion: map['descripcion'],
        precioUnitario: (map['precioUnitario'] as num).toDouble(),
        cantidad: map['cantidad'] ?? 1,
        stock: map['stock'] ?? 10,
        gravaIeps: map['gravaIeps'] ?? true,
        manejaStock: map['manejaStock'] ?? true,
      );
}