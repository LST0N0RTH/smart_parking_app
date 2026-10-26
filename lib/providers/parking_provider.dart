import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import '../models/slot.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class RegisteredVehicle {
    final int id;
    final String plateNumber;
    final String province;

  const RegisteredVehicle({
    required this.id,
    required this.plateNumber,
    required this.province,
  });

  factory RegisteredVehicle.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];

    if (id is! int) {
      throw const FormatException('Vehicle id is invalid');
    }

    return RegisteredVehicle(
      id: id,
      plateNumber: (json['plate_number'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
    );
  }

  String get displayName {
    if (province.isEmpty) {
      return plateNumber;
    }

    return '$plateNumber $province';
  }
}

class ParkingProvider with ChangeNotifier {
  List<Slot> slots = [];
  List<Booking> bookings = [];
  Future<bool>? _bookingLoadRequest;
  int _bookingLoadVersion = 0;
  bool _bookingRefreshPending = false;
  int _sessionVersion = 0;
  int _slotRevision = 0;
  int _slotLoadsInFlight = 0;

  WebSocketChannel? _slotChannel;
  StreamSubscription<dynamic>? _slotSubscription;
  Timer? _slotReconnectTimer;

  WebSocketChannel? _bookingChannel;
  StreamSubscription<dynamic>? _bookingSubscription;
  Timer? _bookingReconnectTimer;

  int _bookingReconnectAttempt = 0;
  int _bookingSocketVersion = 0;
  bool _shouldKeepBookingSocketOpen = false;
  bool _isConnectingBookingSocket = false;

  static Uri get _bookingsWebSocketBaseUri =>
    ApiService.webSocketUri('/ws/bookings');
  int _slotReconnectAttempt = 0;
  bool _shouldKeepSlotSocketOpen = false;

  static Uri get _slotsWebSocketUri =>
    ApiService.webSocketUri('/ws/slots');

 bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _authRestoreFailed = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading || _slotLoadsInFlight > 0;
  bool get isInitialized => _isInitialized;
  bool get authRestoreFailed => _authRestoreFailed;

  String _userName = '';
  String _userUsername = '';
  String _userEmail = '';
  String _userRole = 'user';
  String? _registrationError;
  String? _loginError;
  List<RegisteredVehicle> _userVehicles = [];

  String get userName => _userName;
  String get userUsername => _userUsername;
  String get userEmail => _userEmail;
  String get userRole => _userRole;
  String? get registrationError => _registrationError;
  String? get loginError => _loginError;

  List<RegisteredVehicle> get userVehicles {
    return List.unmodifiable(_userVehicles);
  }

  List<String> get userPlates {
    return List.unmodifiable(
      _userVehicles.map((vehicle) => vehicle.displayName),
    );
  }
  ParkingProvider() {
    ApiService.sessionInvalidations.addListener(
      _handleSessionInvalidated,
    );
    checkAuthStatus();
  }

  @override
  void dispose() {
    ApiService.sessionInvalidations.removeListener(
      _handleSessionInvalidated,
    );
    _stopSlotSocket();
    _stopBookingSocket();
    super.dispose();
  }

  void _handleSessionInvalidated() {
    _resetSessionState(
      authRestoreFailed: true,
    );
  }

  void _resetSessionState({
    required bool authRestoreFailed,
  }) {
    _stopSlotSocket();
    _stopBookingSocket();

    _bookingLoadVersion++;
    _sessionVersion++;
    _slotRevision++;

    _bookingLoadRequest = null;
    _bookingRefreshPending = false;
    _isLoggedIn = false;
    _isLoading = false;

    slots = [];
    bookings = [];

    _userName = '';
    _userUsername = '';
    _userEmail = '';
    _userRole = 'user';

    _registrationError = null;
    _loginError = null;
    _authRestoreFailed = authRestoreFailed;
    _userVehicles = [];

    _slotReconnectAttempt = 0;
    _bookingReconnectAttempt = 0;

    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return;
      }
      if (token.isEmpty) {
        _authRestoreFailed = true;
        await ApiService.clearToken();
        return;
      }
      final restored = await fetchUserProfile(
        rethrowOnFailure: true,
      );
      if (!restored) {
        _authRestoreFailed = true;
        await ApiService.clearToken();
        return;
      }
      _isLoggedIn = true;
      _authRestoreFailed = false;
      _startSlotSocket();

