# STYLE.md — как писать объяснения и конспекты (air_law)

Для каждого writer порций `Pnn`/`Knn`. Формат данных и проверки — `tool/materials/README.md`, подтемы и порядок —
`tool/materials/air_law/topics.json`, состав порций — `.swarm/notes/materials-portions.md`, источники и их условия —
`.swarm/notes/materials-sources.md`. Материалы пишутся **только по-польски**. Этот файл — по-русски, примеры — по-польски.

## 1. Объяснение: форма текста (`text`)
1. **2–4 предложения**, не длиннее 700 символов. Валидатор считает предложения по `.`, `!`, `?`, `…`.
   Сокращения `art.`, `ust.`, `pkt`, `lit.`, `np.`, `m.in.`, `r.` и числа вида `1.5` предложение не рвут.
   **Рвёт** порядковое число с точкой и пробелом: «2. klasy», «1. dnia». Пишите «klasy 2», «drugiej klasy».
2. **Первое предложение — прямой ответ «почему верно»**, со ссылкой на пункт в тексте:
   «Zgodnie z art. 17 ust. 1 Prawa lotniczego …», «Zgodnie z pkt SERA.5005 lit. f) ppkt 1 rozporządzenia 923/2012 …».
   Ответ ULC должен быть узнаваем: повторите его ключевые слова или число.
3. **Не больше одного предложения о ловушке** среди неверных ответов, только когда она есть и следует из источника:
   «Pułapka: 24 miesiące dotyczą …». Не разбирайте все три неверных ответа по очереди.
4. Без воды и оценок: никаких «oczywiście», «warto pamiętać», «jak wiadomo», «należy zauważyć», «bardzo ważne», восклицаний.
5. **Терминология — как в польском тексте акта**: «dowódca statku powietrznego», «członek personelu lotniczego», «Prezes Urzędu
   Lotnictwa Cywilnego» (допустимо «Prezes ULC»), «wysokość względna/bezwzględna», «strefa kontrolowana lotniska (CTR)»,
   «orzeczenie lekarskie klasy 2». Не переводите с английского («pilot-in-command» → только «dowódca statku powietrznego»).
6. **Ни одного факта сверх источника.** Всё, что утверждает текст, должно читаться в процитированных пунктах.
   Если для ловушки нужен другой пункт, добавьте его в `refs`.
7. Не пересказывайте учебники, конспекты ATO, сайты и форумы. Своих знаний «из практики» тоже не добавляйте.

## 2. Ссылки (`refs`)
Каждая ссылка: `{"src": "<id из sources.json>", "loc": "<пункт>", "quote": "<дословно>"}`.

**`loc` — строго по грамматике** (README, раздел «Локаторы»), и пункт должен быть в `anchors/<src>.json` вместе со всеми родителями:

| вид | пример `loc` | как писать в тексте |
|---|---|---|
| `statute` (Prawo lotnicze) | `art. 17 ust. 1`, `art. 96 ust. 1 pkt 2`, `art. 87[1] ust. 1` | «art. 17 ust. 1 Prawa lotniczego» |
| `eu_reg`, статья | `art. 2 pkt 12` | «art. 2 pkt 12 rozporządzenia 923/2012» |
| `eu_reg`, правило приложения | `SERA.5005(f)(1)`, `FCL.210.A(a)`, `MED.A.045(a)(3)(i)`, `NCO.GEN.105` | «pkt SERA.5005 lit. f) ppkt 1», «MED.A.045 lit. a) ppkt 3 (i)» |
| `eu_reg`, приложение/добавление | `dodatek 3`, `załącznik I dodatek 3 pkt 13` | «dodatek 3 do załącznika do rozporządzenia 923/2012» |
| `aip` | `ENR 1.2 pkt 9`, `ENR 1.4 klasa C`, `GEN 2.2 CBA`, `ENR 5.2.1 TSA` | «AIP Polska, ENR 1.2 pkt 9» |
| `easa` (EAR, AMC/GM) | `GM1 SERA.5005(f)`, `AMC1 FCL.210.A` | «GM1 SERA.5005(f) (EASA)» |

- Ссылайтесь на **самый узкий пункт**, где лежит цитата. Если цитата целиком лежит в дочернем якоре, `validate` предупредит
  («укажите его вместо …»). Внутри AMC/GM и учебных программ (SYLLABUS) подъякорей нет: только заголовок блока.
- Номера статей Prawa lotniczego пишутся как в якорях: `87[1]`, `156zd`, `26a`.
- **`quote`**: дословно из `tool/materials/corpus/<src>.txt` внутри текста якоря, **≤ 300 символов**. Это фрагмент, на котором держится
  утверждение, а не весь пункт. Пробелы, кавычки и тире валидатор нормализует, всё остальное должно совпадать буква в букву.
  - `quote` обязателен для источников с цитатами (`statute`, `eu_reg`, `AIP-PL`) и **запрещён** для `easa` (EAR, AMC/GM):
    у них только `src` + `loc`, смысл сверяет editor.
  - Нельзя цитировать текст будущей редакции (метка `⟦PRZYSZŁA REDAKCJA⟧` и диапазоны `future` в якорях). Валидатор это отвергнет.
  - В корпусе Prawa lotniczego есть склеенные из-за выключки слова («zezwolenianaoperację»). Такой фрагмент не цитируйте,
    возьмите соседнюю фразу того же пункта.
  - `AIP-PL`: цитаты только короткие и только из польской колонки. ENR 1.1 есть лишь по-английски. В ENR 1.4 и ENR 2.1 строки PL
    и EN перемешаны: для ENR 1.4/2.1 валидатор предупредит, выбирайте польскую строку. В приложение цитаты не попадают
    (условия PANSA — [ПРОВЕРИТЬ владельцем]), поэтому текст объяснения пересказывает AIP своими словами.
