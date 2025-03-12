import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:reminder/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'dart:ui' as ui;

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _subscriptionData;
  String? _customerPortalUrl;
  bool _isLoading = true;
  String? _error;
  String _language = 'en'; // Default language

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setLanguage();
  }

  void _setLanguage() {
    setState(() {
      _language = Localizations.localeOf(context).languageCode;
    });
  }

  Future<void> _loadInitialData() async {
    print('Loading initial data...');
    await Future.wait([
      _loadSubscriptionData(),
      _loadCustomerPortalUrl(),
    ]);
    print('Subscription data: $_subscriptionData');
  }

  Future<void> _loadSubscriptionData() async {
    try {
      setState(() => _isLoading = true);
      final data = await _apiService.checkSubscription();
      setState(() {
        _subscriptionData = data;
        _isLoading = false;
      });
    } catch (e) {
      _handleError(
          e,
          _language == 'ar'
              ? 'خطأ في تحميل بيانات الاشتراك'
              : 'Error loading subscription data');
    }
  }

  Future<void> _loadCustomerPortalUrl() async {
    try {
      final url = await _apiService.getCustomerPortalUrl();
      setState(() => _customerPortalUrl = url);
    } catch (e) {
      _handleError(
          e,
          _language == 'ar'
              ? 'خطأ في تحميل رابط بوابة العميل'
              : 'Error loading customer portal URL');
    }
  }

  void _handleError(dynamic e, String message) {
    print('$message: $e');
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
    if (e.toString().contains('401')) {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  bool isSubscribed() {
    return _subscriptionData != null &&
        _subscriptionData!['subscribed'] == true &&
        _subscriptionData!['subscription'] != null;
  }

  bool isPaused() {
    return _subscriptionData != null &&
        _subscriptionData!['subscription'] != null &&
        _subscriptionData!['subscription']['status'] == 'paused';
  }

  int? getPausedVariantId() {
    if (!isPaused()) return null;
    final variants =
        _subscriptionData!['subscription']['variants'] as Map<String, dynamic>;
    final pausedVariant = variants.values.firstWhere(
      (variant) => variant['variant_status'] == 'paused',
      orElse: () => null,
    );
    return pausedVariant != null ? pausedVariant['id'] : null;
  }

  Future<void> _changeOffer(String checkoutUrl) async {
    try {
      setState(() => _isLoading = true);
      final response = await http
          .get(Uri.parse(checkoutUrl), headers: {'Accept': 'application/json'});

      await Future.wait([
        _loadSubscriptionData(),
        _loadCustomerPortalUrl(),
      ]);

      _showSnackBar(_language == 'ar'
          ? 'تم تغيير العرض بنجاح'
          : 'Offer changed successfully');
    } catch (e) {
      _handleError(
          e, _language == 'ar' ? 'خطأ في تغيير العرض' : 'Error changing offer');
      _showSnackBar(_language == 'ar'
          ? 'فشل تغيير العرض: $e'
          : 'Failed to change offer: $e');
    }
  }

  Future<void> _pauseSubscription() async {
    await _handleSubscriptionAction(
      'https://purple-zebra-199646.hostingersite.com/api/subscription/pause',
      _language == 'ar'
          ? 'تم إيقاف الاشتراك بنجاح'
          : 'Subscription paused successfully',
      _language == 'ar'
          ? 'خطأ في إيقاف الاشتراك'
          : 'Error pausing subscription',
    );
  }

  Future<void> _cancelSubscription() async {
    await _handleSubscriptionAction(
      'https://purple-zebra-199646.hostingersite.com/api/subscription/cancel',
      _language == 'ar'
          ? 'تم إلغاء الاشتراك بنجاح'
          : 'Subscription cancelled successfully',
      _language == 'ar'
          ? 'خطأ في إلغاء الاشتراك'
          : 'Error cancelling subscription',
    );
  }

  Future<void> _resumeSubscription() async {
    await _handleSubscriptionAction(
      'https://purple-zebra-199646.hostingersite.com/api/subscription/resume',
      _language == 'ar'
          ? 'تم استئناف الاشتراك بنجاح'
          : 'Subscription resumed successfully',
      _language == 'ar'
          ? 'خطأ في استئناف الاشتراك'
          : 'Error resuming subscription',
    );
  }

  Future<void> _handleSubscriptionAction(
      String url, String successMessage, String errorMessage) async {
    try {
      setState(() => _isLoading = true);
      final token = await _apiService.getToken();
      if (token == null)
        throw Exception(_language == 'ar'
            ? 'لم يتم العثور على رمز المصادقة'
            : 'No authentication token found');

      final response = await http.post(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        await Future.wait([
          _loadSubscriptionData(),
          _loadCustomerPortalUrl(),
        ]);
        _showSnackBar(successMessage);
      } else {
        throw Exception('Failed: ${response.body}');
      }
    } catch (e) {
      _handleError(e, errorMessage);
      _showSnackBar('$errorMessage: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  ui.TextDirection _getTextDirection() {
    return _language == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr;
  }

  void _showVariantsModal(BuildContext context, Map<String, dynamic> planData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: _getTextDirection(),
          child: _buildVariantsModalContent(planData),
        );
      },
    );
  }

  Widget _buildVariantsModalContent(Map<String, dynamic> planData) {
    final variants = _extractVariants(planData);
    final isUserSubscribed = isSubscribed();
    final isPausedSubscription = isPaused();
    final pausedVariantId = getPausedVariantId();
    final isCurrentSubscription = planData.containsKey('status');
    final planName = isCurrentSubscription
        ? planData['plan']['name'] ?? 'Unnamed Plan'
        : planData['name'] ?? 'Unnamed Plan';
    final planDescription = isCurrentSubscription
        ? planData['plan']['description']
        : planData['description'];
    final hasAdvancedFeatures = isCurrentSubscription
        ? planData['plan']['has_advanced_features'] == true
        : planData['has_advanced_features'] == true;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _language == 'ar'
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              planName,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isCurrentSubscription)
              Text(
                _language == 'ar'
                    ? 'الحالة: ${planData['status'].toUpperCase()}'
                    : 'Status: ${planData['status'].toUpperCase()}',
                style: TextStyle(
                  color: planData['status'] == 'active'
                      ? Colors.green[700]
                      : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 16),
            planDescription != null
                ? Html(
                    data: planDescription,
                    style: {
                      "body": Style(
                        fontSize: FontSize(14),
                        color: Colors.black54,
                      ),
                      "li": Style(
                        margin: Margins.only(bottom: 4),
                      ),
                    },
                  )
                : Text(
                    _language == 'ar'
                        ? 'لا يوجد وصف متاح'
                        : 'No description available',
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
            const SizedBox(height: 16),
            Text(
              _language == 'ar'
                  ? 'الميزات المتقدمة: ${hasAdvancedFeatures ? 'نعم' : 'لا'}'
                  : 'Advanced Features: ${hasAdvancedFeatures ? 'Yes' : 'No'}',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              _language == 'ar' ? 'الخيارات:' : 'Variants:',
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            variants.isEmpty
                ? Text(
                    _language == 'ar'
                        ? 'لا توجد خيارات متاحة'
                        : 'No variants available',
                    style: const TextStyle(color: Colors.black54),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: variants.length,
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final isPausedVariant = isPausedSubscription &&
                          variant['id'] == pausedVariantId;
                      return _buildVariantCard(
                          variant, isUserSubscribed, isPausedVariant);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _extractVariants(Map<String, dynamic> planData) {
    try {
      return planData['variants'] is Map<String, dynamic>
          ? (planData['variants'] as Map<String, dynamic>).values.toList()
          : planData['variants'] as List<dynamic> ?? [];
    } catch (e) {
      print('Error accessing variants: $e');
      _showSnackBar(_language == 'ar'
          ? 'خطأ في تحميل الخيارات: $e'
          : 'Error loading variants: $e');
      return [];
    }
  }

  Widget _buildVariantCard(
      dynamic variant, bool isUserSubscribed, bool isPausedVariant) {
    return Card(
      color: Colors.grey[100],
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          print('Tapped on variant: ${variant['name']}');
          _showVariantsModal(context,
              {'name': variant['name'], 'description': variant['description']});
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: _language == 'ar'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                _language == 'ar'
                    ? 'الاسم: ${variant['name']}'
                    : 'Name: ${variant['name']}',
                style: const TextStyle(color: Colors.black),
              ),
              variant['description'] != null
                  ? Html(
                      data: variant['description'],
                      style: {
                        "body": Style(
                          fontSize: FontSize(14),
                          color: Colors.black54,
                        ),
                      },
                    )
                  : Text(
                      _language == 'ar' ? 'لا يوجد وصف' : 'No description',
                      style: const TextStyle(color: Colors.black54),
                    ),
              Text(
                _language == 'ar'
                    ? 'السعر: \$${variant['price'].toStringAsFixed(2)}'
                    : 'Price: \$${variant['price'].toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black54),
              ),
              Text(
                _language == 'ar'
                    ? 'المدة: ${variant['duration']}'
                    : 'Duration: ${variant['duration']}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (isPausedVariant) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                        _language == 'ar' ? 'استئناف الخطة' : 'Resume Plan',
                        Colors.green[400], () async {
                      await _resumeSubscription();
                      Navigator.pop(context);
                    }),
                    _buildActionButton(
                        _language == 'ar' ? 'إلغاء الخطة' : 'Cancel Plan',
                        Colors.red[400], () async {
                      await _cancelSubscription();
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ] else ...[
                _buildActionButton(
                  isUserSubscribed
                      ? (_language == 'ar' ? 'تغيير العرض' : 'Change Offer')
                      : (_language == 'ar' ? 'الاشتراك' : 'Subscribe'),
                  Colors.blue[700],
                  () async {
                    if (isUserSubscribed) {
                      await _changeOffer(variant['checkout_url']);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WebViewScreen(url: variant['checkout_url'])),
                      );
                    }
                    await Future.wait([
                      _loadSubscriptionData(),
                      _loadCustomerPortalUrl(),
                    ]);
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color? color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _getTextDirection(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              _language == 'ar' ? 'إدارة الاشتراك' : 'Manage Subscription'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          elevation: 0.8,
        ),
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                        _language == 'ar' ? 'خطأ: $_error' : 'Error: $_error',
                        style: TextStyle(color: Colors.red[700])))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: _language == 'ar'
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          _buildSubscriptionStatus(),
                          if (_subscriptionData != null &&
                              _subscriptionData!['subscription'] != null)
                            _buildCurrentSubscription(),
                          _buildAvailablePlans(),
                          if (_customerPortalUrl != null)
                            _buildManageSubscriptionButton(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildSubscriptionStatus() {
    return Column(
      crossAxisAlignment:
          _language == 'ar' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _language == 'ar' ? 'حالة الاشتراك' : 'Subscription Status',
          style: const TextStyle(
              color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          _subscriptionData != null && _subscriptionData!['subscribed'] == true
              ? (_language == 'ar' ? 'أنت مشترك!' : 'You are subscribed!')
              : isPaused()
                  ? (_language == 'ar'
                      ? 'اشتراكك موقوف.'
                      : 'Your subscription is paused.')
                  : (_language == 'ar'
                      ? 'أنت غير مشترك.'
                      : 'You are not subscribed.'),
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCurrentSubscription() {
    final renewsAt = _subscriptionData!['subscription']['renews_at'] != null
        ? DateFormat('yyyy-MM-dd').format(
            DateTime.parse(_subscriptionData!['subscription']['renews_at']))
        : null;

    return Column(
      crossAxisAlignment:
          _language == 'ar' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _language == 'ar' ? 'الاشتراك الحالي' : 'Current Subscription',
          style: const TextStyle(
              color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            print('Tapped on current subscription');
            if (_subscriptionData != null &&
                _subscriptionData!['subscription'] != null) {
              _showVariantsModal(context, _subscriptionData!['subscription']);
            } else {
              _showSnackBar(_language == 'ar'
                  ? 'لا يوجد اشتراك حالي'
                  : 'No current subscription');
            }
          },
          child: Card(
            color: Colors.white,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: _language == 'ar'
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subscriptionData!['subscription']['plan']['name'] ??
                            'Unnamed Plan',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _language == 'ar'
                            ? 'الحالة: ${_subscriptionData!['subscription']['status']?.toUpperCase() ?? 'غير معروف'}'
                            : 'Status: ${_subscriptionData!['subscription']['status']?.toUpperCase() ?? 'Unknown'}',
                        style: TextStyle(
                          color: _subscriptionData!['subscription']['status'] ==
                                  'active'
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (renewsAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _language == 'ar'
                              ? 'يتجدد في: $renewsAt'
                              : 'Renews at: $renewsAt',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  _buildSubscriptionMenu(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSubscriptionMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      color: Colors.white,
      elevation: 2,
      onSelected: (value) async {
        if (value == 'pause') {
          await _pauseSubscription();
        } else if (value == 'cancel') {
          await _cancelSubscription();
        } else if (value == 'resume') {
          await _resumeSubscription();
        }
      },
      itemBuilder: (BuildContext context) {
        if (isPaused()) {
          return [
            PopupMenuItem(
                value: 'resume',
                child: Text(_language == 'ar' ? 'استئناف الخطة' : 'Resume Plan',
                    style: const TextStyle(color: Colors.black87))),
            PopupMenuItem(
                value: 'cancel',
                child: Text(_language == 'ar' ? 'إلغاء الخطة' : 'Cancel Plan',
                    style: const TextStyle(color: Colors.black87))),
          ];
        } else {
          return [
            PopupMenuItem(
                value: 'pause',
                child: Text(_language == 'ar' ? 'إيقاف الخطة' : 'Pause Plan',
                    style: const TextStyle(color: Colors.black87))),
            PopupMenuItem(
                value: 'cancel',
                child: Text(_language == 'ar' ? 'إلغاء الخطة' : 'Cancel Plan',
                    style: const TextStyle(color: Colors.black87))),
          ];
        }
      },
    );
  }

  Widget _buildAvailablePlans() {
    return Column(
      crossAxisAlignment:
          _language == 'ar' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _language == 'ar' ? 'الخطط المتاحة' : 'Available Plans',
          style: const TextStyle(
              color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_subscriptionData != null && _subscriptionData!['plans'] != null)
          ...(_subscriptionData!['plans'] as List<dynamic>).map<Widget>((plan) {
            return GestureDetector(
              onTap: () {
                print('Tapped on plan: ${plan['name']}');
                _showVariantsModal(context, plan);
              },
              child: Card(
                color: Colors.white,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: _language == 'ar'
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] ?? 'Unnamed Plan',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      plan['description'] != null
                          ? Html(
                              data: plan['description'],
                              style: {
                                "body": Style(
                                  fontSize: FontSize(14),
                                  color: Colors.black54,
                                ),
                                "li": Style(
                                  margin: Margins.only(bottom: 4),
                                ),
                              },
                            )
                          : Text(
                              _language == 'ar'
                                  ? 'لا يوجد وصف متاح'
                                  : 'No description available',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 14),
                            ),
                    ],
                  ),
                ),
              ),
            );
          }).toList()
        else
          Text(
            _language == 'ar'
                ? 'لا توجد خطط متاحة حاليًا'
                : 'No plans available at the moment',
            style: const TextStyle(color: Colors.black54),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildManageSubscriptionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WebViewScreen(url: _customerPortalUrl!)),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        child: Text(
            _language == 'ar' ? 'إدارة الاشتراك' : 'Manage Subscription',
            style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class WebViewScreen extends StatelessWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0.8,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          javaScriptCanOpenWindowsAutomatically: true,
        ),
        onLoadStart: (controller, url) => print('Loading: $url'),
        onLoadStop: (controller, url) => print('Loaded: $url'),
        onLoadError: (controller, url, code, message) =>
            print('Load error: $message'),
      ),
    );
  }
}
