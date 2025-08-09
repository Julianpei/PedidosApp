import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PedidosApp());
}

class PedidosApp extends StatelessWidget {
  const PedidosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pedidos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/* ===================== MODELOS ===================== */
class Cliente {
  final String id;
  String nombre;
  String contacto;

  Cliente({required this.id, required this.nombre, this.contacto = ''});

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'contacto': contacto};
  static Cliente fromMap(Map<String, dynamic> m) =>
      Cliente(id: m['id'], nombre: m['nombre'], contacto: m['contacto'] ?? '');

  @override
  String toString() => nombre;
}

class Proveedor {
  final String id;
  String nombre;
  String contacto;

  Proveedor({required this.id, required this.nombre, this.contacto = ''});

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'contacto': contacto};
  static Proveedor fromMap(Map<String, dynamic> m) =>
      Proveedor(id: m['id'], nombre: m['nombre'], contacto: m['contacto'] ?? '');

  @override
  String toString() => nombre;
}

class MaterialItem {
  final String id;
  String nombre;
  String unidad;

  MaterialItem({required this.id, required this.nombre, this.unidad = 'u'});

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'unidad': unidad};
  static MaterialItem fromMap(Map<String, dynamic> m) =>
      MaterialItem(id: m['id'], nombre: m['nombre'], unidad: m['unidad'] ?? 'u');

  @override
  String toString() => nombre;
}

class LineaPedido {
  final MaterialItem material;
  int cantidad;
  LineaPedido({required this.material, required this.cantidad});

  Map<String, dynamic> toMap() => {
        'material': material.toMap(),
        'cantidad': cantidad,
      };

  static LineaPedido fromMap(Map<String, dynamic> m) =>
      LineaPedido(material: MaterialItem.fromMap(Map<String, dynamic>.from(m['material'])), cantidad: m['cantidad']);
}

class Pedido {
  final String id;
  Cliente? cliente;
  Proveedor? proveedor;
  List<LineaPedido> lineas;
  String notas;

  Pedido({
    required this.id,
    this.cliente,
    this.proveedor,
    this.lineas = const [],
    this.notas = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente': cliente?.toMap(),
        'proveedor': proveedor?.toMap(),
        'lineas': lineas.map((e) => e.toMap()).toList(),
        'notas': notas,
      };

  static Pedido fromMap(Map<String, dynamic> m) => Pedido(
        id: m['id'],
        cliente: m['cliente'] != null ? Cliente.fromMap(Map<String, dynamic>.from(m['cliente'])) : null,
        proveedor: m['proveedor'] != null ? Proveedor.fromMap(Map<String, dynamic>.from(m['proveedor'])) : null,
        lineas: (m['lineas'] as List? ?? [])
            .map((e) => LineaPedido.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        notas: m['notas'] ?? '',
      );

  String toShareText() {
    final sb = StringBuffer();
    sb.writeln('PEDIDO');
    if (cliente != null) sb.writeln('Cliente: ${cliente!.nombre}');
    if (proveedor != null) sb.writeln('Proveedor: ${proveedor!.nombre}');
    sb.writeln('--------------------------------');
    for (final l in lineas) {
      sb.writeln('- ${l.material.nombre} x ${l.cantidad} ${l.material.unidad}');
    }
    if (notas.trim().isNotEmpty) {
      sb.writeln('--------------------------------');
      sb.writeln('Notas: ${notas.trim()}');
    }
    return sb.toString();
  }
}

/* ===================== STORAGE ===================== */
class AppStore extends ChangeNotifier {
  static const _kClientes = 'clientes';
  static const _kProveedores = 'proveedores';
  static const _kMateriales = 'materiales';
  static const _kPedidos = 'pedidos';

  final List<Cliente> clientes = [];
  final List<Proveedor> proveedores = [];
  final List<MaterialItem> materiales = [];
  final List<Pedido> pedidos = [];

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _loadList<Cliente>(sp, _kClientes, clientes, (m) => Cliente.fromMap(m));
    _loadList<Proveedor>(sp, _kProveedores, proveedores, (m) => Proveedor.fromMap(m));
    _loadList<MaterialItem>(sp, _kMateriales, materiales, (m) => MaterialItem.fromMap(m));
    _loadList<Pedido>(sp, _kPedidos, pedidos, (m) => Pedido.fromMap(m));

    // Si está vacío, agrego ejemplos
    if (clientes.isEmpty && proveedores.isEmpty && materiales.isEmpty) {
      clientes.addAll([
        Cliente(id: 'c1', nombre: 'Cliente Demo', contacto: 'cliente@demo.com'),
      ]);
      proveedores.addAll([
        Proveedor(id: 'p1', nombre: 'Proveedor Demo', contacto: 'ventas@proveedor.com'),
      ]);
      materiales.addAll([
        MaterialItem(id: 'm1', nombre: 'Caja corrugada 40x30x20', unidad: 'u'),
        MaterialItem(id: 'm2', nombre: 'Film stretch 50cm', unidad: 'rollo'),
      ]);
      await saveAll();
    }

    notifyListeners();
  }

  Future<void> saveAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kClientes, jsonEncode(clientes.map((e) => e.toMap()).toList()));
    await sp.setString(_kProveedores, jsonEncode(proveedores.map((e) => e.toMap()).toList()));
    await sp.setString(_kMateriales, jsonEncode(materiales.map((e) => e.toMap()).toList()));
    await sp.setString(_kPedidos, jsonEncode(pedidos.map((e) => e.toMap()).toList()));
  }

  void _loadList<T>(SharedPreferences sp, String key, List list, T Function(Map<String, dynamic>) fromMap) {
    final raw = sp.getString(key);
    list.clear();
    if (raw != null && raw.isNotEmpty) {
      final List data = jsonDecode(raw);
      list.addAll(data.map((e) => fromMap(Map<String, dynamic>.from(e))));
    }
  }

  // CRUD genéricos
  void addCliente(Cliente c) { clientes.add(c); saveAll(); notifyListeners(); }
  void addProveedor(Proveedor p) { proveedores.add(p); saveAll(); notifyListeners(); }
  void addMaterial(MaterialItem m) { materiales.add(m); saveAll(); notifyListeners(); }
  void removeCliente(Cliente c){ clientes.remove(c); saveAll(); notifyListeners(); }
  void removeProveedor(Proveedor p){ proveedores.remove(p); saveAll(); notifyListeners(); }
  void removeMaterial(MaterialItem m){ materiales.remove(m); saveAll(); notifyListeners(); }
  void upsertPedido(Pedido p){
    final i = pedidos.indexWhere((e) => e.id == p.id);
    if (i >= 0) { pedidos[i] = p; } else { pedidos.add(p); }
    saveAll(); notifyListeners();
  }
  void removePedido(Pedido p){ pedidos.removeWhere((e)=>e.id==p.id); saveAll(); notifyListeners(); }
}

