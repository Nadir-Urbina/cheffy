import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Voice service for Text-to-Speech and Speech-to-Text functionality.
/// 
/// This service is designed to be used across the app for:
/// - Cheffy reading responses aloud (TTS)
/// - User voice input for ingredients (STT)
/// - Cooking mode hands-free experience
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  
  bool _ttsInitialized = false;
  bool _sttInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  
  // TTS Settings
  double _speechRate = 0.5; // 0.0 - 1.0 (0.5 is natural)
  double _pitch = 1.0; // 0.5 - 2.0
  double _volume = 1.0; // 0.0 - 1.0
  String _language = 'en-US';
  
  // Callbacks
  Function(String)? onSpeechResult;
  Function()? onSpeechStart;
  Function()? onSpeechEnd;
  Function(String)? onTtsStart;
  Function()? onTtsComplete;
  Function(String)? onError;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get isTtsAvailable => _ttsInitialized;
  bool get isSttAvailable => _sttInitialized;

  /// Initialize the voice service
  Future<void> initialize() async {
    await _initTts();
    await _initStt();
  }

  /// Initialize Text-to-Speech
  Future<void> _initTts() async {
    try {
      // Set up TTS
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(_volume);

      // iOS specific settings
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // Set up callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        onTtsStart?.call('');
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onTtsComplete?.call();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        onError?.call('TTS Error: $message');
      });

      _ttsInitialized = true;
      debugPrint('✅ TTS initialized successfully');
    } catch (e) {
      debugPrint('❌ TTS initialization failed: $e');
      onError?.call('Failed to initialize text-to-speech: $e');
    }
  }

  /// Initialize Speech-to-Text
  Future<void> _initStt() async {
    try {
      _sttInitialized = await _stt.initialize(
        onError: (error) {
          _isListening = false;
          onError?.call('STT Error: ${error.errorMsg}');
          debugPrint('❌ STT Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('🎤 STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onSpeechEnd?.call();
          }
        },
      );

      if (_sttInitialized) {
        debugPrint('✅ STT initialized successfully');
      } else {
        debugPrint('⚠️ STT not available on this device');
      }
    } catch (e) {
      debugPrint('❌ STT initialization failed: $e');
      onError?.call('Failed to initialize speech recognition: $e');
    }
  }

  // ==================== TEXT-TO-SPEECH ====================

  /// Speak the given text aloud
  Future<void> speak(String text) async {
    if (!_ttsInitialized) {
      await _initTts();
    }

    if (text.isEmpty) return;

    // Stop any current speech
    if (_isSpeaking) {
      await stop();
    }

    try {
      _isSpeaking = true;
      onTtsStart?.call(text);
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      onError?.call('Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Pause speaking (iOS only)
  Future<void> pause() async {
    if (Platform.isIOS && _isSpeaking) {
      await _tts.pause();
    }
  }

  /// Set speech rate (0.0 - 1.0, default 0.5)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
  }

  /// Set pitch (0.5 - 2.0, default 1.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }

  /// Set volume (0.0 - 1.0, default 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  // ==================== SPEECH-TO-TEXT ====================

  /// Start listening for speech input
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_sttInitialized) {
      await _initStt();
    }

    if (!_sttInitialized) {
      onError?.call('Speech recognition not available');
      return;
    }

    // Stop TTS if speaking
    if (_isSpeaking) {
      await stop();
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      onSpeechStart?.call();

      await _stt.listen(
        onResult: _onSpeechResult,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      _isListening = false;
      onError?.call('Failed to start listening: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
      onSpeechEnd?.call();
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _stt.cancel();
      _isListening = false;
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      onSpeechResult?.call(result.recognizedWords);
    }
  }

  /// Check if speech recognition is available
  Future<bool> checkSttAvailable() async {
    if (!_sttInitialized) {
      await _initStt();
    }
    return _sttInitialized && _stt.isAvailable;
  }

  /// Get available locales for speech recognition
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_sttInitialized) {
      await _initStt();
    }
    return _stt.locales();
  }

  // ==================== CLEANUP ====================

  /// Dispose of resources
  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
