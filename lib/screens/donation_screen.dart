import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donations Page',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Image
              Image.asset(
                'assets/images/adoptlyHeader_Donate.png',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Support Animal Welfare Organizations',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your contribution helps provide food, shelter, and medical care for animals in need.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // NGO List Header
                    Text(
                      'Partner NGOs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NGO 1: Yayasan Kebajikan Haiwan Kebangsaan Malaysia
                    _buildNGOCard(
                      context: context,
                      title: 'Yayasan Kebajikan Haiwan Kebangsaan Malaysia',
                      subtitle: 'Malaysian National Animal Welfare Foundation',
                      logoPath:
                          'assets/images/ngo_logo/yayasanKebajikanHaiwanKebangsaanMalaysia_Logo.png',
                      description:
                          'A national-level foundation established in 1998 to promote animal welfare across Malaysia. They run awareness, education and spay/neuter programs, encourage adoption from shelters instead of buying pets, and coordinate with other organisations and public agencies.',
                      qrCodePath:
                          'assets/images/ngo_logo/yayasanKebajikanHaiwanKebangsaanMalaysia_QR.png',
                      websiteUrl: 'https://mnawf.org.my/Donate/',
                    ),

                    const SizedBox(height: 12),

                    // NGO 2: PAWS Animal Welfare Society
                    _buildNGOCard(
                      context: context,
                      title: 'PAWS Animal Welfare Society',
                      subtitle: 'Persatuan Kebajikan Haiwan PAWS',
                      logoPath: 'assets/images/ngo_logo/PAWS_Logo.png',
                      description:
                          'Based in Petaling Jaya. They rescue unwanted or stray dogs and cats; animals are dewormed, vaccinated, neutered/spayed, then put up for adoption.',
                      qrCodePath:
                          'assets/images/ngo_logo/PAWS_DirectBankInQr.jpg',
                      websiteUrl: 'https://www.paws.org.my/donate/',
                      qrCodeLabel: 'Direct Bank Transfer',
                      qrCodeDescription:
                          'Scan QR code for direct bank transfer',
                    ),

                    const SizedBox(height: 12),

                    // NGO 3: Second Chance Animal Society
                    _buildNGOCard(
                      context: context,
                      title: 'Second Chance Animal Society',
                      subtitle: 'SCAS Malaysia',
                      logoPath:
                          'assets/images/ngo_logo/secondchanceAnimal_Logo.jpg',
                      description:
                          'Shelter located in Cheras, Hulu Langat, Selangor. Focus on rescuing stray dogs (injured, abused, abandoned) and rehoming them once healthy.',
                      websiteUrl: 'https://www.facebook.com/scasmalaysia/',
                    ),

                    const SizedBox(height: 12),

                    // NGO 4: ISPCA
                    _buildNGOCard(
                      context: context,
                      title: 'ISPCA',
                      subtitle:
                          'Ipoh Society for the Prevention of Cruelty to Animals',
                      logoPath: 'assets/images/ngo_logo/ISPCA_Logo.png',
                      description:
                          'Based in Ipoh; rescues and shelters dogs and cats, promotes adoption, and runs stray-rescue and awareness campaigns.',
                      websiteUrl: 'https://ispca.com.my/donation/',
                    ),

                    const SizedBox(height: 12),

                    // Placeholder for more NGOs
                    // Add more _buildNGOCard widgets here as needed
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNGOCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String logoPath,
    required String description,
    String? qrCodePath,
    required String websiteUrl,
    String qrCodeLabel = 'Visit Website',
    String qrCodeDescription = 'Scan QR code to visit their website',
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              logoPath,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'About',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 20),

                  // QR Code Section (only show if QR code is provided)
                  if (qrCodePath != null)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            qrCodeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                                width: 2,
                              ),
                            ),
                            child: Image.asset(
                              qrCodePath,
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            qrCodeDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                  // Donate Button Section
                  Center(
                    child: Column(
                      children: [
                        // Donate Button (only show if websiteUrl is provided)
                        if (websiteUrl.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final Uri url = Uri.parse(websiteUrl);
                                if (!await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open website'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text(
                                'Visit Donation Page',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                      ],
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
