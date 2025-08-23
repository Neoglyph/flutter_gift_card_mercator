import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class GiftCard {
  final String serialCode;
  final double value;
  final String currency;

  GiftCard({
    required this.serialCode,
    required this.value,
    this.currency = 'EUR',
  });

  String get formattedValue {
    return '€${value.toStringAsFixed(2)}';
  }
}

void main() {
  runApp(const MyApp());
}

class CardScannerScreen extends StatefulWidget {
  final Function(String) onSerialDetected;

  const CardScannerScreen({super.key, required this.onSerialDetected});

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
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _controller = CameraController(cameras.first, ResolutionPreset.high);
          await _controller!.initialize();
          if (mounted) {
            setState(() {});
            // Start detection after a short delay
            Future.delayed(const Duration(milliseconds: 500), _captureAndProcess);
          }
        } else {
          if (mounted) {
            setState(() {
              _detectedText = 'No cameras available';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _detectedText = 'Camera permission denied';
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
    if (!_isDetectionActive || _isProcessing || _controller?.value.isInitialized != true) return;
    
    _isProcessing = true;
    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _detectedText = recognizedText.text;
        });
      }

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.replaceAll(' ', '').replaceAll('-', '');
          if (RegExp(r'^\d{15}$').hasMatch(text)) {
            _isDetectionActive = false;
            widget.onSerialDetected(text);
            return;
          }
        }
      }
    } catch (e) {
      // Log error processing image: $e
    } finally {
      _isProcessing = false;
      // Continue trying to detect after a short delay
      if (_isDetectionActive && mounted) {
        Future.delayed(const Duration(milliseconds: 1000), _captureAndProcess);
      }
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
                    'Point camera at gift card serial number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Looking for 15-digit number...',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  if (_detectedText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Detected: $_detectedText',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      onPressed: _isProcessing ? null : _captureAndProcess,
                      child: Text(_isProcessing ? 'Processing...' : 'Capture'),
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
  final List<GiftCard> _giftCards = [
    GiftCard(serialCode: 'AMZ-1234-5678-9012', value: 25.00),
    GiftCard(serialCode: 'APL-4567-8901-2345', value: 50.00),
    GiftCard(serialCode: 'SBX-7890-1234-5678', value: 15.00),
    GiftCard(serialCode: 'TGT-2345-6789-0123', value: 100.00),
    GiftCard(serialCode: 'WMT-5678-9012-3456', value: 75.00),
  ];

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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => CardScannerScreen(
                            onSerialDetected: (serial) {
                              serialController.text = serial;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'Value',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onPressed: () {
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
    final valueController = TextEditingController(text: giftCard.value.toString());

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'Value',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onPressed: () {
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

  void _removeCard(int index) {
    setState(() {
      _giftCards.removeAt(index);
    });
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
                          'Gift Card',
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
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 32,
                              child: const Icon(
                                CupertinoIcons.pen,
                                color: CupertinoColors.systemBlue,
                                size: 18,
                              ),
                              onPressed: () {
                                _showEditCardDialog(index);
                              },
                            ),
                            const SizedBox(width: 4),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 32,
                              child: const Icon(
                                CupertinoIcons.delete,
                                color: CupertinoColors.systemRed,
                                size: 20,
                              ),
                              onPressed: () {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return CupertinoAlertDialog(
                                      title: const Text('Delete Gift Card'),
                                      content: Text('Are you sure you want to delete ${giftCard.serialCode}?'),
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
                            ),
                          ],
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
