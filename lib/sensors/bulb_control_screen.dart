import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class BulbControlScreen extends StatefulWidget {
  const BulbControlScreen({super.key});

  @override
  State<BulbControlScreen> createState() => _BulbControlScreenState();
}

class _BulbControlScreenState extends State<BulbControlScreen> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isBulbOn = false;
  final TextEditingController _ipController = TextEditingController(text: '192.168.75.23');
  String _statusMessage = 'Disconnected';
  Timer? _connectionTimer;
  
  // Voice control
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _voiceText = 'Press mic to speak commands';
  double _micScale = 1.0;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) => print('Status: $status'),
        onError: (error) {
          print('Error: $error');
          setState(() => _voiceText = 'Speech error: $error');
        },
      );
      
      if (!_speechAvailable) {
        setState(() => _voiceText = 'Speech not available');
      }
    } catch (e) {
      print('Speech init error: $e');
      setState(() => _voiceText = 'Failed to initialize speech');
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isConnected = false;
      _statusMessage = 'Connecting...';
    });

    try {
      await _disconnect();
      final uri = Uri.parse('ws://${_ipController.text}:81');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (message) {
          setState(() {
            _isConnected = true;
            if (message == 'STATE:ON') {
              _isBulbOn = true;
              _statusMessage = 'Connected (ON)';
            } else if (message == 'STATE:OFF') {
              _isBulbOn = false;
              _statusMessage = 'Connected (OFF)';
            } else if (message == 'PONG') {
              _statusMessage = 'Connected (${_isBulbOn ? 'ON' : 'OFF'})';
            }
          });
        },
        onError: (error) => _handleDisconnection(),
        onDone: () => _handleDisconnection(),
      );

      await _channel!.ready.timeout(const Duration(seconds: 5));
      setState(() => _isConnected = true);
      _startPingTimer();
      
    } on TimeoutException {
      setState(() => _statusMessage = 'Connection timeout');
      _scheduleReconnect();
    } catch (e) {
      setState(() => _statusMessage = 'Connection failed');
      _scheduleReconnect();
    }
  }

  Future<void> _listen() async {
    if (!_speechAvailable) {
      setState(() => _voiceText = 'Speech not available');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _micScale = 1.0;
        _voiceText = 'Stopped listening';
      });
    } else {
      setState(() {
        _isListening = true;
        _micScale = 1.3;
        _voiceText = 'Listening... Speak now';
      });
      
      final result = await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
      );

      if (!result) {
        setState(() {
          _isListening = false;
          _micScale = 1.0;
          _voiceText = 'Failed to start listening';
        });
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _voiceText = result.recognizedWords);
    if (result.finalResult) {
      _processVoiceCommand(result.recognizedWords.toLowerCase());
    }
  }

  void _processVoiceCommand(String command) {
    if (!_isConnected) {
      setState(() => _voiceText = 'Not connected to device');
      return;
    }

    if (command.contains('on') && !_isBulbOn) {
      _toggleBulb();
      setState(() => _voiceText = 'Turning bulb ON');
    } 
    else if (command.contains('off') && _isBulbOn) {
      _toggleBulb();
      setState(() => _voiceText = 'Turning bulb OFF');
    }
    else if (command.contains('connect')) {
      _connect();
      setState(() => _voiceText = 'Connecting...');
    }
    else {
      setState(() => _voiceText = 'Say "on", "off", or "connect"');
    }
  }

  Future<void> _toggleBulb() async {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(_isBulbOn ? 'OFF' : 'ON');
    } catch (e) {
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    setState(() {
      _isConnected = false;
      _statusMessage = 'Disconnected';
    });
    _scheduleReconnect();
  }

  Future<void> _disconnect() async {
    _connectionTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Timer? _pingTimer;
  void _startPingTimer() {
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add('PING');
      }
    });
  }

  void _scheduleReconnect() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer(const Duration(seconds: 3), _connect);
  }

  @override
  void dispose() {
    _disconnect();
    _ipController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Bulb Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'ESP32 IP Address',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: _isConnected ? Colors.green : Colors.red, size: 12),
                const SizedBox(width: 8),
                Text(_statusMessage, style: TextStyle(color: _isConnected ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONNECT'),
            ),
            const SizedBox(height: 30),
            
            // Voice control section
            Text(
              _voiceText,
              style: TextStyle(
                color: _isListening ? Colors.blue : 
                       !_speechAvailable ? Colors.red : Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            GestureDetector(
              onTap: _listen,
              child: AnimatedScale(
                scale: _micScale,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.blue : 
                           !_speechAvailable ? Colors.grey : Colors.blue[800],
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isListening)
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.6),
                          blurRadius: 15,
                          spreadRadius: 5,
                        )
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : 
                    !_speechAvailable ? Icons.mic_off : Icons.mic_none,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Bulb control
            GestureDetector(
              onTap: _toggleBulb,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBulbOn ? Colors.yellow.withOpacity(0.8) : Colors.grey[800],
                  boxShadow: _isBulbOn
                      ? [BoxShadow(color: Colors.yellow.withOpacity(0.6), blurRadius: 30, spreadRadius: 10)]
                      : null,
                ),
                child: Icon(
                  _isBulbOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 60,
                  color: _isBulbOn ? Colors.orange[900] : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isBulbOn ? 'BULB ON' : 'BULB OFF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isBulbOn ? Colors.yellow : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
