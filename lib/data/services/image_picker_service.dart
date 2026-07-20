import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickAndProcessImage(ImageSource source, {BuildContext? context}) async {
    try {
      // 1. Minta izin galeri sebelum pick (required oleh image_cropper)
      if (source == ImageSource.gallery) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin akses galeri diperlukan untuk memilih foto.')),
            );
          }
          return null;
        }
      }

      // 2. Pick Image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return null;

      // 3. Salin ke file lokal agar image_cropper bisa mengaksesnya
      //    (di beberapa device, pickedFile.path adalah content URI)
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/avatar_raw_${const Uuid().v4()}.jpg';
      final localFile = File(localPath);
      await localFile.writeAsBytes(await pickedFile.readAsBytes());

      // 4. Crop Image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: localFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Foto Profil',
            toolbarColor: const Color(0xFF0D9488),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Potong Foto Profil',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) {
        if (await localFile.exists()) await localFile.delete();
        return null;
      }

      // 5. Hapus file lokal mentah
      await localFile.delete();

      // 6. Compress Image
      final compressedPath = '${tempDir.path}/avatar_${const Uuid().v4()}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        croppedFile.path,
        compressedPath,
        quality: 80,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) return null;

      return File(compressedFile.path);
    } catch (e) {
      debugPrint('Error picking/processing image: $e');
      return null;
    }
  }
}
