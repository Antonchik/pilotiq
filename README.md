# pilotiq

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple)
.

For help getting started with Flutter development, view the
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/docs/development/ui/assets-and-images#resolution-aware)
.

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.

To support additional languages, please visit the tutorial on
[Internationalizing Flutter
apps](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)

## Сборка и ключи

В репозитории **нет ни одного ключа**: ни RevenueCat, ни ключей подписи. Публичные ключи RevenueCat SDK передаются при сборке через `--dart-define`:

```
flutter build appbundle --release \
  --dart-define=RC_API_KEY_ANDROID=<публичный ключ Android из RevenueCat>

flutter build ipa --release \
  --dart-define=RC_API_KEY_IOS=<публичный ключ iOS из RevenueCat>
```

Для запуска и отладки то же самое: `flutter run --dart-define=RC_API_KEY_ANDROID=...`. Ключ каждой платформы нужен только своей сборке. Подпись Android — `android/key.properties` (в git не хранится, см. `android/app/build.gradle.kts`).

**Сборка без ключей** (так запускаются тесты и сборки разработчика) работает: приложение стартует, обучение и симуляции доступны по правилам бесплатного тарифа, а пэйвол честно показывает «Покупки не доступны в этой сборке». Если раньше в этой сборке был оформлен Premium и он сохранён в кэше, он действует до конца оплаченного периода. Если SDK магазина не смог запуститься, приложение так же работает без покупок.

Что настраивается в RevenueCat (не в коде):

- **Entitlement `premium`** (id задан в `lib/src/purchases/purchase_config.dart`) — единственное право, которое открывает Premium. Все продукты подключаются к нему.
- **Offering `default`** (текущий, `current`) с пакетами: Lifetime (тип `Lifetime`), 3 месяца (`Three Month`), 1 месяц (`Monthly`). Экран пэйвола показывает ровно то, что в текущем offering: цены, периоды и пробный период берутся только из данных магазина, поэтому состав планов меняется без выпуска версии.
- **Продукты** в App Store Connect и Google Play Console с теми же id, которые продавались в версии 1.2.0 (LinkFive), чтобы существующие подписчики сохранили Premium.
- Пробный период (introductory offer) настраивается на продукте в магазине; приложение показывает его, только если магазин сообщает, что он доступен этому пользователю.

Как работает покупка в приложении: источник истины — entitlement `premium` в RevenueCat. Последний известный статус кэшируется в боксе `config` на случай офлайна и ошибок (действует до конца оплаченного периода; Lifetime — бессрочно), при ответе RevenueCat «не активен» Premium снимается сразу. При первом запуске после обновления приложение один раз тихо вызывает `syncPurchases`, чтобы подписчики версии 1.2.0 получили Premium без повторной покупки (при ошибке повтор на следующем запуске). «Восстановить покупки» всегда есть на пэйволе и в настройках.
