# tool/materials — учебные материалы (объяснения и конспекты)

Пилот на предмете `air_law` (Prawo lotnicze). Объяснения и конспекты пишутся и проверяются агентами по локальному корпусу текстов
первоисточников; в приложение попадают только проверенные записи. Скрипт: `materials.py` (только стандартная библиотека Python 3.10+,
запуск `python3 -I tool/materials/materials.py <команда>`; опция `--root` меняет корень проекта, нужна тестам).

## Раскладка
| путь | что |
|---|---|
| `materials.py` | подкоманды `inventory`, `build`, `validate`, `apply-review`, `report` |
| `sources.json`, `anchors/*.json`, `corpus/`, `sources/` | реестр источников, якоря, извлечённый текст, скачанные файлы (создаёт шаг S1; `corpus/` и `sources/` не в git) |
| `air_law/inventory.json` | генерируется: все вопросы `air_law` с ключами |
| `air_law/topics.json` | подтемы и порядок ключей: `[{"id","title":{"pl","en"},"order":[ключи],"sources":[…],"complete":false}]` (допустима и форма `{"topics":[…]}`) |
| `air_law/src/Pnn.json` | объяснения одной порции (список записей) |
| `air_law/summaries/<topicId>.json` | конспект подтемы |
| `air_law/reviews/Pnn.rK.editor.json` | вердикты editor (сохраняет оркестратор дословно) |
| `air_law/review_ledger.json` | генерируется `apply-review`: журнал проверок |
| `../../assets/materials/air_law.json` | собранный ассет приложения |

## Ключ вопроса
`key = "<NUMER>#<fp8>"`, где `fp8` — первые 8 hex SHA-1 от строки `вопрос \n верный ответ \n три неверных, отсортированных`.
Каждая ячейка нормализуется: NFC, удалены `<sub>/<sup>`, схлопнуты пробелы, убран хвост `/n`, нижний регистр. Хешируется польский текст
ячейки (`pl`). Поэтому:
- один и тот же вопрос в разных лицензиях (id отличаются) даёт один ключ и несколько ссылок в `links`;
- любая смена вопроса или ответа даёт новый ключ, и старое объяснение к нему не привязывается;
- вопросы PPL(A)/(H) с неразделённым PL+EN (`rawMixed`) дают собственный ключ; если по смыслу это тот же вопрос, у записи ставят `"sameAs": "<ключ-оригинал>"`.

Приложение отпечаток не считает: `build` кладёт в ассет готовую таблицу `links: {licence: {questionId: key}}`.
В `links` попадают вопросы, у которых есть выдаваемое объяснение (в том числе через `sameAs`), а также вопросы из `questionKeys`
выдаваемых разделов конспекта (чтобы кнопка «вопросы по теме» находила вопросы без объяснения). `topics[].order` в ассете содержит
только ключи с выдаваемым объяснением, в порядке `topics.json`.

## Форматы записей
Объяснение (`src/Pnn.json`, один ключ только в одном файле):
```json
{"key":"PL010-0001#1a2b3c4d","status":"draft","text":"2–4 zdania po polsku.","refs":[{"src":"PL-PRAWO-LOTNICZE","loc":"art. 128 ust. 1","quote":"≤300 znaków dosłownie z korpusu"}],"disputeNote":null,"sameAs":null}
```
Запись с `sameAs` не имеет своих `text` и `refs` (текст берётся у оригинала); editor проверяет, что это действительно тот же вопрос.
Конспект (`summaries/<topicId>.json`): `{"topic":"AL03","sections":[{"id":"AL03-1","status":"draft","heading":"…","body":["абзац","- пункт"],"refs":[…],"questionKeys":[…]}]}`.
Статус ведётся по разделам. Допустим и общий `"status"` на уровне файла как значение по умолчанию.

Статусы: `none` (не написано, явная отметка), `draft`, `verified`, `disputed` (ключ ULC противоречит источнику; нужен `disputeNote`),
`unverified` (проверка не пройдена или источника нет), `retired`.

