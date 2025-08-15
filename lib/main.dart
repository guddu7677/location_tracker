// main.dart - Updated with enhanced permission-based routing
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'sender_dashboard_page.dart';
import 'receiver_dashboard_page.dart';
import 'user.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Sharing App - Real-time Updates',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/register':
            return MaterialPageRoute(builder: (context) => const RegisterPage());
          case '/sender-dashboard':
            final user = settings.arguments as User;
            if (!user.isSender) {
              // Redirect to appropriate dashboard if wrong user type
              return MaterialPageRoute(
                builder: (context) => const LoginPage(),
              );
            }
            return MaterialPageRoute(
              builder: (context) => SenderDashboardPage(user: user),
            );
          case '/receiver-dashboard':
            final user = settings.arguments as User;
            if (!user.isReceiver) {
              // Redirect to appropriate dashboard if wrong user type
              return MaterialPageRoute(
                builder: (context) => const LoginPage(),
              );
            }
            return MaterialPageRoute(
              builder: (context) => ReceiverDashboardPage(user: user),
            );
          default:
            return MaterialPageRoute(builder: (context) => const LoginPage());
        }
      },
    );
  }
}

// Enhanced login page with better user experience
class EnhancedLoginPage extends StatefulWidget {
  const EnhancedLoginPage({super.key});

  @override
  State<EnhancedLoginPage> createState() => _EnhancedLoginPageState();
}

class _EnhancedLoginPageState extends State<EnhancedLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final username = _usernameController.text;
        final password = _passwordController.text;

        final user = UserDatabase.users.firstWhere(
          (user) => user.username == username && user.password == password,
          orElse: () => throw Exception('User not found'),
        );

        // Add slight delay for better UX
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Route based on user permission
        if (user.isSender) {
          Navigator.pushReplacementNamed(
            context,
            '/sender-dashboard',
            arguments: user,
          );
        } else if (user.isReceiver) {
          Navigator.pushReplacementNamed(
            context,
            '/receiver-dashboard',
            arguments: user,
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid username or password'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _quickLogin(String username, String password) {
    _usernameController.text = username;
    _passwordController.text = password;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Sharing App - Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Login to Location App',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Username is required' : null,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) =>
                            value!.isEmpty ? 'Password is required' : null,
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _login,
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login),
                          label: Text(_isLoading ? 'Logging in...' : 'Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.deck, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Demo Accounts - Quick Login:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sender Users (real-time location sharing):',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildQuickLoginButton('john_sender', 'pass123', 'John Doe', Icons.send, Colors.green),
                      _buildQuickLoginButton('jane_sender', 'secure456', 'Jane Smith', Icons.send, Colors.green),
                      _buildQuickLoginButton('alice_sender', 'alice789', 'Alice Wong', Icons.send, Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        'Receiver Users (view all sender locations):',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildQuickLoginButton('bob_receiver', 'bob101', 'Bob Jones', Icons.visibility, Colors.blue),
                      _buildQuickLoginButton('emma_receiver', 'emma202', 'Emma Brown', Icons.visibility, Colors.blue),
                      _buildQuickLoginButton('mike_receiver', 'mike303', 'Mike Wilson', Icons.visibility, Colors.blue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'How it Works:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('• Senders share their location automatically every 5 seconds'),
                      const Text('• Receivers can view all sender locations in real-time'),
                      const Text('• Location permission is required for senders'),
                      const Text('• Receivers can calculate distances to sender locations'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginButton(String username, String password, String displayName, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _quickLogin(username, password),
          icon: Icon(icon, size: 16, color: color),
          label: Text(
            '$displayName ($username)',
            style: TextStyle(color: color),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.5)),
            backgroundColor: color.withOpacity(0.05),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}