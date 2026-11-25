# Настройка RevenueCat и магазинов для Pilotiq 2.0

Пошаговая инструкция для владельца. Идентификаторы и требования к ним взяты из кода приложения:

| Что | Значение в коде | Где |
|---|---|---|
| Bundle ID / package name | `antonchik.anton.pilotiq` | `ios/Runner.xcodeproj`, `android/app/build.gradle.kts` |
| Entitlement (право доступа) | `premium` | `lib/src/purchases/purchase_config.dart` |
| Offering (предложение) | то, что отмечено в RevenueCat как **Current** | `purchases_flutter_gateway.dart` (`offerings.current`) |
| Типы пакетов, которые понимает пэйвол | `Lifetime`, `Three Month`, `Monthly` (остальные типы показываются в конце списка как «прочие») | `purchases_flutter_gateway.dart` |
| Ключи SDK | `--dart-define=RC_API_KEY_ANDROID=…`, `--dart-define=RC_API_KEY_IOS=…` | `purchase_config.dart`, `README.md` |

Названия кнопок и разделов в консолях RevenueCat, Apple и Google меняются; если пункт называется иначе, ищите по смыслу. Места, которые я не мог проверить в живой консоли, помечены [ПРОВЕРИТЬ].

Порядок: **сначала магазины (шаги 1–2), потом RevenueCat (шаги 3–7), потом проверка (шаг 8).** RevenueCat не создаёт продукты сам: он только читает то, что заведено в App Store Connect и Play Console.

Предлагаемые идентификаторы продуктов (можно свои, но тогда везде одинаково):

| План | iOS (App Store Connect) | Android (Play Console) |
|---|---|---|
| Lifetime | `pilotiq_lifetime` (Non-Consumable) | `pilotiq_lifetime` (одноразовый продукт) |
| 3 месяца | `pilotiq_premium_3m` (Auto-Renewable) | подписка `pilotiq_premium`, базовый план `p3m` |
| 1 месяц | `pilotiq_premium_1m` (Auto-Renewable) | подписка `pilotiq_premium`, базовый план `p1m` |

Product ID после создания изменить нельзя, а удалённый ID нельзя использовать повторно. Старые ID из 1.2.0 переносить не нужно: в LinkFive активных пользователей не было (подтверждено владельцем 24.11.2026), поэтому и переноса покупок в приложении нет.

---

## 1. App Store Connect

1. **Соглашения и выплаты.** App Store Connect → Business (раньше «Agreements, Tax, and Banking»): соглашение **Paid Apps** в статусе Active, заполнены банк и налоги. Без этого покупки не работают даже в sandbox.
2. **Lifetime.** Приложение → Monetization → In-App Purchases → «+» → тип **Non-Consumable**, Reference Name «Premium Lifetime», Product ID `pilotiq_lifetime`. Цена (база — Польша, PLN), локализация PL и EN (название, описание), скриншот для ревью (можно снимок пэйвола). Статус должен стать «Ready to Submit».
3. **Подписки.** Monetization → Subscriptions → создать **группу подписок** «Premium» (обе подписки в одной группе, тогда пользователь может переходить между ними без двойной оплаты).
   - В группе: `pilotiq_premium_3m` (длительность 3 Months) и `pilotiq_premium_1m` (1 Month). Цены, локализации PL/EN, скриншот.
   - Уровни (Subscription Levels) внутри группы: 3 месяца и 1 месяц можно поставить на один уровень — это разные сроки одного и того же доступа. [ПРОВЕРИТЬ: как Apple трактует смену плана на одном уровне — при следующем продлении.]
   - **Пробный период** для 3 месяцев: у подписки → Subscription Prices → Introductory Offers → «+» → Free, 3 дня, все страны. Пэйвол сам покажет строку о пробном периоде, если магазин его отдаёт.
   - Локализация группы (название группы видят пользователи в настройках подписок).
4. **Ключ для RevenueCat (обязателен для StoreKit 2).** Users and Access → Integrations → **In-App Purchase** → «Generate In-App Purchase Key» → скачать файл `.p8` (скачивается **один раз**), записать Key ID. Issuer ID — на той же странице сверху.
5. **(По желанию) ключ App Store Connect API** для импорта продуктов в RevenueCat: Users and Access → Integrations → App Store Connect API → Team Keys → «+», роль **App Manager**, скачать `.p8`, записать Key ID и Issuer ID.
6. **Тестовый аккаунт.** Users and Access → Sandbox → Test Accounts → «+» (почта, которой нет в Apple ID). На iPhone: Настройки → App Store → Sandbox Account → войти этим аккаунтом.
7. **Первую покупку отправлять на ревью вместе с версией приложения.** При отправке версии 2.0 на ревью в разделе In-App Purchases and Subscriptions отметьте все три продукта. Ревьюеры Apple проверяют покупки в sandbox.