**`unverified` с `basis`** (решения владельца 24.11.2026). У `unverified`-записи без нормативного источника writer ставит `refs: []` (или только
подтверждённую часть), `basis` и `basisNote` (короткая причина; формат: категория из `materials-portions.md` §3 в начале, например `old-reg: …`).
Значения `basis`:
- `no-source` — нормы нет или она устарела: `text` обязателен (2–4 предложения, ≤ 700 символов). `aip-missing` — нужен раздел AIP, которого нет:
  `text` может быть пустым (заглушка), иначе проверяется так же.
- `outdated` — вопрос опирается на отменённую норму: `text` **пуст**, `refs` необязательны, `basisNote` обязателен (≤ 300 символов: что отменено и чем заменено).
- `basis`/`basisNote` допустимы только у `unverified`, входят в хеш записи; `sameAs` с `basis` запрещён.
- **Любые указанные `refs` проверяются как у опубликованных**: `src` есть в `sources.json` и доступен, `loc` проходит грамматику, якорь и родители
  существуют, `quote` (если дан) найден в тексте якоря с учётом диапазонов будущих редакций. Отсутствие `quote` ошибкой не считается.
- `apply-review` пропускает записи с `basis` (предупреждение, статус и журнал не меняются): `PASS` не сделает запись без `refs` проверенной.
- `report` считает отдельно `unverified/no-source`, `unverified/aip-missing`, `unverified/outdated` и прочие `unverified`.
- Покрытие `complete: true`: в `questionKeys` не требуются только ключи, у которых запись — `unverified` с допустимым `basis`. `topics.json` `gaps` не читается.

**Что попадает в ассет.** В ассет идут только `verified` и `disputed` с совпадающим хешем и вердиктом журнала. `no-source` и `aip-missing` в ассет **не попадают
никогда**. `outdated` попадает отдельным списком: `"outdated": {"<ключ>": {"note": "<basisNote>"}}` (schema остаётся 1: поле необязательное и добавлено, старый
разбор его игнорирует) и ссылками в `links`; приложение показывает пометку «Pytanie opiera się na nieaktualnych przepisach. Jeśli pojawi się na egzaminie,
liczy się odpowiedź z klucza ULC.» **всем** (без пэйвола). Для приложения нужна правка: прочитать `outdated`, при наличии ключа вопроса показать пометку
вместо/над объяснением (текста объяснения нет); видна всем именно пометка, `note` (причина) — по решению владельца (в Premium или всем); `note` не должен начинаться со служебного префикса вида `old-licence:` (`validate` это отвергает). Ключи `outdated` не входят в `topics[].order` (не занимают места в бесплатном образце).

TODO (решение владельца позже, отдельным шагом): путь публикации записей, одобренных экспертом-человеком (свой вердикт `EXPERT`
с указанием кто и когда; показ без `refs` с пометкой «wyjaśnienie bez podstawy w przepisach, sprawdzone przez …»). Сейчас такого пути нет намеренно.

Локаторы `loc` по виду источника (`kind` в `sources.json`):
- `statute`: `art. N[ ust. N][ pkt N[ lit. a]]`, для rozporządzeń `§ N[ ust. N][ pkt N[ lit. a]]` (`lit.`: буква `a)`, вставки `ea)`/`eb)`); приложения `załącznik N[ tabela T][ część R][ pkt L]`;
  `convention`: `art. N[ ust. N][ lit. a]` (`art. 12`, `art. 3bis`, `art. 44 lit. a`, `art. 1 ust. 1 lit. a`; Konwencja chicagowska не имеет ust., токийская/монреальская — имеют) или `załącznik N`. Источники: `PL-KONWENCJA-CHICAGO-1944` (ISAP, tekst jednolity 16.11.2020, цитаты разрешены; старый `PL-KONWENCJA-CHICAGO` остаётся unavailable), `PL-KONWENCJA-TOKIO-1963`, `-RZYM-1933`, `-MONTREAL-1999`, `-HAGA-1970` (Dz.U., копии со страницы ULC), `PL-KONWENCJA-WARSZAWA-1929` (zestawienie ULC «ze zm.», **reference-only**, без цитат); профиль `konwencja-isap`;