/* ===================== UI ===================== */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final store = AppStore();
  int idx = 0;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CatalogPage<Cliente>(
        title: 'Clientes',
        items: store.clientes,
        itemBuilder: (c) => ListTile(
          title: Text(c.nombre),
          subtitle: Text(c.contacto.isEmpty ? '—' : c.contacto),
        ),
        onAdd: () async {
          final c = await showDialog<Cliente>(context: context, builder: (_) => ClienteDialog());
          if (c != null) store.addCliente(c);
        },
        onDelete: (c) => store.removeCliente(c),
        editDialogBuilder: (c) => ClienteDialog(existing: c),
        onEdit: (c, edited) {
          c.nombre = edited.nombre; c.contacto = edited.contacto; store.saveAll(); store.notifyListeners();
        },
      ),
      CatalogPage<Proveedor>(
        title: 'Proveedores',
        items: store.proveedores,
        itemBuilder: (p) => ListTile(
          title: Text(p.nombre),
          subtitle: Text(p.contacto.isEmpty ? '—' : p.contacto),
        ),
        onAdd: () async {
          final p = await showDialog<Proveedor>(context: context, builder: (_) => ProveedorDialog());
          if (p != null) store.addProveedor(p);
        },
        onDelete: (p) => store.removeProveedor(p),
        editDialogBuilder: (p) => ProveedorDialog(existing: p),
        onEdit: (p, edited) {
          p.nombre = edited.nombre; p.contacto = edited.contacto; store.saveAll(); store.notifyListeners();
        },
      ),
      CatalogPage<MaterialItem>(
        title: 'Materiales',
        items: store.materiales,
        itemBuilder: (m) => ListTile(
          title: Text(m.nombre),
          subtitle: Text(m.unidad),
        ),
        onAdd: () async {
          final m = await showDialog<MaterialItem>(context: context, builder: (_) => MaterialDialog());
          if (m != null) store.addMaterial(m);
        },
        onDelete: (m) => store.removeMaterial(m),
        editDialogBuilder: (m) => MaterialDialog(existing: m),
        onEdit: (m, edited) {
          m.nombre = edited.nombre; m.unidad = edited.unidad; store.saveAll(); store.notifyListeners();
        },
      ),
      PedidosPage(store: store),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.factory), label: 'Proveedores'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Materiales'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Pedidos'),
        ],
      ),
    );
  }
}

/* --------- Catálogo genérico --------- */
typedef ItemBuilder<T> = Widget Function(T item);
typedef EditDialogBuilder<T> = Widget Function(T item);

