import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_venta.dart';
import '../models/cliente.dart';
import '../data/catalogo_datos.dart';
import '../services/ticket_service.dart';
import '../services/licencia_service.dart';
import '../services/printer_service.dart';
import '../services/actualizacion_service.dart';
import '../widgets/liquid_glass.dart';

class VentaScreen extends StatefulWidget {
  final bool initialDarkMode;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const VentaScreen({
    super.key,
    required this.initialDarkMode,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<ItemVenta> _carrito = [];
  final formatMoneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  int _tabSeleccionada = 1;
  int _tabAnterior = 1;
  bool _modoNoche = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<ItemVenta> _catalogo = List.from(catalogoInicial);
  final List<Map<String, dynamic>> _historialVentas = [];
  final List<Cliente> _clientes = [];
  String _filtroBusqueda = '';
  final TextEditingController _searchController = TextEditingController();

  String _nombreNegocio = 'NACIONAL DE ALIMENTOS Y HELADOS';
  String _rfc = 'NAH850320159';
  String _datosNegocio = 'AV SAN JERONIMO 307 # 307\nSAN JERONIMO\nMONTERREY, NUEVO LEON\nC.P. 64640';
  String _telefono = '81222300';
  String _vendedor = '';
  String _sucursal = '23 SAN LUIS POTOSI';
  String _ruta = '';
  String _nombreCliente = '9618 LA GUERA II';
  String _clienteAcd = '23009618';
  String _mensajePie = '¡GRACIAS POR SU COMPRA!';

  bool _licenciaActiva = true;
  String _terminalId = '';
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    _modoNoche = widget.isDarkMode;
    _cargarDatosLocales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    _modoNoche = prefs.getBool('modo_noche') ?? false;

    final int versionGuardada = prefs.getInt('version_catalogo') ?? 1;
    final catalogoJson = prefs.getString('catalogo');

    if (catalogoJson != null && versionGuardada >= 2) {
      final List decodificado = jsonDecode(catalogoJson);
      setState(() {
        _catalogo.clear();
        _catalogo.addAll(decodificado.map((e) => ItemVenta.fromMap(e)));
      });
    } else {
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

    final clientesJson = prefs.getString('clientes_db');
    if (clientesJson != null && clientesJson.isNotEmpty) {
      final List decodificado = jsonDecode(clientesJson);
      setState(() {
        _clientes.clear();
        _clientes.addAll(decodificado.map((e) => Cliente.fromMap(e)));
      });
    }

    final idTerm = await LicenciaService.obtenerTerminalId();
    await LicenciaService.sincronizarEnLinea();
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

    if (!activa && mounted) {
      _mostrarDialogoLicencia();
    }

    _comprobarActualizacionDisponible();
  }

  void _alternarModoNoche() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _modoNoche = !_modoNoche);
    await prefs.setBool('modo_noche', _modoNoche);
    widget.onThemeToggle();
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

  Future<void> _guardarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_clientes.map((e) => e.toMap()).toList());
    await prefs.setString('clientes_db', jsonString);
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

  double get subtotalVenta => _carrito.fold(0.0, (acc, item) => acc + item.importe);
  double get iepsVenta => _carrito.fold(0.0, (acc, item) => acc + item.montoIeps);
  double get totalVenta => subtotalVenta + iepsVenta;
  int get totalPiezas => _carrito.fold(0, (acc, item) => acc + item.cantidad);


  void _agregarAlCarrito(ItemVenta item) {
    if (item.manejaStock && item.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡${item.descripcion} está agotado!')),
      );
      return;
    }

