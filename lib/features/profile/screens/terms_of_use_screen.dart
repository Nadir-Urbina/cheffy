import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

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
          'Terms of Use',
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
              'Please read these Terms of Use ("Terms") carefully before using the My Chefsito mobile '
              'application ("App") operated by Turbina Apps ("we", "us", or "our").',
            ),

            _buildSectionTitle('Acceptance of Terms'),
            _buildParagraph(
              'By downloading, installing, or using the App, you agree to be bound by these Terms. '
              'If you do not agree, do not use the App.',
            ),

            _buildSectionTitle('Description of Service'),
            _buildParagraph(
              'My Chefsito is a cooking companion app that helps users discover recipes, scan ingredients, '
              'extract recipes from videos, and provides step-by-step cooking guidance with voice control.',
            ),

            _buildSectionTitle('Account Registration'),
            _buildParagraph(
              'You must create an account to use the App. You are responsible for maintaining the '
              'confidentiality of your account credentials and for all activities under your account.',
            ),

            _buildSectionTitle('Subscriptions and Payments'),

            _buildSubsectionTitle('Free Features'),
            _buildParagraph(
              'Recipe search, browsing, and chat-based ingredient suggestions are available at no cost.',
            ),

            _buildSubsectionTitle('Chefsito Pro'),
            _buildParagraph(
              'Premium features require an active subscription. Subscription options include:',
            ),
            _buildBullet('Monthly: \$5.99 USD per month'),
            _buildBullet('Yearly: \$39.99 USD per year'),
            const SizedBox(height: 8),
            _buildParagraph(
              'Both plans include a 7-day free trial for new subscribers.',
            ),

            _buildSubsectionTitle('Billing'),
            _buildParagraph(
              'Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions '
              'automatically renew unless canceled at least 24 hours before the end of the current billing '
              'period. You can manage or cancel your subscription at any time in your Apple ID account settings.',
            ),

            _buildSubsectionTitle('Refunds'),
            _buildParagraph(
              'Refund requests are handled by Apple in accordance with their refund policies.',
            ),

            _buildSectionTitle('Acceptable Use'),
            _buildParagraph('You agree not to:'),
            _buildBullet('Use the App for any unlawful purpose'),
            _buildBullet('Attempt to reverse engineer, decompile, or disassemble the App'),
            _buildBullet('Interfere with or disrupt the App\'s services or servers'),
            _buildBullet('Use the App to transmit harmful or malicious content'),
            _buildBullet('Create multiple accounts to abuse free trials'),

            _buildSectionTitle('Intellectual Property'),
            _buildParagraph(
              'The App, including its design, features, and content, is owned by Turbina Apps and protected '
              'by intellectual property laws. Recipe data is provided by third-party services and is subject '
              'to their respective terms.',
            ),

            _buildSectionTitle('AI-Generated Content'),
            _buildParagraph(
              'The App uses artificial intelligence to identify ingredients, generate recipe instructions, and '
              'provide cooking guidance. AI-generated content is provided for informational purposes and may not '
              'always be accurate. Always use your judgment when cooking, especially regarding food safety, '
              'allergies, and dietary restrictions.',
            ),

            _buildSectionTitle('Disclaimer of Warranties'),
            _buildParagraph(
              'The App is provided "as is" and "as available" without warranties of any kind. We do not '
              'guarantee that recipes, nutritional information, or AI-generated content will be accurate, '
              'complete, or suitable for your needs.',
            ),

            _buildSectionTitle('Limitation of Liability'),
            _buildParagraph(
              'To the maximum extent permitted by law, Turbina Apps shall not be liable for any indirect, '
              'incidental, special, or consequential damages arising from your use of the App, including but '
              'not limited to food allergies, dietary issues, or injuries related to cooking.',
            ),

            _buildSectionTitle('Termination'),
            _buildParagraph(
              'We reserve the right to suspend or terminate your account at our discretion if you violate '
              'these Terms. You may delete your account at any time through the App\'s settings.',
            ),

            _buildSectionTitle('Changes to Terms'),
            _buildParagraph(
              'We may update these Terms from time to time. Continued use of the App after changes '
              'constitutes acceptance of the updated Terms.',
            ),

            _buildSectionTitle('Governing Law'),
            _buildParagraph(
              'These Terms shall be governed by and construed in accordance with the laws of the United States, '
              'without regard to conflict of law principles.',
            ),

            _buildSectionTitle('Contact Us'),
            _buildParagraph(
              'If you have questions about these Terms, please contact us at support@turbinapps.com.',
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
