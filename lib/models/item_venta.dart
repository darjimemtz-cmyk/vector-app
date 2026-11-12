class ItemVenta {
  final String id;
  final String descripcion;
  final double precioUnitario;
  int cantidad;
  int stock;
  final bool gravaIeps; // true: Botana con 8% de IEPS (*), false: Exento (Charras/Tostadas)

  ItemVenta({
    required this.id,
    required this.descripcion,
    required this.precioUnitario,
    this.cantidad = 1,
    this.stock = 10,
    this.gravaIeps = true,
  });

  // Cálculo automático del importe base en tiempo real
  double get importe => cantidad * precioUnitario;

  // Cálculo del IEPS correspondiente a este renglón (8% si grava)
  double get montoIeps => gravaIeps ? (importe * 0.08) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'descripcion': descripcion,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
        'stock': stock,
        'gravaIeps': gravaIeps,
      };

  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta(
        id: map['id'],
        descripcion: map['descripcion'],
        precioUnitario: (map['precioUnitario'] as num).toDouble(),
        cantidad: map['cantidad'] ?? 1,
        stock: map['stock'] ?? 10,
        gravaIeps: map['gravaIeps'] ?? true,
      );
}