import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fotos de los perros: se guardan SOLO en el teléfono (no se suben a ningún
/// servidor), en la carpeta privada de la app.
abstract class PetPhotoStore {
  Future<Uint8List?> read(String petId);
  Future<void> save(String petId, Uint8List bytes);
  Future<void> delete(String petId);
  Future<void> deleteAll();
}

class FilePetPhotoStore implements PetPhotoStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/pet_photos').create(recursive: true);
  }

  Future<File> _file(String petId) async =>
      File('${(await _dir()).path}/$petId.jpg');

  @override
  Future<Uint8List?> read(String petId) async {
    final file = await _file(petId);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> save(String petId, Uint8List bytes) async =>
      (await _file(petId)).writeAsBytes(bytes, flush: true);

  @override
  Future<void> delete(String petId) async {
    final file = await _file(petId);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteAll() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// En el navegador (y en pruebas) las fotos viven solo mientras la app está abierta.
class MemoryPetPhotoStore implements PetPhotoStore {
  final _photos = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String petId) async => _photos[petId];

  @override
  Future<void> save(String petId, Uint8List bytes) async =>
      _photos[petId] = bytes;

  @override
  Future<void> delete(String petId) async => _photos.remove(petId);

  @override
  Future<void> deleteAll() async => _photos.clear();
}

PetPhotoStore defaultPetPhotoStore() =>
    kIsWeb ? MemoryPetPhotoStore() : FilePetPhotoStore();

/// Preferencias del teléfono (por ahora, si ya vio la presentación). Si el
/// almacenamiento falla, la app sigue: en el peor caso repite la presentación.
class AppPrefs {
  static const _onboardingKey = 'onboarding_seen';

  static Future<bool> onboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e) {
      debugPrint('AppPrefs: no se pudo leer ($e)');
      return false;
    }
  }

  static Future<void> markOnboardingSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(
        _onboardingKey,
        true,
      );
    } catch (e) {
      debugPrint('AppPrefs: no se pudo guardar ($e)');
    }
  }
}
