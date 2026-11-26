# Пошагово: от пустого компьютера до проверки на телефоне

Руководство для первого раза. Предполагается Mac: собрать приложение для iPhone можно только на macOS. Если у вас Windows или Linux, проходите только Android-части, а iOS делайте на Mac.

Названия кнопок в Android Studio, Xcode и консолях магазинов меняются. Если пункт называется иначе, ищите по смыслу или пришлите скриншот — подскажу. Места, которые я не мог проверить сам, помечены «[проверить]».

Время: инструменты ставятся за 2–3 часа (в основном это загрузки). Первая загрузка сборки в магазины и обработка занимают ещё около часа. Покупки Android могут заработать только через сутки-полторы после подключения учётных данных Google в RevenueCat.

---

## Часть 1. Инструменты (один раз)

### 1.1. Xcode (для iPhone)

1. App Store на Mac → найти **Xcode** → установить (около 15 ГБ). Проекту нужен Xcode 26.
2. Открыть Xcode один раз, принять лицензию, дождаться установки компонентов.
3. Терминал (Программы → Утилиты → Терминал):
   ```
   sudo xcodebuild -runFirstLaunch
   xcode-select -p
   ```
   Вторая команда должна вывести путь внутри `Xcode.app`.
4. Xcode → Settings → Accounts → «+» → Apple ID разработчика. Тогда Xcode сможет подписывать сборки.

### 1.2. Android Studio (для Android)

1. Скачать с developer.android.com/studio → установить → открыть → мастер первого запуска (Standard).
2. Settings → Languages & Frameworks → **Android SDK**:
   - вкладка SDK Platforms → **Android API 37** (галочка, Apply);
   - вкладка SDK Tools → **NDK (Side by side)** версии `28.2.13676358` (включите «Show Package Details»), **Android SDK Command-line Tools**, **CMake** → Apply.
3. **JDK 17.** Проекту нужна именно 17. Проще всего установить Temurin 17 (adoptium.net). Путь к ней понадобится в 1.3.

### 1.3. Flutter 3.50.1

Проекту нужна именно эта версия.

1. Скачать архив Flutter 3.50.1 для macOS со страницы Flutter SDK archive (docs.flutter.dev → Release → SDK archive). Распаковать, например, в `~/development/flutter`.
2. Добавить в PATH. В Терминале:
   ```
   echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   flutter --version
   ```
   Должно быть `Flutter 3.50.1`.
3. Указать JDK 17 и принять лицензии Android:
   ```
   flutter config --jdk-dir "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
   flutter doctor --android-licenses      # на все вопросы — y
   flutter doctor
   ```
   В `flutter doctor` у Flutter, Android toolchain и Xcode должны стоять галочки. Предупреждения про Chrome и VS Code не важны. Если есть крестик — пришлите вывод.

### 1.4. Проект

```
cd ~/development
git clone https://github.com/Antonchik/pilotiq.git
cd pilotiq
git checkout claude/dreamy-hamilton-ijiat7
flutter pub get
flutter test
```

`flutter test` должен закончиться строкой «All tests passed!». Если просит войти в GitHub — репозиторий приватный, войдите своим аккаунтом (или используйте GitHub Desktop).

### 1.5. Файлы, которых нет в репозитории

1. **Ключ загрузки Android** (файл `.jks` или `.keystore`, которым вы подписывали прошлые версии). Положите его вне проекта, например `~/keys/pilotiq-upload.jks`.
2. Создайте файл `android/key.properties` (в git он не попадает):
   ```
   storePassword=пароль_хранилища
   keyPassword=пароль_ключа
   keyAlias=имя_ключа
   storeFile=/Users/ВАШЕ_ИМЯ/keys/pilotiq-upload.jks
   ```
3. Ключи RevenueCat (RevenueCat → Project Settings → API keys) — в файл `~/pilotiq-keys.env` вне проекта:
   ```
   RC_API_KEY_ANDROID=goog_...
   RC_API_KEY_IOS=appl_...
   ```

---

## Часть 2. Первый запуск на телефоне (без покупок)

### 2.1. Android

1. На телефоне: Настройки → О телефоне → семь раз нажать **«Номер сборки»** → «Вы стали разработчиком».
2. Настройки → Для разработчиков → включить **Отладку по USB**.
3. Подключить кабелем, на телефоне разрешить отладку для этого компьютера.
4. В Терминале в папке проекта:
   ```
   flutter devices          # телефон должен быть в списке
   flutter run
   ```
   Первая сборка идёт 5–15 минут. Приложение откроется на телефоне.
5. Пройдите **быструю проверку** из `docs/device-test-plan.md`, раздел 1. Пэйвол здесь покажет «Zakupy nie są dostępne w tej wersji aplikacji.» — так и должно быть без ключа.

