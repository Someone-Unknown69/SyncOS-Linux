import 'package:laptop_controller/core/storage/domain/i_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsStorage implements IStorageService{
  final SharedPreferences _prefs;
    PrefsStorage(this._prefs);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
  @override
  Future<String?> read(String key) => Future.value(_prefs.getString(key));
  @override
  Future<void> delete(String key) => _prefs.remove(key);
  @override
  Future<void> clearAll() => _prefs.clear();
}