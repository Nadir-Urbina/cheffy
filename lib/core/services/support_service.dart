import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Types of support requests
enum SupportRequestType {
  question,
  issue,
  feedback,
  featureRequest,
  other,
}

extension SupportRequestTypeExtension on SupportRequestType {
  String get displayName {
    switch (this) {
      case SupportRequestType.question:
        return 'Question';
      case SupportRequestType.issue:
        return 'Issue / Bug';
      case SupportRequestType.feedback:
        return 'Feedback';
      case SupportRequestType.featureRequest:
        return 'Feature Request';
      case SupportRequestType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case SupportRequestType.question:
        return '❓';
      case SupportRequestType.issue:
        return '🐛';
      case SupportRequestType.feedback:
        return '💬';
      case SupportRequestType.featureRequest:
        return '💡';
      case SupportRequestType.other:
        return '📝';
    }
  }
}

/// Service for sending support requests via Resend
class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  static const String _resendApiUrl = 'https://api.resend.com/emails';
  static const String _supportEmail = 'contactform@turbinapps.com';
  
  // Using Resend's default sender for now - update when you have a custom domain
  static const String _fromEmail = 'My Chefsito <onboarding@resend.dev>';

  String get _apiKey => dotenv.env['RESEND_API_KEY'] ?? '';

  /// Send a support request email
  Future<SupportResult> sendSupportRequest({
    required String userEmail,
    required String userName,
    required SupportRequestType type,
    required String message,
  }) async {
    if (_apiKey.isEmpty) {
      debugPrint('❌ Resend API key not configured');
      return SupportResult.failure('Email service not configured');
    }

    try {
      final subject = '[My Chefsito] ${type.emoji} ${type.displayName} from $userName';
      
      final htmlBody = '''
<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <h2 style="color: #4CAF50; margin-top: 0;">New Support Request</h2>
    
    <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
      <tr>
        <td style="padding: 8px 0; color: #666; width: 120px;"><strong>Type:</strong></td>
        <td style="padding: 8px 0;">${type.emoji} ${type.displayName}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #666;"><strong>From:</strong></td>
        <td style="padding: 8px 0;">$userName</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #666;"><strong>Email:</strong></td>
        <td style="padding: 8px 0;"><a href="mailto:$userEmail" style="color: #4CAF50;">$userEmail</a></td>
      </tr>
    </table>
    
    <div style="background: #f9f9f9; border-radius: 8px; padding: 16px; margin-top: 16px;">
      <h3 style="margin-top: 0; color: #333;">Message:</h3>
      <p style="color: #444; line-height: 1.6; white-space: pre-wrap;">${_escapeHtml(message)}</p>
    </div>
    
    <p style="color: #999; font-size: 12px; margin-top: 24px; margin-bottom: 0;">
      Sent from My Chefsito App
    </p>
  </div>
</body>
</html>
''';

      final response = await http.post(
        Uri.parse(_resendApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': [_supportEmail],
          'reply_to': userEmail,
          'subject': subject,
          'html': htmlBody,
        }),
      );

      debugPrint('📧 Resend response: ${response.statusCode}');
      debugPrint('📧 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SupportResult.success();
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['message']?.toString() ?? 'Failed to send message';
        return SupportResult.failure(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Support email error: $e');
      return SupportResult.failure('Failed to send message. Please try again.');
    }
  }

  /// Escape HTML special characters
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

/// Result of a support request
class SupportResult {
  final bool success;
  final String? error;

  SupportResult.success()
      : success = true,
        error = null;

  SupportResult.failure(this.error) : success = false;
}
