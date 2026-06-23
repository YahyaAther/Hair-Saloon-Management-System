import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

String formatTime(dynamic timeStr) {
  if (timeStr == null) return '';
  final str = timeStr.toString();
  if (str.isEmpty) return '';
  final parts = str.split(':');
  if (parts.length < 2) return str;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts[1];
  final ampm = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:$minute $ampm';
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, StylistProvider>(
          create: (_) => StylistProvider(),
          update: (_, auth, stylist) => stylist!..updateAuth(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ManagerProvider>(
          create: (_) => ManagerProvider(),
          update: (_, auth, manager) => manager!..updateAuth(auth.token),
        ),
      ],
      child: const SaloonProMobileApp(),
    ),
  );
}

class SaloonProMobileApp extends StatelessWidget {
  const SaloonProMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaloonPro Staff Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE5A55D),
        scaffoldBackgroundColor: const Color(0xFF090A0F), // Ultra premium deep black
        cardColor: const Color(0xFF13151B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5A55D),
          secondary: Color(0xFFC58C46), // Rich gold accent
          surface: Color(0xFF13151B),
          error: Color(0xFFF87171),
        ),
        fontFamily: 'Outfit',
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF13151B),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090A0F),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==========================================
// STATE MANAGEMENT - PROVIDERS
// ==========================================

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void logout() {
    _token = null;
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/index.php?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _token = data['token'];
        _user = data['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? 'Invalid username or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection failed. Ensure backend server is running.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

class StylistProvider extends ChangeNotifier {
  String? _authToken;
  bool _isLoadingQueue = false;
  bool _isLoadingWallet = false;
  bool _isLoadingStatus = false;
  List<dynamic> _queue = [];
  Map<String, dynamic>? _walletData;
  bool _isAvailable = false;

  String? get authToken => _authToken;
  bool get isLoadingQueue => _isLoadingQueue;
  bool get isLoadingWallet => _isLoadingWallet;
  bool get isLoadingStatus => _isLoadingStatus;
  List<dynamic> get queue => _queue;
  Map<String, dynamic>? get walletData => _walletData;
  bool get isAvailable => _isAvailable;

  void updateAuth(String? token) {
    if (_authToken != token) {
      _authToken = token;
      if (token == null) {
        _queue = [];
        _walletData = null;
        _isAvailable = false;
      }
    }
  }

  Future<void> loadStylistStatus(int? userId) async {
    if (_authToken == null) return;
    _isLoadingStatus = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=staff'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> staffList = jsonDecode(response.body);
        final me = staffList.firstWhere(
          (s) => s['user_id'].toString() == userId.toString(),
          orElse: () => null,
        );
        if (me != null) {
          _isAvailable = me['status'] == 'available';
        }
      }
    } catch (e) {
      debugPrint('Error loading stylist status: $e');
    } finally {
      _isLoadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> toggleAvailability(bool value) async {
    if (_authToken == null) return;
    _isAvailable = value;
    _isLoadingStatus = true;
    notifyListeners();

    final statusStr = value ? 'available' : 'off';
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/index.php?action=staff_update_status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'status': statusStr}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        _isAvailable = !value;
      }
    } catch (e) {
      _isAvailable = !value;
      debugPrint('Error updating status: $e');
    } finally {
      _isLoadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> loadQueue() async {
    if (_authToken == null) return;
    _isLoadingQueue = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=appointments_today'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (response.statusCode == 200) {
        _queue = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error loading stylist queue: $e');
    } finally {
      _isLoadingQueue = false;
      notifyListeners();
    }
  }

  Future<void> loadWallet() async {
    if (_authToken == null) return;
    _isLoadingWallet = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=stylist_payouts'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (response.statusCode == 200) {
        _walletData = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error loading wallet details: $e');
    } finally {
      _isLoadingWallet = false;
      notifyListeners();
    }
  }

  Future<bool> updateAppointmentStatus(int id, String status) async {
    if (_authToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/index.php?action=appointments_update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'id': id, 'status': status}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await loadQueue();
        if (status == 'completed') {
          await loadWallet();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Failed to update status: $e');
    }
    return false;
  }
}

class ManagerProvider extends ChangeNotifier {
  String? _authToken;
  bool _isLoadingMetrics = false;
  bool _isLoadingExpenses = false;
  bool _isLoadingStaff = false;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _expenses = [];
  List<dynamic> _staffList = [];

  String? get authToken => _authToken;
  bool get isLoadingMetrics => _isLoadingMetrics;
  bool get isLoadingExpenses => _isLoadingExpenses;
  bool get isLoadingStaff => _isLoadingStaff;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<dynamic> get expenses => _expenses;
  List<dynamic> get staffList => _staffList;