class CatalogPage<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final ItemBuilder<T> itemBuilder;
  final Future<void> Function()? onAdd;
  final void Function(T item) onDelete;
  final EditDialogBuilder<T> editDialogBuilder;
  final void Function(T item, T edited) onEdit;

  const CatalogPage({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onAdd,
    required this.onDelete,
    required this.editDialogBuilder,
    required this.onEdit,
  });

  @override
  State<CatalogPage<T>> createState() => _CatalogPageState<T>();
}

class _CatalogPageState<T> extends State<CatalogPage<T>> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: widget.itemBuilder(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final edited = await showDialog<T>(
                            context: context,
                            builder: (_) => widget.editDialogBuilder(item),
                          );
                          if (edited != null) widget.onEdit(item, edited);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => widget.onDelete(item),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

/* --------- Diálogos de edición --------- */
String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

class ClienteDialog extends StatefulWidget {
  final Cliente? existing;
  const ClienteDialog({super.key, this.existing});

  @override
  State<ClienteDialog> createState() => _ClienteDialogState();
}

class _ClienteDialogState extends State<ClienteDialog> {
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      nameCtrl.text = widget.existing!.nombre;
      contactCtrl.text = widget.existing!.contacto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contacto (tel/email)')),
        ],
      ),
      actions: [
          IconButton(
            onPressed: () { enviarPedidoAlCliente(pedido); },
            icon: const Icon(Icons.send),
            tooltip: 'Enviar al cliente',
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            final c = Cliente(
              id: widget.existing?.id ?? _newId(),
              nombre: nameCtrl.text.trim(),
              contacto: contactCtrl.text.trim(),
            );
            Navigator.pop(context, c);
          },
          child: const Text('Guardar'),
        )
      ],
    );
  }
}

class ProveedorDialog extends StatefulWidget {
  final Proveedor? existing;
  const ProveedorDialog({super.key, this.existing});

  @override
  State<ProveedorDialog> createState() => _ProveedorDialogState();
}

class _ProveedorDialogState extends State<ProveedorDialog> {
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      nameCtrl.text = widget.existing!.nombre;
      contactCtrl.text = widget.existing!.contacto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo proveedor' : 'Editar proveedor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contacto (tel/email)')),
        ],
      ),
      actions: [
          IconButton(
            onPressed: () { enviarPedidoAlCliente(pedido); },
            icon: const Icon(Icons.send),
            tooltip: 'Enviar al cliente',
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            final p = Proveedor(
              id: widget.existing?.id ?? _newId(),
              nombre: nameCtrl.text.trim(),
              contacto: contactCtrl.text.trim(),
            );
            Navigator.pop(context, p);
          },
          child: const Text('Guardar'),
        )
      ],
    );
  }
}

class MaterialDialog extends StatefulWidget {
  final MaterialItem? existing;
  const MaterialDialog({super.key, this.existing});

  @override
  State<MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<MaterialDialog> {
  final nameCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: 'u');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      nameCtrl.text = widget.existing!.nombre;
      unitCtrl.text = widget.existing!.unidad;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo material' : 'Editar material'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unidad (u, rollo, caja...)')),
        ],
      ),
      actions: [
          IconButton(
            onPressed: () { enviarPedidoAlCliente(pedido); },
            icon: const Icon(Icons.send),
            tooltip: 'Enviar al cliente',
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            final m = MaterialItem(
              id: widget.existing?.id ?? _newId(),
              nombre: nameCtrl.text.trim(),
              unidad: unitCtrl.text.trim().isEmpty ? 'u' : unitCtrl.text.trim(),
            );
            Navigator.pop(context, m);
          },
          child: const Text('Guardar'),
        )
      ],
    );
  }
}

