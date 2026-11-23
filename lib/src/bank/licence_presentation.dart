import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// Text and cover image of a licence card.
extension LicencePresentation on Licence {
  String title(AppLocalizations local) => switch (this) {
    Licence.ppla => local.licencePplaTitle,
    Licence.pplh => local.licencePplhTitle,
    Licence.spl => local.licenceSplTitle,
    Licence.bpl => local.licenceBplTitle,
  };

  String subtitle(AppLocalizations local) => switch (this) {
    Licence.ppla => local.licencePplaSubtitle,
    Licence.pplh => local.licencePplhSubtitle,
    Licence.spl => local.licenceSplSubtitle,
    Licence.bpl => local.licenceBplSubtitle,
  };

  /// File name inside `assets/covers/`.
  String get coverImage => switch (this) {
    Licence.ppla => 'ppla.png',
    Licence.pplh => 'pplh.png',
    Licence.spl => 'plg.png',
    Licence.bpl => 'plfb.png',
  };
}
