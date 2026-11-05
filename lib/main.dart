import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'authentication_screen.dart';
import 'profile_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Autumn Product Manager',
    home: AuthGate(),
  ));
}

double? parsePrice(String text) {
  final input = text.trim();
  if (!RegExp(r'^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$').hasMatch(input)) {
    return null;
  }
  final value = double.tryParse(input);
  return value != null && value.isFinite ? value : null;
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();

  final _search = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _minPrice.clear();
      _maxPrice.clear();
    });
  }

  Future<void> _openEditor({
    DocumentReference<Map<String, dynamic>>? document,
    String name = '',
    String price = '',
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ProductEditor(
        products: _products,
        document: document,
        initialName: name,
        initialPrice: price,
      ),
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $name?'),
        content: Text('Document ID: $id'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    String message;
    try {
      await _products.doc(id).delete();
      message = 'Product deleted.';
    } on FirebaseException catch (error) {
      message = 'Delete failed (${error.code}).';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _priceInput(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.text.trim().toLowerCase();
    final minInput = _minPrice.text.trim();
    final maxInput = _maxPrice.text.trim();
    final min = parsePrice(minInput);
    final max = parsePrice(maxInput);
    final filtering = search.isNotEmpty ||
        minInput.isNotEmpty ||
        maxInput.isNotEmpty;

    String? filterError;
    if ((minInput.isNotEmpty && min == null) ||
        (maxInput.isNotEmpty && max == null)) {
      filterError = 'Enter a valid price of zero or more, or leave it blank.';
    } else if (min != null && max != null && min > max) {
      filterError = 'Min price must be less than or equal to max price.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    Expanded(child: _priceInput(_minPrice, 'Min price')),
                    const SizedBox(width: 12),
                    Expanded(child: _priceInput(_maxPrice, 'Max price')),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                if (filterError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      filterError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Products could not load. Check connection and permissions.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (filterError != null) {
                  return const Center(child: Text('Fix the price range above.'));
                }

                final documents = snapshot.data!.docs;
                if (documents.isEmpty) {
                  return const Center(child: Text('No products yet.'));
                }

                final visible = documents.where((document) {
                  if (!filtering) return true;
                  final data = document.data();
                  final name = data['name'];
                  final price = data['price'];
                  return name is String &&
                      name.trim().isNotEmpty &&
                      price is num &&
                      price.isFinite &&
                      price >= 0 &&
                      name.trim().toLowerCase().contains(search) &&
                      (min == null || price >= min) &&
                      (max == null || price <= max);
                }).toList();

                if (visible.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final document = visible[index];
                    final data = document.data();
                    final name = data['name'];
                    final price = data['price'];

                    if (name is! String ||
                        name.trim().isEmpty ||
                        price is! num ||
                        !price.isFinite ||
                        price < 0) {
                      return ListTile(
                        title: Text(
                          'Invalid product ${document.id}: check name/price types.',
                        ),
                      );
                    }

                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(
                          '${price.toStringAsFixed(2)}\nID: ${document.id}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openEditor(
                                document: document.reference,
                                name: name,
                                price: price.toString(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete product',
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteProduct(document.id, name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({
    super.key,
    required this.products,
    required this.document,
    required this.initialName,
    required this.initialPrice,
  });

  final CollectionReference<Map<String, dynamic>> products;
  final DocumentReference<Map<String, dynamic>>? document;
  final String initialName;
  final String initialPrice;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _price = TextEditingController(text: widget.initialPrice);
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'price': parsePrice(_price.text)!,
    };

    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await document.update(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.document == null ? 'Create product' : 'Edit product'),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) => parsePrice(value ?? '') == null
                      ? 'Enter a valid price of zero or more'
                      : null,
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text('Waiting for Firestore. Reconnect if you’re offline.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Unable to check your session. Please restart the app.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return AuthenticationScreen(auth: _auth);
        }

        return ProfileScreen(
          key: ValueKey(user.uid),
          auth: _auth,
        );
      },
    );
  }
}