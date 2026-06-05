import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/purchase_service.dart';
import '../storage.dart';
import '../utils/i18n.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selectedPlan = 'yearly'; // 'monthly' | 'yearly'
  bool _wasPremiumOnOpen = false;
  bool _isRestoring = false;
  bool _hasHandledPremium = false;

  String get _lang =>
      Storage.txBox.get('selectedLanguage', defaultValue: 'en') as String;

  @override
  void initState() {
    super.initState();
    _wasPremiumOnOpen = context.read<PurchaseService>().isPremium;
  }

  Future<void> _handleRestore(PurchaseService svc) async {
    setState(() => _isRestoring = true);
    await svc.restorePurchases();

    // Give the purchase stream up to 5 seconds to deliver restored purchases
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (svc.isPremium) break;
    }

    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (!svc.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('paywall_nothing_to_restore', _lang))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseService>(
      builder: (context, svc, _) {
        // Auto-close after successful purchase/restore (한 번만 실행)
        if (!_wasPremiumOnOpen && svc.isPremium && !_hasHandledPremium) {
          _hasHandledPremium = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('paywall_purchase_success', _lang)),
              ),
            );
            Navigator.of(context).pop();
          });
        }

        // Show error if any (errorMessage를 로컬에 캡처해 콜백 실행 시점의 null 방지)
        if (svc.errorMessage != null) {
          final errorMsg = svc.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            svc.clearError();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
          });
        }

        final monthly = svc.monthlyProduct;
        final yearly = svc.yearlyProduct;
        final monthlyPrice = monthly?.price ?? '\$1.99';
        final yearlyPrice = yearly?.price ?? '\$9.99';
        final selectedProduct = _selectedPlan == 'yearly' ? yearly : monthly;
        final primary = Theme.of(context).colorScheme.primary;

        return Scaffold(
          appBar: AppBar(
            title: Text(t('paywall_title', _lang)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (svc.isLoading || _isRestoring)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Header
                  _Header(lang: _lang, primary: primary),
                  const SizedBox(height: 24),

                  // Plan selector
                  _PlanSelector(
                    lang: _lang,
                    selectedPlan: _selectedPlan,
                    monthlyPrice: monthlyPrice,
                    yearlyPrice: yearlyPrice,
                    primary: primary,
                    onChanged: (v) => setState(() => _selectedPlan = v),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  _FeatureList(lang: _lang, primary: primary),
                  const SizedBox(height: 28),

                  // Subscribe button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (svc.isLoading || _isRestoring)
                          ? null
                          : () async {
                              if (selectedProduct == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t('paywall_unavailable', _lang),
                                    ),
                                  ),
                                );
                                return;
                              }
                              await svc.buy(selectedProduct);
                            },
                      child: Text(
                        t('paywall_subscribe', _lang),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Restore button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: (svc.isLoading || _isRestoring)
                          ? null
                          : () => _handleRestore(svc),
                      child: Text(t('paywall_restore', _lang)),
                    ),
                  ),

                  // Later button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        t('paywall_later', _lang),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Legal
                  Column(
                    children: [
                      Text(
                        t('paywall_terms', _lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://momoy07.github.io/doni-money/terms.html');
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            },
                            child: Text(
                              'Terms of Use',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://momoy07.github.io/doni-money/privacy_policy.html');
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            },
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String lang;
  final Color primary;

  const _Header({required this.lang, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: primary.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 15, color: primary),
              const SizedBox(width: 4),
              Text(
                'PREMIUM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t('paywall_subtitle', lang),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Plan Selector ───────────────────────────────────────────────────────────

class _PlanSelector extends StatelessWidget {
  final String lang;
  final String selectedPlan;
  final String monthlyPrice;
  final String yearlyPrice;
  final Color primary;
  final ValueChanged<String> onChanged;

  const _PlanSelector({
    required this.lang,
    required this.selectedPlan,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanCard(
          lang: lang,
          planId: 'monthly',
          price: monthlyPrice,
          perLabel: t('paywall_per_month', lang),
          isSelected: selectedPlan == 'monthly',
          primary: primary,
          onTap: () => onChanged('monthly'),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          lang: lang,
          planId: 'yearly',
          price: yearlyPrice,
          perLabel: t('paywall_per_year', lang),
          isSelected: selectedPlan == 'yearly',
          primary: primary,
          badge: t('paywall_best_value', lang),
          onTap: () => onChanged('yearly'),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String lang;
  final String planId; // 'monthly' | 'yearly' | 'lifetime'
  final String price;
  final String perLabel;
  final bool isSelected;
  final Color primary;
  final String? badge;
  final VoidCallback onTap;

  const _PlanCard({
    required this.lang,
    required this.planId,
    required this.price,
    required this.perLabel,
    required this.isSelected,
    required this.primary,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primary.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : const Color(0xFFD9E4EE),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primary : const Color(0xFFBBCDD9),
                  width: 2,
                ),
                color: isSelected ? primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                planId == 'yearly'
                    ? t('paywall_yearly_label', lang)
                    : t('paywall_monthly_label', lang),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: perLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(140),
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

// ─── Feature List ────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  final String lang;
  final Color primary;

  const _FeatureList({required this.lang, required this.primary});

  @override
  Widget build(BuildContext context) {
    final features = [
      t('paywall_feature_themes', lang),
      t('paywall_feature_no_ads', lang),
      t('paywall_feature_backup', lang),
      t('paywall_feature_csv', lang),
      t('paywall_feature_recurring', lang),
      t('paywall_feature_categories', lang),
      t('paywall_feature_cloud', lang),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withAlpha(40)),
      ),
      child: Column(
        children: features
            .map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
