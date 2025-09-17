import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../infrastructure/food_service.dart';

class FoodState {
  final bool isLoading;
  final XFile? imageFile;
  final String? resultText;

  FoodState({this.isLoading = false, this.imageFile, this.resultText});

  FoodState copyWith({
    bool? isLoading,
    XFile? imageFile,
    String? resultText,
  }) {
    return FoodState(
      isLoading: isLoading ?? this.isLoading,
      imageFile: imageFile ?? this.imageFile,
      resultText: resultText ?? this.resultText,
    );
  }
}

class FoodController extends StateNotifier<FoodState> {
  FoodController(this._foodService) : super(FoodState());

  final FoodService _foodService;

  Future<void> scanFood(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.first;

      final image = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (_) => TakePictureScreen(camera: camera),
        ),
      );

      if (image != null) {
        state = state.copyWith(isLoading: true, imageFile: image);

        final result = await _foodService.analyzeFood(File(image.path));

        state = state.copyWith(isLoading: false, resultText: result);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, resultText: "Error: $e");
    }
  }
}

final foodControllerProvider =
StateNotifierProvider<FoodController, FoodState>((ref) {
  return FoodController(FoodService());
});

/// Simple camera preview screen
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  const TakePictureScreen({super.key, required this.camera});

  @override
  State<TakePictureScreen> createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Take a picture")),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();
            if (!mounted) return;
            Navigator.pop(context, image);
          } catch (e) {
            debugPrint("Camera error: $e");
          }
        },
      ),
    );
  }
}
