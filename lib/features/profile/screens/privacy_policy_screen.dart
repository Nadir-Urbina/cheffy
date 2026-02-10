import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated('February 10, 2026'),
            const SizedBox(height: 20),
            _buildParagraph(
              'Turbina Apps ("we", "us", or "our") operates the My Chefsito mobile application (the "App"). '
              'This Privacy Policy explains how we collect, use, and protect your information.',
            ),

            _buildSectionTitle('Information We Collect'),

            _buildSubsectionTitle('Account Information'),
            _buildParagraph(
              'When you create an account, we collect your name, email address, and profile photo (optional). '
              'You may sign in using email/password, Google Sign-In, or Sign in with Apple.',
            ),

            _buildSubsectionTitle('Usage Data'),
            _buildParagraph(
              'We collect information about how you use the App, including recipes viewed, cooking history, '
              'meal plans, and dietary preferences. This data is used to personalize your experience.',
            ),

            _buildSubsectionTitle('Camera and Photos'),
            _buildParagraph(
              'When you use the ingredient scanning feature, photos are sent to OpenAI\'s API for ingredient '
              'recognition. Photos are processed in real-time and are not stored on our servers.',
            ),

            _buildSubsectionTitle('Microphone and Voice'),
            _buildParagraph(
              'When you use Conversational Mode during cooking, voice audio is processed locally on your device '
              'using Apple\'s Speech Recognition framework. Voice data is not sent to our servers.',
            ),

            _buildSubsectionTitle('Location'),
            _buildParagraph(
              'We request location access solely to find nearby grocery retailers for the Instacart shopping '
              'integration. Location data is not stored.',
            ),

            _buildSectionTitle('Third-Party Services'),
            _buildParagraph(
              'The App uses the following third-party services, each with their own privacy policies:',
            ),
            const SizedBox(height: 8),
            _buildBullet('Firebase (Google) — Authentication, database, and file storage.'),
            _buildBullet('OpenAI — AI-powered ingredient recognition, recipe generation, and text-to-speech.'),
            _buildBullet('Spoonacular — Recipe database and nutrition information.'),
            _buildBullet('Instacart — Grocery shopping integration.'),
            _buildBullet('RevenueCat — Subscription management.'),

            _buildSectionTitle('Data Storage and Security'),
            _buildParagraph(
              'Your account data is stored securely in Google Firebase with encryption in transit and at rest. '
              'We do not sell, trade, or share your personal information with third parties for marketing purposes.',
            ),

            _buildSectionTitle('Subscriptions'),
            _buildParagraph(
              'My Chefsito offers auto-renewable subscriptions managed through Apple\'s App Store. Payment is '
              'processed by Apple and we do not have access to your payment information. You can manage or cancel '
              'your subscription at any time through your Apple ID settings.',
            ),

            _buildSectionTitle('Data Deletion'),
            _buildParagraph(
              'You can delete your account and all associated data at any time from Settings > Delete Account '
              'in the App. Account deletion is processed within 30 days.',
            ),

            _buildSectionTitle('Children\'s Privacy'),
            _buildParagraph(
              'The App is not directed to children under 13. We do not knowingly collect personal information '
              'from children under 13.',
            ),

            _buildSectionTitle('Changes to This Policy'),
            _buildParagraph(
              'We may update this Privacy Policy from time to time. We will notify you of any changes by '
              'posting the new policy in the App.',
            ),

            _buildSectionTitle('Contact Us'),
            _buildParagraph(
              'If you have questions about this Privacy Policy, please contact us at support@turbinapps.com.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(String date) {
    return Text(
      'Last updated: $date',
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
