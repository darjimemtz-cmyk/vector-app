import 'package:intl/intl.dart';
import '../models/item_venta.dart';

class TicketService {
  final formatDecimal = NumberFormat('0.00', 'en_US');

  String _sanitizarZpl(String texto) => texto.replaceAll(RegExp(r'[\^~]'), ' ').trim();

  /// Genera la nota de venta ZPL idéntica a Bokados con espaciado vertical holgado
  String generarTicketZPL({
    String nombreNegocio = 'NACIONAL DE ALIMENTOS Y HELADOS',
    String rfc = 'NAH850320159',
    String direccionFiscal = 'AV SAN JERONIMO 307 # 307\nSAN JERONIMO\nMONTERREY, NUEVO LEON\nC.P. 64640',
    String telefono = '81222300',
    String direccionTelefono = '',
    String mensajePie = '',
    required String folio,
    String cliente = '9618 LA GUERA II',
    String clienteAcd = '23009618',
    String vendedor = '371293 MARTINEZ MARTINEZ',
    String sucursal = '23 SAN LUIS POTOSI',
    String ruta = '',
    String metodoPago = 'EFECTIVO',
    required List<ItemVenta> articulos,
    double total = 0.0,
    double efectivo = 0.0,
    double cambio = 0.0,
  }) {
    final body = StringBuffer();
    const lineaPunteada = '------------------------------------';
    const lineaFirma = '----------------------'; // 22 guiones exactos de rúbrica

    // Sanitizar todos los textos dinámicos
    final sNombreNegocio = _sanitizarZpl(nombreNegocio);
    final sDireccionFiscal = _sanitizarZpl(direccionFiscal);
    final sCliente = _sanitizarZpl(cliente);
    final sClienteAcd = _sanitizarZpl(clienteAcd);
    final sVendedor = _sanitizarZpl(vendedor);
    final sSucursal = _sanitizarZpl(sucursal);
    final sRuta = _sanitizarZpl(ruta);

    // Fecha idéntica a Bokados con "a. m." / "p. m."
    final now = DateTime.now();
    final diaMesAnio = DateFormat('dd/MM/yyyy').format(now);
    final horaMinuto = DateFormat('hh:mm').format(now);
    final sufijoAmPm = now.hour < 12 ? 'a. m.' : 'p. m.';
    final fecha = '$diaMesAnio $horaMinuto $sufijoAmPm';

    // Cálculos matemáticos rigurosos independientes
    final double subtotalCalculado = articulos.fold(0.0, (acc, item) => acc + item.importe);
    final double iepsCalculado = articulos.fold(0.0, (acc, item) => acc + item.montoIeps);
    final double totalFinal = subtotalCalculado + iepsCalculado;
    final int totalPiezas = articulos.fold(0, (acc, item) => acc + item.cantidad);
    final int variedadProductos = articulos.length;
    final double precioUnitarioPromedio = totalPiezas > 0 ? (totalFinal / totalPiezas) : 0.0;

    // Algoritmo oficial Folio Ventas de Bokados: V + Sucursal(4) + Ruta(4) + Folio(6)
    final numSucursal = RegExp(r'\d+').firstMatch(sucursal)?.group(0) ?? '23';
    final numRuta = RegExp(r'\d+').firstMatch(ruta)?.group(0) ?? '00';
    final folioVentas = 'V${numSucursal.padLeft(4, '0')}${numRuta.padLeft(4, '0')}${folio.padLeft(6, '0')}';

    // Agrupación automática por Precio Unitario para la Tabla de Liquidación
    final Map<double, int> agrupadoPorPrecio = {};
    for (final item in articulos) {
      agrupadoPorPrecio[item.precioUnitario] =
          (agrupadoPorPrecio[item.precioUnitario] ?? 0) + item.cantidad;
    }
    final preciosOrdenados = agrupadoPorPrecio.keys.toList()..sort();

    // Margen superior holgado para librar sierra y dar aire antes de COPIA
    int y = 100;

    // 1. ENCABEZADO INSTITUCIONAL
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 26;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD-------------COPIA-------------^FS');
    y += 26;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 26;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 26;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD**** NOTA DE VENTA CONTADO ****^FS');
    y += 28;
    // Doble línea punteada arriba de Nacional de Alimentos
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$sNombreNegocio^FS');
    y += 28;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FDR.F.C. $rfc^FS');
    y += 28;

    for (final linea in sDireccionFiscal.split('\n')) {
      body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD${_sanitizarZpl(linea)}^FS');
      y += 28;
    }
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$telefono^FS');
    y += 28;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$fecha^FS');
    y += 28;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 2. DATOS DE RUTA, CLIENTE Y FOLIOS (28 puntos de separación)
    body.writeln('^FO8,$y^ADN,18,10^FDCte: $sCliente^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDCliente ACD: $sClienteAcd^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDVend: $sVendedor^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDSucursal: $sSucursal^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDRuta: $sRuta^FS');
    y += 28;
    // FOLIO REMISION en negrita (doble pasada)
    body.writeln('^FO8,$y^ADN,18,10^FDFOLIO REMISION: ${folio.padLeft(5, '0')}^FS');
    body.writeln('^FO9,$y^ADN,18,10^FDFOLIO REMISION: ${folio.padLeft(5, '0')}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDFOLIO VENTAS: $folioVentas^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDExija siempre su ticket de^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDventa para cualquier aclaracion^FS');
    y += 28;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 3. RESUMEN SUPERIOR en negrita (doble pasada texto y números)
    body.writeln('^FO8,$y^ADN,18,10^FDTOTAL A PAGAR:^FS');
    body.writeln('^FO9,$y^ADN,18,10^FDTOTAL A PAGAR:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    body.writeln('^FO181,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    y += 28;

    body.writeln('^FO8,$y^ADN,18,10^FDTOTAL DE PIEZAS:^FS');
    body.writeln('^FO9,$y^ADN,18,10^FDTOTAL DE PIEZAS:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD$totalPiezas^FS');
    body.writeln('^FO181,$y^ADN,18,10^FB188,1,0,R^FD$totalPiezas^FS');
    y += 28;

    body.writeln('^FO8,$y^ADN,18,10^FDVARIEDAD DE PRODUCTOS:^FS');
    body.writeln('^FO9,$y^ADN,18,10^FDVARIEDAD DE PRODUCTOS:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD$variedadProductos^FS');
    body.writeln('^FO181,$y^ADN,18,10^FB188,1,0,R^FD$variedadProductos^FS');
    y += 28;

    // Doble línea punteada debajo de Variedad de Productos
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 4. TABLA DE ARTÍCULOS (CNT centrado bajo el inicio de la descripción)
    body.writeln('^FO8,$y^ADN,18,10^FDLINEA NOMBRE^FS');
    y += 28;
    // CNT colocado en X=110 (justo a mitad del nombre del producto)
    body.writeln('^FO110,$y^ADN,18,10^FB50,1,0,C^FDCNT^FS');
    body.writeln('^FO160,$y^ADN,18,10^FB85,1,0,R^FDPU^FS');
    body.writeln('^FO250,$y^ADN,18,10^FB120,1,0,R^FDIMPORTE^FS');
    y += 60;

    for (int i = 0; i < articulos.length; i++) {
      final item = articulos[i];
      final sDescripcion = _sanitizarZpl(item.descripcion);
      // 2 espacios exactos para los que no llevan '*' y margen libre a la derecha
      final prefijoIeps = item.gravaIeps ? '* ' : '  ';
      final lineaTitulo = '$prefijoIeps${i + 1}.- $sDescripcion';

      // Renglón 1: Descripción completa sin mochar
      body.writeln('^FO8,$y^ADN,18,10^FD$lineaTitulo^FS');
      y += 28;

      // Renglón 2: Cantidad (en X=110), P.U. (en X=160) e Importe (en X=250)
      body.writeln('^FO110,$y^ADN,18,10^FB50,1,0,C^FD${item.cantidad}^FS');
      body.writeln('^FO160,$y^ADN,18,10^FB85,1,0,R^FD${formatDecimal.format(item.precioUnitario)}^FS');
      body.writeln('^FO250,$y^ADN,18,10^FB120,1,0,R^FD${formatDecimal.format(item.importe)}^FS');
      y += 28;
    }

    // Mini-cierre bajo artículos (guiones y total de piezas alineados en X=110)
    body.writeln('^FO110,$y^ADN,18,10^FB50,1,0,C^FD--^FS');
    body.writeln('^FO160,$y^ADN,18,10^FB85,1,0,R^FD-----^FS');
    y += 24;
    body.writeln('^FO110,$y^ADN,18,10^FB50,1,0,C^FD$totalPiezas^FS');
    body.writeln('^FO160,$y^ADN,18,10^FB85,1,0,R^FD${formatDecimal.format(precioUnitarioPromedio)}^FS');
    y += 28;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 5. BLOQUE DE SUBTOTAL E IMPUESTOS (28 puntos de separación)
    body.writeln('^FO8,$y^ADN,18,10^FDSUBTOTAL:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(subtotalCalculado)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDCREDITO:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD0.00^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDDESCTO PORC:  0%^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD0.00^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDSUBTOTAL - DSCTO:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(subtotalCalculado)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDIVA:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD0.00^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDIEPS:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(iepsCalculado)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDTOTAL A PAGAR:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB188,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    y += 28;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 6. LEYENDAS FISCALES
    body.writeln('^FO8,$y^ADN,18,10^FDP.U. No incluyen IEPS^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FD* Productos gravan IEPS^FS');
    y += 28; // Espacio limpio: SIN línea punteada falsa

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 60;

    // 7. TABLA RESUMEN POR PRECIO (28 puntos de separación)
    body.writeln('^FO20,$y^ADN,18,10^FB90,1,0,R^FDPRECIO^FS');
    body.writeln('^FO130,$y^ADN,18,10^FB110,1,0,R^FDCANTIDAD^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FDIMPORTE^FS');
    y += 28;

    for (final precio in preciosOrdenados) {
      final cant = agrupadoPorPrecio[precio]!;
      final imp = precio * cant;
      body.writeln('^FO20,$y^ADN,18,10^FB90,1,0,R^FD${formatDecimal.format(precio)}^FS');
      body.writeln('^FO120,$y^ADN,18,10^FB115,1,0,R^FD$cant^FS');
      body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD${formatDecimal.format(imp)}^FS');
      y += 28;
    }

    // Impuestos al ras izquierdo (X=8), sin empalmarse y alineados por el ':' en X=133
    body.writeln('^FO8,$y^ADN,18,10^FB125,1,0,R^FDIEPS:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD${formatDecimal.format(iepsCalculado)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FB125,1,0,R^FDDescuento:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD0.00^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FB125,1,0,R^FDIVA:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD0.00^FS');
    y += 30;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // Totalizador de piezas alineado a la derecha en la misma columna X=240
    body.writeln('^FO130,$y^ADN,18,10^FB110,1,0,R^FD$totalPiezas^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    y += 28;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 28;

    // 8. RESUMEN DE CRÉDITOS (28 puntos de separación)
    body.writeln('^FO8,$y^ADN,18,10^FDResumen de Creditos^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDSaldo Anterior:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD0.00^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDVenta:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDAbono:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD${formatDecimal.format(totalFinal)}^FS');
    y += 28;
    body.writeln('^FO8,$y^ADN,18,10^FDDescuento:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD0.00^FS');

    // Renglón en blanco para aislar Saldo
    y += 42;
    body.writeln('^FO8,$y^ADN,18,10^FDSaldo:^FS');
    body.writeln('^FO225,$y^ADN,18,10^FB143,1,0,R^FD0.00^FS');
    y += 30;

    // Línea previa antes del pagaré
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 48;

    // 9. PAGARÉ LEGAL Y FIRMA
    body.writeln('^FO8,$y^ADN,18,10^FDDebo y Pagare a Nombre de^FS');
    y += 25;
    body.writeln('^FO8,$y^ADN,18,10^FD$sNombreNegocio^FS');

    // Espacio amplio para firma física idéntico al original
    y += 150;

    // LÍNEA DE FIRMA: Centrada armónicamente en todo el ancho del papel
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaFirma^FS');
    y += 22;

    // Versión a la izquierda y Nombre y Firma en la mitad derecha bajo la línea
    // X = 35 empuja la versión hacia la derecha dejando margen limpio
    body.writeln('^FO35,$y^ADN,18,10^FDV26.3.3^FS');
    body.writeln('^FO175,$y^ADN,18,10^FDNombre y Firma^FS');

    // Avance corto para corte al ras
    y += 35;
    body.writeln('^FO8,$y^ADN,10,10^FD ^FS');

    final int largoTotal = y + 15;

    final buffer = StringBuffer();
    buffer.writeln('^XA');
    buffer.writeln('^CI28'); // Codificación UTF-8
    buffer.writeln('^PW384'); // Ancho de 58 mm
    buffer.writeln('^MD6');   // Contraste térmico estándar
    buffer.writeln('^LL$largoTotal'); // Medición dinámica
    buffer.write(body.toString());
    buffer.writeln('^XZ');

    return buffer.toString();
  }

  /// Genera el ticket ZPL de Corte con fuente matricial nativa (Font D)
  String generarCorteZPL({
    required String nombreNegocio,
    String direccionTelefono = '',
    required double totalVenta,
    required double totalEfectivo,
    required double totalTarjeta,
    required double totalTransf,
    required int totalTickets,
  }) {
    final body = StringBuffer();
    final fecha = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    const lineaPunteada = '------------------------------------';

    // Sanitizar textos dinámicos
    final sNombreNegocio = _sanitizarZpl(nombreNegocio);
    final sDireccionTelefono = _sanitizarZpl(direccionTelefono);

    int y = 50;
    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$sNombreNegocio^FS');
    y += 28;

    if (direccionTelefono.isNotEmpty) {
      body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$sDireccionTelefono^FS');
      y += 24;
    }

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FDCORTE DE CAJA / CIERRE^FS');
    y += 28;
    body.writeln('^FO15,$y^ADN,18,10^FDFecha de corte: $fecha^FS');
    y += 26;
    body.writeln('^FO15,$y^ADN,18,10^FDTickets emitidos: $totalTickets^FS');
    y += 26;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 26;

    body.writeln('^FO15,$y^ADN,18,10^FDEfectivo en caja:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB185,1,0,R^FD${formatDecimal.format(totalEfectivo)}^FS');
    y += 26;

    body.writeln('^FO15,$y^ADN,18,10^FDPagos con Tarjeta:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB185,1,0,R^FD${formatDecimal.format(totalTarjeta)}^FS');
    y += 26;

    body.writeln('^FO15,$y^ADN,18,10^FDTransferencias SPEI:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB185,1,0,R^FD${formatDecimal.format(totalTransf)}^FS');
    y += 26;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD$lineaPunteada^FS');
    y += 26;

    body.writeln('^FO15,$y^ADN,18,10^FDTOTAL DEL TURNO:^FS');
    body.writeln('^FO180,$y^ADN,18,10^FB185,1,0,R^FD${formatDecimal.format(totalVenta)}^FS');
    y += 30;

    body.writeln('^FO0,$y^ADN,18,10^FB384,1,0,C^FD*** FIN DE JORNADA ***^FS');
    y += 38;
    body.writeln('^FO15,$y^ADN,10,10^FD ^FS');

    final int largoTotal = y + 15;

    final buffer = StringBuffer();
    buffer.writeln('^XA');
    buffer.writeln('^CI28');
    buffer.writeln('^PW384');
    buffer.writeln('^MD14');
    buffer.writeln('^LL$largoTotal');
    buffer.write(body.toString());
    buffer.writeln('^XZ');

    return buffer.toString();
  }
}
