import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../food_scan/infrastructure/food_service.dart';

/// ✅ Providers
final foodServiceProvider = Provider((ref) => FoodService());
final localStorageProvider = Provider((ref) => LocalFoodStorage());

class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key});

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  CameraController? _cameraController;
  late Future<void> _initCamera;
  String _result = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera = _setupCamera();
    _loadLast();
  }

  /// Load last saved result from SharedPreferences
  Future<void> _loadLast() async {
    final storage = ref.read(localStorageProvider);
    final last = await storage.getLastAnalysis();
    if (last != null && mounted) {
      setState(() => _result = last);
    }
  }

  /// Initialize camera safely
  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return; // prevent crash if no cameras available
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController!.initialize();
  }

  /// Common method for analyzing images
  Future<void> _analyzeImage(File? imageFile) async {
    if (imageFile == null || !await imageFile.exists()) {
      setState(() => _result = "❌ Invalid image file.");
      return;
    }

    setState(() => _busy = true);

    try {
      final service = ref.read(foodServiceProvider);
      final storage = ref.read(localStorageProvider);

      final analysis = await service.analyzeFood(imageFile);
      setState(() => _result = analysis);
      await storage.saveLastAnalysis(analysis);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Food analyzed and saved to history!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _result = '❌ Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Capture image from camera
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() => _result = "❌ Camera not ready.");
      return;
    }
    final picture = await _cameraController!.takePicture();
    await _analyzeImage(File(picture.path));
  }

  /// Upload from gallery
  Future<void> _uploadAndAnalyze() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _analyzeImage(File(pickedFile.path));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan or Upload Food')),
      body: FutureBuilder(
        future: _initCamera,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: _cameraController != null &&
                    _cameraController!.value.isInitialized
                    ? CameraPreview(_cameraController!)
                    : const Center(
                  child: Text("📷 Camera not available"),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green[50],
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Text(
                      _result.isEmpty
                          ? '📸 Capture or upload to analyze'
                          : _result,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _captureAndAnalyze,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _uploadAndAnalyze,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
