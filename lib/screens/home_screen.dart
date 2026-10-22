import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/slot.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class _SupportMessage {
  final String senderRole;
  final String body;
  final DateTime createdAt;

  const _SupportMessage({
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  factory _SupportMessage.fromJson(Map<String, dynamic> json) {
    final senderRole = json['sender_role'];
    final body = json['body'];
    final createdAtValue = json['created_at'];

    if (senderRole is! String ||
        !const {'user', 'admin'}.contains(senderRole) ||
        body is! String ||
        createdAtValue is! String) {
      throw const FormatException('Invalid support message');
    }

    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('Invalid support message date');
    }

    return _SupportMessage(
      senderRole: senderRole,
      body: body,
      createdAt: createdAt.toLocal(),
    );
  }
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog();

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  static const Color _primaryColor = Color(0xFF0000CD);

  final TextEditingController _messageController = TextEditingController();
  List<_SupportMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _loadError;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMessages());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final rawMessages = await ApiService.getSupportMessages();
      final messages = rawMessages.map((rawMessage) {
        if (rawMessage is! Map) {
          throw const FormatException('Invalid support message item');
        }
        return _SupportMessage.fromJson(
          Map<String, dynamic>.from(rawMessage),
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (error) {
      debugPrint('Load support messages error: $error');

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'ข้อความไม่ถูกต้อง';
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending) {
      return;
    }
    setState(() {
      _isSending = true;
      _sendError = null;
    });
    try {
      final savedMessage = _SupportMessage.fromJson(
        await ApiService.sendSupportMessage(message),
      );
      if (!mounted) {
        return;
      }

      _messageController.clear();
      setState(() {
        _messages = [..._messages, savedMessage];
        _isSending = false;
      });
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
        _sendError = error.message;
      });
    } catch (error) {
      debugPrint('Send support message error: $error');

      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
        _sendError = 'ข้อความไม่ถูกต้อง';
      });
    }
  }

  Widget _buildConversation() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCD2626)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'ไม่พบข้อความติดต่อเจ้าหน้าที่',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'th');

    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - index - 1];
        final sentByUser = message.senderRole == 'user';

        return Align(
          alignment: sentByUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: sentByUser
                  ? _primaryColor
                  : const Color(0xFFE9ECF4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentByUser ? 'คุณ' : 'เจ้าหน้าที่',
                  style: TextStyle(
                    color: sentByUser
                        ? Colors.white70
                        : const Color(0xFF555555),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  style: TextStyle(
                    color: sentByUser
                        ? Colors.white
                        : const Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatter.format(message.createdAt),
                  style: TextStyle(
                    color: sentByUser
                        ? Colors.white70
                        : const Color(0xFF777777),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(
        children: [
          const Icon(
            Icons.support_agent,
            color: _primaryColor,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ติดต่อเจ้าหน้าที่',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadMessages,
            tooltip: 'กำลังโหลดข้อความล่าสุด...',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'ปิด',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            Expanded(
              child: _buildConversation(),
            ),
            const Divider(),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _sendError!,
                  style: const TextStyle(
                    color: Color(0xFFCD2626),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'ข้อความ...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _overlayDelay = Duration(milliseconds: 500);
  static const Color _primaryColor = Color(0xFF0000CD);
  static const Color _reservedColor = Color(0xFFFFC107);

  Timer? _overlayDelayTimer;
  int _tab = 0;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  bool _showLoadingOverlay = false;
  bool _hasAttemptedSlotLoad = false;
  bool _slotLoadFailed = false;
  bool _supportDialogOpen = false;
  bool _supportOpenedFromLink = false;

  bool get _isBusy => _isRefreshing || _isLoggingOut;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadHomeData());
        _openSupportFromLinkIfRequested();
      }
    });
  }

  @override
  void dispose() {
    _overlayDelayTimer?.cancel();
    super.dispose();
  }
  void _scheduleLoadingOverlay() {
    _overlayDelayTimer?.cancel();
    _overlayDelayTimer = Timer(_overlayDelay, () {
      if (mounted && _isBusy) {
        setState(() => _showLoadingOverlay = true);
      }
    });
  }

  void _cancelLoadingOverlay() {
    _overlayDelayTimer?.cancel();
    _overlayDelayTimer = null;
  }

  Future<void> _loadHomeData({
    bool includeBookings = false,
    bool showResult = false,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isRefreshing = true);
    _scheduleLoadingOverlay();

    final provider = context.read<ParkingProvider>();
    var slotsLoaded = false;
    var bookingsLoaded = true;

    try {
      if (includeBookings) {
        final results = await Future.wait<bool>([
          provider.loadSlots(),
          provider.loadBookings(),
        ]);

        slotsLoaded = results[0];
        bookingsLoaded = results[1];
      } else {
        slotsLoaded = await provider.loadSlots();
      }
    } catch (error) {
      debugPrint('Load Home data error: $error');
      slotsLoaded = false;
      bookingsLoaded = !includeBookings;
    }

    if (!mounted) {
      return;
    }

    _cancelLoadingOverlay();
    setState(() {
      _isRefreshing = false;
      _showLoadingOverlay = false;
      _hasAttemptedSlotLoad = true;
      _slotLoadFailed = !slotsLoaded && provider.slots.isEmpty;
    });

    if (!showResult) {
      return;
    }

    final succeeded = slotsLoaded && bookingsLoaded;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                ? 'บันทึกข้อมูลล่าสุดแล้ว!'
                : 'ไม่สามารถบันทึกข้อมูลได้ กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: succeeded
              ? const Color(0xFF228B22)
              : const Color(0xFFCD2626),
        ),
      );
  }

  Future<void> _logout() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isLoggingOut = true);
    _scheduleLoadingOverlay();

    final loggedOut = await context.read<ParkingProvider>().logout();

    if (!mounted) {
      return;
    }
    _cancelLoadingOverlay();
    setState(() {
      _isLoggingOut = false;
      _showLoadingOverlay = false;
    });
    if (!loggedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Color(0xFFCD2626),
        ),
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openSupportFromLinkIfRequested() {
  if (_supportOpenedFromLink) {
    return;
  }

  final openSupport = Uri.base.queryParameters['openSupport']?.toLowerCase();
  if (openSupport != 'true' && openSupport != '1') {
    return;
  }
  _supportOpenedFromLink = true;
  unawaited(_openSupportDialog());
}

Future<void> _openSupportDialog() async {
  if (!mounted || _supportDialogOpen) {
    return;
  }
  _supportDialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => const _SupportDialog(),
    );
  } finally {
    _supportDialogOpen = false;
  }
}
  Color _slotColor(Slot slot) {
    if (slot.isAvailable) {
      return const Color(0xFF228B22);
    }
    if (slot.isReserved) {
      return _reservedColor;
    }
    return const Color(0xFFCD2626);
  }
  String _slotLabel(Slot slot) {
    if (slot.isAvailable) {
      return 'ว่าง';
    }
    if (slot.isReserved) {
      return 'จองแล้ว';
    }
    return 'ไม่ว่าง';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Parking',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isBusy
                ? null
                : () => _loadHomeData(
                      includeBookings: true,
                      showResult: true,
                    ),
            tooltip: 'บันทึกข้อมูล',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _isBusy ? null : _logout,
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _tab,
            children: [
              _buildHome(provider),
              const ProfileScreen(),
              const HistoryScreen(),
            ],
          ),
          if (_showLoadingOverlay) ...[
            const ModalBarrier(
              color: Color(0x66000000),
              dismissible: false,
            ),
            const Center(
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.all(
                  Radius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('กำลังโหลดข้อมูลล่าสุด...'),
                        SizedBox(height: 14),
                        LinearProgressIndicator(
                          color: _primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _isBusy ? null : _openSupportDialog,
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.support_agent),
              label: const Text('ติดต่อเจ้าหน้าที่'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_parking),
            label: 'ที่จอดรถ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'ข้อมูลส่วนบุคคล',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'ประวัติ',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(ParkingProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.local_parking,
                    color: _primaryColor,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ช่องจอด',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryColor),
                ),
                child: Text(
                  '${provider.availableCount}/${provider.slots.length}',
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 18,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFF228B22), 'ว่าง'),
              const SizedBox(width: 30),
              _legend(_reservedColor, 'จองแล้ว'),
              const SizedBox(width: 30),
              _legend(
                const Color(0xFFCD2626),
                'ไม่ว่าง',
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildSlotContent(provider),
        ),
      ],
    );
  }

  Widget _buildSlotContent(ParkingProvider provider) {
    if (provider.slots.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: provider.slots.length,
        itemBuilder: (context, index) {
          final slot = provider.slots[index];

          return GestureDetector(
            onTap: slot.isAvailable
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(slot: slot),
                      ),
                    )
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: _slotColor(slot),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _slotLabel(slot),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_slotLoadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                color: Color(0xFFCD2626),
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'ไม่พบสถานะช่องจอดล่าสุด',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isBusy ? null : _loadHomeData,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่อีกครั้ง'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasAttemptedSlotLoad) {
      return const Center(
        child: Text('ไม่พบข้อมูลช่องจอดในระบบ'),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(
      width: 20, 
      height: 20, 
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(6)
      ),
    ),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);
}