    final index = _carrito.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      if (item.manejaStock && _carrito[index].cantidad >= item.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock máximo alcanzado para ${item.descripcion}')),
        );
        return;
      }
      setState(() {
        _carrito[index].cantidad++;
        _tabAnterior = _tabSeleccionada;
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
            manejaStock: item.manejaStock,
          ),
        );
        _tabAnterior = _tabSeleccionada;
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
        builder: (context, setDialogState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.descripcion,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                prod.manejaStock ? 'Stock disponible: ${prod.stock} pzs' : 'Stock ilimitado',
                style: TextStyle(
                  fontSize: 12,
                  color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DialogQtyButton(
                    icon: Icons.remove_circle,
                    color: LiquidColors.coralLight,
                    onPressed: () {
                      if (item.cantidad > 1) {
                        setState(() => item.cantidad--);
                        setDialogState(() {});
                      } else {
                        setState(() => _carrito.removeAt(index));
                        Navigator.pop(context);
                      }
                    },
                    isDark: _modoNoche,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${item.cantidad}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  _DialogQtyButton(
                    icon: Icons.add_circle,
                    color: (!prod.manejaStock || item.cantidad < prod.stock) ? LiquidColors.electricJadeLight : LiquidColors.textSecondaryLight,
                    onPressed: (!prod.manejaStock || item.cantidad < prod.stock)
                        ? () {
                            setState(() => item.cantidad++);
                            setDialogState(() {});
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Límite de stock alcanzado (${prod.stock})')),
                            );
                          },
                    isDark: _modoNoche,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Quitar',
                      isPrimary: false,
                      isDark: _modoNoche,
                      onPressed: () {
                        setState(() => _carrito.removeAt(index));
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Listo',
                      isPrimary: true,
                      isDark: _modoNoche,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarSelectorImpresora() async {
    final macActual = await PrinterService.obtenerImpresoraGuardada();
    final dispositivos = await PrinterService.obtenerDispositivosVinculados();

    showDialog(
      context: context,
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impresora Bluetooth',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MAC activa: ${macActual ?? 'Sin asignar'}',
              style: TextStyle(
                fontSize: 13,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            if (dispositivos.isEmpty)
              Text(
                'No se detectaron impresoras Bluetooth vinculadas.\n(En modo Web no hay acceso a Bluetooth).',
                style: TextStyle(
                  fontSize: 13,
                  color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              )
            else
              SizedBox(
                height: 220,
                width: 340,
                child: ListView.builder(
                  itemCount: dispositivos.length,
                  itemBuilder: (context, index) {
                    final device = dispositivos[index];
                    return LiquidGlassContainer(
                      borderRadius: 12,
                      blurSigma: 10,
                      isDark: _modoNoche,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await PrinterService.guardarImpresora(device.macAdress);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Impresora guardada: ${device.name}'),
                                backgroundColor: LiquidColors.electricJadeLight,
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.print,
                              color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name ?? 'Sin nombre',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    device.macAdress ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }


  void _mostrarDialogoLicencia() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _licenciaActiva ? Icons.check_circle : Icons.cancel,
                    color: _licenciaActiva
                        ? (LiquidColors.electricJadeLight)
                        : (LiquidColors.coralLight),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _licenciaActiva ? 'Licencia ACTIVA' : 'Licencia SUSPENDIDA / VENCIDA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _licenciaActiva
                            ? LiquidColors.electricJadeLight
                            : LiquidColors.coralLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_fechaVencimiento != null)
                Text(
                  'Vence: ${DateFormat('dd/MM/yyyy').format(_fechaVencimiento!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Terminal ID: $_terminalId',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Pago mensual:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${LicenciaService.banco} • CLABE: ${LicenciaService.clabe} (${LicenciaService.costoMensual})',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 20, color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight),
                    onPressed: () async {
                      await LicenciaService.copiarClabe();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CLABE copiada al portapapeles')),
                      );
                    },
                    tooltip: 'Copiar CLABE',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: LiquidGlassContainer(
                  borderRadius: 28,
                  blurSigma: 14,
                  isDark: _modoNoche,
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final String mensaje = 'Hola, acabo de pagar mi mensualidad de Vektor POS. Mi Terminal ID es: $_terminalId. Anexo el comprobante.';
                        final Uri url = Uri.parse('https://wa.me/524447043221?text=${Uri.encodeComponent(mensaje)}');
                        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Ya pagué: Enviar comprobante',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Sincronizar ahora',
                      isPrimary: true,
                      isDark: _modoNoche,
                      icon: Icons.sync,
                      onPressed: () async {
                        setModalState(() {});
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
                            backgroundColor: activa ? LiquidColors.electricJadeLight : LiquidColors.coralLight,
                            content: Text(
                              activa
                                  ? '¡Licencia activa hasta el ${nuevaFecha != null ? DateFormat('dd/MM/yyyy').format(nuevaFecha) : 'vigente'}!'
                                  : 'La terminal sigue suspendida o vencida en el panel.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Cerrar',
                      isPrimary: false,
                      isDark: _modoNoche,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoPrivacidad() {
    showDialog(
      context: context,
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip, color: LiquidColors.luminousBlueLight, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Aviso de Privacidad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Esta aplicación almacena toda la información de forma exclusiva en el dispositivo del usuario.',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Datos que se guardan localmente (SharedPreferences):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            _PrivacyBullet(text: 'Catálogo de productos (descripciones, precios, existencias, configuración IEPS)', isDark: _modoNoche),
            _PrivacyBullet(text: 'Historial completo de ventas realizadas en el turno', isDark: _modoNoche),
            _PrivacyBullet(text: 'Base de datos de clientes (nombre y código ACD)', isDark: _modoNoche),
            _PrivacyBullet(text: 'Configuración de ruta, sucursal, vendedor y datos fiscales de la empresa', isDark: _modoNoche),
            const SizedBox(height: 16),
            Text(
              'Información que se transmite vía HTTPS a Firebase:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Únicamente el identificador anónimo de terminal ($_terminalId) para validar el estado de licencia (switch activo/fecha de vencimiento) y comprobar actualizaciones OTA disponibles.',
              style: TextStyle(
                height: 1.4,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No se envían nombres de clientes, detalles de ventas, catálogo ni ningún dato personal o comercial a servidores externos.',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'El usuario tiene control total: puede borrar los datos de la app desde la configuración del sistema Android en cualquier momento.',
              style: TextStyle(
                fontSize: 12,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            LiquidPillButton(
              label: 'Entendido',
              isPrimary: true,
              isDark: _modoNoche,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: LiquidColors.luminousBlueLight, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Configuración de Ruta y Empresa',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // DATOS FISCALES
            Text(
              'DATOS FISCALES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            _LiquidTextField(
              controller: nombreCtrl,
              label: 'Razón Social / Empresa',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LiquidTextField(
                    controller: rfcCtrl,
                    label: 'R.F.C.',
                    isDark: _modoNoche,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiquidTextField(
                    controller: telCtrl,
                    label: 'Teléfono Empresa',
                    isDark: _modoNoche,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LiquidTextField(
              controller: direccionCtrl,
              label: 'Domicilio Fiscal',
              maxLines: 2,
              isDark: _modoNoche,
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            // OPERACIÓN Y RUTA
            Text(
              'OPERACIÓN Y RUTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _LiquidTextField(
                    controller: rutaCtrl,
                    label: 'Ruta',
                    hint: 'Ej. 30',
                    keyboardType: TextInputType.number,
                    isDark: _modoNoche,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _LiquidTextField(
                    controller: sucursalCtrl,
                    label: 'Sucursal',
                    isDark: _modoNoche,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LiquidTextField(
              controller: vendedorCtrl,
              label: 'Vendedor',
              hint: 'Ej. 371293 NOMBRE APELLIDO',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LiquidPillButton(
                    label: 'Cancelar',
                    isPrimary: false,
                    isDark: _modoNoche,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidPillButton(
                    label: 'Guardar',
                    isPrimary: true,
                    isDark: _modoNoche,
                    onPressed: () {
                      setState(() {
                        _nombreNegocio = nombreCtrl.text;
                        _rfc = rfcCtrl.text;
                        _datosNegocio = direccionCtrl.text;
                        _telefono = telCtrl.text;
                        _vendedor = vendedorCtrl.text;
                        _sucursal = sucursalCtrl.text;
                        _ruta = rutaCtrl.text;
                      });
                      _guardarConfiguracion();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cambiarCliente() {
    final nombreCtrl = TextEditingController(text: _nombreCliente);
    final acdCtrl = TextEditingController(text: _clienteAcd);

    showDialog(
      context: context,
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar Cliente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _LiquidTextField(
              controller: nombreCtrl,
              label: 'Nombre del Cliente',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 14),
            _LiquidTextField(
              controller: acdCtrl,
              label: 'Código ACD',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LiquidPillButton(
                    label: 'Cancelar',
                    isPrimary: false,
                    isDark: _modoNoche,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidPillButton(
                    label: 'Guardar',
                    isPrimary: true,
                    isDark: _modoNoche,
                    onPressed: () {
                      setState(() {
                        _nombreCliente = nombreCtrl.text;
                        _clienteAcd = acdCtrl.text;
                      });
                      _guardarConfiguracion();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _limpiarVenta() {
    setState(() {
      _carrito.clear();
    });
  }


  void _mostrarDialogoCobro() {
    if (!_licenciaActiva) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Licencia suspendida o vencida. Actívala para cobrar.')),
      );
      _mostrarDialogoLicencia();
      return;
    }

    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío')),
      );
      return;
    }

    final TextEditingController pagoController = TextEditingController();
    double cambio = 0.0;
    String metodoPago = 'EFECTIVO';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return LiquidDialog(
              isDark: _modoNoche,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cobrar Nota de Venta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal: ${formatMoneda.format(subtotalVenta)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        'IEPS (8%): ${formatMoneda.format(iepsVenta)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: LiquidColors.electricJadeLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total a pagar: ${formatMoneda.format(totalVenta)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Método de pago:',
                    style: TextStyle(
                      fontSize: 12,
                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'].map((metodo) {
                      final bool seleccionado = metodoPago == metodo;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: LiquidPillButton(
                            label: metodo == 'TRANSFERENCIA' ? 'TRANSF.' : metodo,
                            isPrimary: seleccionado,
                            isDark: _modoNoche,
                            height: 40,
                            borderRadius: 20,
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
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (metodoPago == 'EFECTIVO') ...[
                    _LiquidTextField(
                      controller: pagoController,
                      label: 'Efectivo recibido',
                      prefix: '\$ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      isDark: _modoNoche,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cambio > 0
                            ? LiquidColors.electricJadeLight
                            : (_modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight),
                      ),
                    ),
                  ] else
                    LiquidGlassContainer(
                      borderRadius: 16,
                      blurSigma: 12,
                      isDark: _modoNoche,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            metodoPago == 'TARJETA' ? Icons.credit_card : Icons.account_balance,
                            color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              metodoPago == 'TARJETA'
                                  ? 'Cobro exacto vía terminal punto de venta'
                                  : 'Cobro exacto vía SPEI / Transferencia',
                              style: TextStyle(
                                fontSize: 12,
                                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: LiquidPillButton(
                          label: 'Cancelar',
                          isPrimary: false,
                          isDark: _modoNoche,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LiquidPillButton(
                          label: 'Confirmar Cobro',
                          isPrimary: true,
                          isDark: _modoNoche,
                          onPressed: () async {
                            final double montoEfectivo = metodoPago == 'EFECTIVO'
                                ? (double.tryParse(pagoController.text) ?? totalVenta)
                                : totalVenta;
                            final folioTicket = (_historialVentas.length + 1).toString().padLeft(5, '0');

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
                              articulos: _carrito,
                              total: totalVenta,
                              efectivo: montoEfectivo,
                              cambio: cambio,
                              metodoPago: metodoPago,
                              mensajePie: _mensajePie,
                            );

                            _historialVentas.add({
                              'folio': folioTicket,
                              'fecha': DateTime.now().toIso8601String(),
                              'cliente': _nombreCliente,
                              'total': totalVenta,
                              'items': _carrito.map((e) => e.toMap()).toList(),
                              'metodoPago': metodoPago,
                            });
                            _guardarHistorial();

                            for (var item in _carrito) {
                              final prodIndex = _catalogo.indexWhere((p) => p.id == item.id);
                              if (prodIndex >= 0 && _catalogo[prodIndex].manejaStock) {
                                _catalogo[prodIndex].stock -= item.cantidad;
                              }
                            }
                            _guardarCatalogo();

                            await PrinterService.imprimirTicketZPL(ticketZpl);

                            setState(() {
                              _carrito.clear();
                            });

                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoNuevoProducto() {
    final nombreController = TextEditingController();
    final precioController = TextEditingController();
    final stockController = TextEditingController(text: '15');
    bool gravaIepsLocal = true;
    bool manejaStockLocal = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuevo Producto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),
              _LiquidTextField(
                controller: nombreController,
                label: 'Descripción / Nombre',
                isDark: _modoNoche,
              ),
              const SizedBox(height: 14),
              _LiquidTextField(
                controller: precioController,
                label: 'Precio P.U. (Sin IEPS)',
                prefix: '\$ ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                isDark: _modoNoche,
              ),
              const SizedBox(height: 16),
              LiquidGlassContainer(
                borderRadius: 16,
                blurSigma: 12,
                isDark: _modoNoche,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Grava IEPS (8%)?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            'Activar para botanas (*). Desactivar para tostadas o bebidas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: gravaIepsLocal,
                      activeColor: _modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight,
                      activeTrackColor: (_modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight).withOpacity(0.3),
                      onChanged: (val) {
                        setDialogState(() => gravaIepsLocal = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassContainer(
                borderRadius: 16,
                blurSigma: 12,
                isDark: _modoNoche,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Controlar Inventario?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            'Activar para descontar stock. Desactivar para stock infinito',
                            style: TextStyle(
                              fontSize: 11,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: manejaStockLocal,
                      activeColor: _modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight,
                      activeTrackColor: (_modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight).withOpacity(0.3),
                      onChanged: (val) {
                        setDialogState(() => manejaStockLocal = val);
                      },
                    ),
                  ],
                ),
              ),
              if (manejaStockLocal) ...[
                const SizedBox(height: 14),
                _LiquidTextField(
                  controller: stockController,
                  label: 'Existencias (Stock)',
                  keyboardType: TextInputType.number,
                  isDark: _modoNoche,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Cancelar',
                      isPrimary: false,
                      isDark: _modoNoche,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Guardar',
                      isPrimary: true,
                      isDark: _modoNoche,
                      onPressed: () {
                        final nombre = nombreController.text.trim();
                        final precio = double.tryParse(precioController.text.trim()) ?? 0.0;
                        final stock = int.tryParse(stockController.text.trim()) ?? 0;

                        if (nombre.isNotEmpty && precio > 0) {
                          setState(() {
                            _catalogo.add(
                              ItemVenta(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                descripcion: nombre,
                                precioUnitario: precio,
                                stock: stock,
                                gravaIeps: gravaIepsLocal,
                                manejaStock: manejaStockLocal,
                              ),
                            );
                          });
                          _guardarCatalogo();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(ItemVenta item) {
    final nombreController = TextEditingController(text: item.descripcion);
    final precioController = TextEditingController(text: item.precioUnitario.toStringAsFixed(2));
    final stockController = TextEditingController(text: item.stock.toString());
    bool gravaIepsLocal = item.gravaIeps;
    bool manejaStockLocal = item.manejaStock;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Editar Producto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),
              _LiquidTextField(
                controller: nombreController,
                label: 'Descripción / Nombre',
                isDark: _modoNoche,
              ),
              const SizedBox(height: 14),
              _LiquidTextField(
                controller: precioController,
                label: 'Precio P.U. (Sin IEPS)',
                prefix: '\$ ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                isDark: _modoNoche,
              ),
              const SizedBox(height: 16),
              LiquidGlassContainer(
                borderRadius: 16,
                blurSigma: 12,
                isDark: _modoNoche,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Grava IEPS (8%)?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            'Activar para botanas (*). Desactivar para tostadas o bebidas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: gravaIepsLocal,
                      activeColor: _modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight,
                      activeTrackColor: (_modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight).withOpacity(0.3),
                      onChanged: (val) {
                        setDialogState(() => gravaIepsLocal = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassContainer(
                borderRadius: 16,
                blurSigma: 12,
                isDark: _modoNoche,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Controlar Inventario?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            'Activar para descontar stock. Desactivar para stock infinito',
                            style: TextStyle(
                              fontSize: 11,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: manejaStockLocal,
                      activeColor: _modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight,
                      activeTrackColor: (_modoNoche ? LiquidColors.electricJadeDark : LiquidColors.electricJadeLight).withOpacity(0.3),
                      onChanged: (val) {
                        setDialogState(() => manejaStockLocal = val);
                      },
                    ),
                  ],
                ),
              ),
              if (manejaStockLocal) ...[
                const SizedBox(height: 14),
                _LiquidTextField(
                  controller: stockController,
                  label: 'Existencias (Stock)',
                  keyboardType: TextInputType.number,
                  isDark: _modoNoche,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Cancelar',
                      isPrimary: false,
                      isDark: _modoNoche,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Guardar Cambios',
                      isPrimary: true,
                      isDark: _modoNoche,
                      onPressed: () {
                        final nombre = nombreController.text.trim();
                        final precio = double.tryParse(precioController.text.trim()) ?? 0.0;
                        final stock = int.tryParse(stockController.text.trim()) ?? 0;

                        if (nombre.isNotEmpty && precio > 0) {
                          final index = _catalogo.indexWhere((e) => e.id == item.id);
                          if (index >= 0) {
                            setState(() {
                              _catalogo[index] = ItemVenta(
                                id: item.id,
                                descripcion: nombre,
                                precioUnitario: precio,
                                cantidad: 1,
                                stock: stock,
                                gravaIeps: gravaIepsLocal,
                                manejaStock: manejaStockLocal,
                              );
                            });
                            _guardarCatalogo();
                          }
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _mostrarDialogoClientes() {
    final searchController = TextEditingController();
    String filtro = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: LiquidColors.luminousBlueLight, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Base de Clientes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LiquidTextField(
                controller: searchController,
                label: 'Buscar cliente...',
                prefixIcon: Icons.search,
                isDark: _modoNoche,
                onChanged: (val) {
                  setDialogState(() => filtro = val.toLowerCase());
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                width: 360,
                child: ListView.separated(
                  itemCount: _clientes.where((c) =>
                    c.nombre.toLowerCase().contains(filtro) ||
                    c.acd.toLowerCase().contains(filtro)
                  ).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final filtered = _clientes.where((c) =>
                      c.nombre.toLowerCase().contains(filtro) ||
                      c.acd.toLowerCase().contains(filtro)
                    ).toList();
                    final cliente = filtered[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _nombreCliente = cliente.nombre;
                          _clienteAcd = cliente.acd;
                        });
                        _guardarConfiguracion();
                        Navigator.pop(context);
                      },
                      child: LiquidGlassContainer(
                        borderRadius: 16,
                        blurSigma: 12,
                        isDark: _modoNoche,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: (_modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight).withOpacity(0.2),
                              child: Text(
                                cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cliente.nombre,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    'ACD: ${cliente.acd}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _editarCliente(cliente);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _cambiarCliente();
                },
                icon: Icon(
                  Icons.flash_on,
                  size: 18,
                  color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                ),
                label: Text(
                  'Cliente rápido (sin guardar)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Nuevo Cliente',
                      isPrimary: true,
                      isDark: _modoNoche,
                      icon: Icons.person_add,
                      onPressed: () {
                        Navigator.pop(context);
                        _nuevoCliente();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidPillButton(
                      label: 'Cerrar',
                      isPrimary: false,
                      isDark: _modoNoche,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nuevoCliente() {
    final nombreCtrl = TextEditingController();
    final acdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nuevo Cliente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _LiquidTextField(
              controller: nombreCtrl,
              label: 'Nombre del Cliente',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 14),
            _LiquidTextField(
              controller: acdCtrl,
              label: 'Código ACD',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LiquidPillButton(
                    label: 'Cancelar',
                    isPrimary: false,
                    isDark: _modoNoche,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidPillButton(
                    label: 'Guardar',
                    isPrimary: true,
                    isDark: _modoNoche,
                    onPressed: () {
                      if (nombreCtrl.text.trim().isNotEmpty && acdCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          _clientes.add(Cliente(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            nombre: nombreCtrl.text.trim(),
                            acd: acdCtrl.text.trim(),
                          ));
                        });
                        _guardarClientes();
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editarCliente(Cliente cliente) {
    final nombreCtrl = TextEditingController(text: cliente.nombre);
    final acdCtrl = TextEditingController(text: cliente.acd);

    showDialog(
      context: context,
      builder: (context) => LiquidDialog(
        isDark: _modoNoche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Editar Cliente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _LiquidTextField(
              controller: nombreCtrl,
              label: 'Nombre del Cliente',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 14),
            _LiquidTextField(
              controller: acdCtrl,
              label: 'Código ACD',
              isDark: _modoNoche,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LiquidPillButton(
                    label: 'Cancelar',
                    isPrimary: false,
                    isDark: _modoNoche,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidPillButton(
                    label: 'Guardar',
                    isPrimary: true,
                    isDark: _modoNoche,
                    onPressed: () {
                      if (nombreCtrl.text.trim().isNotEmpty && acdCtrl.text.trim().isNotEmpty) {
                        final index = _clientes.indexWhere((c) => c.id == cliente.id);
                        if (index >= 0) {
                          setState(() {
                            _clientes[index] = Cliente(
                              id: cliente.id,
                              nombre: nombreCtrl.text.trim(),
                              acd: acdCtrl.text.trim(),
                            );
                          });
                          _guardarClientes();
                        }
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _comprobarActualizacionDisponible() async {
    try {
      final info = await ActualizacionService.verificarActualizacion();
      if (info != null && mounted) {
        _mostrarDialogoActualizacion(info);
      }
    } catch (_) {}
  }

  void _mostrarDialogoActualizacion(Map<String, dynamic> info) {
    bool descargando = false;
    double progreso = 0.0;
    String estadoTexto = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => LiquidDialog(
          isDark: _modoNoche,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.system_update, color: LiquidColors.luminousBlueLight, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Actualización Disponible',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Versión ${info['version_nombre'] ?? ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                info['mensaje'] ?? 'Mejoras de rendimiento y correcciones.',
                style: TextStyle(
                  fontSize: 13,
                  color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                ),
              ),
              if (descargando) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progreso > 0 ? progreso : null,
                  backgroundColor: (_modoNoche ? LiquidColors.surfaceDark : Colors.grey.shade300),
                  color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                ),
                const SizedBox(height: 8),
                Text(
                  estadoTexto,
                  style: TextStyle(
                    fontSize: 12,
                    color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!descargando)
                Row(
                  children: [
                    Expanded(
                      child: LiquidPillButton(
                        label: 'Más tarde',
                        isPrimary: false,
                        isDark: _modoNoche,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiquidPillButton(
                        label: 'Actualizar ahora',
                        isPrimary: true,
                        isDark: _modoNoche,
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
                                    estadoTexto = 'Descargando: ${valor.toStringAsFixed(0)}%';
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
                                    estadoTexto = 'Error al actualizar (${event.status.name}).';
                                    break;
                                }
                              });
                            },
                            onError: (error) {
                              setModalState(() {
                                descargando = false;
                                estadoTexto = 'Error: ${error.toString()}';
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                )
              else
                LiquidPillButton(
                  label: 'Cerrar',
                  isPrimary: true,
                  isDark: _modoNoche,
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildVistaProductos({double bottomInset = 0}) {
    final effectiveBottomInset = bottomInset > 0 ? bottomInset : MediaQuery.viewPaddingOf(context).bottom;
    final catalogoFiltrado = _catalogo.where((item) {
      final busqueda = _filtroBusqueda.toLowerCase();
      return item.descripcion.toLowerCase().contains(busqueda);
    }).toList();

    return Column(
      children: [
        LiquidGlassContainer(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          blurSigma: 16,
          isDark: _modoNoche,
          child: _LiquidTextField(
            controller: _searchController,
            label: 'Buscar productos...',
            prefixIcon: Icons.search,
            isDark: _modoNoche,
            onChanged: (val) => setState(() => _filtroBusqueda = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: catalogoFiltrado.length,
            itemBuilder: (context, index) {
              final item = catalogoFiltrado[index];
              return LiquidProductCard(
                title: item.descripcion,
                subtitle: '${item.manejaStock ? 'Stock: ${item.stock}' : 'Stock: ∞'} • ${item.gravaIeps ? 'IEPS' : 'Exento'}',
                price: formatMoneda.format(item.precioUnitario),
                gravaIeps: item.gravaIeps,
                isDark: _modoNoche,
                isCatalog: true,
                onTap: () => _agregarAlCarrito(item),
                onIncrement: () => _agregarAlCarrito(item),
              );
            },
          ),
        ),
        SizedBox(height: effectiveBottomInset + 16),
      ],
    );
  }

  Widget _buildVistaInforme() {
    if (_historialVentas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ventas registradas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las ventas aparecerán aquí al cobrar',
              style: TextStyle(
                fontSize: 14,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        LiquidGlassContainer(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          blurSigma: 16,
          isDark: _modoNoche,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total del Turno',
                      style: TextStyle(
                        fontSize: 12,
                        color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      formatMoneda.format(_historialVentas.fold(0.0, (acc, v) => acc + (v['total'] as double))),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ventas',
                      style: TextStyle(
                        fontSize: 12,
                        color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      '${_historialVentas.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LiquidPillButton(
            label: 'Imprimir Corte de Caja',
            isPrimary: false,
            isDark: _modoNoche,
            icon: Icons.print,
            onPressed: () {
              if (_historialVentas.isEmpty) return;

              showDialog(
                context: context,
                builder: (context) => LiquidDialog(
                  isDark: _modoNoche,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Confirmar Corte de Caja',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¿Deseas imprimir el corte de caja? Esto borrará el historial de ventas actual para iniciar un nuevo turno desde cero.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: LiquidPillButton(
                              label: 'Cancelar',
                              isPrimary: false,
                              isDark: _modoNoche,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LiquidPillButton(
                              label: 'Confirmar',
                              isPrimary: true,
                              isDark: _modoNoche,
                              onPressed: () async {
                                final totalV = _historialVentas.fold(0.0, (acc, v) => acc + (v['total'] as double));
                                final totalEfectivo = _historialVentas.where((v) => v['metodoPago'] == 'EFECTIVO').fold(0.0, (acc, v) => acc + (v['total'] as double));
                                final totalTarjeta = _historialVentas.where((v) => v['metodoPago'] == 'TARJETA').fold(0.0, (acc, v) => acc + (v['total'] as double));
                                final totalTransf = _historialVentas.where((v) => v['metodoPago'] == 'TRANSFERENCIA').fold(0.0, (acc, v) => acc + (v['total'] as double));
                                
                                final zpl = TicketService().generarCorteZPL(
                                  nombreNegocio: _nombreNegocio,
                                  direccionTelefono: '$_telefono\n$_datosNegocio',
                                  totalVenta: totalV,
                                  totalEfectivo: totalEfectivo,
                                  totalTarjeta: totalTarjeta,
                                  totalTransf: totalTransf,
                                  totalTickets: _historialVentas.length,
                                );
                                await PrinterService.imprimirTicketZPL(zpl);
                                
                                if (mounted) {
                                  setState(() {
                                    _historialVentas.clear();
                                  });
                                  _guardarHistorial();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Corte impreso y turno reiniciado')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _historialVentas.length,
            itemBuilder: (context, index) {
              final venta = _historialVentas[_historialVentas.length - 1 - index];
              final fecha = DateTime.parse(venta['fecha']);
              return LiquidGlassContainer(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                blurSigma: 12,
                isDark: _modoNoche,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Folio: ${venta['folio']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(fecha),
                          style: TextStyle(
                            fontSize: 12,
                            color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () async {
                            final List<dynamic> rawItems = venta['items'];
                            final List<ItemVenta> arts = rawItems.map((e) => ItemVenta.fromMap(Map<String, dynamic>.from(e))).toList();
                            final double mTotal = venta['total'];
                            final String mMetodo = venta['metodoPago'];
                            
                            final zpl = TicketService().generarTicketZPL(
                              nombreNegocio: _nombreNegocio,
                              rfc: _rfc,
                              direccionFiscal: _datosNegocio,
                              telefono: _telefono,
                              folio: venta['folio'],
                              cliente: venta['cliente'],
                              clienteAcd: _clienteAcd,
                              vendedor: _vendedor,
                              sucursal: _sucursal,
                              ruta: _ruta,
                              articulos: arts,
                              total: mTotal,
                              efectivo: mTotal,
                              cambio: 0.0,
                              metodoPago: mMetodo,
                              mensajePie: _mensajePie,
                            );
                            await PrinterService.imprimirTicketZPL(zpl);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.print,
                              color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cliente: ${venta['cliente']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Método: ${venta['metodoPago']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          formatMoneda.format(venta['total']),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildVistaVenta({double bottomInset = 0}) {
    final effectiveBottomInset = bottomInset > 0 ? bottomInset : MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LiquidGlassContainer(
            borderRadius: 24,
            blurSigma: 20,
            isDark: _modoNoche,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                InkWell(
                  onTap: _mostrarDialogoClientes,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: (_modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight).withOpacity(0.15),
                          child: Icon(
                            Icons.store,
                            color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nombreCliente,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ACD: $_clienteAcd • ${_ruta.trim().isEmpty ? 'Sin ruta' : 'Ruta ${_ruta.trim()}'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUBTOTAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            formatMoneda.format(subtotalVenta),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          LiquidIepsBadge(text: 'IEPS 8%', isDark: _modoNoche),
                          const SizedBox(height: 6),
                          Text(
                            formatMoneda.format(iepsVenta),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: LiquidColors.electricJadeLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            formatMoneda.format(totalVenta),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_carrito.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Carrito vacío',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega productos desde la pestaña PRODUCTOS',
                    style: TextStyle(
                      fontSize: 14,
                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _carrito.length,
              itemBuilder: (context, index) {
                final item = _carrito[index];
                return LiquidProductCard(
                  title: item.descripcion,
                  subtitle: 'P.U.: ${formatMoneda.format(item.precioUnitario)} • Stock: ${item.stock}',
                  price: formatMoneda.format(item.importe + item.montoIeps),
                  quantity: '${item.cantidad}',
                  gravaIeps: item.gravaIeps,
                  isDark: _modoNoche,
                  onIncrement: () {
                    if (item.cantidad < item.stock) {
                      setState(() => item.cantidad++);
                    }
                  },
                  onDecrement: () {
                    setState(() {
                      if (item.cantidad > 1) {
                        item.cantidad--;
                      } else {
                        _carrito.removeAt(index);
                      }
                    });
                  },
                );
              },
            ),
          ),

        if (_carrito.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, effectiveBottomInset + 16),
            child: Column(
              children: [
                LiquidGlassContainer(
                  borderRadius: 20,
                  blurSigma: 16,
                  isDark: _modoNoche,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal: ${formatMoneda.format(subtotalVenta)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        'IEPS (8%): ${formatMoneda.format(iepsVenta)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: LiquidColors.electricJadeLight,
                        ),
                      ),
                      Text(
                        'TOTAL: ${formatMoneda.format(totalVenta)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LiquidPillButton(
                        label: 'Limpiar',
                        isPrimary: false,
                        isDark: _modoNoche,
                        icon: Icons.delete_sweep,
                        onPressed: _limpiarVenta,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiquidPillButton(
                        label: 'Hecho (Cobrar)',
                        isPrimary: true,
                        isDark: _modoNoche,
                        icon: Icons.point_of_sale,
                        onPressed: _mostrarDialogoCobro,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVistaVentaResponsive(bool esTablet, double maxWidth) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    if (esTablet) {
      return _buildVistaVentaTablet(bottomInset);
    }

    return _buildVistaVenta();
  }

  Widget _buildVistaVentaTablet(double bottomInset) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              LiquidGlassContainer(
                margin: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                blurSigma: 16,
                isDark: _modoNoche,
                child: _LiquidTextField(
                  controller: _searchController,
                  label: 'Buscar productos...',
                  prefixIcon: Icons.search,
                  isDark: _modoNoche,
                  onChanged: (val) => setState(() => _filtroBusqueda = val),
                ),
              ),
              Expanded(child: _buildCatalogoLista()),
              SizedBox(height: bottomInset + 16),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildPanelCliente(),
              Expanded(child: _buildPanelCarrito()),
              if (_carrito.isNotEmpty) _buildPanelCobro(bottomInset) else SizedBox(height: bottomInset + 16),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildCatalogoLista() {
    final catalogoFiltrado = _catalogo.where((item) {
      final busqueda = _filtroBusqueda.toLowerCase();
      return item.descripcion.toLowerCase().contains(busqueda);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
      itemCount: catalogoFiltrado.length,
      itemBuilder: (context, index) {
        final item = catalogoFiltrado[index];
        return LiquidProductCard(
          title: item.descripcion,
          subtitle: '${item.manejaStock ? 'Stock: ${item.stock}' : 'Stock: ∞'} • ${item.gravaIeps ? 'IEPS' : 'Exento'}',
          price: formatMoneda.format(item.precioUnitario),
          gravaIeps: item.gravaIeps,
          isDark: _modoNoche,
          isCatalog: true,
          onTap: () => _agregarAlCarrito(item),
          onIncrement: () => _agregarAlCarrito(item),
        );
      },
    );
  }

  Widget _buildPanelCliente() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LiquidGlassContainer(
        borderRadius: 24,
        blurSigma: 20,
        isDark: _modoNoche,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            InkWell(
              onTap: _mostrarDialogoClientes,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: (_modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight).withOpacity(0.15),
                      child: Icon(
                        Icons.store,
                        color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombreCliente,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _modoNoche ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ACD: $_clienteAcd \u2022 ${_ruta.trim().isEmpty ? 'Sin ruta' : 'Ruta ${_ruta.trim()}'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelCarrito() {
    if (_carrito.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Carrito vacío',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos desde el catálogo',
              style: TextStyle(
                fontSize: 14,
                color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _carrito.length,
      itemBuilder: (context, index) {
        final item = _carrito[index];
        return LiquidProductCard(
          title: item.descripcion,
          subtitle: 'P.U.: ${formatMoneda.format(item.precioUnitario)}',
          price: formatMoneda.format(item.importe + item.montoIeps),
          quantity: '${item.cantidad}',
          gravaIeps: item.gravaIeps,
          isDark: _modoNoche,
          isCatalog: false,
          onIncrement: () {
            if (item.cantidad < item.stock) {
              setState(() => item.cantidad++);
            }
          },
          onDecrement: () {
            setState(() {
              if (item.cantidad > 1) {
                item.cantidad--;
              } else {
                _carrito.removeAt(index);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildPanelCobro(double bottomInset) {
    final subtotal = _carrito.fold(0.0, (acc, i) => acc + i.importe);
    final ieps = _carrito.fold(0.0, (acc, i) => acc + i.montoIeps);
    final total = subtotal + ieps;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Column(
        children: [
          LiquidGlassContainer(
            borderRadius: 20,
            blurSigma: 16,
            isDark: _modoNoche,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal: ${formatMoneda.format(subtotal)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _modoNoche ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'IEPS (8%): ${formatMoneda.format(ieps)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: LiquidColors.electricJadeLight,
                  ),
                ),
                Text(
                  'TOTAL: ${formatMoneda.format(total)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _modoNoche ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LiquidPillButton(
                  label: 'Limpiar',
                  isPrimary: false,
                  isDark: _modoNoche,
                  icon: Icons.delete_sweep,
                  onPressed: _limpiarVenta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LiquidPillButton(
                  label: 'Hecho (Cobrar)',
                  isPrimary: true,
                  isDark: _modoNoche,
                  icon: Icons.point_of_sale,
                  onPressed: _mostrarDialogoCobro,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: LiquidAppBar(
        title: 'POS Lite',
        isDark: _modoNoche,
        onThemeToggle: _alternarModoNoche,
        onLeadingPress: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: LiquidGlassContainer(
          borderRadius: 0,
          blurSigma: 24,
          isDark: _modoNoche,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.people,
                  label: 'Clientes',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoClientes();
                  },
                ),
                _DrawerItem(
                  icon: Icons.add_box,
                  label: 'Nuevo Producto',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoNuevoProducto();
                  },
                ),
                _DrawerItem(
                  icon: Icons.print,
                  label: 'Impresora Bluetooth',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarSelectorImpresora();
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings,
                  label: 'Configuración Ruta / Empresa',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoConfiguracion();
                  },
                ),
                _DrawerItem(
                  icon: Icons.verified_user,
                  label: 'Licencia',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoLicencia();
                  },
                ),
                _DrawerItem(
                  icon: Icons.privacy_tip,
                  label: 'Aviso de Privacidad',
                  isDark: _modoNoche,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoPrivacidad();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: LiquidMeshBackground(
        isDark: _modoNoche,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LiquidSegmentedPill(
                  labels: const ['PRODUCTOS', 'VENTA', 'INFORME'],
                  selectedIndex: _tabSeleccionada,
                  isDark: _modoNoche,
                  onChanged: (index) {
                    if (index == _tabSeleccionada) return;
                    setState(() {
                      _tabAnterior = _tabSeleccionada;
                      _tabSeleccionada = index;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInBack,
                  transitionBuilder: (child, animation) {
                    final bool vaADerecha = _tabSeleccionada >= _tabAnterior;
                    final bool esEntrante = child.key == ValueKey<int>(_tabSeleccionada);
                    final Offset inicio = esEntrante
                        ? Offset(vaADerecha ? 0.08 : -0.08, 0)
                        : Offset(vaADerecha ? -0.08 : 0.08, 0);

                    final slideAnim = Tween<Offset>(begin: inicio, end: Offset.zero).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)
                    );
                    final scaleAnim = Tween<double>(begin: 0.97, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutBack)
                    );

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideAnim,
                        child: ScaleTransition(
                          scale: scaleAnim,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_tabSeleccionada),
                    child: _tabSeleccionada == 0
                        ? _buildVistaProductos()
                        : _tabSeleccionada == 2
                            ? _buildVistaInforme()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final esTablet = constraints.maxWidth >= 600;
                                  return _buildVistaVentaResponsive(esTablet, constraints.maxWidth);
                                },
                              ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogQtyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isDark;

  const _DialogQtyButton({
    required this.icon,
    required this.color,
    this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.15),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  final String text;
  final bool isDark;

  const _PrivacyBullet({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.4,
                color: isDark ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _LiquidTextField({
    required this.controller,
    required this.label,
    this.prefix,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight;
    final borderColor = isDark ? LiquidColors.textSecondaryDark : LiquidColors.textSecondaryLight;

    return LiquidGlassContainer(
      borderRadius: 14,
      blurSigma: 12,
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: borderColor) : null,
          prefixText: prefix,
          prefixStyle: TextStyle(color: textColor, fontSize: 15),
          labelStyle: TextStyle(
            color: borderColor,
            fontSize: 14,
          ),
          floatingLabelStyle: TextStyle(
            color: isDark ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? LiquidColors.luminousBlueDark : LiquidColors.luminousBlueLight,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? LiquidColors.textPrimaryDark : LiquidColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