      if (_userRole == 'user') {
        _startBookingSocket();
      }
    } on ApiRequestException catch (error) {
      debugPrint('Restore session error: ${error.message}');

      if (error.statusCode == 401) {
        _authRestoreFailed = true;
        try {
          await ApiService.clearToken();
        } catch (clearError) {
          debugPrint('Clear invalid token error: $clearError');
        }
      } else {
        _authRestoreFailed = false;
      }
    } catch (error) {
      debugPrint('Restore session error: $error');
      _authRestoreFailed = false;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> loadSlots() async {
    final requestRevision = ++_slotRevision;
    final requestSessionVersion = _sessionVersion;
    _slotLoadsInFlight++;
    notifyListeners();

    try {
      final latestSlots = await ApiService.getSlots();
      if (requestRevision != _slotRevision ||
          requestSessionVersion != _sessionVersion ||
          !_isLoggedIn) {
        return false;
      }
      latestSlots.sort((a, b) => a.name.compareTo(b.name));
      slots = latestSlots;
      return true;
    } on ApiRequestException catch (error) {
      debugPrint('GetSlots Error: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('GetSlots Unexpected Error: $error');
      return false;
    } finally {
      _slotLoadsInFlight--;
      notifyListeners();
    }
  }

  void _applyUserProfile(Map<String, dynamic> data) {
    _userName = data['name'] ?? 'ไม่ระบุชื่อ';
    _userUsername = data['username']?.toString() ?? '';
    _userEmail = data['email'] ?? 'ไม่ระบุอีเมล';
    _userRole = data['role']?.toString() ?? 'user';

    final vehicles = <RegisteredVehicle>[];
    final rawVehicles = data['vehicles'];

    if (rawVehicles is List) {
      for (final rawVehicle in rawVehicles) {
        if (rawVehicle is Map) {
          try {
            vehicles.add(
              RegisteredVehicle.fromJson(
                Map<String, dynamic>.from(rawVehicle),
              ),
            );
          } on FormatException {
            debugPrint('Invalid vehicle data received from API');
          }
        }
      }
    }
    _userVehicles = vehicles;
  }

  Future<bool> loadBookings() {
    final activeRequest = _bookingLoadRequest;

    if (activeRequest != null) {
      _bookingRefreshPending = true;
      return activeRequest;
    }
    final version = _bookingLoadVersion;
    final request = _fetchBookings(version);
    _bookingLoadRequest = request;
    return request;
  }

  Future<bool> _fetchBookings(int version) async {
    try {
      while (version == _bookingLoadVersion) {
        _bookingRefreshPending = false;
        final latestBookings = await ApiService.getMyBookings();

        if (version != _bookingLoadVersion) {
          return false;
        }
        if (_bookingRefreshPending) {
          continue;
        }
        bookings = latestBookings;
        notifyListeners();
        return true;
      }
      return false;
    } on ApiRequestException catch (error) {
      debugPrint('GetMyBookings Error: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('GetMyBookings Unexpected Error: $error');
      return false;
    } finally {
      if (version == _bookingLoadVersion) {
        _bookingLoadRequest = null;

        if (_bookingRefreshPending) {
          _bookingRefreshPending = false;
          unawaited(loadBookings());
        }
      }
    }
  }

  Future<bool> fetchUserProfile({
    bool rethrowOnFailure = false,
  }) async {
    final requestSessionVersion =
        _sessionVersion;
    try {
      final data =
          await ApiService.getUserProfile();
      if (
          requestSessionVersion !=
          _sessionVersion
      ) {
        return false;
      }
      if (
          !const {'user', 'admin'}.contains(
            data['role']?.toString(),
          )
      ) {
        return false;
      }
      _applyUserProfile(data);
      notifyListeners();
      return true;
    } on ApiRequestException catch (error) {
      debugPrint(
        'FetchUserProfile Error: ${error.message}',
      );

      if (rethrowOnFailure) {
        rethrow;
      }
      return false;

    } catch (error) {
      debugPrint(
        'FetchUserProfile Error: $error',
      );

      if (rethrowOnFailure) {
        rethrow;
      }
      return false;
    }
  }

    Future<void> updateUserProfile({
      String? username,
      List<Map<String, String>>? vehicles,
    }) async {
      final profile = await ApiService.updateProfile(
        _userName,
        userPlates,
        username: username,
        vehicles: vehicles,
      );

      _applyUserProfile(profile);
      notifyListeners();
    }

  void updateSlotStatus(String slotName, String status) {
    _slotRevision++;

    slots = slots.map((slot) {
      if (slot.name == slotName) {
        return Slot(
          id: slot.id,
          name: slot.name,
          status: status,
        );
      }
      return slot;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _startSlotSocket() {
    _shouldKeepSlotSocketOpen = true;
    _slotReconnectTimer?.cancel();

    if (_slotChannel != null) {
      return;
    }
    _connectSlotSocket();
  }

  void _connectSlotSocket() {
    if (!_shouldKeepSlotSocketOpen || _slotChannel != null) {
      return;
    }
    try {
      final channel = WebSocketChannel.connect(
        _slotsWebSocketUri,
      );
      _slotChannel = channel;
      _slotSubscription = channel.stream.listen(
        _handleSlotSocketMessage,
        onError: (_, __) => _handleSlotSocketClosed(channel),
        onDone: () => _handleSlotSocketClosed(channel),
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Slot WebSocket connection error: $error');
      _scheduleSlotSocketReconnect();
    }
  }

  void _handleSlotSocketClosed(WebSocketChannel channel) {
    if (!identical(channel, _slotChannel)) {
      return;
    }

    _slotChannel = null;
    _slotSubscription = null;
    _scheduleSlotSocketReconnect();
  }

  void _scheduleSlotSocketReconnect() {
    if (
        !_shouldKeepSlotSocketOpen ||
        (_slotReconnectTimer?.isActive ?? false)) {
      return;
    }

    final delaySeconds = _slotReconnectAttempt >= 4
        ? 15
        : 1 << _slotReconnectAttempt;

    _slotReconnectAttempt++;
    _slotReconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      _connectSlotSocket,
    );
  }

    void _handleSlotSocketMessage(dynamic rawMessage) {
    if (rawMessage is! String) {
      return;
    }
    try {
      final payload = jsonDecode(rawMessage);

      if (payload is List) {
        final statuses = <String, String>{};
        for (final rawSlot in payload) {
          if (rawSlot is Map) {
            final name = rawSlot['slot']?.toString();
            final status = rawSlot['status']?.toString();
            if (name != null &&
                status != null &&
                const {'available', 'reserved', 'occupied'}.contains(status)) {
              statuses[name] = status;
            }
          }
        }
        if (statuses.isEmpty) {
          return;
        }

        _slotReconnectAttempt = 0;
        _slotRevision++;

        if (slots.isEmpty ||
            statuses.keys.any(
              (name) => !slots.any((slot) => slot.name == name),
            )) {
          unawaited(
            ApiService.runInBackground(loadSlots),
          );
          return;
        }

        slots = slots.map((slot) {
          final status = statuses[slot.name];

          return status == null
              ? slot
              : Slot(
                  id: slot.id,
                  name: slot.name,
                  status: status,
                );
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        notifyListeners();
        return;
      }

      if (payload is Map) {
        final slotName = payload['slot']?.toString();
        final status = payload['status']?.toString();

        if (slotName == null ||
            status == null ||
            !const {
              'available',
              'reserved',
              'occupied',
            }.contains(status)) {
          return;
        }
        _slotReconnectAttempt = 0;
        _slotRevision++;

        if (!slots.any((slot) => slot.name == slotName)) {
          unawaited(
            ApiService.runInBackground(loadSlots),
          );
          return;
        }

        final hasChanged = slots.any(
          (slot) => slot.name == slotName && slot.status != status,
        );
        if (!hasChanged) {
          return;
        }

        slots = slots.map((slot) {
          if (slot.name == slotName) {
            return Slot(
              id: slot.id,
              name: slot.name,
              status: status,
            );
          }
          return slot;
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Invalid Slot WebSocket payload: $error');
    }
  }

  void _stopSlotSocket() {
    _shouldKeepSlotSocketOpen = false;

    _slotReconnectTimer?.cancel();
    _slotReconnectTimer = null;

    final subscription = _slotSubscription;
    final channel = _slotChannel;

    _slotSubscription = null;
    _slotChannel = null;

    subscription?.cancel();
    channel?.sink.close();
  }

    void _startBookingSocket() {
    _shouldKeepBookingSocketOpen = true;
    _bookingReconnectTimer?.cancel();

    if (_bookingChannel != null || _isConnectingBookingSocket) {
      return;
    }
    unawaited(_connectBookingSocket());
  }

  Future<void> _connectBookingSocket() async {
    if (!_shouldKeepBookingSocketOpen ||
        _bookingChannel != null ||
        _isConnectingBookingSocket) {
      return;
    }
    _isConnectingBookingSocket = true;
    final connectionVersion = _bookingSocketVersion;
    WebSocketChannel? channel;

    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        _shouldKeepBookingSocketOpen = false;
        return;
      }
      if (!_shouldKeepBookingSocketOpen ||
          connectionVersion != _bookingSocketVersion ||
          _bookingChannel != null) {
        return;
      }
      final socketUri = _bookingsWebSocketBaseUri.replace(
        queryParameters: {'token': token},
      );
      final connectedChannel = WebSocketChannel.connect(socketUri);
      channel = connectedChannel;
      _bookingChannel = connectedChannel;

      _bookingSubscription = connectedChannel.stream.listen(
        _handleBookingSocketMessage,
        onError: (_, __) => _handleBookingSocketClosed(connectedChannel),
        onDone: () => _handleBookingSocketClosed(connectedChannel),
        cancelOnError: true,
      );
      await connectedChannel.ready.timeout(const Duration(seconds: 10));

      if (_shouldKeepBookingSocketOpen &&
          connectionVersion == _bookingSocketVersion &&
          identical(connectedChannel, _bookingChannel)) {
        _bookingReconnectAttempt = 0;
        unawaited(
          ApiService.runInBackground(loadBookings),
        );
      }
    } catch (error) {
      debugPrint('Booking WebSocket connection error: $error');
      if (channel != null && identical(channel, _bookingChannel)) {
        _bookingChannel = null;
        _bookingSubscription?.cancel();
        _bookingSubscription = null;
        channel.sink.close();
      }
    } finally {
      if (connectionVersion == _bookingSocketVersion) {
        _isConnectingBookingSocket = false;
        if (_shouldKeepBookingSocketOpen && _bookingChannel == null) {
          _scheduleBookingSocketReconnect();
        }
      }
    }
  }

  void _handleBookingSocketMessage(dynamic rawMessage) {
    if (rawMessage is! String) {
      return;
    }

    try {
      final payload = jsonDecode(rawMessage);

      if (payload is! Map) {
        return;
      }

      final type = payload['type']?.toString();
      final event = payload['event']?.toString();
      final bookingId = payload['booking_id'];

      const supportedEvents = {
        'booking_created',
        'booking_cancelled',
        'booking_time_out',
        'booking_entered',
        'payment_paid',
        'booking_completed',
      };

      if (type != 'booking_updated' ||
          bookingId is! int ||
          !supportedEvents.contains(event)) {
        return;
      }

      _bookingReconnectAttempt = 0;
      unawaited(
        ApiService.runInBackground(loadBookings),
      );
    } catch (error) {
      debugPrint('Invalid Booking WebSocket payload: $error');
    }
  }

  void _handleBookingSocketClosed(WebSocketChannel channel) {
    if (!identical(channel, _bookingChannel)) {
      return;
    }

    _bookingChannel = null;
    _bookingSubscription = null;
    _scheduleBookingSocketReconnect();
  }

  void _scheduleBookingSocketReconnect() {
    if (
        !_shouldKeepBookingSocketOpen ||
        (_bookingReconnectTimer?.isActive ?? false)) {
      return;
    }

    final delaySeconds = _bookingReconnectAttempt >= 4
        ? 15
        : 1 << _bookingReconnectAttempt;

    _bookingReconnectAttempt++;

    _bookingReconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () => unawaited(_connectBookingSocket()),
    );
  }

  void _stopBookingSocket() {
    _shouldKeepBookingSocketOpen = false;
    _bookingSocketVersion++;
    _isConnectingBookingSocket = false;

    _bookingReconnectTimer?.cancel();
    _bookingReconnectTimer = null;

    final subscription = _bookingSubscription;
    final channel = _bookingChannel;

    _bookingSubscription = null;
    _bookingChannel = null;

    subscription?.cancel();
    channel?.sink.close();
  }
  int get availableCount => slots.where((s) => s.isAvailable).length;

Future<bool> login(
    String email,
    String password,
  ) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    try {
      final success = await ApiService.login(
        email,
        password,
      );

      if (!success) {
        return false;
      }

      if (!await fetchUserProfile()) {
        _loginError =
            'ไม่พบบัญชี กรุณาลองอีกครั้ง';

        try {
          await ApiService.logoutFromServer();
        } catch (error) {
          debugPrint(
            'Revoke incomplete login error: $error',
          );
        }

        await ApiService.clearToken();
        return false;
      }

      _isLoggedIn = true;
      _loginError = null;
      _authRestoreFailed = false;

      _startSlotSocket();

      if (_userRole == 'user') {
        _startBookingSocket();
      }

      return true;
    } on ApiRequestException catch (error) {
      _loginError = error.message;
      return false;
    } catch (error) {
      debugPrint('Login error: $error');
      _loginError =
          'ไม่สามารถเข้าสู่ระบบได้ กรุณาลองอีกครั้ง';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginAdmin(
    String identifier,
    String password,
  ) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    try {
      final role = await ApiService.adminLogin(
        identifier,
        password,
      );
      if (role == null) {
        return false;
      }
      if (
          role != 'admin' ||
          !await fetchUserProfile() ||
          _userRole != 'admin'
      ) {
        _loginError =
            'ไม่พบสิทธิ์ผู้ดูแลพื้นที่ กรุณาลองใหม่อีกครั้ง';
        try {
          await ApiService.logoutFromServer();
        } catch (error) {
          debugPrint(
            'Revoke incomplete admin login error: $error',
          );
        }
        await ApiService.clearToken();
        return false;
      }
      _isLoggedIn = true;
      _loginError = null;
      _authRestoreFailed = false;

      _startSlotSocket();
      return true;
    } on ApiRequestException catch (error) {
      _loginError = error.message;
      return false;
    } catch (error) {
      debugPrint(
        'Admin login error: $error',
      );
      _loginError =
          'ไม่สามารถเข้าสู่ระบบผู้ดูแลได้ กรุณาลองใหม่';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
    
    Future<bool> register(
      String name,
      String email,
      String password,
      String plate, {
      String? username,
      String? passwordConfirmation,
      String? province,
    }) async {
      _isLoading = true;
      _registrationError = null;
      _loginError = null;
      notifyListeners();
      
    try {
        return await ApiService.register(
          name,
          email,
          password,
          plate,
          username: username,
          passwordConfirmation: passwordConfirmation,
          province: province,
        );
      } on ApiRequestException catch (error) {
        _registrationError = error.message;
        return false;
      } catch (error) {
        debugPrint('Register error: $error');
        _registrationError = 'ไม่สามารถเชื่อมต่อระบบสมัครสมาชิกได้';
        return false;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }

  Future<bool> logout() async {
    _isLoading = true;
    notifyListeners();

    bool serverConfirmed;
    try {
      serverConfirmed = await ApiService.logoutFromServer();
    } catch (error) {
      debugPrint('Server logout error: $error');
      serverConfirmed = false;
    }

    if (!serverConfirmed) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      await ApiService.clearToken();
    } catch (error) {
      debugPrint('Clear token after logout error: $error');
    }
    _stopSlotSocket();
    _stopBookingSocket();
    _bookingLoadVersion++;
    _sessionVersion++;
    _slotRevision++;
    _bookingLoadRequest = null;
    _bookingRefreshPending = false;
    _isLoggedIn = false;
    _isLoading = false;
    slots = [];
    bookings = [];
    _userName = '';
    _userUsername = '';
    _userEmail = '';
    _userRole = 'user';
    _registrationError = null;
    _loginError = null;
    _authRestoreFailed = false;
    _userVehicles = [];
    _slotReconnectAttempt = 0;
    _bookingReconnectAttempt = 0;
    notifyListeners();
    return true;
  }
}