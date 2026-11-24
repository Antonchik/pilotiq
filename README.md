# pilotiq

Pilotiq is a Flutter app for preparing for the theoretical PPL exam of the
Polish Civil Aviation Authority (ULC). It covers the PPL(A), PPL(H), SPL and
BPL licences, practises the official question banks with spaced repetition,
simulates the exam per subject, and is available in Polish and English.

## Requirements

- Flutter 3.50.1 (Dart 3.14), release steps are in `docs/release-checklist.md`.
- Android and iOS toolchains are needed only to build the app.

## Checks

```
flutter pub get
flutter analyze
flutter test
```

`flutter analyze` is expected to report "No issues found!".

## Localization

Strings live in per-feature fragments, `lib/src/localization/fragments/*_en.arb`
and `*_pl.arb` (Polish needs the plural forms one/few/many/other). After
changing them, rebuild the merged files and the generated code:

```
dart run tool/l10n/merge_arb.dart && flutter gen-l10n
```

`dart run tool/l10n/merge_arb.dart --check` verifies that the merged files are
up to date.

## More documentation

- [docs/release-checklist.md](docs/release-checklist.md): steps before a release.
- [docs/monetization.md](docs/monetization.md): plans, free limits and the paywall.
- [tool/ulc/README.md](tool/ulc/README.md): how the question banks are built from the ULC sources.

## Сборка и ключи

В репозитории **нет ни одного ключа**: ни RevenueCat, ни ключей подписи. Публичные ключи RevenueCat SDK передаются при сборке через `--dart-define`:

```
flutter build appbundle --release \
  --dart-define=RC_API_KEY_ANDROID=<публичный ключ Android из RevenueCat>

flutter build ipa --release \
  --dart-define=RC_API_KEY_IOS=<публичный ключ iOS из RevenueCat>
```

Для запуска и отладки то же самое: `flutter run --dart-define=RC_API_KEY_ANDROID=...`. Ключ каждой платформы нужен только своей сборке. Подпись Android — `android/key.properties` (в git не хранится, см. `android/app/build.gradle.kts`).

**Сборка без ключей** (так запускаются тесты и сборки разработчика) работает: приложение стартует, обучение и симуляции доступны по правилам бесплатного тарифа, а пэйвол честно показывает «Purchases are not available in this build of the app.» / «Zakupy nie są dostępne w tej wersji aplikacji.» (покупки недоступны в этой сборке). Если раньше в этой сборке был оформлен Premium и он сохранён в кэше, он действует до конца оплаченного периода. Если SDK магазина не смог запуститься, приложение так же работает без покупок.

Что настраивается в RevenueCat (не в коде):

- **Entitlement `premium`** (id задан в `lib/src/purchases/purchase_config.dart`) — единственное право, которое открывает Premium. Все продукты подключаются к нему.
- **Offering `default`** (текущий, `current`) с пакетами: Lifetime (тип `Lifetime`), 3 месяца (`Three Month`), 1 месяц (`Monthly`). Экран пэйвола показывает ровно то, что в текущем offering: цены, периоды и пробный период берутся только из данных магазина, поэтому состав планов меняется без выпуска версии.
- **Продукты** в App Store Connect и Google Play Console с теми же id, которые продавались в версии 1.2.0 (LinkFive), чтобы существующие подписчики сохранили Premium.
- Пробный период (introductory offer) настраивается на продукте в магазине; приложение показывает его, только если магазин сообщает, что он доступен этому пользователю.

Как работает покупка в приложении: источник истины — entitlement `premium` в RevenueCat. Последний известный статус кэшируется в боксе `config` на случай офлайна и ошибок (действует до конца оплаченного периода; Lifetime — бессрочно), при ответе RevenueCat «не активен» Premium снимается сразу. При первом запуске после обновления приложение один раз тихо вызывает `syncPurchases`, чтобы подписчики версии 1.2.0 получили Premium без повторной покупки (при ошибке повтор на следующем запуске). В сборке с ключами «Restore purchases» / «Przywróć zakupy» (восстановить покупки) всегда есть на пэйволе и в настройках. В сборке без ключей на пэйволе этой кнопки нет, а в настройках строка неактивна с подписью «Not available in this build of the app.» / «Niedostępne w tej wersji aplikacji.».
