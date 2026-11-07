import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class DashboardTab extends StatefulWidget {
  final Function(int) onTabChange;

  const DashboardTab({
    super.key,
    required this.onTabChange,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  CustomerModel? _customer;
  List<TransactionModel> _recentTransactions = [];
  Map<String, dynamic>? _pendingWithdrawal;
  bool _isLoading = true;
  bool _hideBalance = false;
  Timer? _pollTimer;
  bool _isPinDialogOpen = false;
  int? _lastPromptedTrxId;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Polling setiap 3 detik untuk mendeteksi permintaan penarikan dari loket teller secara realtime
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPendingWithdrawal();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingWithdrawal() async {
    final res = await ApiService().getPendingWithdrawal();
    if (res.success && mounted) {
      if (_pendingWithdrawal?['id'] != res.data?['id']) {
        setState(() {
          _pendingWithdrawal = res.data;
        });
      }

      // Jika ada permintaan penarikan baru dan dialog belum terbuka, otomatis munculkan Pop-up PIN
      if (res.data != null && !_isPinDialogOpen) {
        final trxId = res.data!['id'];
        if (_lastPromptedTrxId != trxId) {
          _lastPromptedTrxId = trxId;
          _isPinDialogOpen = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isPinDialogOpen) {
              _showPinDialog(res.data!);
            }
          });
        }
      } else if (res.data == null) {
        // Transaksi pending sudah selesai atau dibatalkan teller
        _lastPromptedTrxId = null;
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final cached = await ApiService().getCachedCustomer();
    if (cached != null && mounted) {
      setState(() {
        _customer = cached;
      });
    }

    final saldoResult = await ApiService().getSaldo();
    if (saldoResult.success && saldoResult.data != null && mounted) {
      setState(() {
        _customer = saldoResult.data;
      });
    }

    final mutasiResult = await ApiService().getMutasi();
    if (mutasiResult.success && mutasiResult.data != null && mounted) {
      setState(() {
        _recentTransactions = mutasiResult.data!.take(5).toList();
      });
    }

    await _checkPendingWithdrawal();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPinDialog(Map<String, dynamic> trx) {
    final pinController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final amount = trx['amount'] ?? 0;
          final formattedAmount = CurrencyFormatter.format(amount);
          final tellerName = trx['user']?['staff_name'] ?? 'Petugas Teller';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.security, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  'Konfirmasi Penarikan',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permintaan penarikan tunai diajukan di loket:',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nominal Penarikan:',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                        ),
                        Text(
                          formattedAmount,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teller: $tellerName',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Masukkan PIN Transaksi (6 Digit)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 20, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        _isPinDialogOpen = false;
                        Navigator.of(ctx).pop();
                        _handleReject(trx['id']);
                      },
                child: Text('Tolak', style: GoogleFonts.inter(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pin = pinController.text.trim();
                        if (pin.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN harus terdiri dari 6 digit angka.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        final res = await ApiService().confirmWithdrawal(trx['id'], pin);

                        _isPinDialogOpen = false;
                        navigator.pop();
                        if (!mounted) return;

                        if (res.success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadData();
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Otorisasi', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleReject(int trxId) async {
    final res = await ApiService().rejectWithdrawal(trxId);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan penarikan telah ditolak.'),
          backgroundColor: Colors.grey,
        ),
      );
      _loadData();
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'S';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(_customer?.studentName ?? 'Siswa');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accent,
          backgroundColor: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BANK MINI SEKOLAH',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.accentHover,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _customer?.studentName ?? 'Siswa Nasabah',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_customer?.className ?? ''} • NIS: ${_customer?.studentId ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Interactive Profile Avatar Button (Redirects to Profile Tab)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onTabChange(3),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.outfit(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Banner Notifikasi Penarikan Pending di Loket Teller
                if (_pendingWithdrawal != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notification_important, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Permintaan Penarikan Dana',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF92400E),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Loket Teller mengajukan penarikan tunai sebesar:',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(_pendingWithdrawal!['amount'] ?? 0),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () {
                                  _isPinDialogOpen = true;
                                  _showPinDialog(_pendingWithdrawal!);
                                },
                                icon: const Icon(Icons.key, size: 16),
                                label: Text(
                                  'Input PIN Otorisasi',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () => _handleReject(_pendingWithdrawal!['id']),
                              child: Text('Tolak', style: GoogleFonts.inter(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Kartu Virtual ATM Bank Mini (Charcoal + Amber)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TABUNGAN PELAJAR',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _customer?.status ?? 'Aktif',
                              style: GoogleFonts.inter(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Total Saldo Rekening',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _hideBalance
                                ? 'Rp ••••••••'
                                : CurrencyFormatter.format(_customer?.balance ?? 0),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _hideBalance = !_hideBalance;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFF374151), height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NO. REKENING',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customer?.accountNumber ?? '---',
                                style: GoogleFonts.sourceCodePro(
                                  color: AppColors.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: Text(
                              'QR Loket',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => widget.onTabChange(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info Saldo Mengendap (Clean Alert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accentHover, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aturan Saldo: Saldo mengendap minimal Rp 10.000 wajib tersisa di rekening saat penarikan tunai.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Header Aktivitas Terakhir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aktivitas Terakhir',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentHover,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => widget.onTabChange(2),
                      child: Text(
                        'Lihat Semua',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // List Transaksi Terakhir (Clean & Professional)
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28.0),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else if (_recentTransactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'Belum Ada Transaksi',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transaksi loket teller akan tercatat otomatis di sini.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentTransactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = _recentTransactions[index];
                      final isDep = tx.isDeposit;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDep ? AppColors.successBg : AppColors.dangerBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDep ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isDep ? AppColors.success : AppColors.danger,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.description ?? tx.transactionType,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatDate(tx.transactionDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isDep ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDep ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