- `eu_reg`: `art. N[ ust. N][ pkt N]` или пункт приложения `SERA.5005`, `FCL.205.A`, `NCO.GEN.105`, `MED.A.030` с подпунктами `(a)(1)(i)`, в том числе двухбуквенными `(ea)`, `(aa)`;
  приложения `załącznik [R][ dodatek N][ sekcja R(a)(1)][ pkt L]` (`załącznik XI dodatek 1 sekcja I(a)(2)`; главы и подпункты приложений без ID правил `załącznik pkt 6.8.7.10`, определения `załącznik I pkt 57`);
- `aip`: `GEN 1.2`, `ENR 1.2 pkt 2.1`, `GEN 2.2 CBA` (сокращение; второе значение того же сокращения `GEN 2.2 CTA 2`), `GEN 2.4 EPWW`, `ENR 5.2.1 TSA`, `ENR 1.4 klasa C`, `ENR 1.4 przypis **` (сноска таблицы);
- `easa`: как `eu_reg`, с префиксом `AMC`/`GM`/`CS`; `AMC1 SFCL.145 SECTION 2A` (секции программы экзамена; вторая таблица того же AMC: `AMC1 SFCL.145 (2) SECTION 5`, цифра = номер абзаца `(2)` перед таблицей);
  `Article N(M)`, `Annex I(12)` (определения регламента), `Appendix N[ pkt L]`, `Appendix N to AMC1 …`;
- `icao`: `Article 3 bis(a)`, `Chapter 5`, `pkt 5.4.2.1`, `def Aerodrome control service` (подопределения `def Risk of collision` — самостоятельные якоря, родитель обрезан до них), `Appendix N`; `itu`: `Appendix 18 channel 06`, `Appendix 18 note f`.
- `icao_pl` (польские тексты ICAO: `ICAO-ZAL-02`, `-11`, `-12`, `-13`, `-14-I`, `-14-II`, `-17`, `-15`, `-10-II`, `-10-IV`, `-10-V` и `ICAO-DOC-4444-PL` — официальные из Dz. Urz. ULC, цитаты разрешены; `ICAO-ZAL-01` — перевод со страницы ULC без obwieszczenia, **reference-only**). Профили: `ulc-annex`, `ulc-pans` (Doc 4444), `ulc-plain` (конфигурируется в `fetch.files[]`: `head`/`foot`/`drop` — regex колонтитулов, `prefacePages`, `bodyPage`, `style` = `caps`|`caps-letter`|`caps-alone`|`title`|`numcaps`, `defStyle` = `paren`|`dash`|`dot`, `flatAppendix`, `lenientSeq`, `figures`, `numFix` = [[префикс строки, номер]] для опечатки в нумерации источника, `skipLines` = regex строк, не являющихся якорями; «UZUPEŁNIENIE A.» = `załącznik A`):
  `rozdział 3`, `3.1.2`, `3.1.2 lit. a` (родители `3.1.2` → `3.1` → `rozdział 3`; в 14-I также `2.6a.1`), `definicja Faza alarmu` (польский термин до скобки, родитель `rozdział 1`),
  `dodatek 1`, `dodatek 1 pkt 2.1[ lit. a]` (Załącznik 12: `dodatek`, `dodatek pkt 2.1`), `załącznik A`, `załącznik A pkt 2.1`, `załącznik A sekcja 19a` (14-I),
  `dodatek A`, `dodatek A pkt 2` (Zał. 10), `tabela 3-1`, `tabela A-1`, `tabela 2.1`, `tabela A5-1-1`, `rysunek 5-25A` (Doc 4444, Zał. 10 t. IV, Zał. 1, 15), `dodatek 2 pole 7` (Doc 4444, «PUNKT 7:» planu lotu), а также `obwieszczenie`, `przedmowa`. Doc 4444 (`ICAO-DOC-4444-PL`): `rozdział 12`, `4.5.7.1.1`, `15.3.10`, `definicja Trak`, `dodatek 3 pkt 1.1`; Zał. 17: dodatek (wyciągi z innych dokumentów) — единый якорь `dodatek` без пунктов. Номер, напечатанный дважды подряд (две версии «do 25 listopada 2026» / «od 26 listopada 2026»),
  — один якорь на обе версии; термин, определённый дважды вразбивку, — первое определение. Рисунки и символы (сигналы Zał. 12 dodatek pkt 2.1–2.2, Zał. 2 dodatek 1 pkt 4–6, рисунки Zał. 14)
  — изображения: в корпусе только подписи и описания (`fetch.files[].imageOnly` в `sources.json`); многоколоночные таблицы извлечены с перемешанным порядком слов в строках.

