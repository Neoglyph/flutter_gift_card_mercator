import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

class GiftCard {
  final String serialCode;
  final double value;
  final String currency;

  GiftCard({
    required this.serialCode,
    required this.value,
    this.currency = 'EUR',
  });

  GiftCard copyWith({
    String? serialCode,
    double? value,
    String? currency,
  }) {
    return GiftCard(
      serialCode: serialCode ?? this.serialCode,
      value: value ?? this.value,
      currency: currency ?? this.currency,
    );
  }

  String get formattedValue {
    return '€${value.toStringAsFixed(2)}';
  }

  // Convert GiftCard to JSON
  Map<String, dynamic> toJson() {
    return {
      'serialCode': serialCode,
      'value': value,
      'currency': currency,
    };
  }

  // Create GiftCard from JSON
  factory GiftCard.fromJson(Map<String, dynamic> json) {
    return GiftCard(
      serialCode: json['serialCode'] as String,
      value: (json['value'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
    );
  }
}

void main() {
  runApp(const MyApp());
}

class CardScannerScreen extends StatefulWidget {
  final Function(String, double) onCardAdded;

  const CardScannerScreen({super.key, required this.onCardAdded});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  CameraController? _controller;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  String _detectedText = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Permission should already be granted when navigating here
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras.first, 
          ResolutionPreset.veryHigh,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {});
        }
      } else {
        if (mounted) {
          setState(() {
            _detectedText = 'No cameras available';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detectedText = 'Error initializing camera: $e';
        });
      }
    }
  }

  bool _isDetectionActive = true;

  void _captureAndProcess() async {
    if (_isProcessing || _controller?.value.isInitialized != true) return;

    _isProcessing = true;
    try {
      final image = await _controller!.takePicture();
      
      // Navigate to preview screen with captured image
      if (mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => CapturePreviewScreen(
              imagePath: image.path,
              onCardAdded: (serial, value) {
                widget.onCardAdded(serial, value);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detectedText = 'Error capturing image: $e';
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isDetectionActive = false;
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Scan Gift Card'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Stack(
        children: [
          if (_controller?.value.isInitialized == true)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CupertinoActivityIndicator(),
            ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Position the 15-digit serial number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill the frame with the number area. Use good lighting and hold steady.',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  if (_detectedText.isNotEmpty && _detectedText.startsWith('Error')) ...[
                    const SizedBox(height: 8),
                    Text(
                      _detectedText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      onPressed: _isProcessing ? null : _captureAndProcess,
                      child: Text(
                        _isProcessing ? 'Capturing...' : 'Capture Photo',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CapturePreviewScreen extends StatefulWidget {
  final String imagePath;
  final Function(String, double) onCardAdded;

  const CapturePreviewScreen({
    super.key,
    required this.imagePath,
    required this.onCardAdded,
  });

  @override
  State<CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<CapturePreviewScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _detectedText = '';
  String? _foundSerial;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    try {
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _detectedText = recognizedText.text;
          _isProcessing = false;
        });
      }

      // Look for serial numbers with multiple patterns
      final List<String> allNumbers = [];
      
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            // Get raw text
            final rawText = element.text;
            allNumbers.add(rawText);
            
            // Clean text for processing
            final cleanText = rawText.replaceAll(RegExp(r'[^0-9]'), '');
            
            // Check various patterns for serial numbers
            if (_isValidSerial(cleanText)) {
              if (mounted) {
                setState(() {
                  _foundSerial = cleanText;
                });
              }
              break;
            }
            
            // Also check if this element might be part of a larger number
            if (cleanText.length >= 10) {
              // Look for any sequence of 15 digits within the text
              final matches = RegExp(r'\d{15}').allMatches(cleanText);
              for (final match in matches) {
                final serial = match.group(0)!;
                if (_isValidSerial(serial)) {
                  if (mounted) {
                    setState(() {
                      _foundSerial = serial;
                    });
                  }
                  break;
                }
              }
            }
          }
          if (_foundSerial != null) break;
        }
        if (_foundSerial != null) break;
      }
      
      // Store all detected numbers for debugging
      if (mounted && allNumbers.isNotEmpty) {
        setState(() {
          _detectedText += '\n\nDetected Numbers: ${allNumbers.join(', ')}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detectedText = 'Error processing image: $e';
          _isProcessing = false;
        });
      }
    }
  }

  bool _isValidSerial(String text) {
    // Check for exactly 15 digits
    if (RegExp(r'^\d{15}$').hasMatch(text)) {
      return true;
    }
    
    // Check for common Mercator card patterns
    // Pattern like: 591840279069565 (the example from your image)
    if (text.length == 15 && text.startsWith('59')) {
      return true;
    }
    
    // Check for other common gift card prefixes
    if (text.length == 15 && (text.startsWith('4') || text.startsWith('5') || text.startsWith('6'))) {
      return true;
    }
    
    return false;
  }

  void _showValueDialog() {
    final valueController = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Card Value'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              const Text('Enter the value for this gift card:'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'Value (e.g. 25.00)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Add Card'),
              onPressed: () {
                final valueText = valueController.text.trim();
                if (valueText.isNotEmpty) {
                  final value = double.tryParse(valueText);
                  if (value != null && value > 0) {
                    // Add the card with captured serial and entered value
                    widget.onCardAdded(_foundSerial!, value);
                    
                    // Close dialog and pop both preview and scanner screens
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close preview
                    Navigator.of(context).pop(); // Close scanner
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Capture Preview'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Back'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Image preview
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Detection results
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isProcessing) ...[
                    const Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 12),
                        Text(
                          'Processing image...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ] else if (_foundSerial != null) ...[
                    const Text(
                      'Serial Number Found:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CupertinoColors.systemGreen),
                      ),
                      child: Text(
                        _foundSerial!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'No Serial Number Detected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try taking another photo with better lighting or closer to the card, or enter the number manually below.',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      placeholder: 'Enter 15-digit serial manually',
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      onChanged: (value) {
                        final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleanValue.length == 15) {
                          setState(() {
                            _foundSerial = cleanValue;
                          });
                        } else {
                          setState(() {
                            _foundSerial = null;
                          });
                        }
                      },
                    ),
                  ],
                  
                  if (_detectedText.isNotEmpty && !_detectedText.startsWith('Error')) ...[
                    const SizedBox(height: 16),
                    Text(
                      'All Detected Text:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: SingleChildScrollView(
                        child: Text(
                          _detectedText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Action buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: CupertinoColors.systemGrey4,
                      child: const Text(
                        'Retake Photo',
                        style: TextStyle(
                          color: CupertinoColors.label,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onPressed: _foundSerial != null ? () {
                        _showValueDialog();
                      } : null,
                      child: const Text(
                        'Add This Card',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Mercator Cards',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.label,
        ),
      ),
      home: const MyHomePage(title: 'Gift Cards'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<GiftCard> _giftCards = [];

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
  }

  // Load gift cards from SharedPreferences
  Future<void> _loadGiftCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? giftCardsJson = prefs.getString('gift_cards');
      
      if (giftCardsJson != null) {
        final List<dynamic> giftCardsList = jsonDecode(giftCardsJson);
        setState(() {
          _giftCards = giftCardsList
              .map((json) => GiftCard.fromJson(json as Map<String, dynamic>))
              .toList();
        });
      } else {
        // Add sample cards only if no saved cards exist
        setState(() {
          _giftCards = [
            GiftCard(serialCode: 'AMZ-1234-5678-9012', value: 25.00),
            GiftCard(serialCode: 'APL-4567-8901-2345', value: 50.00),
            GiftCard(serialCode: 'SBX-7890-1234-5678', value: 15.00),
            GiftCard(serialCode: 'TGT-2345-6789-0123', value: 100.00),
            GiftCard(serialCode: 'WMT-5678-9012-3456', value: 75.00),
          ];
        });
        await _saveGiftCards();
      }
    } catch (e) {
      // If loading fails, start with sample cards
      setState(() {
        _giftCards = [
          GiftCard(serialCode: 'AMZ-1234-5678-9012', value: 25.00),
          GiftCard(serialCode: 'APL-4567-8901-2345', value: 50.00),
          GiftCard(serialCode: 'SBX-7890-1234-5678', value: 15.00),
          GiftCard(serialCode: 'TGT-2345-6789-0123', value: 100.00),
          GiftCard(serialCode: 'WMT-5678-9012-3456', value: 75.00),
        ];
      });
    }
  }

  // Save gift cards to SharedPreferences
  Future<void> _saveGiftCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String giftCardsJson = jsonEncode(
        _giftCards.map((card) => card.toJson()).toList(),
      );
      await prefs.setString('gift_cards', giftCardsJson);
    } catch (e) {
      // Handle save error silently
    }
  }

  // Method channel for native camera permissions
  static const MethodChannel _cameraChannel = MethodChannel('camera_permissions');

  // Check and request camera permissions using AVFoundation
  Future<void> _requestCameraAndNavigate() async {
    if (!Platform.isIOS) {
      // For non-iOS platforms, directly navigate (or implement Android-specific logic)
      _navigateToScanner();
      return;
    }

    try {
      // Check current authorization status
      final String status = await _cameraChannel.invokeMethod('checkCameraPermission');
      
      switch (status) {
        case 'authorized':
          _navigateToScanner();
          break;
        case 'notDetermined':
          // Request permission
          final String result = await _cameraChannel.invokeMethod('requestCameraPermission');
          if (result == 'authorized') {
            _navigateToScanner();
          } else {
            _showPermissionDeniedDialog();
          }
          break;
        case 'denied':
        case 'restricted':
          _showPermissionPermanentlyDeniedDialog();
          break;
        default:
          _showPermissionDeniedDialog();
      }
    } catch (e) {
      // Fallback to direct navigation if method channel fails
      _navigateToScanner();
    }
  }

  void _navigateToScanner() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CardScannerScreen(
          onCardAdded: (serial, value) async {
            // Add card directly to the list
            setState(() {
              _giftCards.add(GiftCard(
                serialCode: serial,
                value: value,
              ));
            });
            await _saveGiftCards();
          },
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('Camera access is needed to scan gift card serial numbers. Please grant permission to use this feature.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                // Retry the permission request
                _cameraChannel.invokeMethod('requestCameraPermission');
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('Camera access has been permanently denied. Please go to Settings to enable camera permission for this app.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                // Open iOS app settings
                _cameraChannel.invokeMethod('openAppSettings');
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddCardDialog() {
    final serialController = TextEditingController();
    final valueController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Add Gift Card'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: serialController,
                      placeholder: 'Serial Code',
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 40,
                    child: const Icon(
                      CupertinoIcons.camera,
                      size: 20,
                      color: CupertinoColors.systemBlue,
                    ),
                    onPressed: () {
                      _requestCameraAndNavigate();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'Value',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Add'),
              onPressed: () async {
                final serial = serialController.text.trim();
                final valueText = valueController.text.trim();

                if (serial.isNotEmpty && valueText.isNotEmpty) {
                  final value = double.tryParse(valueText);
                  if (value != null && value > 0) {
                    setState(() {
                      _giftCards.add(GiftCard(
                        serialCode: serial,
                        value: value,
                      ));
                    });
                    await _saveGiftCards();
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditCardDialog(int index) {
    final giftCard = _giftCards[index];
    final serialController = TextEditingController(text: giftCard.serialCode);
    final valueController =
        TextEditingController(text: giftCard.value.toString());

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Edit Gift Card'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: serialController,
                placeholder: 'Serial Code',
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'Value',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Save'),
              onPressed: () async {
                final serial = serialController.text.trim();
                final valueText = valueController.text.trim();

                if (serial.isNotEmpty && valueText.isNotEmpty) {
                  final value = double.tryParse(valueText);
                  if (value != null && value > 0) {
                    setState(() {
                      _giftCards[index] = GiftCard(
                        serialCode: serial,
                        value: value,
                      );
                    });
                    await _saveGiftCards();
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _removeCard(int index) async {
    setState(() {
      _giftCards.removeAt(index);
    });
    await _saveGiftCards();
  }

  void _showSubtractValueDialog(int index) {
    final giftCard = _giftCards[index];
    final amountController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Spend from Card'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Current balance: ${giftCard.formattedValue}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Enter purchase amount:'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: amountController,
                placeholder: 'Amount (e.g. 12.50)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Subtract'),
              onPressed: () async {
                final amountText = amountController.text.trim();
                if (amountText.isNotEmpty) {
                  final amount = double.tryParse(amountText);
                  if (amount != null && amount > 0) {
                    final newValue = giftCard.value - amount;
                    if (newValue >= 0) {
                      setState(() {
                        _giftCards[index] = giftCard.copyWith(value: newValue);
                      });
                      await _saveGiftCards();
                      Navigator.of(context).pop();
                    } else {
                      // Show error for insufficient balance
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Insufficient Balance'),
                          content: Text(
                            'Cannot subtract ${amount.toStringAsFixed(2)}. Current balance is ${giftCard.formattedValue}.',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Gift Cards'),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showAddCardDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: _giftCards.isEmpty
            ? const Center(
                child: Text(
                  'No gift cards available',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              )
            : CupertinoScrollbar(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _giftCards.length,
                  itemBuilder: (context, index) {
                    final giftCard = _giftCards[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _showSubtractValueDialog(index);
                        },
                        child: CupertinoListTile(
                          padding: const EdgeInsets.all(16),
                          title: Text(
                            giftCard.serialCode,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label,
                            ),
                          ),
                          subtitle: Text(
                            'Tap to spend • ${giftCard.formattedValue} remaining',
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                giftCard.formattedValue,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  _showEditCardDialog(index);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    CupertinoIcons.pen,
                                    color: CupertinoColors.systemBlue,
                                    size: 18,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showCupertinoDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return CupertinoAlertDialog(
                                        title: const Text('Delete Gift Card'),
                                        content: Text(
                                            'Are you sure you want to delete ${giftCard.serialCode}?'),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text('Cancel'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          CupertinoDialogAction(
                                            isDestructiveAction: true,
                                            child: const Text('Delete'),
                                            onPressed: () {
                                              _removeCard(index);
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    CupertinoIcons.delete,
                                    color: CupertinoColors.systemRed,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