  void updateAuth(String? token) {
    if (_authToken != token) {
      _authToken = token;
      if (token == null) {
        _dashboardData = null;
        _expenses = [];
        _staffList = [];
      }
    }
  }

  Future<void> loadStaff() async {
    if (_authToken == null) return;
    _isLoadingStaff = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=staff'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (response.statusCode == 200) {
        _staffList = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
    } finally {
      _isLoadingStaff = false;
      notifyListeners();
    }
  }

  Future<void> loadMetrics() async {
    if (_authToken == null) return;
    _isLoadingMetrics = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=dashboard'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (response.statusCode == 200) {
        _dashboardData = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error loading metrics: $e');
    } finally {
      _isLoadingMetrics = false;
      notifyListeners();
    }
  }

  Future<void> loadExpenses() async {
    if (_authToken == null) return;
    _isLoadingExpenses = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/index.php?action=expenses'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (response.statusCode == 200) {
        _expenses = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    } finally {
      _isLoadingExpenses = false;
      notifyListeners();
    }
  }

  Future<bool> logExpense(String category, double amount, String description) async {
    if (_authToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/index.php?action=expenses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'category': category,
          'amount': amount,
          'description': description,
          'expense_date': DateTime.now().toIso8601String().split('T')[0]
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await loadExpenses();
        await loadMetrics();
        return true;
      }
    } catch (e) {
      debugPrint('Error logging expense: $e');
    }
    return false;
  }
}

