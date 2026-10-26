import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http_package;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slot.dart';
import '../models/booking.dart';
import '../models/payment_card.dart';
import '../models/booking_qr_token.dart';

const Duration _readTimeout = Duration(seconds: 15);
const Duration _writeTimeout = Duration(seconds: 25);
const Duration _logoutTimeout = Duration(seconds: 5);
const Object _backgroundRequestZoneKey = Object();

@immutable
class ApiActivityState {
  final int requestCount;
  final String message;

  const ApiActivityState({
    this.requestCount = 0,
    this.message = '',
  });

  bool get isBusy => requestCount > 0;
}

final ValueNotifier<ApiActivityState> _apiActivity =
    ValueNotifier<ApiActivityState>(
  const ApiActivityState(),
);

final ValueNotifier<int> _sessionInvalidations =
    ValueNotifier<int>(0);

bool _sessionInvalidationInProgress = false;

void _beginApiActivity(String message) {
  final current = _apiActivity.value;

  _apiActivity.value = ApiActivityState(
    requestCount: current.requestCount + 1,
    message: message,
  );
}

void _endApiActivity() {
  final current = _apiActivity.value;
  final nextCount = current.requestCount > 0
      ? current.requestCount - 1
      : 0;

  _apiActivity.value = ApiActivityState(
    requestCount: nextCount,
    message: nextCount == 0
        ? ''
        : current.message,
  );
}

bool _isPublicAuthenticationRequest(Uri uri) {
  return const {
    '/auth/login',
    '/auth/register',
    '/auth/logout',
    '/admin/login',
  }.contains(uri.path);
}

Duration _timeoutFor(
  String method,
  Uri uri,
) {
  if (uri.path == '/auth/logout') {
    return _logoutTimeout;
  }

  return method.toUpperCase() == 'GET'
      ? _readTimeout
      : _writeTimeout;
}

String _activityMessageFor(
  String method,
  Uri uri,
) {
  if (uri.path == '/auth/logout') {
    return 'กำลังออกจากระบบ...';
  }

  return method.toUpperCase() == 'GET'
      ? 'กำลังโหลดข้อมูล...'
      : 'กำลังบันทึกข้อมูล...';
}

String _timeoutMessageFor(
  String method,
  Uri uri,
) {
  if (uri.path == '/auth/logout') {
    return 'หมดเวลารอการออกจากระบบ กรุณาลองใหม่อีกครั้ง';
  }

  return method.toUpperCase() == 'GET'
      ? 'หมดเวลารอข้อมูล กรุณาลองใหม่อีกครั้ง'
      : 'หมดเวลารอบันทึกข้อมูล กรุณาลองใหม่อีกครั้ง';
}

Future<void> _invalidateExpiredSession() async {
  if (
      _sessionInvalidationInProgress ||
      await ApiService.getToken() == null
  ) {
    return;
  }

  _sessionInvalidationInProgress = true;

  try {
    await ApiService.clearToken();
    _sessionInvalidations.value++;
  } finally {
    _sessionInvalidationInProgress = false;
  }
}

Future<T> _executeHttpRequest<T>({
  required String method,
  required Uri uri,
  required Future<T> Function() send,
  required int Function(T response) statusCode,
}) async {
  final tracksActivity =
      Zone.current[_backgroundRequestZoneKey] != true;

  if (tracksActivity) {
    _beginApiActivity(
      _activityMessageFor(method, uri),
    );
  }

  try {
    final response = await send().timeout(
      _timeoutFor(method, uri),
    );

    if (
        statusCode(response) == 401 &&
        !_isPublicAuthenticationRequest(uri)
    ) {
      await _invalidateExpiredSession();

      throw const ApiRequestException(
        'สิทธิ์การเข้าสู่ระบบหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง',
        statusCode: 401,
      );
    }

    return response;
  } on TimeoutException {
    throw ApiRequestException(
      _timeoutMessageFor(method, uri),
    );
  } finally {
    if (tracksActivity) {
      _endApiActivity();
    }
  }
}

class _SessionAwareClient
    extends http_package.BaseClient {
  final http_package.Client _inner =
      http_package.Client();

  @override
  Future<http_package.StreamedResponse> send(
    http_package.BaseRequest request,
  ) {
    return _executeHttpRequest<
        http_package.StreamedResponse>(
      method: request.method,
      uri: request.url,
      send: () => _inner.send(request),
      statusCode: (response) =>
          response.statusCode,
    );
  }

  @override
  void close() {
    _inner.close();
  }
}