### 2.2. iPhone

1. Подключить iPhone кабелем, на телефоне нажать «Доверять».
2. На iPhone: Настройки → Конфиденциальность и безопасность → **Режим разработчика** → включить, перезагрузить.
3. Открыть в Xcode файл `ios/Runner.xcworkspace` → слева **Runner** → вкладка **Signing & Capabilities** → Team: ваша команда разработчика. Bundle Identifier должен остаться `antonchik.anton.pilotiq`.
4. На той же вкладке должна быть возможность **In-App Purchase**; если её нет — «+ Capability» → In-App Purchase.
5. В Терминале:
   ```
   flutter run
   ```
   Первая сборка iOS может сама изменить файлы в папке `ios/` (переход на Swift Package Manager, раздел 5.2 чек-листа). После неё выполните `git status` и пришлите мне список изменений — я их проверю и закоммичу.

---

## Часть 3. Сборка с покупками и загрузка в магазины

Покупки удобнее всего проверять на сборках из магазинов, а не с компьютера:
- на iPhone через **TestFlight** покупки идут в тестовой среде Apple, деньги не списываются, отдельный sandbox-аккаунт не нужен;
- на Android через **Internal testing** у тестировщиков лицензий покупки бесплатные, а месячная подписка длится около 5 минут.

### 3.1. Android: Internal testing

1. Сборка:
   ```
   set -a; source ~/pilotiq-keys.env; set +a
   flutter build appbundle --release --dart-define=RC_API_KEY_ANDROID=$RC_API_KEY_ANDROID
   ```
   Файл появится в `build/app/outputs/bundle/release/app-release.aab`.
2. Play Console → приложение → **Testing → Internal testing** → Create new release → загрузить `.aab` → заметки к выпуску (можно «Testy 2.0») → Next → **Save and publish** (или Start rollout).
3. Вкладка **Testers**: создать список, добавить свой Google-аккаунт → Save → скопировать **ссылку для присоединения** (Join on Android / Copy link).
4. **Setup → License testing**: добавить тот же аккаунт, ответ «RESPOND_NORMALLY» → Save.
5. На телефоне, под этим же аккаунтом Google, открыть ссылку → **Стать тестировщиком** → перейти в Google Play → установить или обновить Pilotiq. Если в Play всё ещё старая версия, подождите 10–30 минут и обновите страницу.

Если при загрузке Play Console покажет предупреждение (версия Billing Library, целевой API, страницы 16 КБ) — пришлите текст.

### 3.2. iPhone: TestFlight

1. Сборка:
   ```
   set -a; source ~/pilotiq-keys.env; set +a
   flutter build ipa --release --dart-define=RC_API_KEY_IOS=$RC_API_KEY_IOS
   ```
   Файл `.ipa` появится в `build/ios/ipa/`.
2. Установить из App Store на Mac приложение **Transporter** → войти Apple ID → перетащить `.ipa` → **Deliver**.
3. App Store Connect → приложение → **TestFlight**. Через 10–30 минут сборка появится со статусом обработки. Если спросят про шифрование (Export Compliance): приложение использует только стандартное шифрование системы (HTTPS) [проверить ответ по формулировке вопроса].
4. TestFlight → **Internal Testing** → создать группу, добавить себя.
5. На iPhone установить приложение **TestFlight** из App Store → в нём появится Pilotiq → Install.

---

## Часть 4. Проверка

Идите по `docs/device-test-plan.md`, разделы 3–6: покупки, обновление поверх 1.2.0, материалы, напоминания, крупный шрифт. Результаты записывайте в таблицу в конце того же файла.

Самое важное для первого раза:

1. Пэйвол показывает три плана с ценами магазина; у «3 miesiące» есть строка о пробном периоде.
2. Покупка «1 miesiąc» → «Dziękujemy!», Premium открыт сразу. В RevenueCat → **Customers** появился клиент с активным `premium`.
3. «Przywróć zakupy» после переустановки возвращает Premium.
4. Через ~5 минут (Android) подписка продлевается или истекает по ускоренному расписанию, Premium снимается после отмены.

Если покупка на Android сразу пишет ошибку: проверьте в RevenueCat → Apps & providers → Android, нет ли ошибки учётных данных Google. Если есть — подождите до 36 часов после их загрузки.

---

## Если что-то не получается

Пришлите мне:
- команду, которую запускали, и последние 30–50 строк вывода;
- или скриншот экрана с ошибкой.

Ключи, пароли, файлы `.jks`, `.p8` и JSON сервисного аккаунта не присылайте — они не нужны для разбора ошибок.