Номера статей: `67`, `67fa`, `156zd`, `87[1]`, `87[1a]` (надстрочный индекс в квадратных скобках, как в `anchors/PL-PRAWO-LOTNICZE.json`).
Источник со `status: "unavailable"` в `sources.json` процитировать нельзя: ссылка на него — ошибка `validate`, запись в ассет не идёт.
У источников с `allowQuote: false` (`easa`, `icao`, `itu`; значение по умолчанию для `aip`, `easa`, `icao`, `itu` — `false`, `aip` с `allowQuote: true` задан явно для AIP-PL) `quote` не хранится (ошибка, если указан); проверяется только существование якоря.
`legalStateAsOf` в ассете — **самая поздняя** дата среди использованных источников (`legalState`, если нет — `fetched`): «Stan prawny na» = состояние самого свежего из цитируемых актов/дата проверки текста. Самая ранняя дата (было до 25.11.2026) вводила в заблуждение: старый неизменный акт (EU 376/2014, 2018) делал бы весь раздел «устаревшим».

Проверка `quote`: sha256 корпуса `corpus/<id>.txt` должен совпадать с `textSha` в `anchors/<id>.json` (иначе смещения якорей указывают на чужой текст, ошибка).
Для источников с `allowQuote: true` у `verified/disputed` `quote` обязателен. Если `quote` целиком лежит в более точном дочернем якоре,
`validate` выдаёт предупреждение «укажите его вместо …»: ссылайтесь на самый точный пункт.
`build` берёт в ассет запись, только если статус, хеш и вердикт журнала согласованы (`verified` ↔ `PASS`, `disputed` ↔ `DISPUTED`);
ручная смена статуса на `verified` после `FIX` запись в ассет не пускает.
**Reference-only источники (EASA, ICAO, ITU; AIP-PL — с цитатами):** машинно проверяется только существование якоря, смысл по тексту корпуса обязан сверить editor
(цитат там нет).

Дополнительные формы: statute `załącznik N[ tabela T][ część R][ pkt L]`; eu_reg `art. N[ ust. K][ pkt M]`, `załącznik [R]`, `dodatek N`, `załącznik R dodatek N`, любое из них с `pkt L`, правила `21.A.3A`, `M.A.201`, `ORA.AeMC.215`; easa `Article N(M)`, `GMn Article N(M)`, `Appendix N[ pkt L]`.
`quote` с маркером `⟦PRZYSZŁA REDAKCJA⟧` (текст будущей редакции акта) отвергается. Диапазоны будущих редакций extractor записывает в `anchors/<id>.json` в поле `"future": [[start, end], ...]`; при проверке `quote` эти диапазоны внутри якоря заменяются заглушкой, поэтому процитировать недействующий текст нельзя и без маркера (даже через охватывающий якорь).

Строки таблиц приложения 6 Prawa lotniczego адресуются как `załącznik 6 tabela T część R pkt L` (нумерация строк в каждой части начинается заново). Внутри AMC/GM EASA отдельных подъякорей нет (`AMC1 X(b)` и `GM1 X` — только заголовки блоков); на подъякоря внутри программ экзаменов (SYLLABUS) ссылаться нельзя.
`loc` и все его родители (`art. 5 ust. 2 pkt 3` → `art. 5 ust. 2` → `art. 5`; `SERA.5005(a)(1)` → `SERA.5005(a)` → `SERA.5005`) должны быть в `anchors/<src>.json`.