// ==========================================
// AUTH WRAPPER
// ==========================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.token == null || auth.user == null) {
      return const LoginScreen();
    }

    final role = auth.user!['role'] ?? '';
    if (role == 'admin' || role == 'receptionist') {
      return const ManagerDashboard();
    } else if (role == 'stylist') {
      return const StylistDashboard();
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Unknown user role'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: auth.logout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// ==========================================
// LOGIN SCREEN
// ==========================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and password are required')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.login(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1.0 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(32.0),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF13151B), Color(0xFF090A0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFE5A55D).withOpacity(0.25), width: 1.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A55D).withOpacity(0.04),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A55D).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.content_cut_rounded, color: Color(0xFFE5A55D), size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SaloonPro',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Staff Portal Login',
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFE5A55D), size: 20),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5A55D), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE5A55D), size: 20),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5A55D), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE5A55D), Color(0xFFC58C46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5A55D).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F1115),
                              ),
                            )
                          : const Text(
                              'SIGN IN',
                              style: TextStyle(
                                color: Color(0xFF0F1115),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pulsing indicator for availability dot
class PulsingStatusDot extends StatefulWidget {
  final bool isAvailable;
  const PulsingStatusDot({required this.isAvailable, super.key});

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isAvailable ? Colors.green : Colors.red;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF13151B), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25 + 0.45 * _controller.value),
                blurRadius: 4 + 6 * _controller.value,
                spreadRadius: 1 + 2 * _controller.value,
              )
            ],
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// OWNER/MANAGER DASHBOARD
// ==========================================

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _selectedTab = 0;

  // Add Expense form controllers
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Rent';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ManagerProvider>(context, listen: false);
      provider.loadMetrics();
      provider.loadExpenses();
      provider.loadStaff();
    });
  }

  void _refresh() {
    final provider = Provider.of<ManagerProvider>(context, listen: false);
    provider.loadMetrics();
    provider.loadExpenses();
    provider.loadStaff();
  }

  Future<void> _logExpense() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );
      return;
    }

    final provider = Provider.of<ManagerProvider>(context, listen: false);
    final success = await provider.logExpense(_selectedCategory, amount, _descController.text.trim());
    if (success) {
      _amountController.clear();
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense logged successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log expense')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final manager = Provider.of<ManagerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? 'Manager Dashboard' : 'Salon Expenses',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFFE5A55D),
                child: Text(
                  auth.user?['name']?[0]?.toUpperCase() ?? 'M',
                  style: const TextStyle(color: Color(0xFF0F1115), fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              accountName: Text(auth.user?['name'] ?? 'Manager'),
              accountEmail: Text('@${auth.user?['username'] ?? 'admin'} • ${(auth.user?['role'] ?? 'admin').toString().toUpperCase()}'),
              decoration: const BoxDecoration(color: Color(0xFF13151B)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard Metrics'),
              selected: _selectedTab == 0,
              onTap: () {
                setState(() => _selectedTab = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallet_outlined),
              title: const Text('Salon Expenses'),
              selected: _selectedTab == 1,
              onTap: () {
                setState(() => _selectedTab = 1);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFF87171)),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFFF87171))),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _selectedTab == 0 
            ? _buildMetricsTab(manager) 
            : _buildExpensesTab(manager),
      ),
    );
  }

  Widget _buildMetricsTab(ManagerProvider manager) {
    if (manager.isLoadingMetrics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (manager.dashboardData == null) {
      return const Center(child: Text('Failed to load dashboard metrics'));
    }

    final totalRevenue = double.tryParse(manager.dashboardData!['totalRevenue']?.toString() ?? '0.0') ?? 0.0;
    final aptToday = manager.dashboardData!['appointmentsToday'] ?? 0;
    final totalClients = manager.dashboardData!['totalClients'] ?? 0;
    final list = manager.dashboardData!['todayAppointmentsList'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'TODAY\'S REVENUE',
                  '\$${totalRevenue.toStringAsFixed(2)}',
                  Icons.monetization_on_outlined,
                  const Color(0xFFE5A55D),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'TODAY\'S QUEUE',
                  aptToday.toString(),
                  Icons.calendar_today_outlined,
                  const Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'TOTAL CLIENTS',
                  totalClients.toString(),
                  Icons.people_outline,
                  const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Stylist Activity Status',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStaffStatusGrid(manager),
          const SizedBox(height: 32),
          const Text(
            'Today\'s Salon Schedule',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No appointments booked for today.')),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final apt = list[idx];
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 350 + (idx * 50).clamp(0, 300)),
                  curve: Curves.easeOut,
                  builder: (context, val, child) {
                    return Opacity(
                      opacity: val,
                      child: Transform.translate(offset: Offset(0, 15 * (1 - val)), child: child),
                    );
                  },
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.event),
                      ),
                      title: Text(
                        apt['client_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${apt['service_name']} @ ${apt['start_time']} • Stylist: ${apt['staff_name']}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      trailing: Chip(
                        label: Text(
                          apt['status'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: apt['status'] == 'active'
                            ? const Color(0xFFE5A55D).withOpacity(0.2)
                            : Colors.white10,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffStatusGrid(ManagerProvider manager) {
    if (manager.isLoadingStaff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final stylists = manager.staffList.where((s) => s['role'] == 'stylist').toList();

    if (stylists.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No stylists registered.')),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
        double childAspectRatio = constraints.maxWidth > 800 ? 2.5 : 3.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stylists.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final stylist = stylists[index];
            final name = stylist['name'] ?? 'Stylist';
            final specializations = stylist['specializations'] ?? 'General Styling';
            final status = stylist['status'] ?? 'off';
            final isAvailable = status == 'available';

            return InkWell(
              onTap: () => _showStylistDetailsDialog(stylist),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  border: Border.all(
                    color: isAvailable ? Colors.green.withOpacity(0.3) : Colors.white10,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE5A55D),
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF0F1115),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1E222B), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specializations,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAvailable ? 'AVAILABLE' : 'OFF DUTY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? Colors.green : Colors.red,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white30,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStylistDetailsDialog(Map<String, dynamic> stylist) {
    final name = stylist['name'] ?? 'Stylist';
    final username = stylist['username'] ?? '';
    final specializations = stylist['specializations'] ?? 'General Styling';
    final commissionRate = stylist['commission_rate'] ?? '0.0';
    final commissionType = stylist['commission_type'] ?? 'percentage';
    final status = stylist['status'] ?? 'off';
    final isAvailable = status == 'available';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5A55D), width: 1),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE5A55D),
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(color: Color(0xFF0F1115), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '@$username',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              _buildDetailItem('Role', 'Stylist Partner'),
              _buildDetailItem('Specializations', specializations),
              _buildDetailItem('Commission', '$commissionRate% ($commissionType)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Activity Status: ', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAvailable ? 'Available' : 'Off Duty',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: Color(0xFFE5A55D), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(ManagerProvider manager) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Log new expense form
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log New Expense',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const Text('Category', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: ['Rent', 'Utilities', 'Salon Supplies', 'Marketing', 'Salaries', 'Other']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Amount (\$)', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '0.00',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Description', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter expense description...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _logExpense,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5A55D), foregroundColor: const Color(0xFF0F1115)),
                        child: const Text('LOG EXPENSE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right Column: Expenses History List
        Expanded(
          flex: 3,
          child: manager.isLoadingExpenses
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: manager.expenses.length,
                  itemBuilder: (context, idx) {
                    final exp = manager.expenses[idx];
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (idx * 50).clamp(0, 300)),
                      curve: Curves.easeOut,
                      builder: (context, val, child) {
                        return Opacity(
                          opacity: val,
                          child: Transform.translate(offset: Offset(0, 15 * (1 - val)), child: child),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.outbox_outlined, color: Color(0xFFF87171)),
                          ),
                          title: Text(
                            exp['category'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${exp['expense_date']} • ${exp['description'] ?? "No description"}\nLogged by: ${exp['logged_by_name']}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: Text(
                            '-\$${double.parse(exp['amount'].toString()).toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          isThreeLine: true,
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

// ==========================================
// STYLIST PORTAL & WALLET
// ==========================================

class StylistDashboard extends StatefulWidget {
  const StylistDashboard({super.key});

  @override
  State<StylistDashboard> createState() => _StylistDashboardState();
}

class _StylistDashboardState extends State<StylistDashboard> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final stylist = Provider.of<StylistProvider>(context, listen: false);
      stylist.loadStylistStatus(auth.user?['id']);
      stylist.loadQueue();
      stylist.loadWallet();
    });
  }

  void _refresh() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final stylist = Provider.of<StylistProvider>(context, listen: false);
    stylist.loadStylistStatus(auth.user?['id']);
    stylist.loadQueue();
    stylist.loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final stylist = Provider.of<StylistProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? 'My Task Queue' : 'My Payout Wallet',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: auth.logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFFE5A55D),
                child: Text(
                  auth.user?['name']?[0]?.toUpperCase() ?? 'S',
                  style: const TextStyle(color: Color(0xFF0F1115), fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              accountName: Text(auth.user?['name'] ?? 'Stylist'),
              accountEmail: Text('@${auth.user?['username'] ?? "stylist"} • Stylist Partner'),
              decoration: const BoxDecoration(color: Color(0xFF13151B)),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted_rounded),
              title: const Text('My Daily Tasks'),
              selected: _selectedTab == 0,
              onTap: () {
                setState(() => _selectedTab = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('My Wallet & Earnings'),
              selected: _selectedTab == 1,
              onTap: () {
                setState(() => _selectedTab = 1);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFFF87171))),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _selectedTab == 0 ? _buildQueueTab(stylist, auth) : _buildWalletTab(stylist, auth),
      ),
    );
  }

  Widget _buildStatusSwitchCard(StylistProvider stylist, AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF13151B),
            Color(0xFF090A0F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stylist.isAvailable 
              ? const Color(0xFFE5A55D).withOpacity(0.3) 
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          if (stylist.isAvailable)
            BoxShadow(
              color: const Color(0xFFE5A55D).withOpacity(0.03),
              blurRadius: 20,
              spreadRadius: 2,
            )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: stylist.isAvailable
                        ? [const Color(0xFFE5A55D), const Color(0xFFC58C46)]
                        : [Colors.white10, Colors.white24],
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF0F1115),
                  child: Text(
                    auth.user?['name']?[0]?.toUpperCase() ?? 'S',
                    style: const TextStyle(
                      color: Color(0xFFE5A55D),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: PulsingStatusDot(isAvailable: stylist.isAvailable),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${auth.user?['name'] ?? 'Stylist'}!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: stylist.isAvailable ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stylist.isAvailable ? 'AVAILABLE FOR CLIENTS' : 'OFF DUTY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stylist.isAvailable ? Colors.green : Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (stylist.isLoadingStatus) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFE5A55D),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: stylist.isAvailable,
            activeColor: const Color(0xFFE5A55D),
            activeTrackColor: const Color(0xFFE5A55D).withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.2),
            onChanged: stylist.isLoadingStatus ? null : (val) => stylist.toggleAvailability(val),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTab(StylistProvider stylist, AuthProvider auth) {
    return Column(
      children: [
        _buildStatusSwitchCard(stylist, auth),
        Expanded(
          child: stylist.isLoadingQueue
              ? const Center(child: CircularProgressIndicator())
              : stylist.queue.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text('No bookings assigned for today.', style: TextStyle(fontSize: 16, color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      itemCount: stylist.queue.length,
                      itemBuilder: (context, idx) {
                        final apt = stylist.queue[idx];
                        final start = formatTime(apt['start_time']);
                        final statusStr = apt['status'].toString().toUpperCase();
                        final isActive = apt['status'] == 'active';
                        final isCompleted = apt['status'] == 'completed';
                        final isUpcoming = apt['status'] == 'upcoming';

                        return TweenAnimationBuilder<double>(
                          key: ValueKey(apt['id']),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 350 + (idx * 50).clamp(0, 300)),
                          curve: Curves.easeOut,
                          builder: (context, val, child) {
                            return Opacity(
                              opacity: val,
                              child: Transform.translate(offset: Offset(0, 15 * (1.0 - val)), child: child),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isActive ? const Color(0xFF16251E) : const Color(0xFF13151B),
                                  const Color(0xFF090A0F),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive 
                                    ? Colors.green.withOpacity(0.4) 
                                    : (isCompleted ? Colors.white10.withOpacity(0.04) : Colors.white10),
                                width: isActive ? 2.0 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                                if (isActive)
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.05),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time_filled_rounded, color: Color(0xFFE5A55D), size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              start,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE5A55D), fontFamily: 'Outfit'),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive 
                                                ? Colors.green.withOpacity(0.15) 
                                                : (isCompleted ? Colors.white10 : const Color(0xFFE5A55D).withOpacity(0.1)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isActive 
                                                  ? Colors.green.withOpacity(0.3) 
                                                  : (isCompleted ? Colors.transparent : const Color(0xFFE5A55D).withOpacity(0.2)),
                                              width: 1,
                                            )
                                          ),
                                          child: Text(
                                            statusStr,
                                            style: TextStyle(
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold,
                                              color: isActive 
                                                  ? Colors.green 
                                                  : (isCompleted ? Colors.white60 : const Color(0xFFE5A55D)),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 28, color: Colors.white12),
                                    Text(
                                      apt['client_name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, fontFamily: 'Outfit'),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.spa_rounded, color: Colors.white54, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          apt['service_name'],
                                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.timer_outlined, color: Colors.white54, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${apt['duration_mins']} mins',
                                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if (apt['client_phone'] != null && apt['client_phone'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_rounded, color: Colors.white38, size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            apt['client_phone'],
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    if (isUpcoming)
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: () => stylist.updateAppointmentStatus(apt['id'], 'active'),
                                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                          label: const Text('START SERVICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE5A55D),
                                            foregroundColor: const Color(0xFF0F1115),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      )
                                    else if (isActive)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 44,
                                              child: ElevatedButton.icon(
                                                onPressed: () => stylist.updateAppointmentStatus(apt['id'], 'completed'),
                                                icon: const Icon(Icons.check_rounded, size: 20),
                                                label: const Text('COMPLETE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.black,
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            height: 44,
                                            width: 60,
                                            child: ElevatedButton(
                                              onPressed: () => stylist.updateAppointmentStatus(apt['id'], 'cancelled'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFF87171).withOpacity(0.15),
                                                foregroundColor: const Color(0xFFF87171),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: const BorderSide(color: Color(0xFFF87171), width: 1),
                                                ),
                                              ),
                                              child: const Icon(Icons.close_rounded, size: 20),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white24),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'No actions available for completed appointments.',
                                            style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildWalletTab(StylistProvider stylist, AuthProvider auth) {
    if (stylist.isLoadingWallet) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stylist.walletData == null) {
      return const Center(child: Text('Failed to load wallet data'));
    }

    final totalEarned = double.tryParse(stylist.walletData!['total_earned']?.toString() ?? '0.0') ?? 0.0;
    final payouts = stylist.walletData!['payouts'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payout Balance Card (Luxury Gold Credit Card style)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFD4AF37), // Metallic Gold
                  Color(0xFFC58C46), // Rich Gold
                  Color(0xFFAA7C11), // Dark Gold
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC58C46).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SALOONPRO WALLET',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white30, width: 1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 20,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'TOTAL COMMISSION EARNED',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\$${totalEarned.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              auth.user?['name']?.toUpperCase() ?? 'PARTNER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Text(
                              'VIP PARTNER',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'Earnings Log Details',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (payouts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: const Color(0xFF13151B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
              ),
              child: const Center(child: Text('No payouts logged yet.', style: TextStyle(color: Colors.white38))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payouts.length,
              itemBuilder: (context, idx) {
                final pay = payouts[idx];
                final date = pay['created_at'].toString().split(' ')[0];
                final name = pay['service_name'] ?? pay['product_name'] ?? 'Item';

                return TweenAnimationBuilder<double>(
                  key: ValueKey(pay['id'] ?? idx),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (idx * 50).clamp(0, 300)),
                  curve: Curves.easeOut,
                  builder: (context, val, child) {
                    return Opacity(
                      opacity: val,
                      child: Transform.translate(offset: Offset(0, 15 * (1.0 - val)), child: child),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.attach_money_rounded, color: Colors.green, size: 22),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '$date • Type: ${pay['item_type'].toString().toUpperCase()} • Sold Qty: ${pay['quantity']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      trailing: Text(
                        '+\$${double.parse(pay['commission_paid'].toString()).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