## 2. Google Play Console

1. **Платёжный профиль.** Setup → Payments profile привязан к аккаунту разработчика (польский налоговый профиль, банк).
2. **Сборка с биллингом в консоли.** Продукты нельзя создать, пока в Play Console нет хотя бы одной сборки с разрешением биллинга. Соберите `flutter build appbundle --release --dart-define=RC_API_KEY_ANDROID=…` (ключ можно добавить позже, сборка без него тоже подходит для этого шага) и загрузите во **Internal testing** (Testing → Internal testing → Create new release). Разрешение `com.android.vending.BILLING` добавляет плагин `purchases_flutter`. [ПРОВЕРИТЬ: в собранном AAB есть это разрешение — Play Console покажет предупреждение, если нет.]
3. **Lifetime.** Monetize → Products → **In-app products** (одноразовые) → Create product: ID `pilotiq_lifetime`, название и описание PL/EN, цена → **Activate**.
4. **Подписки.** Monetize → Products → **Subscriptions** → Create subscription: Product ID `pilotiq_premium`, название, описание.
   - Base plan `p3m`: Auto-renewing, период 3 months, цены → Activate.
   - Base plan `p1m`: Auto-renewing, период 1 month, цены → Activate.
   - **Пробный период** для `p3m`: в базовом плане → Add offer → Offer ID `trial3d`, eligibility «New customer acquisition», фаза Free trial 3 days → Activate.
   - Не заводите у этой подписки **prepaid** базовые планы, если не хотите разбираться, какой из них покажет пэйвол (см. `docs/monetization.md`, «Предоплаченные планы»).
5. **Тестировщики лицензий.** Setup → License testing → добавить свои Google-аккаунты; ответ лицензии «RESPOND_NORMALLY». Те же аккаунты добавить в список тестировщиков Internal testing и принять приглашение по ссылке на телефоне. У тестировщиков лицензий покупки бесплатные, а подписки ускорены (месяц ≈ 5 минут).

## 3. Учётные данные Google для RevenueCat (самый долгий шаг)

RevenueCat проверяет покупки Android через сервисный аккаунт Google Cloud. Следуйте актуальному гайду RevenueCat «Creating Play Service Credentials» — он меняется. Суть:

1. В Google Cloud Console (проект можно создать новый) включить **Google Play Android Developer API** и **Google Play Developer Reporting API**. [ПРОВЕРИТЬ: точный список API в гайде RevenueCat.]
2. IAM & Admin → Service Accounts → Create service account (имя, например, `revenuecat`) → роли **Pub/Sub Editor** и **Monitoring Viewer** (нужны для уведомлений) → Keys → Add key → **JSON** → скачать.
3. Play Console → **Users and permissions** → Invite new users → почта сервисного аккаунта → права на приложение: **View app information and download bulk reports**, **View financial data, orders, and cancellation survey responses**, **Manage orders and subscriptions** → Invite.
4. В RevenueCat (шаг 4.3) загрузить JSON. **Учётные данные начинают работать не сразу — до 36 часов.** Пока RevenueCat показывает ошибку проверки ключа, покупки Android не проверяются; это нормально, просто подождите.

## 4. RevenueCat: проект и приложения

1. **Проект** уже создан. Project Settings → General: название «Pilotiq».
2. **iOS-приложение:** Project → Apps & providers (раньше «Apps») → + New → **App Store**:
   - App name «Pilotiq iOS», Bundle ID `antonchik.anton.pilotiq`;
   - **In-App Purchase Key**: загрузить `.p8` из шага 1.4, Key ID, Issuer ID;
   - (по желанию) App Store Connect API key из шага 1.5 — для импорта продуктов;
   - **App Store Server Notifications**: RevenueCat покажет URL. Скопируйте его в App Store Connect → приложение → App Information → App Store Server Notifications → **Production Server URL** и **Sandbox Server URL**, версия **Version 2**.
3. **Android-приложение:** + New → **Play Store**:
   - App name «Pilotiq Android», Package name `antonchik.anton.pilotiq`;
   - Service Account credentials JSON из шага 3;
   - **Google Real-time Developer Notifications**: в настройках приложения в RevenueCat кнопка подключения Google Pub/Sub (Connect to Google) → RevenueCat создаёт тему → скопировать имя темы в Play Console → Monetize → Monetization setup → Real-time developer notifications → Topic name → **Send test notification** → в RevenueCat должно появиться «последнее уведомление получено». [ПРОВЕРИТЬ: точное название кнопки.]
