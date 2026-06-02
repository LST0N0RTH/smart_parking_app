import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slot.dart';
import '../models/booking.dart';

class ApiService {
  static const _base = 'https://tender-mercy-production-0bf1.up.railway.app';

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

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveToken(data['access_token']);
        return true;
      }
    } catch (e) {
      debugPrint('Login Error: $e');
    }
    return false;
  }

  static Future<bool> register(String name, String email, String password, String plate) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'license_plate': plate,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Slot>> getSlots() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/slots'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => Slot.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('GetSlots Error: $e');
    }
    return [];
  }

  static Future<bool> createBooking(int slotId, DateTime start, DateTime end, String plate) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/bookings'),
        headers: await _headers(),
        body: jsonEncode({
          'slot_id': slotId,
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
          'license_plate': plate,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Booking>> getMyBookings() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/bookings/me'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => Booking.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('GetMyBookings Error: $e');
    }
    return [];
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

  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/users/me'),
        headers: await _headers(),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        List<String> userPlates = [];
        if (data['license_plate'] != null && data['license_plate'].toString().isNotEmpty) {
          userPlates = data['license_plate'].toString().split(',').map((e) => e.trim()).toList();
        }

        return {
          'name': data['name'] ?? 'ไม่ระบุชื่อ',
          'email': data['email'] ?? 'ไม่ระบุอีเมล',
          'plates': userPlates,
        }; 
      }
    } catch (e) {
      debugPrint('GetUserProfile Error: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(String name, List<String> plates, {String? password}) async {
    try {
      final body = <String, dynamic>{
        'name': name,
      };
      
      if (plates.isNotEmpty) {
        body['license_plate'] = plates.join(',');
      } else {
        body['license_plate'] = '';
      }
      
      if (password != null) {
        body['password'] = password;
      }

      final res = await http.put(
        Uri.parse('$_base/users/me'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('UpdateProfile Error: $e');
      return false;
    }
  }

  static Future<bool> confirmPayment(int bookingId, String method) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/payments/confirm'),
        headers: await _headers(),
        body: jsonEncode({'booking_id': bookingId, 'method': method}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ConfirmPayment Error: $e');
      return false;
    }
  }
}