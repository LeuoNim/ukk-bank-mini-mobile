import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final name in [
      'current_password',
      'current_pin',
      'new_password',
      'new_password_confirmation',
      'new_pin',
      'new_pin_confirmation',
    ])
      name: TextEditingController(),
  };
  String _mode = 'both';
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _input(
    String name,
    String label, {
    bool pin = false,
    bool current = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _fields[name],
        obscureText: true,
        keyboardType: pin
            ? TextInputType.number
            : TextInputType.visiblePassword,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Wajib diisi';
          if (pin &&
              !(current ? RegExp(r'^\d{4,6}$') : RegExp(r'^\d{6}$')).hasMatch(
                value,
              )) {
            return current ? 'PIN lama 4–6 digit' : 'PIN baru harus 6 digit';
          }
          if (!pin && !current && value.length < 6) return 'Minimal 6 karakter';
          if (name.endsWith('_confirmation') &&
              value != _fields[name.replaceAll('_confirmation', '')]!.text) {
            return 'Konfirmasi tidak sama';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, String>{
      'current_password': _fields['current_password']!.text,
      'current_pin': _fields['current_pin']!.text,
      if (_mode != 'pin') ...{
        'new_password': _fields['new_password']!.text,
        'new_password_confirmation': _fields['new_password_confirmation']!.text,
      },
      if (_mode != 'password') ...{
        'new_pin': _fields['new_pin']!.text,
        'new_pin_confirmation': _fields['new_pin_confirmation']!.text,
      },
    };
    final result = await ApiService().changeSecurity(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Berhasil' : 'Belum berhasil'),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result.success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan Akun')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Password dipakai untuk login web dan HP. PIN dipakai untuk transaksi. Jika lupa kredensial lama, datang ke teller membawa kartu pelajar.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(
                  labelText: 'Yang ingin diubah',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('Password dan PIN'),
                  ),
                  DropdownMenuItem(
                    value: 'password',
                    child: Text('Password saja'),
                  ),
                  DropdownMenuItem(value: 'pin', child: Text('PIN saja')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _mode = value!),
              ),
              const SizedBox(height: 20),
              _input(
                'current_password',
                'Password saat ini (akun lama: PIN awal)',
                current: true,
              ),
              _input('current_pin', 'PIN saat ini', pin: true, current: true),
              if (_mode != 'pin') ...[
                _input('new_password', 'Password baru'),
                _input('new_password_confirmation', 'Ulangi password baru'),
              ],
              if (_mode != 'password') ...[
                _input('new_pin', 'PIN baru', pin: true),
                _input('new_pin_confirmation', 'Ulangi PIN baru', pin: true),
              ],
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
