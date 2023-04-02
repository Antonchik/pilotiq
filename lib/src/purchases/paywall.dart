import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchases_paywall_ui/paywall/model/icon_and_text.dart';
import 'package:in_app_purchases_paywall_ui/paywall/model/text_and_url.dart';
import 'package:in_app_purchases_paywall_ui/paywall/simple/simple_paywall.dart';
import 'package:in_app_purchases_paywall_ui/paywall/widgets/campaign_banner.dart';
import 'package:in_app_purchases_paywall_ui/paywall/wrapper/paywall_scaffold.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';

class Paywall extends ConsumerWidget {
  const Paywall({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(linkFiveProvider);
    return PaywallScaffold(
      appBarTitle: "Premium",
      child: SimplePaywall(
        callbackInterface: data.callbackInterface,
        subscriptionListData: data.paywallUIHelperData(context),
        title: "Go Premium",
        // SubTitle
        subTitle: "All features at a glance",
        // Add as many bullet points as you like
        bulletPoints: [
          IconAndText(Icons.new_releases_outlined, "Access to all exams"),
          IconAndText(Icons.subject, "Access to all subjects"),
          IconAndText(Icons.dark_mode_outlined, "Dark mode")
        ],
        // Shown if isPurchaseSuccess == true
        successTitle: "You're a Premium User!",
        // Shown if isPurchaseSuccess == true
        successSubTitle: "Thanks for your Support!",
        // Widget can be anything. Shown if isPurchaseSuccess == true
        successWidget: Container(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(
                child: Text("Let's go!"),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            ])),
        // tosData: TextAndUrl("Terms of Service", "https://www.linkfive.io/tos"),
        // provide your PP
        ppData: TextAndUrl("Privacy Policy",
            "https://www.termsfeed.com/live/da031152-c5f9-4dd0-a4e6-42d78de414ae"),
        // add a custom campaign widget
        campaignWidget: CampaignBanner(
          headline: "🥳 Summer Special Sale",
        ),
      ),
    );
  }
}
