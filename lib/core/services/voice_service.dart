import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// OpenAI TTS Voice options - natural, human-like voices
enum CheffyVoice {
  alloy,    // Balanced, neutral
  echo,     // Warm, conversational
  fable,    // Expressive, storytelling
  onyx,     // Deep, authoritative
  nova,     // Friendly, warm (recommended for Cheffy)
  shimmer,  // Soft, gentle
}

extension CheffyVoiceExtension on CheffyVoice {
  String get value => name;
  
  String get description {
    switch (this) {
      case CheffyVoice.alloy:
        return 'Balanced and neutral';
      case CheffyVoice.echo:
        return 'Warm and conversational';
      case CheffyVoice.fable:
        return 'Expressive storyteller';
      case CheffyVoice.onyx:
        return 'Deep and authoritative';
      case CheffyVoice.nova:
        return 'Friendly and warm';
      case CheffyVoice.shimmer:
        return 'Soft and gentle';
    }
  }
}

/// Voice service for Text-to-Speech (OpenAI) and Speech-to-Text functionality.
/// 
/// This service provides ChatGPT-quality voice using OpenAI's TTS API:
/// - Cheffy reading responses aloud (TTS via OpenAI)
/// - User voice input for ingredients (STT via device)
/// - Natural, human-like voices
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final SpeechToText _stt = SpeechToText();
  
  bool _sttInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  
  // OpenAI TTS Settings
  static const String _ttsModel = 'tts-1'; // Use 'tts-1-hd' for higher quality
  CheffyVoice _voice = CheffyVoice.nova; // Friendly voice for Cheffy
  double _speed = 1.0; // 0.25 to 4.0
  
  // Cache directory for audio files
  Directory? _cacheDir;
  
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
  bool get isSttAvailable => _sttInitialized;
  CheffyVoice get currentVoice => _voice;

  /// Initialize the voice service
  Future<void> initialize() async {
    await _initAudioPlayer();
    await _initStt();
    await _initCacheDir();
  }

  /// Initialize audio player
  Future<void> _initAudioPlayer() async {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isSpeaking = false;
        onTtsComplete?.call();
      }
    });
    
    debugPrint('✅ Audio player initialized');
  }

  /// Initialize cache directory for audio files
  Future<void> _initCacheDir() async {
    try {
      _cacheDir = await getTemporaryDirectory();
      debugPrint('✅ Cache directory: ${_cacheDir?.path}');
    } catch (e) {
      debugPrint('⚠️ Could not get cache directory: $e');
    }
  }

  /// Initialize Speech-to-Text
  Future<void> _initStt() async {
    try {
      _sttInitialized = await _stt.initialize(
        onError: (error) {
          _isListening = false;
          onError?.call('Speech recognition error: ${error.errorMsg}');
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

  // ==================== TEXT-TO-SPEECH (OpenAI) ====================

  /// Speak the given text using OpenAI TTS
  /// 
  /// This provides ChatGPT-quality, natural-sounding voice
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Stop any current speech
    if (_isSpeaking) {
      await stop();
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_openai_api_key_here') {
      onError?.call('OpenAI API key not configured');
      return;
    }

    try {
      _isSpeaking = true;
      onTtsStart?.call(text);
      
      debugPrint('🔊 Speaking with OpenAI TTS (${_voice.value}): "${text.substring(0, text.length.clamp(0, 50))}..."');

      // Call OpenAI TTS API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _ttsModel,
          'input': text,
          'voice': _voice.value,
          'speed': _speed,
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode == 200) {
        // Save audio to temporary file and play
        final audioFile = await _saveAudioToFile(response.bodyBytes);
        
        if (audioFile != null) {
          await _audioPlayer.setFilePath(audioFile.path);
          await _audioPlayer.play();
        } else {
          throw Exception('Failed to save audio file');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error']?['message'] ?? 'TTS API error: ${response.statusCode}');
      }
    } catch (e) {
      _isSpeaking = false;
      debugPrint('❌ OpenAI TTS Error: $e');
      onError?.call('Voice error: ${e.toString()}');
    }
  }

  /// Save audio bytes to a temporary file
  Future<File?> _saveAudioToFile(Uint8List audioBytes) async {
    try {
      if (_cacheDir == null) {
        await _initCacheDir();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${_cacheDir?.path}/cheffy_tts_$timestamp.mp3');
      await file.writeAsBytes(audioBytes);
      
      // Clean up old files (keep last 5)
      _cleanupOldAudioFiles();
      
      return file;
    } catch (e) {
      debugPrint('❌ Error saving audio file: $e');
      return null;
    }
  }

  /// Clean up old audio files to prevent storage buildup
  void _cleanupOldAudioFiles() async {
    try {
      if (_cacheDir == null) return;
      
      final files = _cacheDir!
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('cheffy_tts_'))
          .toList();
      
      if (files.length > 5) {
        // Sort by name (timestamp) and delete oldest
        files.sort((a, b) => a.path.compareTo(b.path));
        for (var i = 0; i < files.length - 5; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_isSpeaking) {
      await _audioPlayer.stop();
      _isSpeaking = false;
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_isSpeaking) {
      await _audioPlayer.pause();
    }
  }

  /// Resume speaking
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  /// Set the voice for Cheffy
  void setVoice(CheffyVoice voice) {
    _voice = voice;
    debugPrint('🎤 Voice changed to: ${voice.value}');
  }

  /// Set speech speed (0.25 to 4.0, default 1.0)
  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 4.0);
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
        listenFor: listenFor ?? const Duration(seconds: 60),
        pauseFor: pauseFor ?? const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
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
    _audioPlayer.dispose();
    _stt.stop();
  }
}