class HttpFacade {
  // ignore: non_constant_identifier_names
  http_package.Client Client() =>
      _SessionAwareClient();

  Future<http_package.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _executeHttpRequest<
        http_package.Response>(
      method: 'GET',
      uri: uri,
      send: () => http_package.get(
        uri,
        headers: headers,
      ),
      statusCode: (response) =>
          response.statusCode,
    );
  }

  Future<http_package.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _executeHttpRequest<
        http_package.Response>(
      method: 'POST',
      uri: uri,
      send: () => http_package.post(
        uri,
        headers: headers,
        body: body,
        encoding: encoding,
      ),
      statusCode: (response) =>
          response.statusCode,
    );
  }

  Future<http_package.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _executeHttpRequest<
        http_package.Response>(
      method: 'PUT',
      uri: uri,
      send: () => http_package.put(
        uri,
        headers: headers,
        body: body,
        encoding: encoding,
      ),
      statusCode: (response) =>
          response.statusCode,
    );
  }

  Future<http_package.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _executeHttpRequest<
        http_package.Response>(
      method: 'DELETE',
      uri: uri,
      send: () => http_package.delete(
        uri,
        headers: headers,
        body: body,
        encoding: encoding,
      ),
      statusCode: (response) =>
          response.statusCode,
    );
  }
}
final HttpFacade http = HttpFacade();

class ApiRequestException implements Exception {
  final String message;
  final int? statusCode;
  const ApiRequestException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static ValueListenable<ApiActivityState>
      get activity => _apiActivity;

  static ValueListenable<int>
      get sessionInvalidations =>
          _sessionInvalidations;

  static Future<T> runInBackground<T>(
    Future<T> Function() request,
  ) {
    return runZoned(
      request,
      zoneValues: {
        _backgroundRequestZoneKey: true,
      },
    );
  }

  static const _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-parking-backend-h6cm.onrender.com',
  );

  static Uri webSocketUri(String path) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(
        path,
        'path',
        'WebSocket path must begin with /',
      );
    }
    final apiUri = Uri.parse(_base);
    if (apiUri.host.isEmpty ||
        (apiUri.scheme != 'http' && apiUri.scheme != 'https')) {
      throw StateError('API_BASE_URL must be an absolute http(s) URL');
    }
    final basePath = apiUri.path.endsWith('/')
        ? apiUri.path.substring(0, apiUri.path.length - 1)
        : apiUri.path;
    return apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '$basePath$path',
      query: null,
      fragment: null,
    );
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<bool> logoutFromServer() async {
    if (await getToken() == null) return true;
    try {
      final response = await http.post(
        Uri.parse('$_base/auth/logout'),
        headers: await _headers(),
      );
      return response.statusCode == 200 || response.statusCode == 401;
    } catch (error) {
      debugPrint('Logout Error: $error');
      return false;
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _errorMessage(
    http_package.Response response,
    String fallback,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        final detail =
            decoded['detail'] ??
            decoded['message'];
        if (
            detail != null &&
            detail.toString().trim().isNotEmpty
        ) {
          return detail.toString();
        }
      }
    } catch (_) {}

    return fallback;
  }

  static Map<String, dynamic> _objectBody(
    http_package.Response response,
    String fallback,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (_) {}
    throw ApiRequestException(fallback);
  }

  static Future<List<dynamic>> _getList(
    String path,
    String fallback, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_base$path').replace(queryParameters: query),
        headers: await _headers(),
      );
      if (response.statusCode != 200) {
        throw ApiRequestException(_errorMessage(response, fallback));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw ApiRequestException(fallback);
      return decoded;
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('GET $path Error: $error');
      throw ApiRequestException(fallback);
    }
  }

  static Future<Map<String, dynamic>> _getObject(
    String path,
    String fallback, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_base$path').replace(queryParameters: query),
        headers: await _headers(),
      );
      if (response.statusCode != 200) {
        throw ApiRequestException(_errorMessage(response, fallback));
      }
      return _objectBody(response, fallback);
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('GET $path Error: $error');
      throw ApiRequestException(fallback);
    }
  }
  
  static Map<String, String> _analyticsQuery(
    String period, {
    DateTime? anchorDate,
  }) {
    if (!const {'daily', 'weekly', 'monthly'}.contains(period)) {
      throw const ApiRequestException('ช่วงสถิติไม่ถูกต้อง');
    }
    final query = <String, String>{
      'period': period,
    };
    if (anchorDate != null) {
      final localDate = anchorDate.toLocal();
      final year = localDate.year.toString().padLeft(4, '0');
      final month = localDate.month.toString().padLeft(2, '0');
      final day = localDate.day.toString().padLeft(2, '0');
      query['anchor_date'] = '$year-$month-$day';
    }
    return query;
  }