- **Источники — только из корпуса** (`sources.json`, статус не `unavailable`). Конвенция чикагская (`PL-KONWENCJA-CHICAGO`)
  недоступна: ссылаться на неё нельзя, в тексте её нельзя называть основанием ответа.
- Регламенты ЕС цитируются по польской консолидированной версии из корпуса. EASA EAR (английский) — вторичный справочник для AMC/GM;
  если тот же пункт есть в польском регламенте, ссылайтесь на польский.

## 3. Когда источника нет: `unverified`, а не догадка
- Если нужный пункт не найден в корпусе, запись получает `"status": "unverified"`, `refs` может быть пустым, а `text` — пустой строкой
  или черновиком. Причина — одна строка в отчёте writer (ключ → причина). Выдумывать ссылку или «близкий» пункт нельзя.
- В `topics.json` у каждой подтемы есть `gaps.noSource` (вероятно нет нормы: общие знания, устаревшие правила, акты вне корпуса)
  и `gaps.aipNotSupplied` (нужен раздел AIP, которого владелец не дал). Это **оценка S4, не приговор**:
  - если норма для ключа из `gaps.noSource` всё же нашлась в корпусе, пишите обычную запись `draft`;
  - если не нашлась — `unverified` с причиной. Решение владельца по ключам без источника ещё не принято, тратить время на поиски
    вне корпуса не нужно.
  - Ключи из `gaps.aipNotSupplied` — `unverified` с причиной «brak sekcji AIP: ENR 1.10» (раздел из заметки), пока владелец не добавит раздел.

## 4. Спорные вопросы и `disputeNote`
Ключ ULC в банке не меняется никогда. Если текущий источник расходится с ключом ULC или защитимы два ответа:
- `text` объясняет, **на чём держится ключ ULC** (какая норма или формулировка к нему ведёт), 2–4 предложения, со ссылкой;
- `disputeNote` (1–3 предложения, ≤ 400 символов) говорит: что именно расходится, с каким пунктом (`SERA.5005 lit. f)`, `ENR 1.2 pkt 10`
  и т. п.) и что **na egzaminie ULC zaliczana jest odpowiedź z klucza**. Каждый пункт из `disputeNote` должен быть и в `refs`;
- статус пишите `draft`, окончательный `disputed` ставит editor. Не пишите «ULC się myli»: пишите, что ключ отражает
  wcześniejsze przepisy или inną interpretację.

Шаблон `disputeNote`:
> «Według aktualnego brzmienia pkt SERA.5005 lit. f) ppkt 1 rozporządzenia 923/2012 minimalna wysokość nad gęstą zabudową nie zależy
> od klasy przestrzeni powietrznej, a AIP Polska (ENR 1.2 pkt 10) określa poziomy przelotu powyżej 900 m według tabeli poziomów.
> Na egzaminie ULC zaliczana jest odpowiedź z klucza.»

(Это образец формы, а не готовый текст: факты каждого спорного ключа сверяются с корпусом заново.)

## 5. `sameAs`
Ставится, когда ключ — **тот же вопрос** по смыслу, что уже объяснённый ключ: обычно вариант `rawMixed` (польский и английский текст
в одной ячейке) или вариант с отличием только в опечатке, пунктуации, «Wszystkie odpowiedzi są prawidłowe/poprawne».
- Правильный ответ и смысл вопроса совпадают полностью, объяснение подходит без единой правки.
- Запись: `{"key": "<ключ>", "status": "draft", "sameAs": "<ключ-оригинал>"}`, без `text` и `refs`. Оригинал — в той же порции или
  уже проверен.
- Не ставьте `sameAs`, если отличаются неверные ответы, на которые ссылается ловушка, или формулировка меняет условие
  (другая klasa przestrzeni, другая wysokość, «nie» в вопросе). Тогда пишется отдельное объяснение.

## 6. Образцы объяснений (проверены валидатором по корпусу)

**Образец 1** — Prawo lotnicze (`statute`), ключ во всех четырёх лицензиях:
```json
{"key": "PL010-0327#ffde589b", "status": "draft",
 "text": "Zgodnie z art. 17 ust. 1 Prawa lotniczego Państwowa Komisja Badania Wypadków Lotniczych działa przy ministrze właściwym do spraw transportu. Jest to komisja niezależna i stała, która prowadzi lub nadzoruje badania zdarzeń lotniczych. Przepis nie przewiduje jej działania przy Prezesie Urzędu Lotnictwa Cywilnego, Radzie Ministrów ani Prezydencie RP.",
 "refs": [{"src": "PL-PRAWO-LOTNICZE", "loc": "art. 17 ust. 1",
           "quote": "Przy ministrze właściwym do spraw transportu działa niezależna, stała Państwowa Komisja Badania Wypadków Lotniczych, prowadząca lub nadzorująca badania zdarzeń lotniczych"}],
 "disputeNote": null, "sameAs": null}
```

