import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:reminder/services/api_service.dart';

class OffersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final ApiService _apiService =
      ApiService(); // إضافة ApiService للتحقق من حالة الاشتراك

  OffersScreen({super.key, required this.plans});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Subscription Plan'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            print('Plan data: $plan');
            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['name']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan['description']?.toString() ??
                          'No description available',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Available Variants:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display Variants
                    ...?plan['variants']?.map<Widget>((variant) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${variant['name']} (${variant['duration']})',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '\$${variant['price']?.toStringAsFixed(2) ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })?.toList() ??
                        [
                          const Text('No variants available',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14))
                        ],
                    const SizedBox(height: 16),
                    Text(
                      'Advanced Features: ${plan['has_advanced_features'] == true ? "Yes" : "No"}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (plan['checkout_url'] != null) {
                          // الانتقال إلى PaymentWebViewScreen
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentWebViewScreen(
                                checkoutUrl: plan['checkout_url'].toString(),
                              ),
                            ),
                          );

                          // بعد العودة من PaymentWebViewScreen، تحقق من حالة الاشتراك
                          try {
                            final data = await _apiService.checkSubscription();
                            if (data['subscribed'] == true) {
                              print(
                                  'User is subscribed, redirecting to RemindersScreen');
                              Navigator.pushReplacementNamed(
                                  context, '/reminders');
                            } else {
                              print('User is not subscribed after payment');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Payment failed or subscription not confirmed.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error checking subscription status: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Could not verify subscription status.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Checkout URL not available for this plan.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Subscribe Now'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;

  const PaymentWebViewScreen({super.key, required this.checkoutUrl});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  @override
  void initState() {
    super.initState();
    print(
        'PaymentWebViewScreen initState called with URL: ${widget.checkoutUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // عند الضغط على زر الرجوع، أغلق الـ WebView وعد إلى OffersScreen
        print('Back button pressed, closing WebView');
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Subscription'),
          backgroundColor: Colors.black,
          automaticallyImplyLeading: true, // زر الرجوع
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
          ),
          onLoadStart: (controller, url) {
            if (url != null) {
              print('onLoadStart: $url');
              if (url.toString().contains('/success')) {
                print('Payment success detected, closing WebView');
                Navigator.pop(context);
              }
            }
          },
          onLoadStop: (controller, url) {
            if (url != null) {
              print('onLoadStop: $url');
              if (url.toString().contains('/success')) {
                print('Payment success detected, closing WebView');
                Navigator.pop(context);
              }
            }
          },
          onUpdateVisitedHistory: (controller, url, androidIsReload) {
            if (url != null) {
              print('onUpdateVisitedHistory: $url');
              if (url.toString().contains('/success')) {
                print('Payment success detected, closing WebView');
                Navigator.pop(context);
              }
            }
          },
          onLoadError: (controller, url, code, message) {
            print('Load error: $message');
          },
        ),
      ),
    );
  }
}
