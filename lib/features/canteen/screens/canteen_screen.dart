import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class _MenuItem {
  const _MenuItem({
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.available = true,
  });

  final String name;
  final String category;
  final double price;
  final String description;
  final bool available;
}

class CanteenScreen extends StatefulWidget {
  const CanteenScreen({super.key});

  @override
  State<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends State<CanteenScreen> {
  static const _deliveryFee = 8.0;
  static const _menu = <_MenuItem>[
    _MenuItem(name: 'Jollof rice', category: 'Meals', price: 35, description: 'Jollof rice with chicken and salad'),
    _MenuItem(name: 'Fried rice', category: 'Meals', price: 38, description: 'Fried rice with chicken and vegetables'),
    _MenuItem(name: 'Rice and stew', category: 'Meals', price: 32, description: 'Steamed rice with house stew'),
    _MenuItem(name: 'Spaghetti / Indomie', category: 'Meals', price: 28, description: 'Freshly prepared noodles or spaghetti'),
    _MenuItem(name: 'Banku and okro', category: 'Meals', price: 35, description: 'Traditional banku with okro soup'),
    _MenuItem(name: 'Kenkey and pepper', category: 'Meals', price: 30, description: 'Kenkey with pepper and fish'),
    _MenuItem(name: 'Samosa', category: 'Snacks', price: 12, description: 'Crispy savoury samosa'),
    _MenuItem(name: 'Spring rolls', category: 'Snacks', price: 12, description: 'Crispy vegetable spring rolls'),
    _MenuItem(name: 'Sobolo', category: 'Drinks', price: 10, description: 'Chilled hibiscus drink'),
    _MenuItem(name: 'Bottled water', category: 'Drinks', price: 5, description: '500ml bottled water'),
  ];

  final Map<String, int> _cart = {};
  final _searchController = TextEditingController();
  String _category = 'All';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MenuItem> get _filteredMenu {
    final query = _searchController.text.trim().toLowerCase();
    return _menu.where((item) {
      final categoryMatches = _category == 'All' || item.category == _category;
      final queryMatches = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList();
  }

  double get _subtotal => _cart.entries.fold(0, (total, entry) {
        final item = _menu.firstWhere((menuItem) => menuItem.name == entry.key);
        return total + item.price * entry.value;
      });

  int get _cartCount => _cart.values.fold(0, (total, count) => total + count);

  void _changeQuantity(_MenuItem item, int change) {
    final next = (_cart[item.name] ?? 0) + change;
    setState(() {
      if (next <= 0) {
        _cart.remove(item.name);
      } else {
        _cart[item.name] = next;
      }
    });
  }

  Future<void> _openCheckout() async {
    if (_cart.isEmpty) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckoutSheet(subtotal: _subtotal, deliveryFee: _deliveryFee),
    );
    if (result == null || !mounted) return;
    await _submitOrder(result);
  }

  Future<void> _submitOrder(Map<String, String> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    final delivery = details['fulfilment'] == 'Delivery';
    try {
      await FirebaseFirestore.instance.collection('canteen_orders').add({
        'userId': user.uid,
        'customerName': user.displayName ?? user.email ?? 'Regent user',
        'items': _cart.entries.map((entry) => {
              'name': entry.key,
              'quantity': entry.value,
              'unitPrice': _menu.firstWhere((item) => item.name == entry.key).price,
            }).toList(),
        'fulfilment': details['fulfilment'],
        'pickupOrDeliveryPoint': details['location'],
        'momoNumber': details['momoNumber'],
        'subtotal': _subtotal,
        'deliveryFee': delivery ? _deliveryFee : 0,
        'total': _subtotal + (delivery ? _deliveryFee : 0),
        'paymentMethod': 'Mobile Money',
        'paymentStatus': 'Awaiting confirmation',
        'orderStatus': 'Received',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Order received. Complete the MoMo prompt to confirm payment.'),
        backgroundColor: RegentColors.statusAccent,
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order could not be placed: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Meals', 'Snacks', 'Drinks'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regent Canteen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Message Canteen',
            onPressed: _openCanteenChat,
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Call Canteen',
            onPressed: () => _openCanteenChat(startCall: true),
          ),
          IconButton(icon: const Icon(Icons.receipt_long_outlined), onPressed: _showOrders, tooltip: 'My orders'),
          Stack(clipBehavior: Clip.none, children: [
            IconButton(icon: const Icon(Icons.shopping_bag_outlined), onPressed: _openCheckout, tooltip: 'Cart'),
            if (_cartCount > 0) Positioned(right: 5, top: 2, child: _Badge(value: _cartCount)),
          ]),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [RegentColors.primaryDark, RegentColors.primaryBright]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good food, ready when you are', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Pre-order from campus vendors and pick up or get it delivered.', style: TextStyle(color: Colors.white.withOpacity(.85))),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search meals, snacks or drinks',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        SizedBox(height: 54, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => ChoiceChip(label: Text(categories[index]), selected: _category == categories[index], onSelected: (_) => setState(() => _category = categories[index])),
        )),
        Expanded(child: _filteredMenu.isEmpty
            ? const Center(child: Text('No matching canteen items'))
            : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: _filteredMenu.length, itemBuilder: (_, index) => _menuCard(_filteredMenu[index]))),
      ]),
      floatingActionButton: _cartCount == 0 ? null : FloatingActionButton.extended(onPressed: _openCheckout, icon: const Icon(Icons.shopping_bag), label: Text('Cart ($_cartCount)')),
    );
  }

  Widget _menuCard(_MenuItem item) {
    final quantity = _cart[item.name] ?? 0;
    final icon = item.category == 'Drinks' ? Icons.local_drink : item.category == 'Snacks' ? Icons.cookie_outlined : Icons.rice_bowl;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: RegentColors.primarySoft, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: RegentColors.primaryDark, size: 30)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text(item.description, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)), const SizedBox(height: 6), Text('GH₵ ${item.price.toStringAsFixed(2)}', style: const TextStyle(color: RegentColors.primaryDark, fontWeight: FontWeight.w800))])),
        if (quantity == 0) IconButton(onPressed: () => _changeQuantity(item, 1), icon: const Icon(Icons.add_circle, color: RegentColors.primaryBright), tooltip: 'Add to cart') else Row(children: [IconButton(onPressed: () => _changeQuantity(item, -1), icon: const Icon(Icons.remove_circle_outline)), Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(onPressed: () => _changeQuantity(item, 1), icon: const Icon(Icons.add_circle, color: RegentColors.primaryBright))]),
      ])),
    );
  }

  void _showOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * .72, child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('canteen_orders').where('userId', isEqualTo: user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Orders are temporarily unavailable.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) return const Center(child: Text('You have no canteen orders yet.'));
        return ListView(padding: const EdgeInsets.all(20), children: [const Text('My orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 12), ...orders.map((doc) { final data = doc.data() as Map<String, dynamic>; return Card(child: ListTile(leading: const Icon(Icons.restaurant, color: RegentColors.primaryBright), title: Text('${data['fulfilment'] ?? 'Pickup'} · GH₵ ${(data['total'] ?? 0).toString()}'), subtitle: Text('${data['orderStatus'] ?? 'Received'} · ${data['paymentStatus'] ?? 'Awaiting payment'}'), isThreeLine: true)); })]);
      },
    )));
  }

  void _openCanteenChat({bool startCall = false}) {
    Navigator.pushNamed(context, '/chat', arguments: {
      'userId': 'official:canteen',
      'userName': 'Regent Canteen',
    });
    if (startCall) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Open the Canteen chat and use the call button to start the call.'),
      ));
    }
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.subtotal, required this.deliveryFee});
  final double subtotal;
  final double deliveryFee;
  @override State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _fulfilment = 'Pickup';
  final _location = TextEditingController();
  final _momo = TextEditingController();
  @override void dispose() { _location.dispose(); _momo.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final total = widget.subtotal + (_fulfilment == 'Delivery' ? widget.deliveryFee : 0);
    return Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Checkout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      Text('Subtotal: GH₵ ${widget.subtotal.toStringAsFixed(2)}'),
      const SizedBox(height: 14),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'Pickup', label: Text('Pick up'), icon: Icon(Icons.storefront)), ButtonSegment(value: 'Delivery', label: Text('Delivery'), icon: Icon(Icons.delivery_dining))], selected: {_fulfilment}, onSelectionChanged: (value) => setState(() => _fulfilment = value.first)),
      const SizedBox(height: 12),
      TextField(controller: _location, decoration: InputDecoration(labelText: _fulfilment == 'Pickup' ? 'Pickup note (optional)' : 'Office / class delivery location', prefixIcon: const Icon(Icons.location_on_outlined))),
      const SizedBox(height: 12),
      TextField(controller: _momo, onChanged: (_) => setState(() {}), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'MoMo number', hintText: '024 000 0000', prefixIcon: Icon(Icons.phone_android))),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: RegentColors.primarySoft, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivery fee: GH₵ ${(_fulfilment == 'Delivery' ? widget.deliveryFee : 0).toStringAsFixed(2)}'), const SizedBox(height: 4), Text('Total: GH₵ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _momo.text.trim().isEmpty ? null : () => Navigator.pop(context, {'fulfilment': _fulfilment, 'location': _location.text.trim(), 'momoNumber': _momo.text.trim()}), icon: const Icon(Icons.payment), label: const Text('Place order and pay with MoMo'))),
      const SizedBox(height: 6), const Text('A payment prompt or vendor confirmation may be required after placing the order.', style: TextStyle(fontSize: 12)),
    ])));
  }
}

class _Badge extends StatelessWidget { const _Badge({required this.value}); final int value; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: const BoxDecoration(color: RegentColors.green, shape: BoxShape.circle), child: Text('$value', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))); }
