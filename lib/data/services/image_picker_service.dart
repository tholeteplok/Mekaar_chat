import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickAndProcessImage(ImageSource source, {BuildContext? context}) async {
    try {
      // 1. Pick Image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile == null) return null;

      // 2. Crop Image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Foto Profil',
            toolbarColor: const Color(0xFF0D9488), // Guardian Teal
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

      if (croppedFile == null) return null;

      // 3. Compress Image
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${const Uuid().v4()}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        croppedFile.path,
        targetPath,
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
