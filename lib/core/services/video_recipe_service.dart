import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/recipe_model.dart';
import '../models/video_recipe_models.dart';

/// Service for extracting recipes from YouTube cooking videos
///
/// Flow:
/// 1. Parse and validate YouTube URL
/// 2. Fetch video metadata (title, description, thumbnail)
/// 3. Try to get transcript/captions
/// 4. If transcript available: Send to GPT-4 for recipe extraction
/// 5. If no transcript: Fall back to GPT-4o Vision with thumbnail + description
class VideoRecipeService {
  static const String _model = 'gpt-4o';
  static const String _openAiBaseUrl = 'https://api.openai.com/v1';

  final YoutubeExplode _yt = YoutubeExplode();
  bool _initialized = false;
  String? _apiKey;

  /// Callback for status updates during processing
  Function(VideoProcessingStatus)? onStatusUpdate;

  /// Initialize the OpenAI client
  void _initialize() {
    if (_initialized) return;

    _apiKey = dotenv.env['OPENAI_API_KEY'];
    if (_apiKey == null ||
        _apiKey!.isEmpty ||
        _apiKey == 'your_openai_api_key_here') {
      throw Exception('OpenAI API key not configured. Please add it to .env file.');
    }

    _initialized = true;
  }

  /// Extract a recipe from a YouTube video URL
  Future<VideoRecipeResult> extractRecipeFromUrl(String url) async {
    _initialize();

    try {
      // Step 1: Validate and parse URL
      final videoId = _extractVideoId(url);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL. Please enter a valid YouTube video link.');
      }

      // Step 2: Fetch video information
      _updateStatus(VideoProcessingStatus.fetchingVideo);
      final videoInfo = await _fetchVideoInfo(videoId);

      // Step 3: Try to get transcript
      _updateStatus(VideoProcessingStatus.fetchingTranscript);
      final transcript = await _fetchTranscript(videoId);

      Recipe recipe;
      bool usedVisionFallback = false;

      if (transcript != null && !transcript.isEmpty) {
        // Step 4a: Extract recipe from transcript
        _updateStatus(VideoProcessingStatus.analyzingContent);
        recipe = await _extractRecipeFromTranscript(videoInfo, transcript);
      } else {
        // Step 4b: Fall back to vision-based extraction
        _updateStatus(VideoProcessingStatus.extractingFrames);
        usedVisionFallback = true;
        recipe = await _extractRecipeFromVision(videoInfo);
      }

      _updateStatus(VideoProcessingStatus.complete);

      return VideoRecipeResult.success(
        videoInfo: videoInfo,
        recipe: recipe,
        usedVisionFallback: usedVisionFallback,
        transcript: transcript,
      );
    } catch (e) {
      debugPrint('Error extracting recipe: $e');
      _updateStatus(VideoProcessingStatus.error);

      // Create a minimal video info for error case
      final videoId = _extractVideoId(url);
      final videoInfo = VideoInfo(
        videoId: videoId ?? 'unknown',
        title: 'Video',
      );

      return VideoRecipeResult.failure(
        videoInfo: videoInfo,
        error: e.toString(),
      );
    }
  }

  /// Extract video ID from various YouTube URL formats
  String? _extractVideoId(String url) {
    // Handle various YouTube URL formats:
    // - https://www.youtube.com/watch?v=VIDEO_ID
    // - https://youtu.be/VIDEO_ID
    // - https://www.youtube.com/embed/VIDEO_ID
    // - https://www.youtube.com/v/VIDEO_ID
    // - https://www.youtube.com/shorts/VIDEO_ID
    // - youtube.com/watch?v=VIDEO_ID (without https)

    url = url.trim();

    // Try using youtube_explode's parser first
    try {
      final videoId = VideoId.parseVideoId(url);
      if (videoId != null) {
        return videoId;
      }
    } catch (_) {
      // Fall through to manual parsing
    }

    // Manual regex patterns
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/|youtube\.com\/shorts\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'^([a-zA-Z0-9_-]{11})$'), // Just the video ID
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Fetch video metadata from YouTube
  Future<VideoInfo> _fetchVideoInfo(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);

      return VideoInfo(
        videoId: videoId,
        title: video.title,
        description: video.description,
        channelName: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration,
        uploadDate: video.uploadDate,
      );
    } catch (e) {
      debugPrint('Error fetching video info: $e');
      // Return minimal info if fetch fails
      return VideoInfo(
        videoId: videoId,
        title: 'YouTube Video',
      );
    }
  }

  /// Fetch video transcript/captions
  Future<VideoTranscript?> _fetchTranscript(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);

      if (manifest.tracks.isEmpty) {
        debugPrint('No captions available for video');
        return null;
      }

      // Prefer English captions, then auto-generated, then any available
      ClosedCaptionTrackInfo? selectedTrack;

      // First, look for manual English captions
      selectedTrack = manifest.tracks.where((t) =>
          t.language.code.startsWith('en') && !t.isAutoGenerated).firstOrNull;

      // Then, auto-generated English
      selectedTrack ??= manifest.tracks.where((t) =>
          t.language.code.startsWith('en') && t.isAutoGenerated).firstOrNull;

      // Then, any manual captions
      selectedTrack ??= manifest.tracks.where((t) => !t.isAutoGenerated).firstOrNull;

      // Finally, any captions
      selectedTrack ??= manifest.tracks.firstOrNull;

      if (selectedTrack == null) {
        return null;
      }

      debugPrint('Using caption track: ${selectedTrack.language.name} (auto: ${selectedTrack.isAutoGenerated})');

      final track = await _yt.videos.closedCaptions.get(selectedTrack);

      final segments = track.captions.map((caption) {
        return TranscriptSegment(
          text: caption.text,
          start: caption.offset,
          end: caption.offset + caption.duration,
        );
      }).toList();

      return VideoTranscript(
        videoId: videoId,
        languageCode: selectedTrack.language.code,
        segments: segments,
        isAutoGenerated: selectedTrack.isAutoGenerated,
      );
    } catch (e) {
      debugPrint('Error fetching transcript: $e');
      return null;
    }
  }

  /// Extract recipe from transcript using GPT-4
  Future<Recipe> _extractRecipeFromTranscript(
    VideoInfo videoInfo,
    VideoTranscript transcript,
  ) async {
    _updateStatus(VideoProcessingStatus.analyzingContent);

    final prompt = '''You are a recipe extraction assistant. Analyze this cooking video transcript and extract a complete recipe.

VIDEO TITLE: ${videoInfo.title}

VIDEO DESCRIPTION: ${videoInfo.description ?? 'Not available'}

TRANSCRIPT:
${transcript.fullText}

Extract the recipe and respond with ONLY a JSON object in this exact format:
{
  "name": "Recipe name (use the dish name from the video)",
  "description": "Brief 1-2 sentence description of the dish",
  "cuisineType": "italian/mexican/chinese/indian/american/french/thai/mediterranean/other",
  "prepTimeMinutes": 15,
  "cookTimeMinutes": 30,
  "difficulty": "easy/medium/hard",
  "servings": 4,
  "ingredients": [
    {"name": "ingredient name", "quantity": 2.0, "unit": "cups"},
    {"name": "another ingredient", "quantity": 1.0, "unit": "tbsp"}
  ],
  "instructions": [
    "Step 1: Do this first",
    "Step 2: Then do this",
    "Step 3: Continue with this"
  ]
}

IMPORTANT:
- Extract ALL ingredients mentioned with their quantities
- Create clear, numbered step-by-step instructions
- If exact quantities aren't mentioned, make reasonable estimates
- If this doesn't appear to be a cooking video, still try to identify any recipe content
- Use standard cooking measurements (cups, tbsp, tsp, oz, lb, g, ml, etc.)''';

    return _callGptForRecipe(prompt, videoInfo);
  }

  /// Extract recipe using GPT-4o Vision (fallback when no transcript)
  Future<Recipe> _extractRecipeFromVision(VideoInfo videoInfo) async {
    _updateStatus(VideoProcessingStatus.analyzingContent);

    // Fetch thumbnail image
    final thumbnailUrl = videoInfo.highQualityThumbnail;
    String? thumbnailBase64;

    try {
      final response = await http.get(Uri.parse(thumbnailUrl));
      if (response.statusCode == 200) {
        thumbnailBase64 = base64Encode(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Error fetching thumbnail: $e');
    }

    // If we couldn't get the thumbnail, try standard quality
    if (thumbnailBase64 == null) {
      try {
        final response = await http.get(Uri.parse(videoInfo.standardThumbnail));
        if (response.statusCode == 200) {
          thumbnailBase64 = base64Encode(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error fetching standard thumbnail: $e');
      }
    }

    // Build content items with proper object format for image_url
    final contentItems = <Map<String, dynamic>>[];

    // Add text prompt
    contentItems.add({
      'type': 'text',
      'text': '''You are a recipe extraction assistant. This is a cooking video without available transcript. 
Analyze the video thumbnail and metadata to extract or infer the recipe.

VIDEO TITLE: ${videoInfo.title}

VIDEO DESCRIPTION: ${videoInfo.description ?? 'Not available'}

CHANNEL: ${videoInfo.channelName ?? 'Unknown'}

Based on the video title, description, thumbnail, and your knowledge of cooking, extract or create a reasonable recipe.

Respond with ONLY a JSON object in this exact format:
{
  "name": "Recipe name",
  "description": "Brief 1-2 sentence description",
  "cuisineType": "italian/mexican/chinese/indian/american/french/thai/mediterranean/other",
  "prepTimeMinutes": 15,
  "cookTimeMinutes": 30,
  "difficulty": "easy/medium/hard",
  "servings": 4,
  "ingredients": [
    {"name": "ingredient name", "quantity": 2.0, "unit": "cups"},
    {"name": "another ingredient", "quantity": 1.0, "unit": "tbsp"}
  ],
  "instructions": [
    "Step 1: Do this first",
    "Step 2: Then do this"
  ]
}

NOTE: Since there's no transcript, use the video title and thumbnail to infer what the recipe likely contains. Make reasonable assumptions based on common recipes.''',
    });

    // Add thumbnail if available with proper object format
    if (thumbnailBase64 != null) {
      contentItems.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,$thumbnailBase64',
          'detail': 'auto',
        },
      });
    }

    // Make direct HTTP request to ensure proper format
    final response = await http.post(
      Uri.parse('$_openAiBaseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': contentItems,
          }
        ],
        'max_tokens': 2000,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'API request failed');
    }

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('No response from AI');
    }

    return _parseRecipeJson(content, videoInfo);
  }

  /// Call GPT for recipe extraction (text-only)
  Future<Recipe> _callGptForRecipe(String prompt, VideoInfo videoInfo) async {
    final response = await http.post(
      Uri.parse('$_openAiBaseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': 2000,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'API request failed');
    }

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('No response from AI');
    }

    return _parseRecipeJson(content, videoInfo);
  }

  /// Parse the JSON response into a Recipe object
  Recipe _parseRecipeJson(String text, VideoInfo videoInfo) {
    _updateStatus(VideoProcessingStatus.parsingRecipe);

    final jsonStr = _extractJson(text);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // Parse ingredients
    final ingredientsList = data['ingredients'] as List<dynamic>? ?? [];
    final ingredients = ingredientsList.map((ing) {
      if (ing is Map<String, dynamic>) {
        return RecipeIngredient(
          name: ing['name'] ?? '',
          quantity: (ing['quantity'] ?? 0).toDouble(),
          unit: ing['unit'] ?? '',
          isAvailable: true, // User doesn't have ingredients from video
        );
      }
      return RecipeIngredient(name: ing.toString(), quantity: 0, unit: '');
    }).toList();

    // Parse instructions
    final instructionsList = data['instructions'] as List<dynamic>? ?? [];
    final instructions = instructionsList.map((i) => i.toString()).toList();

    return Recipe(
      id: 'video_${videoInfo.videoId}_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] ?? videoInfo.title,
      description: data['description'] ?? '',
      cuisineType: data['cuisineType'] ?? 'other',
      prepTimeMinutes: data['prepTimeMinutes'] ?? 15,
      cookTimeMinutes: data['cookTimeMinutes'] ?? 30,
      difficulty: data['difficulty'] ?? 'medium',
      servings: data['servings'] ?? 4,
      ingredients: ingredients,
      instructions: instructions,
      matchPercentage: 100, // N/A for video recipes
      missingIngredients: [], // User needs to determine this
      imageUrl: videoInfo.highQualityThumbnail,
    );
  }

  /// Extract JSON from a response that might contain markdown or other text
  String _extractJson(String text) {
    // Try to find JSON in markdown code blocks
    final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final codeBlockMatch = codeBlockPattern.firstMatch(text);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)?.trim() ?? text;
    }

    // Try to find JSON object directly
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(0) ?? text;
    }

    return text;
  }

  /// Update processing status
  void _updateStatus(VideoProcessingStatus status) {
    debugPrint('Video processing: ${status.message}');
    onStatusUpdate?.call(status);
  }

  /// Validate if a URL is a valid YouTube URL
  bool isValidYouTubeUrl(String url) {
    return _extractVideoId(url) != null;
  }

  /// Dispose resources
  void dispose() {
    _yt.close();
  }
}
