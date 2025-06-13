import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img; // Using image package for image processing
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Assistant',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const DrivingAssistantPage(title: 'Driving Assistant'),
    );
  }
}

class DrivingAssistantPage extends StatefulWidget {
  const DrivingAssistantPage({super.key, required this.title});

  final String title;

  @override
  State<DrivingAssistantPage> createState() => _DrivingAssistantPageState();
}

class _DrivingAssistantPageState extends State<DrivingAssistantPage> {
  bool _isProcessing = false;
  OrtSession? _objectDetectionSession;
  final objectDetectionModelPath = 'assets/models/yolov8n.onnx';
  final classNamesPath = 'assets/models/coco-labels.json';
  final imagePath = 'assets/images/test.jpg';
  List<Map<String, dynamic>> _displayResults = [];
  List<OrtProvider> _availableProviders = [];
  String? _selectedProvider;
  // Cache for decoded image to avoid decoding it multiple times
  img.Image? _cachedImage;
  // Store detection results
  List<Detection> _detections = [];
  // UI image with bounding boxes only
  Uint8List? _resultImageBytes;
  // Available cameras
  List<CameraDescription> _cameras = [];

  // Zoom control variables
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadModels();
    _loadAndCacheImage();
    _initializeCameras();
  }

  // Initialize available cameras
  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      print('Found ${_cameras.length} cameras');
    } catch (e) {
      print('Error initializing cameras: $e');
      _cameras = [];
    }
  }

  // Load and cache the image during initialization
  Future<void> _loadAndCacheImage() async {
    try {
      print("Loading image from path: $imagePath");
      final ByteData imageData = await rootBundle.load(imagePath);
      print("Image data loaded, size: ${imageData.lengthInBytes} bytes");

      _cachedImage = img.decodeImage(imageData.buffer.asUint8List());
      if (_cachedImage == null) {
        print("Failed to decode image!");
        throw Exception('Failed to decode image');
      }

      print("Image decoded successfully: ${_cachedImage!.width}x${_cachedImage!.height}");
    } catch (e) {
      print("Error loading image: $e");
      rethrow;
    }
  }

  Future<void> _loadModels() async {
    try {
      print("Starting to load models...");
      OrtProvider provider;
      if (_selectedProvider == null) {
        provider = OrtProvider.CPU;
      } else {
        provider = OrtProvider.values.firstWhere((p) => p.name == _selectedProvider);
      }

      final sessionOptions = OrtSessionOptions(providers: [provider]);

      // Load object detection model
      print("Loading object detection model from: $objectDetectionModelPath");
      _objectDetectionSession ??= await OnnxRuntime().createSessionFromAsset(
        objectDetectionModelPath,
        options: sessionOptions,
      );
      print("Object detection model loaded successfully");

      // Get available providers
      _availableProviders = await OnnxRuntime().getAvailableProviders();
      setState(() {
        _selectedProvider = _availableProviders.isNotEmpty ? _availableProviders[0].name : null;
      });

      setState(() {
        _displayResults = [
          {'title': 'Object Detection Model', 'value': objectDetectionModelPath.split('/').last},
          {'title': 'Processing Device', 'value': _selectedProvider ?? 'CPU'},
          {'title': 'Status', 'value': 'Models loaded successfully'},
        ];
      });
    } catch (e) {
      setState(() {
        _displayResults = [
          {'title': 'Error', 'value': 'Failed to load models: $e'},
        ];
      });
    }
  }

  Future<void> _selectNewImage() async {
    try {
      // Use file picker to select an image
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final File imageFile = File(result.files.single.path!);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final img.Image? image = img.decodeImage(imageBytes);

        if (image != null) {
          // Cache the new selected image
          _cachedImage = image;

          // Clear previous results
          setState(() {
            _displayResults.clear();
            _detections.clear();
            _resultImageBytes = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New image selected! Press "Process Image" to analyze it.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to decode selected image');
        }
      }
    } catch (e) {
      print('Error selecting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _processFrame() async {
    setState(() {
      _isProcessing = true;
      _detections = [];
    });

    try {
      // Use the cached image or load it if not available
      if (_cachedImage == null) {
        await _loadAndCacheImage();
      }

      final img.Image image = _cachedImage!;
      final startTime = DateTime.now();

      // Run object detection
      await _runObjectDetection(image);

      // Draw results on image
      final resultImage = _drawDetections(image);
      _resultImageBytes = img.encodeJpg(resultImage);

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;

      // Calculate average distance of detected objects
      final objectsWithDistance = _detections.where((d) => d.distance != null).toList();
      final avgDistance = objectsWithDistance.isNotEmpty
          ? objectsWithDistance.map((d) => d.distance!).reduce((a, b) => a + b) / objectsWithDistance.length
          : null;

      setState(() {
        _displayResults = [
          {'title': 'Processing Device', 'value': _selectedProvider ?? 'CPU'},
          {'title': 'Objects Detected', 'value': _detections.length.toString()},
          {'title': 'Objects with Distance', 'value': objectsWithDistance.length.toString()},
          {'title': 'Average Distance', 'value': DistanceCalculator.formatDistance(avgDistance)},
          {'title': 'Processing Time', 'value': '$processingTime ms'},
        ];
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _displayResults = [
          {'title': 'Error', 'value': 'Failed to process frame: $e'},
        ];
        _isProcessing = false;
      });
    }
  }

  Future<void> _runObjectDetection(img.Image image) async {
    if (_objectDetectionSession == null) return;

    try {
      print("Starting object detection...");
      
      // Get model info for debugging
      print("Object detection model input names: ${_objectDetectionSession!.inputNames}");
      print("Object detection model output names: ${_objectDetectionSession!.outputNames}");
      
      // Preprocess image for YOLOv8 model (resize to 640x640)
      final img.Image resizedImage = img.copyResize(image, width: 640, height: 640);

      // Convert to RGB float tensor [1, 3, 640, 640] with values normalized between 0-1
      final Float32List inputData = Float32List(1 * 3 * 640 * 640);

      int pixelIndex = 0;
      for (int c = 0; c < 3; c++) { // RGB channels
        for (int y = 0; y < 640; y++) {
          for (int x = 0; x < 640; x++) {
            // Get R, G, B values (0-255)
            double value;
            if (c == 0) {
              value = resizedImage.getPixel(x, y).r.toDouble(); // R
            } else if (c == 1) {
              value = resizedImage.getPixel(x, y).g.toDouble(); // G
            } else {
              value = resizedImage.getPixel(x, y).b.toDouble(); // B
            }

            // Normalize to 0-1 range
            value = value / 255.0;
            inputData[pixelIndex++] = value;
          }
        }
      }

      // Create OrtValue from preprocessed image
      OrtValue inputTensor = await OrtValue.fromList(
        inputData,
        [1, 3, 640, 640], // Input shape: batch, channels, height, width
      );

      // Get input and output names
      final String inputName = _objectDetectionSession!.inputNames.first;
      final String outputName = _objectDetectionSession!.outputNames.first;
      print("Running inference with input: $inputName, output: $outputName");

      // Run inference
      final outputs = await _objectDetectionSession!.run({
        inputName: inputTensor,
      });
      print("Inference completed, processing results");

      // For debugging: check actual output shape
      final outputVal = outputs[outputName]!;
      final shape = outputVal.shape;
      print("Model output shape: $shape");
      
      final List<double> detections = (await outputVal.asFlattenedList()).cast<double>();
      print("Output data length: ${detections.length}");
      
      // Debug: Print sample of output data
      if (detections.isNotEmpty) {
        print("First 10 values of output: ${detections.take(10).toList()}");
      }
      
      // Store all candidate detections before NMS
      List<Detection> candidateDetections = [];
      
      try {
        // Load class names
        final String classNamesJson = await rootBundle.loadString(classNamesPath);
        print("Loaded class names JSON: ${classNamesJson.substring(0, math.min(100, classNamesJson.length))}...");
        
        final dynamic decodedJson = jsonDecode(classNamesJson);
        final List<dynamic> classNames;
        
        if (decodedJson is Map) {
          classNames = List.generate(decodedJson.length, (index) => decodedJson[index.toString()] ?? "unknown");
        } else if (decodedJson is List) {
          classNames = decodedJson;
    } else {
          throw Exception("Unexpected JSON format");
        }
        
        print("Successfully parsed ${classNames.length} class names");
        
        // -------------------------------------------------------------------------------
        // YOLOv8 specific processing for transposed output format [1, 84, 8400]
        // -------------------------------------------------------------------------------
        
        if (shape.length == 3 && shape[1] == 84 && shape[2] == 8400) {
          print("Processing YOLOv8 transposed output format [1, 84, 8400]");
          
          // In YOLOv8, the output is transposed compared to YOLOv5
          // Format is [1, 4+80, 8400] where:
          // - First 4 rows are for bounding box coordinates (x, y, w, h)
          // - Next 80 rows are for class probabilities
          // - 8400 is the number of candidate detections
          
          final int numClasses = 80; // Standard COCO classes
          final int numBoxes = shape[2]; // Number of candidate boxes
          
          // Use a much lower confidence threshold for testing
          final double confidenceThreshold = 0.55;
          
          // Process each detection
          for (int i = 0; i < numBoxes; i++) {
            // Get the highest class probability and its index
            int classId = -1;
            double maxProb = 0.0;
            
            // Check class probabilities (indices 4 to 83 in dim 1)
            for (int c = 0; c < numClasses; c++) {
              double classProb = detections[(c + 4) * numBoxes + i];
              if (classProb > maxProb) {
                maxProb = classProb;
                classId = c;
              }
            }
            
            // Only process if the max probability is above threshold
            if (maxProb > confidenceThreshold && classId >= 0 && classId < classNames.length) {
              // Get bounding box coordinates
              // In YOLOv8, these are in [x, y, w, h] format at indices 0-3
              double x = detections[0 * numBoxes + i];
              double y = detections[1 * numBoxes + i];
              double w = detections[2 * numBoxes + i];
              double h = detections[3 * numBoxes + i];
              
              // Convert from center coordinates to corner coordinates
              double x1 = (x - w/2) * image.width / 640;
              double y1 = (y - h/2) * image.height / 640;
              double x2 = (x + w/2) * image.width / 640;
              double y2 = (y + h/2) * image.height / 640;
              
              // Make sure coordinates are within image bounds
              x1 = math.max(0, math.min(image.width - 1, x1));
              y1 = math.max(0, math.min(image.height - 1, y1));
              x2 = math.max(0, math.min(image.width - 1, x2));
              y2 = math.max(0, math.min(image.height - 1, y2));
              
              // Add detection if the box has area
              if (x2 > x1 && y2 > y1) {
                final String className = classNames[classId];
                final detection = Detection(
                  classId: classId,
                  className: className,
                  confidence: maxProb,
                  box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
                );

                // Calculate distance for this detection
                final distance = DistanceCalculator.calculateDistance(
                  detection,
                  image.width,
                  image.height
                );

                candidateDetections.add(Detection(
                  classId: classId,
                  className: className,
                  confidence: maxProb,
                  box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
                  distance: distance,
                ));
              }
            }
          }
          
          print("Found ${candidateDetections.length} candidate detections before NMS");
          
          // Apply Non-Maximum Suppression (NMS) to filter duplicates
          _detections = _applyNonMaximumSuppression(candidateDetections, 0.5); // 0.5 IoU threshold
          
          print("After NMS: ${_detections.length} detections");
          
          // Log the remaining detections
          for (final detection in _detections) {
            final box = detection.box;
            print("Detected: ${detection.className} (${(detection.confidence * 100).toInt()}%) at [${box.x1.toInt()},${box.y1.toInt()},${box.x2.toInt()},${box.y2.toInt()}]");
          }
          
        } else {
          print("Unsupported model output format: $shape");
          // Add fallback detection for UI testing
          _detections.add(Detection(
            classId: 0,
            className: "test",
            confidence: 0.99,
            box: BoundingBox(
              x1: image.width * 0.2,
              y1: image.height * 0.2,
              x2: image.width * 0.8, 
              y2: image.height * 0.8
            ),
          ));
        }
      } catch (e) {
        print('Error processing class names or detections: $e');
        
        // Add a fallback detection for testing the visualization
        final fallbackDetection = Detection(
          classId: 0,
          className: "test_fallback",
          confidence: 0.5,
          box: BoundingBox(
            x1: 50, y1: 50,
            x2: image.width - 50,
            y2: image.height - 50
          ),
        );
        final fallbackDistance = DistanceCalculator.calculateDistance(
          fallbackDetection,
          image.width,
          image.height
        );
        _detections.add(Detection(
          classId: 0,
          className: "test_fallback",
          confidence: 0.5,
          box: BoundingBox(
            x1: 50, y1: 50,
            x2: image.width - 50,
            y2: image.height - 50
          ),
          distance: fallbackDistance,
        ));
        print("Added fallback detection box");
      }

      // Clean up resources
      await inputTensor.dispose();
      for (var output in outputs.values) {
        await output.dispose();
      }

    } catch (e) {
      print('Object detection error: $e');
      
      // Even in case of error, add a mock detection to test UI
      final errorDetection = Detection(
        classId: 0,
        className: "error_test",
        confidence: 0.99,
        box: BoundingBox(
          x1: 100, y1: 100,
          x2: 300, y2: 300
        ),
      );
      final errorDistance = DistanceCalculator.calculateDistance(
        errorDetection,
        640, // Default image width
        640  // Default image height
      );
      _detections.add(Detection(
        classId: 0,
        className: "error_test",
        confidence: 0.99,
        box: BoundingBox(
          x1: 100, y1: 100,
          x2: 300, y2: 300
        ),
        distance: errorDistance,
      ));
    }
  }


  
  img.Image _drawDetections(img.Image originalImage) {
    // Create a copy of the original image to draw on
    final img.Image resultImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);
    
    // Draw bounding boxes for object detections
    for (final detection in _detections) {
      final box = detection.box;

      // Determine if object is at close distance (less than 10 meters)
      final bool isCloseDistance = detection.distance != null && detection.distance! < 10.0;

      // Fill the bounding box with transparent color for close objects
      if (isCloseDistance) {
        // Use semi-transparent red fill for close objects
        img.fillRect(
          resultImage,
          x1: box.x1.toInt(),
          y1: box.y1.toInt(),
          x2: box.x2.toInt(),
          y2: box.y2.toInt(),
          color: img.ColorRgba8(255, 50, 50, 80), // Red with 80/255 transparency (~31%)
        );
      }

      // Calculate dynamic thickness for mobile visibility
      final int thickness = math.max(4, (resultImage.width / 150).round()); // Minimum 4px, scales with image size

      // Choose border color based on distance
      final img.Color borderColor = isCloseDistance
          ? img.ColorRgb8(255, 255, 0) // Bright yellow for close objects
          : img.ColorRgb8(255, 50, 50); // Bright red for normal objects

      // Draw thicker rectangle with multiple lines for better mobile visibility
      for (int i = 0; i < thickness; i++) {
        img.drawRect(
          resultImage,
          x1: (box.x1 - i).toInt(),
          y1: (box.y1 - i).toInt(),
          x2: (box.x2 + i).toInt(),
          y2: (box.y2 + i).toInt(),
          color: borderColor,
          thickness: 1,
        );
      }

      // Draw label with distance information
      final String confidenceText = '${(detection.confidence * 100).toInt()}%';
      final String distanceText = DistanceCalculator.formatDistance(detection.distance);
      final String label = '${detection.className} $confidenceText';
      final String distanceLabel = 'Dist: $distanceText';

      // Calculate text background dimensions (larger for mobile with better spacing)
      final int textWidth = math.max(label.length * 12, distanceLabel.length * 12);
      final int textHeight = 65; // Increased height for better line spacing
      final int textX = box.x1.toInt();
      final int textY = math.max(0, box.y1.toInt() - textHeight);

      // Draw background rectangle for text
      img.fillRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(0, 0, 0), // Black background
      );

      // Draw border around text background
      img.drawRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(255, 255, 255), // White border
        thickness: 2,
      );

      // Draw main label with bold effect
      _drawBoldText(
        resultImage,
        label,
        x: textX + 4,
        y: textY + 6,
        color: img.ColorRgb8(255, 255, 255), // White text
      );

      // Draw distance label with bright color (more spacing)
      _drawBoldText(
        resultImage,
        distanceLabel,
        x: textX + 4,
        y: textY + 38, // Increased spacing between lines
        color: img.ColorRgb8(255, 255, 0), // Bright yellow text
      );
    }
    

    
    return resultImage;
  }

  // Helper method to draw bold text for mobile visibility
  void _drawBoldText(img.Image image, String text, {required int x, required int y, required img.Color color}) {
    // Draw text multiple times with larger offsets to create bigger, bolder effect
    for (int dx = 0; dx <= 2; dx++) {
      for (int dy = 0; dy <= 2; dy++) {
        img.drawString(
          image,
          text,
          x: x + dx,
          y: y + dy,
          color: color,
          font: img.arial24, // Use larger font
        );
      }
    }
  }

  // Implement Non-Maximum Suppression (NMS) to filter duplicate detections
  List<Detection> _applyNonMaximumSuppression(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // List to store the kept detections
    List<Detection> keptDetections = [];
    // List to track which boxes to remove
    List<bool> shouldRemove = List.filled(detections.length, false);
    
    // Process per class to allow different classes to overlap
    Map<int, List<int>> classToIndices = {};
    
    // Group detection indices by class
    for (int i = 0; i < detections.length; i++) {
      int classId = detections[i].classId;
      if (!classToIndices.containsKey(classId)) {
        classToIndices[classId] = [];
      }
      classToIndices[classId]!.add(i);
    }
    
    // Process each class separately
    for (final indices in classToIndices.values) {
      // For each box in this class
      for (int i = 0; i < indices.length; i++) {
        // If this box is already marked for removal, skip it
        if (shouldRemove[indices[i]]) continue;
        
        // Keep this box
        keptDetections.add(detections[indices[i]]);
        
        // Check all remaining boxes in this class
        for (int j = i + 1; j < indices.length; j++) {
          // If this box is already marked for removal, skip it
          if (shouldRemove[indices[j]]) continue;
          
          // Calculate IoU between the two boxes
          double iou = _calculateIoU(
            detections[indices[i]].box, 
            detections[indices[j]].box
          );
          
          // If IoU exceeds threshold, mark for removal
          if (iou > iouThreshold) {
            shouldRemove[indices[j]] = true;
          }
        }
      }
    }
    
    return keptDetections;
  }
  
  // Calculate Intersection over Union (IoU) between two bounding boxes
  double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    // Calculate intersection area
    double xLeft = math.max(box1.x1, box2.x1);
    double yTop = math.max(box1.y1, box2.y1);
    double xRight = math.min(box1.x2, box2.x2);
    double yBottom = math.min(box1.y2, box2.y2);
    
    // If boxes don't intersect, return 0
    if (xRight < xLeft || yBottom < yTop) return 0.0;
    
    double intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    
    // Calculate union area
    double box1Area = (box1.x2 - box1.x1) * (box1.y2 - box1.y1);
    double box2Area = (box2.x2 - box2.x1) * (box2.y2 - box2.y1);
    double unionArea = box1Area + box2Area - intersectionArea;
    
    // Calculate IoU
    return intersectionArea / unionArea;
  }

  // Method to select and process video file
  Future<void> _selectAndProcessVideo() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening file picker...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Try to pick video file directly - FilePicker handles permissions internally
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        allowCompression: false,
      );

      if (result != null && result.files.single.path != null) {
        final videoFile = File(result.files.single.path!);

        // Verify file exists and is accessible
        if (await videoFile.exists()) {
          // Navigate to video processing screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VideoProcessingScreen(
                videoFile: videoFile,
                objectDetectionSession: _objectDetectionSession,
                classNamesPath: classNamesPath,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file is not accessible')),
          );
        }
      } else {
        // User cancelled or no file selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No video file selected')),
        );
      }
    } catch (e) {
      print('Error selecting video: $e');

      // Show user-friendly error message
      String errorMessage = 'Error selecting video file';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please grant storage access in app settings.';
      } else if (e.toString().contains('not found')) {
        errorMessage = 'File picker not available on this device.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dashboard image at the top with zoom functionality
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Center( // Center the image within the container
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 5.0,
                          child: _resultImageBytes != null
                              ? Image.memory(_resultImageBytes!, fit: BoxFit.contain)
                              : Image.asset(imagePath, fit: BoxFit.contain),
                        ),
                      ),
                      // Reset zoom button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _transformationController.value = Matrix4.identity();
                          },
                          backgroundColor: Colors.black54,
                          child: const Icon(Icons.zoom_out_map, color: Colors.white, size: 16),
                          tooltip: 'Reset Zoom',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Dropdown for selecting execution provider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Provider:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  DropdownButton<String>(
                    value: _selectedProvider,
                    hint: const Text('Select Execution Provider'),
                    items: _availableProviders.map((provider) {
                          return DropdownMenuItem<String>(value: provider.name, child: Text(provider.name));
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProvider = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Process Frame, Camera, and Video buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processFrame,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        child: _isProcessing
                                ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)),
                                    SizedBox(width: 12),
                                    Text('Processing...'),
                                  ],
                                )
                          : const Text('Process Image', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Change Image', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isProcessing ? null : _selectNewImage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text('Live Camera', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_cameras.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No cameras available. Please check camera permissions.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CameraScreen(
                              cameras: _cameras,
                              objectDetectionSession: _objectDetectionSession,
                              classNamesPath: classNamesPath,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_file, size: 18),
                    label: const Text('Process Video File', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isProcessing ? null : _selectAndProcessVideo,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Results section
            Expanded(
              child: _displayResults.isEmpty
                      ? const Center(
                        child: Text(
                        'Press the Process Frame button to analyze the image',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : Column(
                        children: [
                          // Summary results
                          Expanded(
                            flex: 1,
                            child: ListView.builder(
                              itemCount: _displayResults.length,
                              itemBuilder: (context, index) {
                                final result = _displayResults[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            result['title'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        Expanded(flex: 3, child: Text(result['value'], style: const TextStyle(fontSize: 14))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Detailed detections list
                          if (_detections.isNotEmpty) ...[
                            const Divider(),
                            const Text('Detected Objects with Distances:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Expanded(
                              flex: 1,
                              child: ListView.builder(
                                itemCount: _detections.length,
                                itemBuilder: (context, index) {
                                  final detection = _detections[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.visibility,
                                        color: detection.distance != null ? Colors.green : Colors.grey,
                                      ),
                                      title: Text(
                                        '${detection.className} (${(detection.confidence * 100).toInt()}%)',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        'Distance: ${DistanceCalculator.formatDistance(detection.distance)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: detection.distance != null ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                      trailing: detection.distance != null
                                          ? Icon(
                                              detection.distance! < 5.0 ? Icons.warning : Icons.check_circle,
                                              color: detection.distance! < 5.0 ? Colors.orange : Colors.green,
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data models for detections
class BoundingBox {
  final double x1, y1, x2, y2;
  BoundingBox({required this.x1, required this.y1, required this.x2, required this.y2});
}

class Detection {
  final int classId;
  final String className;
  final double confidence;
  final BoundingBox box;
  final double? distance; // Distance in meters
  Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.box,
    this.distance,
  });
}

class Point {
  final double x, y;
  Point(this.x, this.y);
}

// Distance calculation utility class
class DistanceCalculator {
  // Camera calibration parameters (these should be calibrated for your specific camera)
  static const double focalLength = 800.0; // Focal length in pixels (approximate for typical mobile camera)
  static const double cameraHeight = 1.2; // Camera height from ground in meters (typical car dashboard camera)
  static const double cameraTiltAngle = 0.0; // Camera tilt angle in radians (0 = horizontal)

  // Known real-world object sizes in meters (height)
  static const Map<String, double> objectSizes = {
    'person': 1.7,
    'bicycle': 1.1,
    'car': 1.5,
    'motorcycle': 1.2,
    'airplane': 8.0,
    'bus': 3.0,
    'train': 3.5,
    'truck': 2.5,
    'boat': 2.0,
    'traffic light': 3.0,
    'fire hydrant': 0.8,
    'stop sign': 2.0,
    'parking meter': 1.2,
    'bench': 0.8,
    'bird': 0.2,
    'cat': 0.3,
    'dog': 0.6,
    'horse': 1.6,
    'sheep': 0.9,
    'cow': 1.4,
    'elephant': 3.0,
    'bear': 1.0,
    'zebra': 1.4,
    'giraffe': 5.0,
  };

  // Calculate distance using object size estimation
  static double? calculateDistanceBySize(Detection detection, int imageHeight) {
    final objectSize = objectSizes[detection.className];
    if (objectSize == null) return null;

    final boxHeight = detection.box.y2 - detection.box.y1;
    if (boxHeight <= 0) return null;

    // Distance = (Real Object Height * Focal Length) / Object Height in Pixels
    final distance = (objectSize * focalLength) / boxHeight;

    // Apply reasonable bounds (0.5m to 100m)
    return distance.clamp(0.5, 100.0);
  }

  // Calculate distance using perspective geometry (ground plane assumption)
  static double? calculateDistanceByPerspective(Detection detection, int imageWidth, int imageHeight) {
    // Get the bottom center point of the bounding box (where object touches ground)
    final bottomCenterX = (detection.box.x1 + detection.box.x2) / 2;
    final bottomY = detection.box.y2;

    // Convert to normalized coordinates (-1 to 1)
    final normalizedX = (bottomCenterX - imageWidth / 2) / (imageWidth / 2);
    final normalizedY = (bottomY - imageHeight / 2) / (imageHeight / 2);

    // Calculate distance using perspective projection
    // This assumes the camera is looking at a ground plane
    final verticalAngle = math.atan2(normalizedY, focalLength / imageHeight);
    final groundDistance = cameraHeight / math.tan(verticalAngle + cameraTiltAngle);

    // Apply reasonable bounds
    return groundDistance.clamp(0.5, 100.0);
  }

  // Hybrid distance calculation combining multiple methods
  static double? calculateDistance(Detection detection, int imageWidth, int imageHeight) {
    final sizeDistance = calculateDistanceBySize(detection, imageHeight);
    final perspectiveDistance = calculateDistanceByPerspective(detection, imageWidth, imageHeight);

    // If both methods give results, use weighted average
    if (sizeDistance != null && perspectiveDistance != null) {
      // Weight size-based method more for objects with known sizes
      final sizeWeight = objectSizes.containsKey(detection.className) ? 0.7 : 0.3;
      final perspectiveWeight = 1.0 - sizeWeight;
      return (sizeDistance * sizeWeight + perspectiveDistance * perspectiveWeight);
    }

    // Use whichever method gives a result
    return sizeDistance ?? perspectiveDistance;
  }

  // Format distance for display
  static String formatDistance(double? distance) {
    if (distance == null) return 'N/A';
    if (distance < 1.0) {
      return '${(distance * 100).toInt()}cm';
    } else {
      return '${distance.toStringAsFixed(1)}m';
    }
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final OrtSession? objectDetectionSession;
  final String classNamesPath;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.objectDetectionSession,
    required this.classNamesPath,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  List<Detection> _detections = [];

  Uint8List? _processedImageBytes;
  List<String>? _classNames;
  Timer? _processingTimer;
  bool _showProcessedView = true;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadClassNames();
  }
  
  Future<void> _loadClassNames() async {
    try {
      final String classNamesJson = await rootBundle.loadString(widget.classNamesPath);
      final dynamic decodedJson = jsonDecode(classNamesJson);
      
      if (decodedJson is Map) {
        _classNames = List.generate(
          decodedJson.length, 
          (index) => decodedJson[index.toString()] ?? "unknown"
        );
      } else if (decodedJson is List) {
        _classNames = List<String>.from(decodedJson);
      }
      
      print('Loaded ${_classNames?.length} class names');
    } catch (e) {
      print('Error loading class names: $e');
    }
  }
  
  Future<void> _initializeCamera() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      print('Camera permission denied');
      return;
    }
    
    // Check if cameras are available
    if (widget.cameras.isEmpty) {
      print('No cameras available');
      return;
    }
    
    // Initialize the camera with the first available camera
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    
    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
        
        // Start processing frames every 500ms
        _processingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (!_isProcessing && mounted) {
            _processFrame();
          }
        });
      }
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }
  }
  
  Future<void> _processFrame() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _isProcessing ||
        !mounted) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Capture a frame from the camera
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image');
        setState(() {
          _isProcessing = false;
        });
        return;
      }
      
      // Process the frame
      await _processImage(image);
      
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  Future<void> _processImage(img.Image image) async {
    // Reset detections
    _detections = [];
    
    try {
      // Run object detection
      if (widget.objectDetectionSession != null) {
        await _runObjectDetection(image);
      }
      

      
      // Draw results on image
      final processedImage = _drawDetections(image);
      _processedImageBytes = img.encodeJpg(processedImage);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error in image processing: $e');
    }
  }
  
  // Reuse the object detection logic from the main app
  Future<void> _runObjectDetection(img.Image image) async {
    // Skip if session is null or we don't have class names
    if (widget.objectDetectionSession == null || _classNames == null) return;
    
    try {
      // Preprocess image for YOLOv8 model (resize to 640x640)
      final img.Image resizedImage = img.copyResize(image, width: 640, height: 640);

      // Convert to RGB float tensor [1, 3, 640, 640] with values normalized between 0-1
      final Float32List inputData = Float32List(1 * 3 * 640 * 640);

      int pixelIndex = 0;
      for (int c = 0; c < 3; c++) { // RGB channels
        for (int y = 0; y < 640; y++) {
          for (int x = 0; x < 640; x++) {
            // Get R, G, B values (0-255)
            double value;
            if (c == 0) {
              value = resizedImage.getPixel(x, y).r.toDouble(); // R
            } else if (c == 1) {
              value = resizedImage.getPixel(x, y).g.toDouble(); // G
            } else {
              value = resizedImage.getPixel(x, y).b.toDouble(); // B
            }

            // Normalize to 0-1 range
            value = value / 255.0;
            inputData[pixelIndex++] = value;
          }
        }
      }

      // Create OrtValue from preprocessed image
      OrtValue inputTensor = await OrtValue.fromList(
        inputData,
        [1, 3, 640, 640], // Input shape: batch, channels, height, width
      );

      // Get input and output names
      final String inputName = widget.objectDetectionSession!.inputNames.first;
      final String outputName = widget.objectDetectionSession!.outputNames.first;

      // Run inference
      final outputs = await widget.objectDetectionSession!.run({
        inputName: inputTensor,
      });

      // For debugging: check actual output shape
      final outputVal = outputs[outputName]!;
      final shape = outputVal.shape;
      final List<double> detections = (await outputVal.asFlattenedList()).cast<double>();
      
      // Store all candidate detections before NMS
      List<Detection> candidateDetections = [];
      
      // YOLOv8 specific processing for transposed output format [1, 84, 8400]
      if (shape.length == 3 && shape[1] == 84 && shape[2] == 8400) {
        final int numClasses = 80; // Standard COCO classes
        final int numBoxes = shape[2]; // Number of candidate boxes
        
        // Use a moderate confidence threshold for video
        final double confidenceThreshold = 0.50;
        
        // Process each detection
        for (int i = 0; i < numBoxes; i++) {
          // Get the highest class probability and its index
          int classId = -1;
          double maxProb = 0.0;
          
          // Check class probabilities (indices 4 to 83 in dim 1)
          for (int c = 0; c < numClasses; c++) {
            double classProb = detections[(c + 4) * numBoxes + i];
            if (classProb > maxProb) {
              maxProb = classProb;
              classId = c;
            }
          }
          
          // Only process if the max probability is above threshold
          if (maxProb > confidenceThreshold && classId >= 0 && classId < _classNames!.length) {
            // Get bounding box coordinates
            // In YOLOv8, these are in [x, y, w, h] format at indices 0-3
            double x = detections[0 * numBoxes + i];
            double y = detections[1 * numBoxes + i];
            double w = detections[2 * numBoxes + i];
            double h = detections[3 * numBoxes + i];
            
            // Convert from center coordinates to corner coordinates
            double x1 = (x - w/2) * image.width / 640;
            double y1 = (y - h/2) * image.height / 640;
            double x2 = (x + w/2) * image.width / 640;
            double y2 = (y + h/2) * image.height / 640;
            
            // Make sure coordinates are within image bounds
            x1 = math.max(0, math.min(image.width - 1, x1));
            y1 = math.max(0, math.min(image.height - 1, y1));
            x2 = math.max(0, math.min(image.width - 1, x2));
            y2 = math.max(0, math.min(image.height - 1, y2));
            
            // Add detection if the box has area
            if (x2 > x1 && y2 > y1) {
              final String className = _classNames![classId];
              final detection = Detection(
                classId: classId,
                className: className,
                confidence: maxProb,
                box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
              );

              // Calculate distance for this detection
              final distance = DistanceCalculator.calculateDistance(
                detection,
                image.width,
                image.height
              );

              candidateDetections.add(Detection(
                classId: classId,
                className: className,
                confidence: maxProb,
                box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
                distance: distance,
              ));
            }
          }
        }
        
        // Apply Non-Maximum Suppression (NMS) to filter duplicates
        _detections = _applyNonMaximumSuppression(candidateDetections, 0.5); // 0.5 IoU threshold
      }

      // Clean up resources
      await inputTensor.dispose();
      for (var output in outputs.values) {
        await output.dispose();
      }

    } catch (e) {
      print('Object detection error: $e');
    }
  }
  

  
  // Reuse the drawing function and other utilities from the main class
  img.Image _drawDetections(img.Image originalImage) {
    // Create a copy of the original image to draw on
    final img.Image resultImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);
    
    // Draw bounding boxes for object detections
    for (final detection in _detections) {
      final box = detection.box;

      // Determine if object is at close distance (less than 10 meters)
      final bool isCloseDistance = detection.distance != null && detection.distance! < 10.0;

      // Fill the bounding box with transparent color for close objects
      if (isCloseDistance) {
        // Use semi-transparent red fill for close objects
        img.fillRect(
          resultImage,
          x1: box.x1.toInt(),
          y1: box.y1.toInt(),
          x2: box.x2.toInt(),
          y2: box.y2.toInt(),
          color: img.ColorRgba8(255, 50, 50, 80), // Red with 80/255 transparency (~31%)
        );
      }

      // Calculate dynamic thickness for mobile visibility
      final int thickness = math.max(4, (resultImage.width / 150).round()); // Minimum 4px, scales with image size

      // Choose border color based on distance
      final img.Color borderColor = isCloseDistance
          ? img.ColorRgb8(255, 255, 0) // Bright yellow for close objects
          : img.ColorRgb8(255, 50, 50); // Bright red for normal objects

      // Draw thicker rectangle with multiple lines for better mobile visibility
      for (int i = 0; i < thickness; i++) {
        img.drawRect(
          resultImage,
          x1: (box.x1 - i).toInt(),
          y1: (box.y1 - i).toInt(),
          x2: (box.x2 + i).toInt(),
          y2: (box.y2 + i).toInt(),
          color: borderColor,
          thickness: 1,
        );
      }

      // Draw label with distance information
      final String confidenceText = '${(detection.confidence * 100).toInt()}%';
      final String distanceText = DistanceCalculator.formatDistance(detection.distance);
      final String label = '${detection.className} $confidenceText';
      final String distanceLabel = 'Dist: $distanceText';

      // Calculate text background dimensions (larger for mobile with better spacing)
      final int textWidth = math.max(label.length * 12, distanceLabel.length * 12);
      final int textHeight = 65; // Increased height for better line spacing
      final int textX = box.x1.toInt();
      final int textY = math.max(0, box.y1.toInt() - textHeight);

      // Draw background rectangle for text
      img.fillRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(0, 0, 0), // Black background
      );

      // Draw border around text background
      img.drawRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(255, 255, 255), // White border
        thickness: 2,
      );

      // Draw main label with bold effect
      _drawBoldText(
        resultImage,
        label,
        x: textX + 4,
        y: textY + 6,
        color: img.ColorRgb8(255, 255, 255), // White text
      );

      // Draw distance label with bright color (more spacing)
      _drawBoldText(
        resultImage,
        distanceLabel,
        x: textX + 4,
        y: textY + 38, // Increased spacing between lines
        color: img.ColorRgb8(255, 255, 0), // Bright yellow text
      );
    }
    

    
    return resultImage;
  }

  // Helper method to draw bold text for mobile visibility
  void _drawBoldText(img.Image image, String text, {required int x, required int y, required img.Color color}) {
    // Draw text multiple times with larger offsets to create bigger, bolder effect
    for (int dx = 0; dx <= 2; dx++) {
      for (int dy = 0; dy <= 2; dy++) {
        img.drawString(
          image,
          text,
          x: x + dx,
          y: y + dy,
          color: color,
          font: img.arial24, // Use larger font
        );
      }
    }
  }

  // Reuse the NMS function
  List<Detection> _applyNonMaximumSuppression(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // List to store the kept detections
    List<Detection> keptDetections = [];
    // List to track which boxes to remove
    List<bool> shouldRemove = List.filled(detections.length, false);
    
    // Process per class to allow different classes to overlap
    Map<int, List<int>> classToIndices = {};
    
    // Group detection indices by class
    for (int i = 0; i < detections.length; i++) {
      int classId = detections[i].classId;
      if (!classToIndices.containsKey(classId)) {
        classToIndices[classId] = [];
      }
      classToIndices[classId]!.add(i);
    }
    
    // Process each class separately
    for (final indices in classToIndices.values) {
      // For each box in this class
      for (int i = 0; i < indices.length; i++) {
        // If this box is already marked for removal, skip it
        if (shouldRemove[indices[i]]) continue;
        
        // Keep this box
        keptDetections.add(detections[indices[i]]);
        
        // Check all remaining boxes in this class
        for (int j = i + 1; j < indices.length; j++) {
          // If this box is already marked for removal, skip it
          if (shouldRemove[indices[j]]) continue;
          
          // Calculate IoU between the two boxes
          double iou = _calculateIoU(
            detections[indices[i]].box, 
            detections[indices[j]].box
          );
          
          // If IoU exceeds threshold, mark for removal
          if (iou > iouThreshold) {
            shouldRemove[indices[j]] = true;
          }
        }
      }
    }
    
    return keptDetections;
  }
  
  // Reuse the IoU calculation function
  double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    // Calculate intersection area
    double xLeft = math.max(box1.x1, box2.x1);
    double yTop = math.max(box1.y1, box2.y1);
    double xRight = math.min(box1.x2, box2.x2);
    double yBottom = math.min(box1.y2, box2.y2);
    
    // If boxes don't intersect, return 0
    if (xRight < xLeft || yBottom < yTop) return 0.0;
    
    double intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    
    // Calculate union area
    double box1Area = (box1.x2 - box1.x1) * (box1.y2 - box1.y1);
    double box2Area = (box2.x2 - box2.x1) * (box2.y2 - box2.y1);
    double unionArea = box1Area + box2Area - intersectionArea;
    
    // Calculate IoU
    return intersectionArea / unionArea;
  }
  
  @override
  void dispose() {
    _processingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving Assistant Camera'),
        actions: [
          IconButton(
            icon: Icon(_showProcessedView ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showProcessedView = !_showProcessedView;
              });
            },
            tooltip: 'Toggle processed view',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                if (!_showProcessedView || _processedImageBytes == null)
                  CameraPreview(_cameraController!),
                
                // Processed image overlay with zoom functionality
                if (_showProcessedView && _processedImageBytes != null)
                  InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.memory(
                      _processedImageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                
                // Processing indicator
                if (_isProcessing)
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          
          // Statistics
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Objects: ${_detections.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Show object list (scrollable)
                if (_detections.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _detections.length,
                      itemBuilder: (context, index) {
                        final detection = _detections[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                detection.className,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                '${(detection.confidence * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                              Text(
                                DistanceCalculator.formatDistance(detection.distance),
                                style: const TextStyle(color: Colors.yellow, fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _processFrame,
        child: const Icon(Icons.camera),
      ),
    );
  }
}

// Utility class for lane detection processing
class LaneDetectionUtils {
  static Future<List<List<Point>>> processUFLDv2Output(
    List<double> output, 
    List<int> shape, 
    int imageWidth, 
    int imageHeight
  ) async {
    if (shape.length != 4) {
      print("Unexpected lane output shape: $shape");
      return _createMockLanes(imageWidth, imageHeight);
    }

    final int batchSize = shape[0];  // 1
    final int numCols = shape[1];    // 100 - possible x positions
    final int numRows = shape[2];    // 56 - y positions
    final int numLanes = shape[3];   // 4 - lane types

    List<List<Point>> lanes = [];
    
    try {
      // Define the y coordinates where we'll look for lanes
      // Focus on the bottom 80% of the image where the road is most visible
      List<double> yPositions = List.generate(numRows, (index) {
        double t = index / (numRows - 1);
        // Use a non-linear mapping to focus more on the closer part of the road
        double y = 0.2 + (1.0 - math.pow(1.0 - t, 2)) * 0.8;
        return y * imageHeight;
      });

      // Process each lane type
      for (int laneId = 0; laneId < numLanes; laneId++) {
        List<Point> laneCandidates = [];
        List<double> laneConfidences = [];

        // For each row (y position)
        for (int row = 0; row < numRows; row++) {
          // Get all x-position scores for this row and lane
          List<double> rowScores = [];
          for (int col = 0; col < numCols; col++) {
            int idx = (((0 * numCols + col) * numRows + row) * numLanes) + laneId;
            rowScores.add(output[idx]);
          }

          // Apply row-wise softmax with temperature scaling
          double temperature = 1.0; // Adjust this to control confidence sharpness
          double maxScore = rowScores.reduce(math.max);
          List<double> expScores = rowScores.map((s) => math.exp((s - maxScore) / temperature)).toList();
          double sumExp = expScores.reduce((a, b) => a + b);
          List<double> probs = expScores.map((e) => e / sumExp).toList();

          // Find the x position with highest probability
          int bestCol = 0;
          double maxProb = probs[0];
          for (int col = 1; col < numCols; col++) {
            if (probs[col] > maxProb) {
              maxProb = probs[col];
              bestCol = col;
            }
          }

          // Adaptive confidence threshold based on y-position
          // Be more lenient with points that are further away
          double baseThreshold = 0.5;
          double distanceWeight = row / numRows; // 0 for closest, 1 for furthest
          double adaptiveThreshold = baseThreshold * (0.8 + 0.4 * distanceWeight);

          // Only keep points with high confidence
          if (maxProb > adaptiveThreshold) {
            // Convert col index to x coordinate with sub-pixel refinement
            double subpixelOffset = 0.0;
            if (bestCol > 0 && bestCol < numCols - 1) {
              double leftProb = probs[bestCol - 1];
              double rightProb = probs[bestCol + 1];
              subpixelOffset = (rightProb - leftProb) / (2 * (2 * probs[bestCol] - leftProb - rightProb));
              subpixelOffset = math.max(-0.5, math.min(0.5, subpixelOffset));
            }
            
            double x = (bestCol + subpixelOffset) * imageWidth / (numCols - 1);
            double y = yPositions[row];
            laneCandidates.add(Point(x, y));
            laneConfidences.add(maxProb);
          }
        }

        // Only process lanes with enough points and good confidence
        if (laneCandidates.length >= 8) {
          // Sort points by y coordinate
          List<Map<String, dynamic>> sortedPoints = [];
          for (int i = 0; i < laneCandidates.length; i++) {
            sortedPoints.add({
              'point': laneCandidates[i],
              'confidence': laneConfidences[i]
            });
          }
          sortedPoints.sort((a, b) => (a['point'] as Point).y.compareTo((b['point'] as Point).y));

          // Extract sorted points
          List<Point> sortedLane = sortedPoints.map((item) => item['point'] as Point).toList();

          // Validate lane shape
          bool isValidLane = true;
          bool isRightSide = sortedLane[sortedLane.length ~/ 2].x > imageWidth / 2;

          // Calculate average lane direction and allowed deviation
          double avgDx = 0.0;
          int validSegments = 0;
          
          for (int i = 1; i < sortedLane.length; i++) {
            double dx = sortedLane[i].x - sortedLane[i-1].x;
            double dy = sortedLane[i].y - sortedLane[i-1].y;
            if (dy != 0) {
              avgDx += dx / dy;
              validSegments++;
            }
          }
          
          if (validSegments > 0) {
            avgDx /= validSegments;
            
            // Check for consistent direction and smooth curvature
            for (int i = 1; i < sortedLane.length - 1; i++) {
              double prevDx = sortedLane[i].x - sortedLane[i-1].x;
              double nextDx = sortedLane[i+1].x - sortedLane[i].x;
              double prevDy = sortedLane[i].y - sortedLane[i-1].y;
              double nextDy = sortedLane[i+1].y - sortedLane[i].y;
              
              // Normalize by y-distance to get comparable slopes
              if (prevDy != 0) prevDx /= prevDy;
              if (nextDy != 0) nextDx /= nextDy;
              
              // Check for sudden direction changes
              double maxDeviation = 0.5; // Maximum allowed slope change
              if ((prevDx - avgDx).abs() > maxDeviation || 
                  (nextDx - avgDx).abs() > maxDeviation ||
                  (prevDx * nextDx < 0)) { // Direction reversal
                isValidLane = false;
                break;
              }
            }
          }

          if (isValidLane) {
            // Apply spline interpolation for smooth curves
            List<Point> smoothedLane = [];
            
            // Use cubic interpolation with adaptive spacing
            for (int i = 0; i < sortedLane.length - 3; i++) {
              // Use more points for high-curvature regions
              double spacing = 0.1;
              if (i > 0 && i < sortedLane.length - 4) {
                double curvature = _estimateCurvature(
                  sortedLane[i],
                  sortedLane[i+1],
                  sortedLane[i+2],
                  sortedLane[i+3]
                );
                spacing = math.max(0.05, 0.2 - curvature * 0.5);
              }
              
              for (double t = 0; t < 1.0; t += spacing) {
                double x = _cubicInterpolate(
                  sortedLane[i].x,
                  sortedLane[i+1].x,
                  sortedLane[i+2].x,
                  sortedLane[i+3].x,
                  t
                );
                double y = _cubicInterpolate(
                  sortedLane[i].y,
                  sortedLane[i+1].y,
                  sortedLane[i+2].y,
                  sortedLane[i+3].y,
                  t
                );
                smoothedLane.add(Point(x, y));
              }
            }

            // Add the remaining points
            for (int i = math.max(0, sortedLane.length - 3); i < sortedLane.length; i++) {
              smoothedLane.add(sortedLane[i]);
            }

            // Post-process: Remove duplicate or very close points
            List<Point> finalLane = [];
            if (smoothedLane.isNotEmpty) {
              finalLane.add(smoothedLane[0]);
              for (int i = 1; i < smoothedLane.length; i++) {
                double dx = smoothedLane[i].x - finalLane.last.x;
                double dy = smoothedLane[i].y - finalLane.last.y;
                double dist = math.sqrt(dx * dx + dy * dy);
                if (dist > 5.0) { // Minimum distance between points
                  finalLane.add(smoothedLane[i]);
                }
              }
            }

            lanes.add(finalLane);
          }
        }
      }

      // Sort lanes from left to right
      if (lanes.isNotEmpty) {
        lanes.sort((a, b) {
          double avgXA = a.map((p) => p.x).reduce((a, b) => a + b) / a.length;
          double avgXB = b.map((p) => p.x).reduce((a, b) => a + b) / b.length;
          return avgXA.compareTo(avgXB);
        });
        
        // Remove overlapping lanes
        List<List<Point>> filteredLanes = [];
        for (int i = 0; i < lanes.length; i++) {
          bool isOverlapping = false;
          for (int j = 0; j < filteredLanes.length; j++) {
            if (_checkLaneOverlap(lanes[i], filteredLanes[j])) {
              isOverlapping = true;
              break;
            }
          }
          if (!isOverlapping) {
            filteredLanes.add(lanes[i]);
          }
        }
        lanes = filteredLanes;
      }

      return lanes;
    } catch (e) {
      print("Error in lane detection: $e");
      return _createMockLanes(imageWidth, imageHeight);
    }
  }

  // Estimate local curvature using three points
  static double _estimateCurvature(Point p1, Point p2, Point p3, Point p4) {
    // Use the change in slope as a curvature estimate
    double dx1 = p2.x - p1.x;
    double dy1 = p2.y - p1.y;
    double dx2 = p4.x - p3.x;
    double dy2 = p4.y - p3.y;
    
    double slope1 = dy1 != 0 ? dx1 / dy1 : 0;
    double slope2 = dy2 != 0 ? dx2 / dy2 : 0;
    
    return (slope2 - slope1).abs();
  }

  // Check if two lanes overlap significantly
  static bool _checkLaneOverlap(List<Point> lane1, List<Point> lane2) {
    int overlaps = 0;
    int checks = 0;
    
    // Sample points along the lanes and check for proximity
    for (int i = 0; i < lane1.length; i += 3) {
      for (int j = 0; j < lane2.length; j += 3) {
        double dx = lane1[i].x - lane2[j].x;
        double dy = lane1[i].y - lane2[j].y;
        double dist = math.sqrt(dx * dx + dy * dy);
        
        if (dist < 20.0) { // Threshold for considering points as overlapping
          overlaps++;
        }
        checks++;
      }
    }
    
    return overlaps > checks * 0.3; // Consider overlapping if >30% points are close
  }

  // Cubic interpolation helper
  static double _cubicInterpolate(double y0, double y1, double y2, double y3, double t) {
    double a0 = y3 - y2 - y0 + y1;
    double a1 = y0 - y1 - a0;
    double a2 = y2 - y0;
    double a3 = y1;
    
    return a0 * t * t * t + a1 * t * t + a2 * t + a3;
  }

  // Create mock lanes for testing
  static List<List<Point>> _createMockLanes(int width, int height) {
    final List<Point> leftLane = [];
    final List<Point> rightLane = [];

    for (int y = height - 1; y > height / 2; y -= 5) {
      double progress = (height - y) / (height / 2);
      double curve = math.sin(progress * math.pi / 4) * 20;

      leftLane.add(Point(width * 0.35 + curve, y.toDouble()));
      rightLane.add(Point(width * 0.65 + curve, y.toDouble()));
    }

    return [leftLane, rightLane];
  }
}

// Video Processing Screen for processing actual video files
class VideoProcessingScreen extends StatefulWidget {
  final File? videoFile;
  final OrtSession? objectDetectionSession;
  final String classNamesPath;

  const VideoProcessingScreen({
    super.key,
    this.videoFile,
    required this.objectDetectionSession,
    required this.classNamesPath,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  bool _isProcessing = false;
  int _currentFrame = 0;
  int _totalFrames = 0;
  List<Detection> _detections = [];
  Uint8List? _processedImageBytes;

  // Video playback variables
  bool _isPlayingProcessedVideo = false;
  int _currentPlaybackFrame = 0;
  Timer? _playbackTimer;
  List<Uint8List> _processedFrames = []; // Store all processed frames

  // Loading states
  bool _isExtractingFrames = false;
  String _loadingMessage = '';
  List<String>? _classNames;
  VideoPlayerController? _videoController;
  final List<Map<String, dynamic>> _frameResults = [];
  double _processingProgress = 0.0;
  String? _videoPath;
  Duration _videoDuration = Duration.zero;
  bool _videoInitialized = false;
  List<String> _extractedFramePaths = [];
  String? _tempDirectory;

  @override
  void initState() {
    super.initState();
    _loadClassNames();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _playbackTimer?.cancel();
    _cleanupExtractedFrames();
    super.dispose();
  }

  Future<void> _cleanupExtractedFrames() async {
    try {
      for (String framePath in _extractedFramePaths) {
        final file = File(framePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _extractedFramePaths.clear();
    } catch (e) {
      print('Error cleaning up extracted frames: $e');
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoFile == null) {
      // Demo mode - simulate video parameters
      setState(() {
        _videoDuration = const Duration(seconds: 30); // 30 second demo
        _totalFrames = 30; // 30 frames (1 per second)
        _videoInitialized = true;
        _videoPath = 'Demo Video';
      });
      return;
    }

    try {
      _videoController = VideoPlayerController.file(widget.videoFile!);
      await _videoController!.initialize();

      setState(() {
        _videoDuration = _videoController!.value.duration;
        _totalFrames = (_videoDuration.inMilliseconds / 33.33).round(); // Assuming ~30 FPS
        _videoInitialized = true;
        _videoPath = widget.videoFile!.path;
      });

      print('Video initialized: ${_videoDuration.inSeconds}s, ~$_totalFrames frames');
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        _videoInitialized = false;
      });
    }
  }

  Future<void> _loadClassNames() async {
    try {
      final String classNamesJson = await rootBundle.loadString(widget.classNamesPath);
      final dynamic decodedJson = jsonDecode(classNamesJson);

      if (decodedJson is Map) {
        _classNames = List.generate(
          decodedJson.length,
          (index) => decodedJson[index.toString()] ?? "unknown"
        );
      } else if (decodedJson is List) {
        _classNames = List<String>.from(decodedJson);
      }

      print('Loaded ${_classNames?.length} class names for video processing');
    } catch (e) {
      print('Error loading class names: $e');
    }
  }

  Future<void> _startVideoProcessing() async {
    if (_isProcessing || !_videoInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not ready for processing')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentFrame = 0;
      _frameResults.clear();
      _processedFrames.clear(); // Clear previous processed frames
      _processingProgress = 0.0;
      _isPlayingProcessedVideo = false; // Stop any ongoing playback
      _currentPlaybackFrame = 0;
      _processedImageBytes = null; // Clear previous processed image
    });

    // Cancel any ongoing playback
    _playbackTimer?.cancel();

    try {
      if (widget.videoFile != null) {
        // Extract frames from actual video file
        await _extractFramesFromVideo();
      }

      // Process all extracted frames (or demo frames)
      final int framesToProcess = widget.videoFile != null
          ? _extractedFramePaths.length  // Process all extracted frames
          : _totalFrames;  // Demo mode

      print('Processing $framesToProcess frames...');

      for (int i = 0; i < framesToProcess && _isProcessing; i++) {
        setState(() {
          _currentFrame = i + 1;
          _processingProgress = (_currentFrame / framesToProcess);
        });

        print('Processing frame ${i + 1}/$framesToProcess');
        await _processVideoFrame(i);

        // Add a small delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _isProcessing = false;
      });

      _showProcessingComplete();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing video: $e')),
      );
    }
  }

  Future<void> _extractFramesFromVideo() async {
    if (widget.videoFile == null) return;

    setState(() {
      _isExtractingFrames = true;
      _loadingMessage = 'Extracting frames from video...';
    });

    try {
      // Extract frames using video thumbnails
      await _extractFramesUsingThumbnails();
    } catch (e) {
      print('Error extracting frames: $e');
      _extractedFramePaths.clear();
    } finally {
      setState(() {
        _isExtractingFrames = false;
        _loadingMessage = '';
      });
    }
  }

  Future<void> _extractFramesUsingThumbnails() async {
    if (widget.videoFile == null) return;

    try {
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      _tempDirectory = '${tempDir.path}/video_thumbnails';

      // Create frames directory
      final Directory framesDir = Directory(_tempDirectory!);
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create(recursive: true);

      // Extract thumbnails at 1-second intervals
      final int durationSeconds = _videoDuration.inSeconds;
      _extractedFramePaths.clear();

      for (int i = 0; i < durationSeconds && i < 30; i++) { // Limit to 30 frames
        // Update loading message with progress
        setState(() {
          _loadingMessage = 'Extracting frame ${i + 1} of ${math.min(durationSeconds, 30)}...';
        });

        final int timeMs = i * 1000;

        final String? thumbnailPath = await vt.VideoThumbnail.thumbnailFile(
          video: widget.videoFile!.path,
          thumbnailPath: '$_tempDirectory/frame_${i.toString().padLeft(3, '0')}.jpg',
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: timeMs,
          quality: 75,
        );

        if (thumbnailPath != null) {
          _extractedFramePaths.add(thumbnailPath);
        }

        // Small delay to allow UI updates
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('Successfully extracted ${_extractedFramePaths.length} thumbnails');
    } catch (e) {
      print('Error extracting thumbnails: $e');
      _extractedFramePaths.clear();
    }
  }

  Future<void> _processVideoFrame(int frameIndex) async {
    try {
      img.Image? image;

      // Load image from extracted frames or demo images
      if (widget.videoFile != null && _extractedFramePaths.isNotEmpty) {
        // Use extracted frame from actual video
        final int frameFileIndex = frameIndex.clamp(0, _extractedFramePaths.length - 1);
        final String framePath = _extractedFramePaths[frameFileIndex];

        final File frameFile = File(framePath);
        if (await frameFile.exists()) {
          final Uint8List frameBytes = await frameFile.readAsBytes();
          image = img.decodeImage(frameBytes);
        }
      }

      // Skip frame if no image available from video
      if (image == null) {
        print('No image available for frame $frameIndex from video');
        return;
      }

      // Reset detections for this frame
      _detections = [];

      // Run object detection only
      if (widget.objectDetectionSession != null) {
        await _runObjectDetection(image);
      }

      // Draw results on image (only object detection, no lanes)
      final processedImage = _drawDetectionsOnly(image);
      _processedImageBytes = img.encodeJpg(processedImage);

      // Store processed frame for video playback
      _processedFrames.add(_processedImageBytes!);

      // Store frame results
      _frameResults.add({
        'frame': frameIndex + 1,
        'time': frameIndex, // Frame time in seconds
        'detections': _detections.length,
        'objects_with_distance': _detections.where((d) => d.distance != null).length,
        'avg_distance': _calculateAverageDistance(),
        'source': 'video',
      });

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error processing video frame $frameIndex: $e');
    }
  }



  double? _calculateAverageDistance() {
    final objectsWithDistance = _detections.where((d) => d.distance != null).toList();
    if (objectsWithDistance.isEmpty) return null;

    final totalDistance = objectsWithDistance.map((d) => d.distance!).reduce((a, b) => a + b);
    return totalDistance / objectsWithDistance.length;
  }

  void _showProcessingComplete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Video Processing Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Processed ${_frameResults.length} frames successfully!'),
              const SizedBox(height: 16),
              const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_frameResults.isNotEmpty) ...[
                Text('Total Objects Detected: ${_frameResults.map((r) => r['detections'] as int).reduce((a, b) => a + b)}'),
                Text('Average Objects per Frame: ${(_frameResults.map((r) => r['detections'] as int).reduce((a, b) => a + b) / _frameResults.length).toStringAsFixed(1)}'),
                Text('Frames with Distance Data: ${_frameResults.where((r) => (r['objects_with_distance'] as int) > 0).length}'),
              ] else
                const Text('No frames were processed.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _stopProcessing() {
    setState(() {
      _isProcessing = false;
    });
  }

  // Video playback controls for processed frames
  void _startProcessedVideoPlayback() {
    if (_processedFrames.isEmpty) return;

    setState(() {
      _isPlayingProcessedVideo = true;
      _currentPlaybackFrame = 0;
    });

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPlayingProcessedVideo || _processedFrames.isEmpty) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentPlaybackFrame = (_currentPlaybackFrame + 1) % _processedFrames.length;
        _processedImageBytes = _processedFrames[_currentPlaybackFrame];
      });
    });
  }

  void _stopProcessedVideoPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlayingProcessedVideo = false;
    });
  }

  void _pauseProcessedVideoPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlayingProcessedVideo = false;
    });
  }

  void _nextFrame() {
    if (_processedFrames.isEmpty) return;

    setState(() {
      _currentPlaybackFrame = (_currentPlaybackFrame + 1) % _processedFrames.length;
      _processedImageBytes = _processedFrames[_currentPlaybackFrame];
    });
  }

  void _previousFrame() {
    if (_processedFrames.isEmpty) return;

    setState(() {
      _currentPlaybackFrame = (_currentPlaybackFrame - 1 + _processedFrames.length) % _processedFrames.length;
      _processedImageBytes = _processedFrames[_currentPlaybackFrame];
    });
  }

  // Reuse object detection logic from main app
  Future<void> _runObjectDetection(img.Image image) async {
    if (widget.objectDetectionSession == null || _classNames == null) return;

    try {
      // Preprocess image for YOLOv8 model (resize to 640x640)
      final img.Image resizedImage = img.copyResize(image, width: 640, height: 640);

      // Convert to RGB float tensor [1, 3, 640, 640] with values normalized between 0-1
      final Float32List inputData = Float32List(1 * 3 * 640 * 640);

      int pixelIndex = 0;
      for (int c = 0; c < 3; c++) { // RGB channels
        for (int y = 0; y < 640; y++) {
          for (int x = 0; x < 640; x++) {
            // Get R, G, B values (0-255)
            double value;
            if (c == 0) {
              value = resizedImage.getPixel(x, y).r.toDouble(); // R
            } else if (c == 1) {
              value = resizedImage.getPixel(x, y).g.toDouble(); // G
            } else {
              value = resizedImage.getPixel(x, y).b.toDouble(); // B
            }

            // Normalize to 0-1 range
            value = value / 255.0;
            inputData[pixelIndex++] = value;
          }
        }
      }

      // Create OrtValue from preprocessed image
      OrtValue inputTensor = await OrtValue.fromList(
        inputData,
        [1, 3, 640, 640], // Input shape: batch, channels, height, width
      );

      // Get input and output names
      final String inputName = widget.objectDetectionSession!.inputNames.first;
      final String outputName = widget.objectDetectionSession!.outputNames.first;

      // Run inference
      final outputs = await widget.objectDetectionSession!.run({
        inputName: inputTensor,
      });

      // Process results
      final outputVal = outputs[outputName]!;
      final shape = outputVal.shape;
      final List<double> detections = (await outputVal.asFlattenedList()).cast<double>();

      // Store all candidate detections before NMS
      List<Detection> candidateDetections = [];

      // YOLOv8 specific processing for transposed output format [1, 84, 8400]
      if (shape.length == 3 && shape[1] == 84 && shape[2] == 8400) {
        final int numClasses = 80; // Standard COCO classes
        final int numBoxes = shape[2]; // Number of candidate boxes

        // Use a moderate confidence threshold for video
        final double confidenceThreshold = 0.50;

        // Process each detection
        for (int i = 0; i < numBoxes; i++) {
          // Get the highest class probability and its index
          int classId = -1;
          double maxProb = 0.0;

          // Check class probabilities (indices 4 to 83 in dim 1)
          for (int c = 0; c < numClasses; c++) {
            double classProb = detections[(c + 4) * numBoxes + i];
            if (classProb > maxProb) {
              maxProb = classProb;
              classId = c;
            }
          }

          // Only process if the max probability is above threshold
          if (maxProb > confidenceThreshold && classId >= 0 && classId < _classNames!.length) {
            // Get bounding box coordinates
            double x = detections[0 * numBoxes + i];
            double y = detections[1 * numBoxes + i];
            double w = detections[2 * numBoxes + i];
            double h = detections[3 * numBoxes + i];

            // Convert from center coordinates to corner coordinates
            double x1 = (x - w/2) * image.width / 640;
            double y1 = (y - h/2) * image.height / 640;
            double x2 = (x + w/2) * image.width / 640;
            double y2 = (y + h/2) * image.height / 640;

            // Make sure coordinates are within image bounds
            x1 = math.max(0, math.min(image.width - 1, x1));
            y1 = math.max(0, math.min(image.height - 1, y1));
            x2 = math.max(0, math.min(image.width - 1, x2));
            y2 = math.max(0, math.min(image.height - 1, y2));

            // Add detection if the box has area
            if (x2 > x1 && y2 > y1) {
              final String className = _classNames![classId];
              final detection = Detection(
                classId: classId,
                className: className,
                confidence: maxProb,
                box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
              );

              // Calculate distance for this detection
              final distance = DistanceCalculator.calculateDistance(
                detection,
                image.width,
                image.height
              );

              candidateDetections.add(Detection(
                classId: classId,
                className: className,
                confidence: maxProb,
                box: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
                distance: distance,
              ));
            }
          }
        }

        // Apply Non-Maximum Suppression (NMS) to filter duplicates
        _detections = _applyNonMaximumSuppression(candidateDetections, 0.5);
      }

      // Clean up resources
      await inputTensor.dispose();
      for (var output in outputs.values) {
        await output.dispose();
      }

    } catch (e) {
      print('Object detection error in video processing: $e');
    }
  }



  // Reuse NMS logic from main app
  List<Detection> _applyNonMaximumSuppression(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];

    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    // List to store the kept detections
    List<Detection> keptDetections = [];
    // List to track which boxes to remove
    List<bool> shouldRemove = List.filled(detections.length, false);

    // Process per class to allow different classes to overlap
    Map<int, List<int>> classToIndices = {};

    // Group detection indices by class
    for (int i = 0; i < detections.length; i++) {
      int classId = detections[i].classId;
      if (!classToIndices.containsKey(classId)) {
        classToIndices[classId] = [];
      }
      classToIndices[classId]!.add(i);
    }

    // Process each class separately
    for (final indices in classToIndices.values) {
      // For each box in this class
      for (int i = 0; i < indices.length; i++) {
        // If this box is already marked for removal, skip it
        if (shouldRemove[indices[i]]) continue;

        // Keep this box
        keptDetections.add(detections[indices[i]]);

        // Check all remaining boxes in this class
        for (int j = i + 1; j < indices.length; j++) {
          // If this box is already marked for removal, skip it
          if (shouldRemove[indices[j]]) continue;

          // Calculate IoU between the two boxes
          double iou = _calculateIoU(
            detections[indices[i]].box,
            detections[indices[j]].box
          );

          // If IoU exceeds threshold, mark for removal
          if (iou > iouThreshold) {
            shouldRemove[indices[j]] = true;
          }
        }
      }
    }

    return keptDetections;
  }

  // Reuse IoU calculation from main app
  double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    // Calculate intersection area
    double xLeft = math.max(box1.x1, box2.x1);
    double yTop = math.max(box1.y1, box2.y1);
    double xRight = math.min(box1.x2, box2.x2);
    double yBottom = math.min(box1.y2, box2.y2);

    // If boxes don't intersect, return 0
    if (xRight < xLeft || yBottom < yTop) return 0.0;

    double intersectionArea = (xRight - xLeft) * (yBottom - yTop);

    // Calculate union area
    double box1Area = (box1.x2 - box1.x1) * (box1.y2 - box1.y1);
    double box2Area = (box2.x2 - box2.x1) * (box2.y2 - box2.y1);
    double unionArea = box1Area + box2Area - intersectionArea;

    // Calculate IoU
    return intersectionArea / unionArea;
  }

  // Draw only object detections (no lane lines) - optimized for mobile
  img.Image _drawDetectionsOnly(img.Image originalImage) {
    // Create a copy of the original image to draw on
    final img.Image resultImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);

    // Draw bounding boxes for object detections
    for (final detection in _detections) {
      final box = detection.box;

      // Determine if object is at close distance (less than 10 meters)
      final bool isCloseDistance = detection.distance != null && detection.distance! < 10.0;

      // Fill the bounding box with transparent color for close objects
      if (isCloseDistance) {
        // Use semi-transparent red fill for close objects
        img.fillRect(
          resultImage,
          x1: box.x1.toInt(),
          y1: box.y1.toInt(),
          x2: box.x2.toInt(),
          y2: box.y2.toInt(),
          color: img.ColorRgba8(255, 50, 50, 80), // Red with 80/255 transparency (~31%)
        );
      }

      // Calculate dynamic thickness based on image size (for mobile visibility)
      final int thickness = math.max(3, (originalImage.width / 200).round()); // Minimum 3px, scales with image size

      // Choose border color based on distance
      final img.Color borderColor = isCloseDistance
          ? img.ColorRgb8(255, 255, 0) // Bright yellow for close objects
          : img.ColorRgb8(255, 50, 50); // Bright red for normal objects

      // Draw thicker rectangle with multiple lines for better visibility
      for (int i = 0; i < thickness; i++) {
        img.drawRect(
          resultImage,
          x1: (box.x1 - i).toInt(),
          y1: (box.y1 - i).toInt(),
          x2: (box.x2 + i).toInt(),
          y2: (box.y2 + i).toInt(),
          color: borderColor,
          thickness: 1,
        );
      }

      // Draw label background for better text visibility
      final String confidenceText = '${(detection.confidence * 100).toInt()}%';
      final String distanceText = DistanceCalculator.formatDistance(detection.distance);
      final String label = '${detection.className} $confidenceText';
      final String distanceLabel = 'Dist: $distanceText';

      // Calculate text background dimensions (larger for mobile with better spacing)
      final int textWidth = math.max(label.length * 12, distanceLabel.length * 12);
      final int textHeight = 65; // Increased height for better line spacing
      final int textX = box.x1.toInt();
      final int textY = math.max(0, box.y1.toInt() - textHeight);

      // Draw background rectangle for text
      img.fillRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(0, 0, 0), // Black background
      );

      // Draw border around text background
      img.drawRect(
        resultImage,
        x1: textX,
        y1: textY,
        x2: textX + textWidth,
        y2: textY + textHeight,
        color: img.ColorRgb8(255, 255, 255), // White border
        thickness: 2,
      );

      // Draw main label with larger, bold appearance
      _drawBoldText(
        resultImage,
        label,
        x: textX + 4,
        y: textY + 6,
        color: img.ColorRgb8(255, 255, 255), // White text
      );

      // Draw distance label with bright color (more spacing)
      _drawBoldText(
        resultImage,
        distanceLabel,
        x: textX + 4,
        y: textY + 38, // Increased spacing between lines
        color: img.ColorRgb8(255, 255, 0), // Bright yellow text
      );
    }

    return resultImage;
  }

  // Helper method to draw bold text for mobile visibility
  void _drawBoldText(img.Image image, String text, {required int x, required int y, required img.Color color}) {
    // Draw text multiple times with larger offsets to create bigger, bolder effect
    for (int dx = 0; dx <= 2; dx++) {
      for (int dy = 0; dy <= 2; dy++) {
        img.drawString(
          image,
          text,
          x: x + dx,
          y: y + dy,
          color: color,
          font: img.arial24, // Use larger font
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Video info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (widget.videoFile != null) ...[
                      Text('File: ${widget.videoFile!.path.split('/').last}'),
                      if (_videoInitialized) ...[
                        Text('Duration: ${_videoDuration.inMinutes}:${(_videoDuration.inSeconds % 60).toString().padLeft(2, '0')}'),
                        Text('Estimated Frames: $_totalFrames'),
                        Text('Status: Ready for processing'),
                      ] else
                        const Text('Status: Initializing...'),
                    ] else ...[
                      const Text('Mode: Demo Video Processing'),
                      if (_videoInitialized) ...[
                        Text('Duration: ${_videoDuration.inMinutes}:${(_videoDuration.inSeconds % 60).toString().padLeft(2, '0')} (simulated)'),
                        Text('Frames to Process: $_totalFrames'),
                        Text('Status: Ready for demo processing'),
                      ] else
                        const Text('Status: Initializing demo...'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Video display section - vertical layout
            Column(
              children: [
                // Original video (if available)
                if (_videoController != null && _videoController!.value.isInitialized) ...[
                  const Text('Original Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Processed frame
                Text(
                  _processedImageBytes != null ? 'Processed Frame with Object Detection' : 'Processing Preview',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _isExtractingFrames
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _loadingMessage.isNotEmpty ? _loadingMessage : 'Preparing video...',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please wait while we extract frames from your video',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _processedImageBytes != null
                            ? Center( // Center the processed image
                                child: InteractiveViewer(
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  minScale: 0.5,
                                  maxScale: 5.0,
                                  child: Image.memory(
                                    _processedImageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'Processed frames with object detection and distance calculation will appear here during processing\n\nTip: You can pinch to zoom and pan the processed frames',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                  ),
                ),

                // Video playback controls for processed frames
                if (_processedFrames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Processed Video Playback (${_processedFrames.length} frames)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Frame ${_currentPlaybackFrame + 1} of ${_processedFrames.length}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Previous frame
                            IconButton(
                              onPressed: _previousFrame,
                              icon: const Icon(Icons.skip_previous),
                              tooltip: 'Previous Frame',
                            ),
                            // Play/Pause
                            IconButton(
                              onPressed: _isPlayingProcessedVideo
                                  ? _pauseProcessedVideoPlayback
                                  : _startProcessedVideoPlayback,
                              icon: Icon(_isPlayingProcessedVideo ? Icons.pause : Icons.play_arrow),
                              tooltip: _isPlayingProcessedVideo ? 'Pause' : 'Play',
                              iconSize: 32,
                            ),
                            // Stop
                            IconButton(
                              onPressed: _stopProcessedVideoPlayback,
                              icon: const Icon(Icons.stop),
                              tooltip: 'Stop',
                            ),
                            // Next frame
                            IconButton(
                              onPressed: _nextFrame,
                              icon: const Icon(Icons.skip_next),
                              tooltip: 'Next Frame',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Progress indicator
            if (_isProcessing) ...[
              Text(
                'Processing Frame $_currentFrame of $_totalFrames',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _processingProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_processingProgress * 100).toInt()}% Complete',
                style: const TextStyle(fontSize: 14),
              ),
            ],

            const SizedBox(height: 20),

            // Control buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isProcessing || !_videoInitialized) ? null : _startVideoProcessing,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? _stopProcessing : null,
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Stop', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Select New Video', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Results summary
            if (_frameResults.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Processing Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Use a Container with fixed height for the results list
              Container(
                height: 300, // Fixed height for scrollable results
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _frameResults.length,
                  itemBuilder: (context, index) {
                    final result = _frameResults[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            '${result['frame']}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text('Frame ${result['frame']} (${result['time']}s)'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Source: ${result['source'] == 'video' ? 'Video Frame' : 'Demo Image'}'),
                            Text('Objects: ${result['detections']}'),
                            Text('With Distance: ${result['objects_with_distance']}'),
                            if (result['avg_distance'] != null)
                              Text('Avg Distance: ${DistanceCalculator.formatDistance(result['avg_distance'])}'),
                          ],
                        ),
                        trailing: Icon(
                          result['detections'] > 0 ? Icons.check_circle : Icons.info,
                          color: result['detections'] > 0 ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      widget.videoFile != null ? Icons.video_file : Icons.video_file_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.videoFile != null
                          ? 'Press "Start Processing" to analyze your video.\n\nThis will extract frames and run object detection with distance calculation.'
                          : 'No video file selected.\n\nPlease go back and select a video file to process.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],

            // Add some bottom padding for better scrolling
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