## Команды
| команда | что делает |
|---|---|
| `inventory [--stats]` | читает `assets/data/bank_*.json`, пишет `air_law/inventory.json`; `--stats` печатает числа (лицензии, пересечения, `rawMixed`, кандидаты на `sameAs`) |
| `build` | пишет `assets/materials/air_law.json`: детерминированно (сортировка ключей, без дат); `materialsVersion` — sha8 содержимого |
| `validate [--no-corpus] [--check]` | проверки (ниже), exit ≠ 0 при ошибке; `--no-corpus` пропускает сверку `quote` с корпусом; `--check` сверяет ассет с результатом `build` |
| `apply-review <файл> [--date YYYY-MM-DD]` | применяет вердикты editor; имя файла `<порция>.r<K>.editor.json` |
| `report [--src <id>]` | сводка по статусам, подтемам и порциям, доля PASS в раунде 1; `--src` перечисляет записи со ссылками на источник |

`validate` падает, если: вопрос `air_law` не покрыт инвентарём (или инвентарь устарел); запись-сирота (ключа нет в инвентаре, кроме `retired`);
ключ повторяется; статус вне списка; у `verified/disputed` нет `refs`, `src` нет в `sources.json`, `loc` не по грамматике или нет в якорях;
`quote` длиннее 300 символов или не найден в тексте якоря (с нормализацией пробелов, кавычек, тире); у `disputed` нет `disputeNote`;
текст не из 2–4 предложений или длиннее 700 символов; хеш в журнале не совпадает с текущим содержимым; `sameAs` на неизвестный ключ;
в `topics.json` ключ в двух подтемах или не назначен ни в одну; подтема с `"complete": true` имеет ключи вне `questionKeys` выдаваемых разделов.
Хеш охватывает `text`, `refs` (с `quote`), `disputeNote`, `sameAs` (для раздела: `heading`, `body`, `refs`, `questionKeys`).

## Жизненный цикл записи
1. writer создаёт запись со статусом `draft` (стиль — `STYLE.md`, шаг S4).
2. editor проверяет по корпусу и выдаёт вердикты `PASS | FIX | DISPUTED`. Оркестратор сохраняет их в `reviews/Pnn.r1.editor.json` и выполняет
   `apply-review`, затем `build` и `validate`.
3. `PASS` → `verified`; `DISPUTED` → `disputed` (если есть `disputeNote`, иначе `unverified`); `FIX` → остаётся `draft` в раунде 1.
4. writer правит `FIX`, editor проверяет только их (раунд 2). `FIX` в раунде 2 → `unverified`. Раундов не больше двух.
5. Любая правка проверенной записи меняет хеш: запись выпадает из ассета, а `validate` требует новой проверки.

## Когда ULC обновил банк
```
python3 tool/ulc/convert.py --all
python3 tool/materials/materials.py inventory
python3 tool/materials/materials.py build
python3 tool/materials/materials.py validate
```
`validate` перечислит записи-сироты (их ключ изменился или вопрос исчез) вместе с кандидатами: новыми ключами с тем же NUMER.
Для таких пар: перенести текст на новый ключ со статусом `draft` и снова отдать editor, либо пометить старую запись `retired`.
Новые вопросы без записи остаются в сводке `report` как `none`.

## Правило про `quote`
Дословные цитаты хранятся только здесь, в `src/` и `summaries/`, для машинной проверки по корпусу. В ассет `build` их не кладёт
(в `refs` ассета только `src` и `loc`). Источники `easa`, `icao`, `itu` — только ссылки и собственный пересказ. Польские тексты Załączników (`icao_pl`) — urzędowy dokument (art. 4 pkt 2 ustawy o prawie autorskim), цитировать можно только их, не оригинал ICAO.

## Что попадает в ассет из `sources.json`
Только `title` (`title_pl`), `version` и `kind` использованных источников. Пометки владельцу (`[ПРОВЕРИТЬ …]`) живут в `terms_note` и `internal_note` и в ассет не идут; `validate` даёт ошибку, если «ПРОВЕРИТЬ» встретилось в любой строке собранного ассета. `title_pl` показывается пользователю в «Źródła» (поэтому `AIP-PL` = «AIP Polska (PANSA)», подробности в `internal_note`).
`build` (только ассет, источники `src/` не меняются): одинаковые пары (`src`, `loc`) в одном списке `refs` схлопываются (первая остаётся); `note` из `outdated` начинается с заглавной буквы.

## Тесты
`python3 -m unittest discover -s tool/materials/tests -p 'test_materials*.py'`
