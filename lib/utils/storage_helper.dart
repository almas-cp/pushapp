import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_settings.dart';
import '../models/exercise_stats.dart';
import '../models/app_usage_model.dart';
import '../models/monitoring_state.dart';

class StorageHelper {
  // Storage keys
  static const String KEY_SETTINGS = 'exercise_settings';
  static const String KEY_STATS = 'exercise_stats';
  static const String KEY_USAGE = 'app_usage';
  static const String KEY_STATE = 'monitoring_state';

  // In-memory fallback cache
  static final Map<String, String> _inMemoryCache = {};

  // ExerciseSettings methods
  static Future<ExerciseSettings?> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(KEY_SETTINGS) ?? _inMemoryCache[KEY_SETTINGS];
      
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ExerciseSettings.fromJson(json);
    } catch (e) {
      print('Error loading settings: $e');
      // Try to load from in-memory cache
      final cachedString = _inMemoryCache[KEY_SETTINGS];
      if (cachedString != null) {
        try {
          final json = jsonDecode(cachedString) as Map<String, dynamic>;
          return ExerciseSettings.fromJson(json);
        } catch (cacheError) {
          print('Error loading from cache: $cacheError');
        }
      }
      return null;
    }
  }

  static Future<bool> saveSettings(ExerciseSettings settings) async {
    try {
      final jsonString = jsonEncode(settings.toJson());
      
      // Always save to in-memory cache first
      _inMemoryCache[KEY_SETTINGS] = jsonString;
      
      // Try to save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(KEY_SETTINGS, jsonString);
    } catch (e) {
      print('Error saving settings: $e');
      // Data is still in memory cache
      return false;
    }
  }

  // ExerciseStats methods
  static Future<ExerciseStats?> loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(KEY_STATS) ?? _inMemoryCache[KEY_STATS];
      
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ExerciseStats.fromJson(json);
    } catch (e) {
      print('Error loading stats: $e');
      // Try to load from in-memory cache
      final cachedString = _inMemoryCache[KEY_STATS];
      if (cachedString != null) {
        try {
          final json = jsonDecode(cachedString) as Map<String, dynamic>;
          return ExerciseStats.fromJson(json);
        } catch (cacheError) {
          print('Error loading from cache: $cacheError');
        }
      }
      return null;
    }
  }

  static Future<bool> saveStats(ExerciseStats stats) async {
    try {
      final jsonString = jsonEncode(stats.toJson());
      
      // Always save to in-memory cache first
      _inMemoryCache[KEY_STATS] = jsonString;
      
      // Try to save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(KEY_STATS, jsonString);
    } catch (e) {
      print('Error saving stats: $e');
      // Data is still in memory cache
      return false;
    }
  }

  // App Usage methods
  static Future<List<AppUsageModel>> loadUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(KEY_USAGE) ?? _inMemoryCache[KEY_USAGE];
      
      if (jsonString == null) return [];
      
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => AppUsageModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading usage data: $e');
      // Try to load from in-memory cache
      final cachedString = _inMemoryCache[KEY_USAGE];
      if (cachedString != null) {
        try {
          final jsonList = jsonDecode(cachedString) as List<dynamic>;
          return jsonList
              .map((json) => AppUsageModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } catch (cacheError) {
          print('Error loading from cache: $cacheError');
        }
      }
      return [];
    }
  }

  static Future<bool> saveUsageData(List<AppUsageModel> usageList) async {
    try {
      final jsonList = usageList.map((usage) => usage.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // Always save to in-memory cache first
      _inMemoryCache[KEY_USAGE] = jsonString;
      
      // Try to save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(KEY_USAGE, jsonString);
    } catch (e) {
      print('Error saving usage data: $e');
      // Data is still in memory cache
      return false;
    }
  }

  // MonitoringState methods
  static Future<MonitoringState?> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(KEY_STATE) ?? _inMemoryCache[KEY_STATE];
      
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MonitoringState.fromJson(json);
    } catch (e) {
      print('Error loading state: $e');
      // Try to load from in-memory cache
      final cachedString = _inMemoryCache[KEY_STATE];
      if (cachedString != null) {
        try {
          final json = jsonDecode(cachedString) as Map<String, dynamic>;
          return MonitoringState.fromJson(json);
        } catch (cacheError) {
          print('Error loading from cache: $cacheError');
        }
      }
      return null;
    }
  }

  static Future<bool> saveState(MonitoringState state) async {
    try {
      final jsonString = jsonEncode(state.toJson());
      
      // Always save to in-memory cache first
      _inMemoryCache[KEY_STATE] = jsonString;
      
      // Try to save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(KEY_STATE, jsonString);
    } catch (e) {
      print('Error saving state: $e');
      // Data is still in memory cache
      return false;
    }
  }

  // Utility method to clear all data
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(KEY_SETTINGS);
      await prefs.remove(KEY_STATS);
      await prefs.remove(KEY_USAGE);
      await prefs.remove(KEY_STATE);
      
      // Clear in-memory cache
      _inMemoryCache.clear();
      
      return true;
    } catch (e) {
      print('Error clearing data: $e');
      return false;
    }
  }

  // Utility method to check if data exists in cache
  static bool hasInMemoryData(String key) {
    return _inMemoryCache.containsKey(key);
  }
}
