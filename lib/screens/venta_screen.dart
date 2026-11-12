import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_venta.dart';
import '../data/catalogo_datos.dart';
import '../services/ticket_service.dart';
import '../services/licencia_service.dart';
import '../services/printer_service.dart';
import '../services/actualizacion_service.dart';
import 'package:ota_update/ota_update.dart';

class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<ItemVenta> _carrito = [];
  final formatMoneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  int _tabSeleccionada = 1; // 0: PRODUCTOS, 1: VENTA, 2: INFORME

  // Catálogo inicial oficial cargado desde catalogo_datos.dart
  final List<ItemVenta> _catalogo = List.from(catalogoInicial);

  final List<Map<String, dynamic>> _historialVentas = [];
  String _filtroBusqueda = '';

  // Datos institucionales y de ruta (Bokados)
  String _nombreNegocio = 'NACIONAL DE ALIMENTOS Y HELADOS';
  String _rfc = 'NAH850320159';
  String _datosNegocio = 'AV SAN JERONIMO 307 # 307\nSAN JERONIMO\nMONTERREY, NUEVO LEON\nC.P. 64640';
  String _telefono = '81222300';
  String _vendedor = '';
  String _sucursal = '23 SAN LUIS POTOSI';
  String _ruta = '30';
  String _nombreCliente = '9618 LA GUERA II';
  String _clienteAcd = '23009618';
  String _mensajePie = '¡GRACIAS POR SU COMPRA!';

  bool _licenciaActiva = true;
  String _terminalId = '';
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    _cargarDatosLocales();
  }

  Future<void> _cargarDatosLocales() async {
    final prefs = await SharedPreferences.getInstance();

    final int versionGuardada = prefs.getInt('version_catalogo') ?? 1;
    final catalogoJson = prefs.getString('catalogo');

    // Si ya tiene la versión 2 o superior guardada, respeta existencias y cambios locales
    if (catalogoJson != null && versionGuardada >= 2) {
      final List decodificado = jsonDecode(catalogoJson);
      setState(() {
        _catalogo.clear();
        _catalogo.addAll(decodificado.map((e) => ItemVenta.fromMap(e)));
      });
    } else {
      // Primera vez o actualización: migra a los 137 productos oficiales con nuevo precio
      setState(() {
        _catalogo.clear();
        _catalogo.addAll(catalogoInicial);
      });
      await prefs.setInt('version_catalogo', 2);
      await _guardarCatalogo();
    }

    final historialJson = prefs.getString('historial');
    if (historialJson != null) {
      final List decodificado = jsonDecode(historialJson);
      setState(() {
        _historialVentas.clear();
        _historialVentas.addAll(List<Map<String, dynamic>>.from(decodificado));
      });
    }

    // Sincroniza silenciosamente switch y fecha límite si hay internet
    await LicenciaService.sincronizarEnLinea();
    final idTerm = await LicenciaService.obtenerTerminalId();
    final activa = await LicenciaService.isLicenciaValida();
    final fechaVenc = await LicenciaService.obtenerFechaVencimiento();

    setState(() {
      _nombreNegocio = prefs.getString('nombreNegocio') ?? _nombreNegocio;
      _rfc = prefs.getString('rfc') ?? _rfc;
      _datosNegocio = prefs.getString('datosNegocio') ?? _datosNegocio;
      _telefono = prefs.getString('telefono') ?? _telefono;
      _vendedor = prefs.getString('vendedor') ?? _vendedor;
      _sucursal = prefs.getString('sucursal') ?? _sucursal;
      _ruta = prefs.getString('ruta') ?? _ruta;
      _nombreCliente = prefs.getString('nombreCliente') ?? _nombreCliente;
      _clienteAcd = prefs.getString('clienteAcd') ?? _clienteAcd;
      _mensajePie = prefs.getString('mensajePie') ?? _mensajePie;
      _terminalId = idTerm;
      _licenciaActiva = activa;
      _fechaVencimiento = fechaVenc;
    });

    _comprobarActualizacionDisponible();
  }

  Future<void> _guardarCatalogo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_catalogo.map((e) => e.toMap()).toList());
    await prefs.setString('catalogo', jsonString);
  }

  Future<void> _guardarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_historialVentas);
    await prefs.setString('historial', jsonString);
  }

  Future<void> _guardarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nombreNegocio', _nombreNegocio);
    await prefs.setString('rfc', _rfc);
    await prefs.setString('datosNegocio', _datosNegocio);
    await prefs.setString('telefono', _telefono);
    await prefs.setString('vendedor', _vendedor);
    await prefs.setString('sucursal', _sucursal);
    await prefs.setString('ruta', _ruta);
    await prefs.setString('nombreCliente', _nombreCliente);
    await prefs.setString('clienteAcd', _clienteAcd);
    await prefs.setString('mensajePie', _mensajePie);
  }

  // Cálculos matemáticos en vivo
  double get subtotalVenta =>
      _carrito.fold(0.0, (acc, item) => acc + item.importe);

  double get iepsVenta =>
      _carrito.fold(0.0, (acc, item) => acc + item.montoIeps);

  double get totalVenta => subtotalVenta + iepsVenta;

  int get totalPiezas =>
      _carrito.fold(0, (acc, item) => acc + item.cantidad);

  void _agregarAlCarrito(ItemVenta item) {
    if (item.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡${item.descripcion} está agotado!')),
      );
      return;
    }

    final index = _carrito.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      if (_carrito[index].cantidad >= item.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock máximo alcanzado para ${item.descripcion}')),
        );
        return;
      }
      setState(() {
        _carrito[index].cantidad++;
        _tabSeleccionada = 1;
      });
    } else {
      setState(() {
        _carrito.add(
          ItemVenta(
            id: item.id,
            descripcion: item.descripcion,
            precioUnitario: item.precioUnitario,
            cantidad: 1,
            stock: item.stock,
            gravaIeps: item.gravaIeps,
          ),
        );
        _tabSeleccionada = 1;
      });
    }
  }

  void _ajustarCantidad(int index) {
    final item = _carrito[index];
    final prod = _catalogo.firstWhere((p) => p.id == item.id, orElse: () => item);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            '${item.gravaIeps ? "* " : ""}${item.descripcion}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stock disponible: ${prod.stock} pzs', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 36),
                    onPressed: () {
                      if (item.cantidad > 1) {
                        setState(() => item.cantidad--);
                        setDialogState(() {});
                      } else {
                        setState(() => _carrito.removeAt(index));
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('${item.cantidad}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: item.cantidad < prod.stock ? Colors.green : Colors.grey,
                      size: 36,
                    ),
                    onPressed: item.cantidad < prod.stock
                        ? () {
                            setState(() => item.cantidad++);
                            setDialogState(() {});
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Límite de stock alcanzado (${prod.stock})')),
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _carrito.removeAt(index));
                Navigator.pop(context);
              },
              child: const Text('Quitar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorImpresora() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print, color: Color(0xFF0097A7)),
            SizedBox(width: 8),
            Text('Impresora Bluetooth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: FutureBuilder<List<BluetoothInfo>>(
          future: PrinterService.obtenerDispositivosVinculados(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0097A7)),
                ),
              );
            }

            final dispositivos = snapshot.data ?? [];
            if (dispositivos.isEmpty) {
              return const Text(
                'No se detectaron dispositivos vinculados.\n\n1. Enciende el Bluetooth.\n2. Cierra la app oficial de Zebra.\n3. Vincula XX0228 en Ajustes de Bluetooth de Android.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              );
            }

            return SizedBox(
              width: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: dispositivos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = dispositivos[i];
                  return ListTile(
                    leading: const Icon(Icons.print, color: Color(0xFF0097A7)),
                    title: Text(d.name.isNotEmpty ? d.name : 'Impresora Bluetooth'),
                    subtitle: Text(d.macAdress, style: const TextStyle(fontSize: 11)),
                    onTap: () async {
                      Navigator.pop(context);
                      await PrinterService.guardarImpresora(d.macAdress);
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Conectando a ${d.name} e imprimiendo prueba...')),
                      );

                      const ticketTest = '^XA^PW384^FO40,40^A0N,28,28^FDCONEXION EXITOSA^FS^FO40,80^A0N,20,20^FDZebra Lista para Ventas^FS^XZ';
                      final ok = await PrinterService.imprimirTicketZPL(ticketTest);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 4),
                          content: Text(
                            ok
                                ? '¡Conectada! Ticket de prueba impreso con éxito.'
                                : 'Fallo de enlace. Verifica Zebra PrintConnect.',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoLicencia() {
    final fechaTexto = _fechaVencimiento != null
        ? DateFormat('dd/MM/yyyy').format(_fechaVencimiento!)
        : 'Consultando...';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _licenciaActiva ? Icons.verified : Icons.lock_clock,
              color: _licenciaActiva ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Estado de Licencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terminal ID: $_terminalId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                'Estado: ${_licenciaActiva ? "Suscripción Activa" : "VENCIDA"}',
                style: TextStyle(
                  color: _licenciaActiva ? Colors.green.shade700 : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Vence el: $fechaTexto', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance, size: 16, color: Color(0xFF0097A7)),
                        SizedBox(width: 6),
                        Text(
                          'Datos de Transferencia (SPEI)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Banco: Santander', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            'CLABE: 014700569481983803',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Color(0xFF0097A7)),
                          tooltip: 'Copiar CLABE',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: '014700569481983803'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('CLABE Santander copiada al portapapeles'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monto: \$200 MXN / mes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('ENVIAR COMPROBANTE POR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () async {
                    final texto = 'Hola, adjunto mi comprobante de pago de \$200 MXN a Santander para renovar Vektor.\n'
                        'Mi Terminal ID es: $_terminalId';
                    final uriWeb = Uri.parse('https://wa.me/524447043221?text=${Uri.encodeComponent(texto)}');
                    final uriApp = Uri.parse('whatsapp://send?phone=524447043221&text=${Uri.encodeComponent(texto)}');

                    try {
                      if (await canLaunchUrl(uriApp)) {
                        await launchUrl(uriApp, mode: LaunchMode.externalApplication);
                      } else {
                        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir WhatsApp automáticamente')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0097A7)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.sync, color: Color(0xFF0097A7)),
                  label: const Text(
                    'COMPROBAR ESTADO EN LÍNEA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0097A7)),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sincronizando con el servidor...')),
                    );
                    await LicenciaService.sincronizarEnLinea();
                    final activa = await LicenciaService.isLicenciaValida();
                    final nuevaFecha = await LicenciaService.obtenerFechaVencimiento();
                    setState(() {
                      _licenciaActiva = activa;
                      _fechaVencimiento = nuevaFecha;
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: activa ? Colors.green : Colors.orange,
                        content: Text(
                          activa
                              ? '¡Licencia activa hasta el ${DateFormat('dd/MM/yyyy').format(nuevaFecha)}!'
                              : 'La terminal sigue suspendida o vencida en el panel.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoConfiguracion() {
    final nombreCtrl = TextEditingController(text: _nombreNegocio);
    final rfcCtrl = TextEditingController(text: _rfc);
    final direccionCtrl = TextEditingController(text: _datosNegocio);
    final telCtrl = TextEditingController(text: _telefono);
    final vendedorCtrl = TextEditingController(text: _vendedor);
    final sucursalCtrl = TextEditingController(text: _sucursal);
    final rutaCtrl = TextEditingController(text: _ruta);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración de Ruta y Empresa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Razón Social / Empresa'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rfcCtrl,
                decoration: const InputDecoration(labelText: 'R.F.C.'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: direccionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Domicilio Fiscal'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono Empresa'),
              ),
              const Divider(height: 24),
              TextField(
                controller: rutaCtrl,
                decoration: const InputDecoration(labelText: 'Número de Ruta'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sucursalCtrl,
                decoration: const InputDecoration(labelText: 'Sucursal'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: vendedorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vendedor',
                  hintText: 'Ej. 371293 NOMBRE APELLIDO',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            onPressed: () {
              setState(() {
                _nombreNegocio = nombreCtrl.text.trim().isNotEmpty ? nombreCtrl.text.trim() : _nombreNegocio;
                _rfc = rfcCtrl.text.trim().isNotEmpty ? rfcCtrl.text.trim() : _rfc;
                _datosNegocio = direccionCtrl.text.trim();
                _telefono = telCtrl.text.trim();
                _ruta = rutaCtrl.text.trim();
                _sucursal = sucursalCtrl.text.trim();
                _vendedor = vendedorCtrl.text.trim();
              });
              _guardarConfiguracion();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuración de ruta actualizada')),
              );
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _limpiarVenta() {
    setState(() {
      _carrito.clear();
    });
  }

  void _mostrarVistaPreviaZpl(String zpl, String folio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF0097A7)),
            const SizedBox(width: 8),
            Text('Ticket ZPL ($folio)', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Código ZPL enviado a Zebra:', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    zpl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF69F0AE),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            label: const Text('Copiar ZPL', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: zpl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Código ZPL copiado!')),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _cambiarCliente() {
    final ctlNombre = TextEditingController(text: _nombreCliente);
    final ctlAcd = TextEditingController(text: _clienteAcd);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar Cliente de Ruta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctlNombre,
              decoration: const InputDecoration(
                labelText: 'Nombre / Comercio (Cte)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctlAcd,
              decoration: const InputDecoration(
                labelText: 'Código Cliente ACD',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            onPressed: () {
              setState(() {
                _nombreCliente = ctlNombre.text.trim();
                _clienteAcd = ctlAcd.text.trim();
              });
              _guardarConfiguracion();
              Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCobro() {
    if (!_licenciaActiva) {
      _mostrarDialogoLicencia();
      return;
    }

    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto para cobrar')),
      );
      return;
    }

    final TextEditingController pagoController = TextEditingController();
    double cambio = 0.0;
    String metodoPago = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cobrar Nota de Venta', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: ${formatMoneda.format(subtotalVenta)}', style: const TextStyle(fontSize: 13)),
                        Text('IEPS (8%): ${formatMoneda.format(iepsVenta)}', style: const TextStyle(fontSize: 13, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total a pagar: ${formatMoneda.format(totalVenta)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0097A7)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Método de pago:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'].map((metodo) {
                        final bool seleccionado = metodoPago == metodo;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: seleccionado ? const Color(0xFF0097A7) : Colors.transparent,
                                side: BorderSide(
                                  color: seleccionado ? const Color(0xFF0097A7) : Colors.grey.shade400,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  metodoPago = metodo;
                                  if (metodo != 'EFECTIVO') {
                                    pagoController.text = totalVenta.toStringAsFixed(2);
                                    cambio = 0.0;
                                  } else {
                                    pagoController.clear();
                                    cambio = 0.0;
                                  }
                                });
                              },
                              child: Text(
                                metodo == 'TRANSFERENCIA' ? 'TRANSF.' : metodo,
                                style: TextStyle(
                                  color: seleccionado ? Colors.white : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    if (metodoPago == 'EFECTIVO') ...[
                      TextField(
                        controller: pagoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Efectivo recibido',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        onChanged: (valor) {
                          final double monto = double.tryParse(valor) ?? 0.0;
                          setDialogState(() {
                            cambio = monto >= totalVenta ? (monto - totalVenta) : 0.0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cambio: ${formatMoneda.format(cambio)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cambio > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              metodoPago == 'TARJETA' ? Icons.credit_card : Icons.account_balance,
                              color: const Color(0xFF0097A7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                metodoPago == 'TARJETA'
                                    ? 'Cobro exacto vía terminal punto de venta'
                                    : 'Cobro exacto vía SPEI / Transferencia',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BC34A)),
                  onPressed: () {
                    final double montoEfectivo = metodoPago == 'EFECTIVO'
                        ? (double.tryParse(pagoController.text) ?? totalVenta)
                        : totalVenta;
                    final folioTicket = (_historialVentas.length + 1).toString().padLeft(5, '0');

                    // Generación ZPL idéntica a Bokados
                    final ticketZpl = TicketService().generarTicketZPL(
                      nombreNegocio: _nombreNegocio,
                      rfc: _rfc,
                      direccionFiscal: _datosNegocio,
                      telefono: _telefono,
                      folio: folioTicket,
                      cliente: _nombreCliente,
                      clienteAcd: _clienteAcd,
                      vendedor: _vendedor,
                      sucursal: _sucursal,
                      ruta: _ruta,
                      metodoPago: metodoPago,
                      articulos: List.from(_carrito),
                      total: totalVenta,
                      efectivo: montoEfectivo,
                      cambio: cambio,
                    );

                    debugPrint('=== CÓDIGO ZPL GENERADO PARA ZEBRA ===');
                    debugPrint(ticketZpl);

                    setState(() {
                      for (final item in _carrito) {
                        final idx = _catalogo.indexWhere((p) => p.id == item.id);
                        if (idx >= 0) {
                          _catalogo[idx].stock -= item.cantidad;
                        }
                      }

                      _historialVentas.add({
                        'folio': folioTicket,
                        'cliente': _nombreCliente,
                        'total': totalVenta,
                        'metodo': metodoPago,
                        'hora': DateFormat('HH:mm:ss').format(DateTime.now()),
                        'articulos': totalPiezas,
                        'zpl': ticketZpl,
                      });
                    });

                    _guardarCatalogo();
                    _guardarHistorial();

                    Navigator.pop(context);
                    _limpiarVenta();

                    PrinterService.imprimirTicketZPL(ticketZpl).then((exito) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: exito ? Colors.green : Colors.red,
                          content: Text(
                            exito
                                ? '¡Nota de venta impresa con éxito!'
                                : 'Error de impresión. Verifica Zebra PrintConnect.',
                          ),
                        ),
                      );
                    });
                  },
                  child: const Text('Confirmar e Imprimir', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _tabSeleccionada == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0097A7),
              onPressed: _mostrarDialogoNuevoProducto,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0097A7),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF80DEEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.point_of_sale, size: 18, color: Colors.black87),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vektor • Ruta $_ruta',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Último Ticket',
            onPressed: () {
              if (_historialVentas.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aún no hay ventas en este turno')),
                );
              } else {
                _reimprimirTicket(_historialVentas.last);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (valor) {
              if (valor == 'config') _mostrarDialogoConfiguracion();
              if (valor == 'impresora') _mostrarSelectorImpresora();
              if (valor == 'licencia') _mostrarDialogoLicencia();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'config',
                child: Row(
                  children: [
                    Icon(Icons.alt_route, size: 18, color: Color(0xFF0097A7)),
                    SizedBox(width: 8),
                    Text('Datos de Ruta y Empresa'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'impresora',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 18, color: Color(0xFF0097A7)),
                    SizedBox(width: 8),
                    Text('Impresora Bluetooth'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'licencia',
                child: Row(
                  children: [
                    Icon(Icons.vpn_key, size: 18, color: Color(0xFF0097A7)),
                    SizedBox(width: 8),
                    Text('Licencia / Suscripción'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Container(
            color: const Color(0xFF26C6DA),
            child: Row(
              children: [
                _buildTabItem(0, 'PRODUCTOS'),
                _buildTabItem(1, 'VENTA'),
                _buildTabItem(2, 'INFORME'),
              ],
            ),
          ),
        ),
      ),
      body: _tabSeleccionada == 0
          ? _buildVistaProductos()
          : _tabSeleccionada == 2
              ? _buildVistaInforme()
              : Column(
                  children: [
                    // Sub-barra Venta activa
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0xFF4DD0E1),
                      child: Text(
                        'Nota de Venta • Ruta $_ruta',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Selector de Cliente y Total grande táctil
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _cambiarCliente,
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cliente (Cte / ACD):', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        '$_nombreCliente\nACD: $_clienteAcd',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.edit, size: 18, color: Color(0xFF0097A7)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoneda.format(totalVenta),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Pzas: $totalPiezas | IEPS: ${formatMoneda.format(iepsVenta)}',
                                style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Cabecera de la tabla
                    Container(
                      color: const Color(0xFF29B6F6),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text(
                              'QTY',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Descripción (* Grava IEPS)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 65,
                            child: Text(
                              'P.U.',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 75,
                            child: Text(
                              'Importe',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Carrito activo
                    Expanded(
                      child: _carrito.isEmpty
                          ? Center(
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 120,
                                color: Colors.grey.shade200,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _carrito.length,
                              itemBuilder: (context, index) {
                                final item = _carrito[index];
                                return Dismissible(
                                  key: Key('${item.id}_$index'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    color: const Color(0xFFEF5350),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (_) {
                                    setState(() => _carrito.removeAt(index));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${item.descripcion} eliminado')),
                                    );
                                  },
                                  child: InkWell(
                                    onTap: () => _ajustarCantidad(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 38,
                                            child: Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${item.gravaIeps ? "* " : "  "}${item.descripcion}',
                                              style: TextStyle(
                                                fontWeight: item.gravaIeps ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 65,
                                            child: Text(
                                              formatMoneda.format(item.precioUnitario),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 75,
                                            child: Text(
                                              formatMoneda.format(item.importe),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Resumen de impuestos y botones
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal: ${formatMoneda.format(subtotalVenta)}', style: const TextStyle(fontSize: 12)),
                          Text('IEPS (8%): ${formatMoneda.format(iepsVenta)}', style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          Text('TOTAL: ${formatMoneda.format(totalVenta)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0097A7))),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF5350),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: _limpiarVenta,
                              child: const Text(
                                'Limpiar',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8BC34A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: _mostrarDialogoCobro,
                              child: const Text(
                                'Hecho (Cobrar)',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _mostrarDialogoNuevoProducto() {
    final nombreController = TextEditingController();
    final precioController = TextEditingController();
    final stockController = TextEditingController(text: '15');
    bool gravaIepsLocal = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Descripción / Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio P.U. (Sin IEPS)', prefixText: '\$ '),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Existencias (Stock)'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('¿Grava IEPS (8%)?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Activar para botanas (*). Desactivar para tostadas o bebidas.'),
                  value: gravaIepsLocal,
                  activeColor: const Color(0xFF0097A7),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => gravaIepsLocal = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BC34A)),
              onPressed: () {
                final nombre = nombreController.text.trim();
                final precio = double.tryParse(precioController.text.trim()) ?? 0.0;
                final stock = int.tryParse(stockController.text.trim()) ?? 0;

                if (nombre.isNotEmpty && precio > 0) {
                  setState(() {
                    _catalogo.add(
                      ItemVenta(
                        id: '${DateTime.now().millisecondsSinceEpoch}',
                        descripcion: nombre,
                        precioUnitario: precio,
                        stock: stock,
                        gravaIeps: gravaIepsLocal,
                      ),
                    );
                  });
                  _guardarCatalogo();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$nombre agregado al catálogo')),
                  );
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(ItemVenta prod) {
    final nombreController = TextEditingController(text: prod.descripcion);
    final precioController = TextEditingController(text: prod.precioUnitario.toStringAsFixed(2));
    final stockController = TextEditingController(text: prod.stock.toString());
    bool gravaIepsLocal = prod.gravaIeps;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Producto', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Descripción / Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio P.U. (Sin IEPS)',
                    prefixText: r'$ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Existencias (Stock)'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('¿Grava IEPS (8%)?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Activar para botanas (*). Desactivar para tostadas o salsas.'),
                  value: gravaIepsLocal,
                  activeColor: const Color(0xFF0097A7),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => gravaIepsLocal = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
              onPressed: () {
                final nombre = nombreController.text.trim();
                final precio = double.tryParse(precioController.text.trim()) ?? prod.precioUnitario;
                final stock = int.tryParse(stockController.text.trim()) ?? prod.stock;

                if (nombre.isNotEmpty && precio > 0) {
                  setState(() {
                    final idx = _catalogo.indexWhere((p) => p.id == prod.id);
                    if (idx >= 0) {
                      _catalogo[idx] = ItemVenta(
                        id: prod.id,
                        descripcion: nombre,
                        precioUnitario: precio,
                        stock: stock,
                        gravaIeps: gravaIepsLocal,
                      );
                    }
                  });
                  _guardarCatalogo();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$nombre" actualizado correctamente')),
                  );
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaProductos() {
    final productosFiltrados = _catalogo
        .where((p) => p.descripcion.toLowerCase().contains(_filtroBusqueda.toLowerCase()))
        .toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: const Color(0xFF4DD0E1),
          child: const Text(
            'Catálogo de Productos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF0097A7)),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (valor) {
              setState(() {
                _filtroBusqueda = valor;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: productosFiltrados.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final prod = productosFiltrados[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: prod.gravaIeps ? const Color(0xFF80DEEA) : Colors.amber.shade200,
                  child: Text(
                    prod.gravaIeps ? '*' : 'E',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                title: Text(
                  '${prod.gravaIeps ? "* " : ""}${prod.descripcion}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Stock: ${prod.stock} pzs • ${prod.gravaIeps ? "Paga 8% IEPS" : "Exento"}',
                  style: TextStyle(
                    color: prod.stock <= 0 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMoneda.format(prod.precioUnitario),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0097A7),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFF0097A7)),
                      tooltip: 'Editar producto',
                      onPressed: () => _mostrarDialogoEditarProducto(prod),
                    ),
                  ],
                ),
                onTap: () => _agregarAlCarrito(prod),
                onLongPress: () => _confirmarEliminarProducto(prod),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmarEliminarProducto(ItemVenta prod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Producto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Deseas eliminar permanentemente "${prod.descripcion}" del catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _catalogo.removeWhere((p) => p.id == prod.id);
              });
              _guardarCatalogo();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${prod.descripcion}" eliminado del catálogo')),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarCierreTurno() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cierre de Turno', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '¿Deseas cerrar el turno actual?\n\nSe generará el ticket de arqueo en ZPL y el acumulado volverá a \$0.00 para la siguiente jornada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            onPressed: () {
              final double totalCorte =
                  _historialVentas.fold(0.0, (acc, v) => acc + (v['total'] as double));
              final double totalEfectivo = _historialVentas
                  .where((v) => (v['metodo'] ?? 'EFECTIVO') == 'EFECTIVO')
                  .fold(0.0, (acc, v) => acc + (v['total'] as double));
              final double totalTarjeta = _historialVentas
                  .where((v) => v['metodo'] == 'TARJETA')
                  .fold(0.0, (acc, v) => acc + (v['total'] as double));
              final double totalTransf = _historialVentas
                  .where((v) => v['metodo'] == 'TRANSFERENCIA')
                  .fold(0.0, (acc, v) => acc + (v['total'] as double));

              final zplCorte = TicketService().generarCorteZPL(
                nombreNegocio: _nombreNegocio,
                direccionTelefono: _datosNegocio,
                totalVenta: totalCorte,
                totalEfectivo: totalEfectivo,
                totalTarjeta: totalTarjeta,
                totalTransf: totalTransf,
                totalTickets: _historialVentas.length,
              );

              setState(() {
                _historialVentas.clear();
              });
              _guardarHistorial();

              Navigator.pop(context);
              if (kIsWeb) {
                _mostrarVistaPreviaZpl(zplCorte, 'CORTE-TURNO');
              } else {
                PrinterService.imprimirTicketZPL(zplCorte).then((exito) {
                  if (!exito) {
                    _mostrarVistaPreviaZpl(zplCorte, 'CORTE-TURNO');
                  }
                });
              }
            },
            child: const Text('Confirmar y Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reimprimirTicket(Map<String, dynamic> venta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ticket ${venta['folio']}'),
        content: Text(
          '¿Deseas reimprimir el comprobante emitido a las ${venta['hora']} por un monto de ${formatMoneda.format(venta['total'])}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
            onPressed: () {
              Navigator.pop(context);
              PrinterService.imprimirTicketZPL(venta['zpl']).then((exito) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: exito ? Colors.green : Colors.red,
                    content: Text(exito ? 'Ticket reimpreso con éxito' : 'No se pudo conectar a la Zebra'),
                  ),
                );
              });
            },
            child: const Text('Reimprimir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaInforme() {
    final double totalCorte =
        _historialVentas.fold(0.0, (acc, v) => acc + (v['total'] as double));
    final double totalEfectivo = _historialVentas
        .where((v) => (v['metodo'] ?? 'EFECTIVO') == 'EFECTIVO')
        .fold(0.0, (acc, v) => acc + (v['total'] as double));
    final double totalTarjeta = _historialVentas
        .where((v) => v['metodo'] == 'TARJETA')
        .fold(0.0, (acc, v) => acc + (v['total'] as double));
    final double totalTransf = _historialVentas
        .where((v) => v['metodo'] == 'TRANSFERENCIA')
        .fold(0.0, (acc, v) => acc + (v['total'] as double));

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: const Color(0xFF4DD0E1),
          child: const Text(
            'Corte de Caja (Turno Actual)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Total Acumulado', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        formatMoneda.format(totalCorte),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0097A7)),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Tickets Emitidos', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '${_historialVentas.length}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCajaMetodo('Efectivo', totalEfectivo, Icons.payments),
                  _buildCajaMetodo('Tarjeta', totalTarjeta, Icons.credit_card),
                  _buildCajaMetodo('Transf.', totalTransf, Icons.account_balance),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Ventas Realizadas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ),
        Expanded(
          child: _historialVentas.isEmpty
              ? Center(
                  child: Text('No hay ventas registradas en este turno', style: TextStyle(color: Colors.grey.shade500)),
                )
              : ListView.separated(
                  itemCount: _historialVentas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final venta = _historialVentas[index];
                    final metodo = venta['metodo'] ?? 'EFECTIVO';
                    return ListTile(
                      leading: const Icon(Icons.receipt, color: Color(0xFF26C6DA)),
                      title: Text('Folio: ${venta['folio']} - ${venta['hora']}'),
                      subtitle: Text('${venta['articulos']} art. • $metodo • Toca para reimprimir'),
                      trailing: Text(
                        formatMoneda.format(venta['total']),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onTap: () => _reimprimirTicket(venta),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0097A7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.point_of_sale, color: Colors.white),
              label: const Text(
                'Cerrar Turno (Imprimir Corte)',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _historialVentas.isEmpty ? null : _confirmarCierreTurno,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCajaMetodo(String label, double monto, IconData icono) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: Colors.black54),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          formatMoneda.format(monto),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index, String title) {
    final bool activa = _tabSeleccionada == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabSeleccionada = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activa ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: activa ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _comprobarActualizacionDisponible() async {
    final info = await ActualizacionService.verificarActualizacion();
    if (info != null && mounted) {
      _mostrarDialogoActualizacion(info);
    }
  }

  void _mostrarDialogoActualizacion(Map<String, dynamic> info) {
    String estadoTexto = '';
    double progreso = 0.0;
    bool descargando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFF0097A7)),
              SizedBox(width: 8),
              Text('Actualización Disponible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión ${info['version_nombre'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                info['mensaje'] ?? 'Mejoras de rendimiento y correcciones.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              if (descargando) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progreso > 0 ? progreso : null,
                  backgroundColor: Colors.grey.shade300,
                  color: const Color(0xFF0097A7),
                ),
                const SizedBox(height: 8),
                Text(
                  estadoTexto,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
          actions: [
            if (!descargando) ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Más tarde'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0097A7)),
                onPressed: () {
                  final String url = info['url_descarga'] ?? '';
                  if (url.isEmpty) return;

                  setModalState(() {
                    descargando = true;
                    estadoTexto = 'Iniciando descarga...';
                  });

                  ActualizacionService.descargarEInstalar(url).listen(
                    (OtaEvent event) {
                      setModalState(() {
                        switch (event.status) {
                          case OtaStatus.DOWNLOADING:
                            final valor = double.tryParse(event.value ?? '0') ?? 0.0;
                            progreso = valor / 100.0;
                            estadoTexto = 'Descargando: ${event.value}%';
                            break;
                          case OtaStatus.INSTALLING:
                            estadoTexto = 'Abriendo instalador de Android...';
                            break;
                          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                            descargando = false;
                            estadoTexto = 'Permiso denegado para instalar.';
                            break;
                          default:
                            descargando = false;
                            estadoTexto = 'Error al actualizar (${event.status}).';
                            break;
                        }
                      });
                    },
                    onError: (_) {
                      setModalState(() {
                        descargando = false;
                        estadoTexto = 'Fallo de conexión al descargar.';
                      });
                    },
                  );
                },
                child: const Text('Actualizar ahora', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}