class Cliente {
  final String id;
  final String nombre;
  final String acd;

  Cliente({
    required this.id,
    required this.nombre,
    required this.acd,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'acd': acd,
      };

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        acd: map['acd'] as String,
      );
}