**Образец 2** — регламент ЕС (`eu_reg`, Part-MED), с одной ловушкой; каждый факт ловушки подкреплён своей ссылкой:
```json
{"key": "PL010-0172#bb1bec5c", "status": "draft",
 "text": "Zgodnie z pkt MED.A.045 lit. a) ppkt 3 (i) rozporządzenia 1178/2011 (Part-MED) orzeczenie lekarskie klasy 2 zachowuje ważność przez 60 miesięcy, dopóki posiadacz licencji nie osiągnie wieku 40 lat. Pułapka: 24 miesiące to okres ważności orzeczenia klasy 2 dla posiadaczy w wieku między 40 a 50 lat, a 12 miesięcy dotyczy orzeczenia klasy 1.",
 "refs": [{"src": "EU-1178-2011", "loc": "MED.A.045(a)(3)(i)", "quote": "60 miesięcy, dopóki posiadacz licencji nie osiągnie wieku 40 lat"},
          {"src": "EU-1178-2011", "loc": "MED.A.045(a)(3)(ii)", "quote": "24 miesiące w przypadku posiadaczy licencji w wieku między 40 a 50 lat"},
          {"src": "EU-1178-2011", "loc": "MED.A.045(a)(1)", "quote": "Orzeczenia lekarskie 1. klasy zachowują ważność przez okres 12 miesięcy."}],
 "disputeNote": null, "sameAs": null}
```
Обратите внимание: в `quote` «1. klasy» стоит дословно, как в акте, а в `text` написано «klasy 1», иначе счётчик предложений
посчитает «1.» концом предложения.

## 7. Конспект подтемы (`summaries/<topicId>.json`)
- Файл: `{"topic": "AL11", "sections": [{"id": "AL11-1", "status": "draft", "heading": "…", "body": ["абзац", "- пункт списка"],
  "refs": [...], "questionKeys": ["…"]}]}`. Статус и проверка — по каждому разделу отдельно.
- **Раздел — 80–200 слов**, один вопрос темы (например «Minimalne wysokości lotu VFR», «Minima VMC w klasie C i G»).
  Заголовок — по-польски, коротко, без номера.
- `body`: абзацы и пункты списка («- …»). Сначала правило, потом числа и исключения. Без пересказа ключей ULC вопрос за вопросом.
- **Каждый раздел имеет `refs`** (те же правила, что у объяснений, с `quote`) и **`questionKeys`** — ключи вопросов, на которые этот
  раздел отвечает. Каждый ключ подтемы (или части в пилоте) должен стоять в `questionKeys` хотя бы одного раздела.
- **Первый раздел бесплатный** (`freeSummarySectionsPerTopic = 1`): это базовое правило подтемы, понятное без остальных.
- Спорные места в конспекте — одна фраза «Klucz ULC w pytaniach … przyjmuje …; aktualny przepis …», со ссылками; у раздела
  тогда есть `disputeNote`.

## 8. Порядок и бесплатный образец
- Порядок ключей в `topics.json` задан S4 (от базового к частному). Writer его не меняет; если порядок явно плох, пишет об этом в отчёте.
- Первые 3 ключа каждой подтемы бесплатны (`freeExplanationsPerTopic = 3`). Эти объяснения — витрина: пишите их особенно тщательно,
  без спорности и без `sameAs`.

## 9. Чек-лист самопроверки writer (перед сдачей порции)
- [ ] Каждый ключ порции имеет запись: `draft`, `unverified` (с причиной в отчёте) или `sameAs`.
- [ ] 2–4 предложения, ≤ 700 символов; нет «1. klasy»-подобных порядковых чисел с точкой.
- [ ] Первое предложение отвечает на вопрос и называет пункт; ответ ULC узнаваем.
- [ ] Не больше одной фразы о ловушке, и она подтверждена `refs`.
- [ ] Ни одного факта, которого нет в процитированных пунктах; нет «oczywiście» и воды.
- [ ] Термины — как в акте; польская грамматика, падежи после «zgodnie z» / «na podstawie».
- [ ] `loc` проходит грамматику, это самый узкий пункт; `quote` ≤ 300 символов, скопирован из корпуса, не из будущей редакции,
      без склеенных слов; у `easa` нет `quote`.
- [ ] Спорные ключи: `text` объясняет ключ ULC, `disputeNote` называет расходящийся пункт и «na egzaminie zaliczana jest odpowiedź z klucza».
- [ ] `sameAs` только для действительно того же вопроса.
- [ ] Конспект: разделы 80–200 слов, у каждого `refs` и `questionKeys`, все ключи порции покрыты.
- [ ] `python3 -I tool/materials/materials.py validate` (запускает оркестратор) — без ошибок по вашей порции.
