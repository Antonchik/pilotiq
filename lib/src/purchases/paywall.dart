import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Paywall extends ConsumerWidget {
  const Paywall({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(linkFiveProvider);
    final local = AppLocalizations.of(context)!;
    return PaywallScaffold(
      appBarTitle: "Premium",
      child: SimplePaywall(
        callbackInterface: data.callbackInterface,
        subscriptionListData: data.paywallUIHelperData(context),
        headerContainer: Card(
          elevation: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon/paywall_banner.png',
              fit: BoxFit.fitHeight,
            ),
          ),
        ),
        title: local.goPremiumLabel,
        // SubTitle
        subTitle: local.featuresDescriptionTitle,
        // Add as many bullet points as you like
        bulletPoints: [
          IconAndText(Icons.new_releases_outlined, local.allExamsAccessLabel),
          IconAndText(Icons.subject, local.allSubjectsAccessLabel),
          // IconAndText(Icons.dark_mode_outlined, local.darkModeAccessLabel)
        ],
        // Shown if isPurchaseSuccess == true
        successTitle: local.premiumUserGreeting,
        // Shown if isPurchaseSuccess == true
        successSubTitle: local.thankYouMessage,
        // Widget can be anything. Shown if isPurchaseSuccess == true
        successWidget: Container(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(
                child: Text(local.letsGoMessage),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            ])),
        activePlanList: [
          if (Platform.isAndroid)
            GooglePlayGeneralActivePlan()
          else
            AppleAppStoreActivePlan(),
        ],
        // tosData: TextAndUrl("Terms of Service", "https://www.linkfive.io/tos"),
        // provide your PP
        ppData: TextAndUrl(local.privacyPolicyLabel,
            "https://www.termsfeed.com/live/da031152-c5f9-4dd0-a4e6-42d78de414ae"),
        // add a custom campaign widget
        campaignWidget: CampaignBanner(
          headline: local.specialPriceLabel,
        ),
      ),
    );
  }
}