4. **Публичные ключи SDK:** Project Settings → **API keys** → у каждого приложения свой публичный ключ: `appl_…` для iOS, `goog_…` для Android. Именно их передают при сборке через `--dart-define`. **Секретный ключ (`sk_…`) в приложение никогда не вставлять.** В репозиторий и в чат ключи не вносить.

## 5. RevenueCat: продукты и entitlement

1. **Products:** Product catalog → Products → для каждого приложения «+ New» или **Import** (если подключён ключ из 1.5 / учётные данные Google):
   - iOS: `pilotiq_lifetime`, `pilotiq_premium_3m`, `pilotiq_premium_1m`;
   - Android: `pilotiq_lifetime`, `pilotiq_premium:p3m`, `pilotiq_premium:p1m` (для подписок Google идентификатор в RevenueCat — «подписка:базовый план»).
2. **Entitlement:** Product catalog → Entitlements → + New → Identifier **`premium`** (ровно так, строчными: приложение проверяет именно этот id) → Attach → отметить **все шесть** продуктов.

## 6. RevenueCat: offering

1. Product catalog → Offerings → + New → Identifier `default`, описание «Premium 2.0».
2. Внутри offering добавить пакеты, **тип пакета важен** — по нему приложение решает, как назвать план и где его поставить:
   - **Lifetime** (`$rc_lifetime`) → iOS `pilotiq_lifetime`, Android `pilotiq_lifetime`;
   - **Three Month** (`$rc_three_month`) → iOS `pilotiq_premium_3m`, Android `pilotiq_premium:p3m`;
   - **Monthly** (`$rc_monthly`) → iOS `pilotiq_premium_1m`, Android `pilotiq_premium:p1m`.
3. Offering `default` → **Make current** (Set as current). Приложение берёт только текущий offering; если его нет, пэйвол покажет, что планов нет.
4. Порядок пакетов задан в коде (Lifetime → 3 месяца → 1 месяц), метка «Best choice» / «Najlepszy wybór» — только у Lifetime. Менять порядок в RevenueCat не нужно.
5. RevenueCat Paywalls (визуальный редактор пэйволов) **не используйте**: в приложении свой пэйвол.

## 7. Сборка с ключами

```
flutter build appbundle --release --dart-define=RC_API_KEY_ANDROID=goog_…
flutter build ipa --release --dart-define=RC_API_KEY_IOS=appl_…
```

Для отладки на телефоне: `flutter run --dart-define=RC_API_KEY_ANDROID=goog_…` (или `…IOS=appl_…`). Без ключа приложение работает, но пэйвол пишет «Zakupy nie są dostępne w tej wersji aplikacji.»

## 8. Проверка

Подробные сценарии — `docs/release-checklist.md`, разделы 6–7. Минимум:

1. **Android:** установить сборку из Internal testing аккаунтом-тестировщиком → открыть пэйвол → видны 3 плана с ценами из Play, у 3 месяцев — строка о пробном периоде → купить 1 месяц → Premium включился → в RevenueCat (Customers) появился клиент с активным `premium` → через ~5 минут подписка продлилась/истекла по ускоренному расписанию → «Przywróć zakupy» после переустановки возвращает Premium.
2. **iOS:** сборка через TestFlight или Xcode, sandbox-аккаунт → то же самое; Lifetime → Premium навсегда; отмена подписки в sandbox → Premium снимается после истечения.
3. **RevenueCat → Overview / Customers:** покупки видны, в карточке клиента entitlement `premium` активен; в Apps & providers нет ошибок учётных данных и уведомления приходят.
4. Отключите интернет и откройте пэйвол: либо ошибка с кнопкой повтора, либо сохранённые планы, без падений.

## 9. После выпуска

- Старые продукты 1.2.0 в обеих консолях снять с продажи (Play: Deactivate; App Store: Remove from Sale), чтобы их никто не купил: LinkFive отключён, такие покупки не дадут Premium.
- Смотреть в RevenueCat: конверсию в покупку, долю Lifetime, пробный период → оплата, возвраты (см. `docs/monetization.md` §5).
- Цены и состав планов можно менять в консолях и в offering без выпуска новой версии; entitlement `premium` и типы пакетов — нельзя (они в коде).
