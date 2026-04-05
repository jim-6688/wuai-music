import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/nas_sync_service.dart';

final nasSyncServiceProvider = ChangeNotifierProvider((ref) {
  return NasSyncService();
});