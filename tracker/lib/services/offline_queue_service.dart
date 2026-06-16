import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'local_database.dart';

/// Service for managing offline location queue
class OfflineQueueService {
  Timer? _syncTimer;
  bool _isSyncing = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  void Function(List<PendingLocation>)? _onSync;

  /// Start the offline queue service
  void start({void Function(List<PendingLocation>)? onSync}) {
    _onSync = onSync;
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('📶 Connection restored, syncing queue...');
        syncQueue();
      }
    });
    
    // Periodic sync attempt (every 30 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncQueue();
    });
    
    debugPrint('📦 Offline queue service started');
  }

  /// Stop the service
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('📦 Offline queue service stopped');
  }

  /// Queue a location for later sync
  Future<void> queueLocation({
    required double latitude,
    required double longitude,
    int? batteryLevel,
  }) async {
    final location = PendingLocation(
      latitude: latitude,
      longitude: longitude,
      batteryLevel: batteryLevel,
      timestamp: DateTime.now(),
    );
    
    await LocalDatabaseService.addPendingLocation(location);
    
    final count = await LocalDatabaseService.getPendingLocationCount();
    debugPrint('📦 Queued location (total: $count)');
  }

  /// Check if there are pending locations
  Future<bool> hasPendingLocations() async {
    final count = await LocalDatabaseService.getPendingLocationCount();
    return count > 0;
  }

  /// Get pending location count
  Future<int> getPendingCount() async {
    return LocalDatabaseService.getPendingLocationCount();
  }

  /// Sync the queue (called by location service when connected)
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    
    // Check connectivity first
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      debugPrint('📦 No connection, skipping sync');
      return;
    }
    
    _isSyncing = true;
    
    try {
      final pending = await LocalDatabaseService.getPendingLocations(limit: 50);
      
      if (pending.isEmpty) {
        _isSyncing = false;
        return;
      }
      
      debugPrint('📦 Syncing ${pending.length} pending locations...');
      
      // Notify listener to handle the sync
      if (_onSync != null) {
        _onSync!(pending);
      }
      
    } catch (e) {
      debugPrint('❌ Error syncing queue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Mark locations as successfully sent
  Future<void> markAsSent(List<int> ids) async {
    for (final id in ids) {
      await LocalDatabaseService.removePendingLocation(id);
    }
    debugPrint('📦 Removed ${ids.length} sent locations from queue');
  }

  /// Mark locations as failed (increment retry count)
  Future<void> markAsFailed(List<int> ids) async {
    for (final id in ids) {
      await LocalDatabaseService.incrementRetryCount(id);
    }
    
    // Remove locations with too many retries
    final removed = await LocalDatabaseService.removeFailedLocations(maxRetries: 10);
    if (removed > 0) {
      debugPrint('📦 Removed $removed locations with too many retries');
    }
  }

  /// Clear all pending locations
  Future<void> clearQueue() async {
    await LocalDatabaseService.clearPendingLocations();
    debugPrint('📦 Queue cleared');
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getStats() async {
    final count = await LocalDatabaseService.getPendingLocationCount();
    final pending = await LocalDatabaseService.getPendingLocations(limit: 1);
    
    return {
      'pending_count': count,
      'oldest_timestamp': pending.isNotEmpty ? pending.first.timestamp.toIso8601String() : null,
    };
  }
}

/// Singleton instance
final offlineQueueService = OfflineQueueService();