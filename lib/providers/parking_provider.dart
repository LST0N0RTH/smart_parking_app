import 'package:flutter/material.dart';
import '../models/slot.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class ParkingProvider with ChangeNotifier {
  List<Slot>    slots    = [];
  List<Booking> bookings = [];

  bool _isLoggedIn = false;
  bool _isLoading  = false;
  bool _isInitialized = false; 
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading  => _isLoading;
  bool get isInitialized => _isInitialized;

  String _userName = '';
  String _userEmail = '';
  List<String> _userPlates = [];

  String get userName => _userName;
  String get userEmail => _userEmail;
  List<String> get userPlates => _userPlates;

  ParkingProvider() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final token = await ApiService.getToken();
    if (token != null) {
      _isLoggedIn = true; 
      await fetchUserProfile(); 
    }
    _isInitialized = true; 
    notifyListeners();
  }

  Future<void> loadSlots() async {
    _isLoading = true; 
    notifyListeners();
    slots = await ApiService.getSlots();
    slots.sort((a, b) => a.name.compareTo(b.name));
    _isLoading = false; 
    notifyListeners();
  }

  Future<void> loadBookings() async {
    bookings = await ApiService.getMyBookings();
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    final data = await ApiService.getUserProfile();
    if (data != null) {
      _userName = data['name'] ?? 'ไม่ระบุชื่อ';
      _userEmail = data['email'] ?? 'ไม่ระบุอีเมล';
      final String? plateData = data['license_plate'];
      if (plateData != null && plateData.isNotEmpty) {
        _userPlates = plateData.split(',').map((e) => e.trim()).toList();
      } else {
        _userPlates = [];
      }
      
      notifyListeners();
    }
  }

  Future<bool> updateUserProfile(String newName, List<String> newPlates) async {
    final success = await ApiService.updateProfile(newName, newPlates);
    if (success) {
      _userName = newName;
      _userPlates = newPlates;
      notifyListeners();
      return true;
    }
    return false;
  }

  void updateSlotStatus(String slotName, String status) {
    slots = slots.map((s) {
      if (s.name == slotName) return Slot(id: s.id, name: s.name, status: status);
      return s;
    }).toList();
    slots.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  int get availableCount => slots.where((s) => s.isAvailable).length;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await ApiService.login(email, password);
      
      if (success) {
        _isLoggedIn = true; 
        final profile = await ApiService.getUserProfile();
        
        if (profile != null) {
          _userName = profile['name'] ?? 'ผู้ใช้งาน';
          _userEmail = profile['email'] ?? email;
          
          final String? plateData = profile['license_plate'];
          if (plateData != null && plateData.isNotEmpty) {
            _userPlates = plateData.split(',').map((e) => e.trim()).toList();
          } else {
            _userPlates = [];
          }
        }
        
        _isLoading = false;
        notifyListeners(); 
        return true;
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password, String plate) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await ApiService.register(name, email, password, plate);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint("Register error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _isLoggedIn = false; // 
    slots = []; 
    bookings = [];
    _userName = '';
    _userEmail = '';
    _userPlates = [];
    notifyListeners();
  }
}