/* --------- Pedidos --------- */
class PedidosPage extends StatefulWidget {
  final AppStore store;
  const PedidosPage({super.key, required this.store});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  @override
  Widget build(BuildContext context) {
    final pedidos = widget.store.pedidos;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Pedidos', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  final nuevo = await Navigator.push<Pedido>(
                    context, MaterialPageRoute(builder: (_) => PedidoEditor(store: widget.store)));
                  if (nuevo != null) {
                    widget.store.upsertPedido(nuevo);
                    setState((){});
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final p = pedidos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('${p.cliente?.nombre ?? "Sin cliente"} → ${p.proveedor?.nombre ?? "Sin proveedor"}'),
                  subtitle: Text('${p.lineas.length} ítems'),
                  onTap: () async {
                    final edited = await Navigator.push<Pedido>(
                      context, MaterialPageRoute(builder: (_) => PedidoEditor(store: widget.store, existing: p)));
                    if (edited != null) widget.store.upsertPedido(edited);
                    setState((){});
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => Share.share(p.toShareText()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => widget.store.removePedido(p),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


Future<void> enviarPedidoAlCliente(Pedido p) async {
  final texto = p.toShareText();
  final contacto = p.cliente?.contacto.trim() ?? '';

  // Si parece email -> mailto
  if (contacto.contains('@')) {
    final uri = Uri(
      scheme: 'mailto',
      path: contacto,
      queryParameters: {
        'subject': 'Pedido',
        'body': texto,
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
  }

  // Si parece teléfono -> WhatsApp (requiere que el usuario tenga WhatsApp instalado)
  final digits = RegExp(r'\d+').allMatches(contacto).map((m) => m.group(0)).join();
  if (digits.isNotEmpty) {
    final wa = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(texto)}');
    if (await canLaunchUrl(wa)) {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
      return;
    }
  }

  // Fallback: compartir con el share sheet
  Share.share(texto);
}

class PedidoEditor extends StatefulWidget {
  final AppStore store;
  final Pedido? existing;
  const PedidoEditor({super.key, required this.store, this.existing});

  @override
  State<PedidoEditor> createState() => _PedidoEditorState();
}

class _PedidoEditorState extends State<PedidoEditor> {
  late Pedido pedido;

  @override
  void initState() {
    super.initState();
    pedido = widget.existing ?? Pedido(id: _newId(), lineas: []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar pedido'),
        actions: [
          IconButton(
            onPressed: () { enviarPedidoAlCliente(pedido); },
            icon: const Icon(Icons.send),
            tooltip: 'Enviar al cliente',
          ),
          IconButton(
            onPressed: () { Share.share(pedido.toShareText()); },
            icon: const Icon(Icons.ios_share),
            tooltip: 'Compartir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            DropdownButtonFormField<Cliente>(
              value: pedido.cliente,
              items: widget.store.clientes.map((c) =>
                DropdownMenuItem(value: c, child: Text(c.nombre))).toList(),
              onChanged: (c) => setState(()=> pedido.cliente = c),
              decoration: const InputDecoration(labelText: 'Cliente'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Proveedor>(
              value: pedido.proveedor,
              items: widget.store.proveedores.map((p) =>
                DropdownMenuItem(value: p, child: Text(p.nombre))).toList(),
              onChanged: (p) => setState(()=> pedido.proveedor = p),
              decoration: const InputDecoration(labelText: 'Proveedor'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Ítems', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _agregarLinea,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                )
              ],
            ),
            const SizedBox(height: 6),
            ...pedido.lineas.asMap().entries.map((e) {
              final i = e.key; final l = e.value;
              return Card(
                child: ListTile(
                  title: Text(l.material.nombre),
                  subtitle: Text('Cantidad: ${l.cantidad} ${l.material.unidad}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: ()=> _editarLinea(i)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: ()=> setState(()=> pedido.lineas.removeAt(i))),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              minLines: 2, maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notas (opcional)', border: OutlineInputBorder()),
              onChanged: (v) => pedido.notas = v,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () { Navigator.pop(context, pedido); },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            )
          ],
        ),
      ),
    );
  }

  void _agregarLinea() async {
    final nueva = await showDialog<LineaPedido>(
      context: context,
      builder: (_) => LineaDialog(store: widget.store),
    );
    if (nueva != null) setState(()=> pedido.lineas.add(nueva));
  }

  void _editarLinea(int index) async {
    final editada = await showDialog<LineaPedido>(
      context: context,
      builder: (_) => LineaDialog(store: widget.store, existing: pedido.lineas[index]),
    );
    if (editada != null) setState(()=> pedido.lineas[index] = editada);
  }
}

class LineaDialog extends StatefulWidget {
  final AppStore store;
  final LineaPedido? existing;
  const LineaDialog({super.key, required this.store, this.existing});

  @override
  State<LineaDialog> createState() => _LineaDialogState();
}

class _LineaDialogState extends State<LineaDialog> {
  MaterialItem? material;
  final qtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      material = widget.existing!.material;
      qtyCtrl.text = widget.existing!.cantidad.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Agregar ítem' : 'Editar ítem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<MaterialItem>(
            value: material,
            items: widget.store.materiales.map((m) =>
              DropdownMenuItem(value: m, child: Text(m.nombre))).toList(),
            onChanged: (m) => setState(()=> material = m),
            decoration: const InputDecoration(labelText: 'Material'),
          ),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          )
        ],
      ),
      actions: [
          IconButton(
            onPressed: () { enviarPedidoAlCliente(pedido); },
            icon: const Icon(Icons.send),
            tooltip: 'Enviar al cliente',
          ),
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final q = int.tryParse(qtyCtrl.text) ?? 1;
            if (material == null || q <= 0) return;
            Navigator.pop(context, LineaPedido(material: material!, cantidad: q));
          },
          child: const Text('Aceptar'),
        )
      ],
    );
  }
}