static Future<bool> login(
  String identifier,
  String password,
) async {
  try {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await saveToken(data['access_token']);
      return true;
    }
    if (res.statusCode == 401) return false;
    throw ApiRequestException(
      _errorMessage(
        res,
        'ไม่สามารถเข้าสู่ระบบได้',
      ),
    );
  } on ApiRequestException {
    rethrow;
  } catch (error) {
    debugPrint('Login Error: $error');
    throw const ApiRequestException(
      'ไม่สามารถเข้าสู่ระบบได้ กรุณาลองอีกครั้ง',
    );
  }
}
  
  static Future<bool> register(
    String name,
    String email,
    String password,
    String plate, {
    String? username,
    String? passwordConfirmation,
    String? province,
  }) async {
    final cleanedUsername = username?.trim() ?? '';
    final cleanedPlate = plate.trim();
    final cleanedProvince = province?.trim() ?? '';

    if (cleanedUsername.isEmpty || passwordConfirmation == null) {
      throw const ApiRequestException(
        'กรุณากรอกชื่อผู้ใช้งานและยืนยันรหัสผ่าน',
      );
    }
    if (password != passwordConfirmation) {
      throw const ApiRequestException('รหัสผ่านไม่ตรงกัน');
    }
    try {
      final response = await http.post(
        Uri.parse('$_base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'username': cleanedUsername,
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
          'vehicles': cleanedPlate.isEmpty
              ? <Map<String, String>>[]
              : <Map<String, String>>[
                  {
                    'plate_number': cleanedPlate,
                    'province': cleanedProvince,
                  },
                ],
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
      throw ApiRequestException(
        _errorMessage(response, 'ไม่สามารถสมัครสมาชิกได้'),
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('Register Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบสมัครสมาชิกได้',
      );
    }
  }

  static Future<List<Slot>> getSlots() async {
    final client = http.Client();

    try {
      final response = await client
          .get(
            Uri.parse('$_base/slots'),
            headers: await _headers(),
          )
          .timeout(_readTimeout);

      if (response.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(
            response,
            'ไม่สามารถอ่านสถานะช่องจอดได้',
          ),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw const ApiRequestException(
          'สถานะช่องจอดไม่ถูกต้อง',
        );
      }
      return decoded.map((rawSlot) {
        if (rawSlot is! Map) {
          throw const FormatException(
            'Slot item is invalid',
          );
        }
        return Slot.fromJson(
          Map<String, dynamic>.from(rawSlot),
        );
      }).toList(growable: false);
    } on TimeoutException {
      throw const ApiRequestException(
        'หมดเวลารอสถานะช่องจอด กรุณาลองใหม่อีกครั้ง',
      );
    } on ApiRequestException {
      rethrow;
    } on FormatException {
      throw const ApiRequestException(
        'สถานะช่องจอดไม่ถูกต้อง',
      );
    } catch (error) {
      debugPrint('GetSlots Error: $error');

      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่ออ่านสถานะช่องจอดได้',
      );
    } finally {
      client.close();
    }
  }

  static Future<List<Booking>> getMyBookings() async {
    final client = http.Client();
    try {
        final res = await client
          .get(
            Uri.parse('$_base/bookings/me'),
            headers: await _headers(),
          )
          .timeout(_readTimeout);

      if (res.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(res, 'ไม่สามารถอ่านประวัติการจองได้'),
        );
      }
      final decoded = jsonDecode(res.body);

      if (decoded is! List) {
        throw const ApiRequestException(
          'ข้อมูลประวัติการจองไม่ถูกต้อง',
        );
      }
      return decoded.map((rawBooking) {
        if (rawBooking is! Map) {
          throw const FormatException('Booking item is invalid');
        }
        return Booking.fromJson(
          Map<String, dynamic>.from(rawBooking),
        );
      }).toList();
    } on TimeoutException {
      throw const ApiRequestException(
        'หมดเวลารอข้อมูลประวัติการจอง',
      );
    } on ApiRequestException {
      rethrow;
    } on FormatException {
      throw const ApiRequestException(
        'ข้อมูลประวัติการจองไม่ถูกต้อง',
      );
    } catch (error) {
      debugPrint('GetMyBookings Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่ออ่านประวัติการจองได้',
      );
    } finally {
      client.close();
    }
  }

  static Future<bool> cancelBooking(int bookingId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/bookings/$bookingId'),
        headers: await _headers(),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('$_base/users/me'),
            headers: await _headers(),
          )
          .timeout(_readTimeout);
      if (response.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(
            response,
            'ไม่สามารถอ่านข้อมูลผู้ใช้งานได้',
          ),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const ApiRequestException(
          'ข้อมูลผู้ใช้งานไม่ถูกต้อง',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw const ApiRequestException(
        'หมดเวลารอข้อมูลผู้ใช้งาน กรุณาลองใหม่อีกครั้ง',
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('GetUserProfile Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่ออ่านข้อมูลผู้ใช้งานได้',
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String name,
    List<String> plates, {
    String? username,
    List<Map<String, String>>? vehicles,
    String? password,
    String? passwordConfirmation,
  }) async {
    if (password != null &&
        passwordConfirmation == null) {
      throw const ApiRequestException(
        'กรุณายืนยันรหัสผ่าน',
      );
    }
    if (password != null &&
        password != passwordConfirmation) {
      throw const ApiRequestException(
        'รหัสผ่านไม่ตรงกัน',
      );
    }
    try {
      final body = <String, dynamic>{};

      if (username != null) {
        body['username'] = username.trim();
      }
      if (vehicles != null) {
        body['vehicles'] = vehicles;
      } else if (password == null &&
          username == null) {
        body['license_plate'] = plates.join(',');
      }
      if (password != null) {
        body['password'] = password;
        body['password_confirmation'] =
            passwordConfirmation;
      }
      final response = await http
          .put(
            Uri.parse('$_base/users/me'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_writeTimeout);

      if (response.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(
            response,
            'ไม่สามารถบันทึกข้อมูลได้',
          ),
          statusCode: response.statusCode,
        );
      }
      return _objectBody(
        response,
        'ข้อมูลผู้ใช้งานที่ได้รับกลับมาไม่ถูกต้อง',
      );
    } on TimeoutException {
      throw const ApiRequestException(
        'หมดเวลารอบันทึกข้อมูล กรุณาลองใหม่อีกครั้ง',
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('UpdateProfile Error: $error');

      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่อบันทึกข้อมูลได้',
      );
    }
  }

  static Future<Booking> createBookingWithDetails(
    int slotId,
    DateTime start,
    DateTime end,
    String plate,
    String paymentMethod,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/bookings'),
        headers: await _headers(),
        body: jsonEncode({
          'slot_id': slotId,
          'start_time': start.toUtc().toIso8601String(),
          'end_time': end.toUtc().toIso8601String(),
          'license_plate': plate,
          'payment_method': paymentMethod,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return Booking.fromJson(
          _objectBody(res, 'ข้อมูลการจองไม่ถูกต้อง'),
        );
      }
      throw ApiRequestException(
        _errorMessage(
          res,
          'ไม่สามารถสร้างรายการจองได้ กรุณาลองใหม่อีกครั้ง',
        ),
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('CreateBookingWithDetails Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่อสร้างรายการจองได้',
      );
    }
  }

  static Future<List<PaymentCard>> getPaymentCards() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/payment-cards'),
        headers: await _headers(),
      );
      if (res.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(res, 'ไม่สามารถอ่านข้อมูลบัตรได้'),
        );
      }
      final decoded = jsonDecode(res.body);

      if (decoded is! List) {
        throw const ApiRequestException('ข้อมูลบัตรไม่ถูกต้อง');
      }
      return decoded
          .map(
            (item) => PaymentCard.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('GetPaymentCards Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่ออ่านข้อมูลบัตรได้',
      );
    }
  }

  static Future<PaymentCard> createPaymentCard({
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String holderName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/payment-cards'),
        headers: await _headers(),
        body: jsonEncode({
          'card_number': cardNumber.replaceAll(' ', ''),
          'expiry_date': expiryDate,
          'cvv': cvv,
          'holder_name': holderName,
        }),
      );
      if (res.statusCode == 201) {
        return PaymentCard.fromJson(
          _objectBody(res, 'ข้อมูลบัตรไม่ถูกต้อง'),
        );
      }
      throw ApiRequestException(
        _errorMessage(res, 'ไม่สามารถบันทึกบัตรได้'),
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('CreatePaymentCard Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่อบันทึกบัตรได้',
      );
    }
  }

  static Future<Payment> confirmPaymentWithDetails({
    required int bookingId,
    required String method,
    int? paymentCardId,
  }) async {
    if (method == 'card' && paymentCardId == null) {
      throw const ApiRequestException('กรุณาเลือกบัตรที่ต้องการใช้ชำระเงิน');
    }
    if (method != 'card' && paymentCardId != null) {
      throw const ApiRequestException(
        'รหัสบัตรใช้ได้เฉพาะการชำระด้วยบัตรเท่านั้น',
      );
    }
    try {
      final body = <String, dynamic>{
        'booking_id': bookingId,
        'method': method,
      };
      if (paymentCardId != null) {
        body['payment_card_id'] = paymentCardId;
      }
      final res = await http.post(
        Uri.parse('$_base/payments/confirm'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return Payment.fromJson(
          _objectBody(res, 'ไม่พบข้อมูลการชำระเงิน'),
        );
      }
      throw ApiRequestException(
        _errorMessage(res, 'ไม่พบรายการชำระเงิน กรุณาลองใหม่อีกครั้ง'),
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('ConfirmPaymentWithDetails Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่อยืนยันการชำระเงินได้',
      );
    }
  }

  static Future<BookingQrToken> getEntryQr(int bookingId) {
    return _getQr('/bookings/$bookingId/qr/entry');
  }
  static Future<BookingQrToken> createPaymentQr(int bookingId) {
    return _postQr('/bookings/$bookingId/qr/payment');
  }
  static Future<BookingQrToken> reissuePaymentQr(int bookingId) {
    return _postQr('/bookings/$bookingId/qr/payment/reissue');
  }
  static Future<BookingQrToken> getExitQr(int bookingId) {
    return _getQr('/bookings/$bookingId/qr/exit');
  }

  static Future<BookingQrToken> _getQr(String path) async {
    try {
      final res = await http.get(
        Uri.parse('$_base$path'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        return BookingQrToken.fromJson(
          _objectBody(res, 'ข้อมูล QR Code ไม่ถูกต้อง'),
        );
      }
      throw ApiRequestException(
        _errorMessage(res, 'ไม่สามารถอ่าน QR Code ได้ กรุณาลองใหม่อีกครั้ง'),
        statusCode: res.statusCode,
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('GetQr Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่ออ่าน QR Code ได้',
      );
    }
  }

  static Future<BookingQrToken> _postQr(String path) async {
    try {
      final res = await http.post(
        Uri.parse('$_base$path'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return BookingQrToken.fromJson(
          _objectBody(res, 'ข้อมูล QR Code ไม่ถูกต้อง'),
        );
      }
      throw ApiRequestException(
        _errorMessage(res, 'ไม่สามารถสร้าง QR Code ได้ กรุณาลองอีกครั้ง'),
        statusCode: res.statusCode,
      );
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('PostQr Error: $error');
      throw const ApiRequestException(
        'ไม่สามารถเชื่อมต่อระบบเพื่อสร้าง QR Code ได้',
      );
    }
  }

// ตรวจสอบ Admin Login
static Future<String?> adminLogin(
  String identifier,
  String password,
) async {
  try {
    final response = await http.post(
      Uri.parse('$_base/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw ApiRequestException(
        _errorMessage(
          response,
          'ไม่สามารถเข้าสู่ระบบผู้ดูแลพื้นที่ได้',
        ),
      );
    }
    final data = _objectBody(
      response,
      'ข้อมูลผู้ดูแลพื้นที่ไม่ถูกต้อง',
    );
    final token = data['access_token'];

    if (token is! String || token.isEmpty) {
      throw const ApiRequestException(
        'ไม่พบสิทธิ์การเข้าสู่ระบบผู้ดูแลพื้นที่',
      );
    }
    await saveToken(token);

    return data['role']?.toString();
  } on ApiRequestException {
    rethrow;
  } catch (error) {
    debugPrint('AdminLogin Error: $error');
    throw const ApiRequestException(
      'ไม่สามารถติดต่อระบบผู้ดูแลได้',
    );
  }
}

  static Future<List<dynamic>> getAdminList() {
    return _getList(
      '/admin/list',
      'ไม่สามารถอ่านรายชื่อผู้ดูแลพื้นที่ได้',
    );
  }

static Future<void> addAdmin({
  required String firstName,
  required String lastName,
  required String username,
  required String email,
  required String password,
  required String passwordConfirmation,
}) async {
  if (password != passwordConfirmation) {
    throw const ApiRequestException('รหัสผ่านไม่ตรงกัน');
  }
  try {
    final response = await http.post(
      Uri.parse('$_base/admin/add'),
      headers: await _headers(),
      body: jsonEncode({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    if (response.statusCode != 201) {
      throw ApiRequestException(
        _errorMessage(response, 'ไม่สามารถเพิ่มผู้ดูแลพื้นที่ได้'),
      );
    }
  } on ApiRequestException {
    rethrow;
  } catch (error) {
    debugPrint('AddAdmin Error: $error');
    throw const ApiRequestException(
      'ไม่สามารถติดต่อระบบเพื่อเพิ่มผู้ดูแลได้',
    );
  }
}

  static Future<void> deactivateAdmin(int adminId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_base/admin/$adminId'),
        headers: await _headers(),
      );
      if (response.statusCode != 200) {
        throw ApiRequestException(
          _errorMessage(response, 'ไม่สามารถลบบัญชีผู้ดูแลพื้นที่ได้'),
        );
      }
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      debugPrint('DeactivateAdmin Error: $error');
      throw const ApiRequestException(
          'ไม่สามารถติดต่อระบบเพื่อลบบัญชีผู้ดูแลได้');
    }
  }

    // บันทึกการทำงานอุปกรณ์ Hardware Logs
  static Future<List<dynamic>> getHardwareLogs() {
    return _getList(
      '/admin/hardware-logs',
      'ไม่สามารถอ่านประวัติการทำงานของอุปกรณ์ได้',
    );
  }

  static Future<List<dynamic>> getDeviceStatuses() {
    return _getList(
      '/admin/devices',
      'ไม่สามารถอ่านสถานะอุปกรณ์ได้',
    );
  }

  static Future<Map<String, dynamic>> getAdminAnalytics({
    String period = 'daily',
    DateTime? anchorDate,
  }) {
    return _getObject(
      '/admin/analytics',
      'ไม่พบข้อมูลสถิติพื้นที่จอดรถ',
      query: _analyticsQuery(
        period,
        anchorDate: anchorDate,
      ),
    );
  }

  static Future<Map<String, dynamic>> getHardwareErrorAnalytics({
    String period = 'daily',
    DateTime? anchorDate,
  }) {
    return _getObject(
      '/admin/analytics/hardware-errors',
      'ไม่พบข้อมูลสถิติความผิดพลาดของอุปกรณ์',
      query: _analyticsQuery(
        period,
        anchorDate: anchorDate,
      ),
    );
  }

  static Future<List<dynamic>> getAllBookingsAdmin() {
    return _getList(
      '/admin/bookings',
      'ไม่พบข้อมูลประวัติการจอง',
    );
  }

  static Future<Map<String, dynamic>> getGateState() {
    return _getObject(
      '/admin/gate-state',
      'ไม่พบข้อมูลสถานะไม้กั้น',
    );
  }
  
  static Future<Map<String, dynamic>> getHardwareCommand(
    String commandId,
  ) {
    return _getObject(
      '/admin/hardware-commands/$commandId',
      'ไม่พบคำสั่งอุปกรณ์',
    );
  }

  static Future<List<dynamic>> getGateEvents({int limit = 200}) {
    if (limit < 1 || limit > 1000) {
      throw const ApiRequestException('จำนวนเหตุการณ์ไม้กั้นไม่ถูกต้อง');
    }
    return _getList(
      '/admin/gate-events',
      'ไม่สามารถดึงประวัติการทำงานของไม้กั้นได้',
      query: {'limit': '$limit'},
    );
  }

  static Future<List<dynamic>> getSlotStatusLogs({int limit = 200}) {
    if (limit < 1 || limit > 1000) {
      throw const ApiRequestException('จำนวนประวัติช่องจอดไม่ถูกต้อง');
    }
    return _getList(
      '/admin/slot-status-logs',
      'ไม่สามารถดึงประวัติสถานะช่องจอดได้',
      query: {'limit': '$limit'},
    );
  }

  static Future<List<dynamic>> getAdminActivity({int limit = 100}) {
    if (limit < 1 || limit > 500) {
      throw const ApiRequestException(
          'จำนวนกิจกรรมของผู้ดูแลพื้นที่ไม่ถูกต้อง');
    }
    return _getList(
      '/admin/activity',
      'ไม่สามารถดึงประวัติการทำงานของผู้ดูแลพื้นที่ได้',
      query: {'limit': '$limit'},
    );
  }

  static Future<Map<String, dynamic>> overrideServo(
    String action,
  ) async {
    if (!const {'open', 'close'}.contains(action)) {
      throw const ApiRequestException('ไม้กั้นทำงานผิดพลาด');
    }
    final response = await http.post(
      Uri.parse('$_base/admin/override/servo'),
      headers: await _headers(),
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode == 202) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw ApiRequestException(
      _errorMessage(response, 'ไม่สามารถส่งคำสั่งไปยังไม้กั้นได้'),
    );
  }

  static Future<Map<String, dynamic>> overrideRgb(
    String slotName,
    String status,
  ) async {
    if (!const {'M', 'N', 'O'}.contains(slotName) ||
        !const {'available', 'reserved', 'occupied'}.contains(status)) {
      throw const ApiRequestException('สถานะช่องจอดไม่ถูกต้อง');
    }
    final response = await http.post(
      Uri.parse('$_base/admin/override/rgb'),
      headers: await _headers(),
      body: jsonEncode({'slot_name': slotName, 'status': status}),
    );
    if (response.statusCode != 202) {
      throw ApiRequestException(
        _errorMessage(response, 'ไม่สามารถควบคุมสถานะช่องจอดได้'),
      );
    }
    return _objectBody(response, 'ข้อมูลคำสั่งควบคุมสถานะช่องจอดไม่ถูกต้อง');
  }

  static Future<List<dynamic>> getSupportMessages() {
    return _getList('/support/messages', 'ไม่สามารถอ่านข้อความได้');
  }

  static Future<Map<String, dynamic>> sendSupportMessage(String body) async {
    if (body.trim().isEmpty) {
      throw const ApiRequestException('กรุณากรอกข้อความ');
    }
    final response = await http.post(
      Uri.parse('$_base/support/messages'),
      headers: await _headers(),
      body: jsonEncode({'body': body.trim()}),
    );
    if (response.statusCode != 201) {
      throw ApiRequestException(
        _errorMessage(response, 'ไม่สามารถส่งข้อความได้'),
      );
    }
    return _objectBody(response, 'ข้อความไม่ถูกต้อง');
  }

  static Future<List<dynamic>> getAdminInbox() {
    return _getList('/admin/inbox', 'ไม่สามารถวิเคราะห์บทสนทนาได้');
  }

  static Future<List<dynamic>> getAdminConversation(int userId) {
    return _getList(
      '/admin/inbox/$userId',
      'ไม่สามารถอ่านบทสนทนาได้',
    );
  }

  static Future<Map<String, dynamic>> replyToSupportMessage(
    int userId,
    String body,
  ) async {
    if (body.trim().isEmpty) {
      throw const ApiRequestException('กรุณากรอกข้อความตอบกลับ');
    }
    final response = await http.post(
      Uri.parse('$_base/admin/inbox/$userId/reply'),
      headers: await _headers(),
      body: jsonEncode({'body': body.trim()}),
    );
    if (response.statusCode != 201) {
      throw ApiRequestException(
        _errorMessage(response, 'ไม่สามารถตอบกลับข้อความได้'),
      );
    }
    return _objectBody(response, 'ข้อความตอบกลับไม่ถูกต้อง');
  }
}