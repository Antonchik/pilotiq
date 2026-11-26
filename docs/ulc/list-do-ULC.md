# Письмо в ULC (черновик на польском)

Адрес: lke@ulc.gov.pl (так указано в `docs/release-checklist.md`, раздел 3.1; проверьте, что это актуальный адрес Komisji Egzaminacyjnej).
Вложение: `docs/ulc/rejestr-pytan-air-law.xlsx` (собирается скриптом `tool/materials/export_register.py`).
Места в квадратных скобках заполняет автор письма.

---

**Temat:** Prośba o stanowisko w sprawie wykorzystania przykładowych pytań egzaminacyjnych oraz uwagi do kluczy odpowiedzi (prawo lotnicze)

Szanowni Państwo,

nazywam się [imię i nazwisko] i jestem autorem aplikacji mobilnej Pilotiq (Android, iOS), przeznaczonej do nauki do teoretycznego egzaminu ULC na licencje PPL(A), PPL(H), SPL i BPL. Aplikacja jest niezależna i nie jest w żaden sposób powiązana z ULC ani z EASA. Część jej funkcji jest odpłatna (plan Premium). Piszę z trzema sprawami: prośbą o stanowisko, kilkoma pytaniami o bazę pytań oraz uwagami do kluczy odpowiedzi, które zebrałem przy przygotowaniu materiałów do nauki.

**1. Prośba o stanowisko w sprawie wykorzystania pytań**

Aplikacja zawiera pytania z plików „Przykładowe pytania egzaminacyjne” opublikowanych na stronie ULC (pliki PPL(A), PPL(H), SPL i BPL, utworzone 26.07.2024), w oryginalnym brzmieniu. W aplikacji podaję źródło i datę bazy oraz informację, że aplikacja nie jest powiązana z ULC. Na stronie nie znalazłem warunków dotyczących takiego wykorzystania. Uprzejmie proszę o odpowiedź:

- czy ULC wyraża zgodę na wykorzystanie opublikowanych pytań w aplikacji, w której część funkcji jest odpłatna;
- jeśli tak, na jakich warunkach (np. wskazanie źródła, zakaz zmiany treści pytań i odpowiedzi, aktualizowanie po zmianie bazy);
- jeśli nie, czego dotyczy zastrzeżenie i w jaki sposób mogę z pytań korzystać.

**2. Pytania o bazę pytań**

- Czy opublikowane pliki odpowiadają Krajowemu Bankowi Pytań stosowanemu na egzaminie, czy są jego częścią lub wersją przykładową?
- Czy ULC publikuje listę zmian w bazie lub planuje kolejną aktualizację plików? Chętnie będę aktualizował aplikację po każdej zmianie.
- Czy na egzaminach nadal stosuje się pytania oparte na przepisach uchylonych lub zmienionych? W opublikowanych plikach są takie pytania, np. powołujące się na rozporządzenie MI z 9.10.2003 r. w sprawie ograniczeń lotów, które zostało uchylone.

**3. Uwagi do kluczy odpowiedzi**

Zestawiłem 982 warianty pytań z przedmiotu „Prawo lotnicze” z aktami prawnymi, na których się opierają. W załączonym pliku Excel (rejestr) wskazuję:

- 82 warianty, w których klucz odpowiedzi może być niezgodny z aktualnym przepisem albo więcej niż jedna odpowiedź jest zgodna z przepisem;
- 107 wariantów, które opierają się na przepisach uchylonych lub zmienionych;
- wykaz aktów prawnych, od których zależą pytania (arkusze „Akty prawne” i „Zależności”), co może ułatwić sprawdzanie aktualności pytań po zmianie przepisów.

Zaznaczam, że analiza została przygotowana z użyciem narzędzi AI i nie została jeszcze zweryfikowana przez eksperta merytorycznego, więc proszę traktować ją jako sygnał do sprawdzenia, a nie jako stanowisko. Możliwe też, że część uwag dotyczy wersji pytań już poprawionej. Przykłady:

- **Minimalne wysokości lotów VFR.** PL010-0446 i PL010-0452 (warianty b66d2091 i fb09d002): pytanie dotyczy lotu VFR powyżej 900 m nad terenem w FIR Warszawa, a w kluczu jest „wysokość bezwzględna 300 m”. Według SERA.5005 lit. g) i AIP ENR 1.2 pkt 10 powyżej 900 m nad ziemią obowiązują poziomy z tabeli w dodatku 3. W wariancie 62407f64 pytania PL010-0452 (klasa A, lasy) klucz „300 m” jest niezgodny z SERA.5005 lit. f) ppkt 2 (150 m), a w klasie A dozwolone są wyłącznie loty IFR (SERA.6001 lit. a) ppkt 1). Podobne uwagi dotyczą pozostałych pytań z serii PL010-0438…0452.
- **Zarządzanie przestrzenią powietrzną.** To samo pytanie „Na czym polega zarządzanie przestrzenią powietrzną?” ma różne klucze w różnych wariantach: PL010-0161 (199151b9): „przydział elementów przestrzeni powietrznej użytkownikom”, PL010-0161 (352f1e5b): „optymalizacja natężenia ruchu lotniczego”, PL010-0162 (b1693ba4): „Żadna z odpowiedzi nie jest prawidłowa”. Definicja w art. 2 pkt 12 rozporządzenia (UE) 2024/2803 jest bliższa pierwszej odpowiedzi, a zgodność natężenia ruchu z przepustowością należy do zarządzania przepływem ruchu lotniczego (art. 2 pkt 8).
- **Ograniczenia lotów nad miastami.** PL010-0244 (e370aaec): pytanie powołuje się na uchylone rozporządzenie z 9.10.2003 r., a klucz „500 m” dotyczy lotu samolotu z silnikiem innym niż tłokowy nad miastem o 25–50 tys. mieszkańców. Według § 3 ust. 1 pkt 2 lit. a rozporządzenia z 5.03.2019 r. (t.j. Dz.U. 2025 poz. 947) dla takich samolotów obowiązuje 1000 m.
- **Skład personelu załóg.** PL010-0491 (85063041) i PL010-0492 (ee529e21): w kluczu jest „dyspozytor lotniczy” oraz „kontroler ruchu lotniczego”, a art. 94 ust. 6 pkt 1 Prawa lotniczego ich nie wymienia (to odrębne specjalności z pkt 5 i 4). W innym wariancie pytania PL010-0491 kluczem jest „Żadna z odpowiedzi nie jest prawidłowa”.
- **Odwołanie od orzeczenia komisji lekarskiej.** PL010-0050 (5482a1de): klucz „do Naczelnego Lekarza, a w szczególnych przypadkach do Prezesa ULC”. Według art. 106 ust. 4 Prawa lotniczego Prezes w szczególnych przypadkach sam może złożyć odwołanie, a nie rozpatruje go (art. 106 ust. 3, art. 107 ust. 1 pkt 1). Inny wariant (ce6170e3) ma klucz „do Naczelnego Lekarza Lotnictwa Cywilnego”.
- **Zmiana prędkości w locie.** PL010-0399 (f1407309): w pytaniu jest próg 5%, a według SERA.8020 lit. b) ppkt 3 jest to co najmniej ±0,02 Macha lub 19 km/h (10 kt) prędkości rzeczywistej.
- **Ważność raportu o zdarzeniu.** PL099-0067: nie znalazłem przepisu o „ważności” raportu o zdarzeniu. Klucz „złoży go jeden członek załogi” częściowo odpowiada art. 4 ust. 6 lit. a rozporządzenia (UE) 376/2014.

Pełna lista, z podaniem przepisów i kolumnami na Państwa decyzję i komentarz, znajduje się w arkuszu „Do weryfikacji”. Zestawienie udostępniam ULC bez ograniczeń [potwierdzić przed wysłaniem]. Jeśli będzie przydatne, mogę je aktualizować po zmianach przepisów lub bazy pytań.

Dziękuję za poświęcony czas i będę wdzięczny za odpowiedź, także krótką.

Z poważaniem
[imię i nazwisko]
[adres e-mail]
[telefon, opcjonalnie]

Załącznik: rejestr-pytan-air-law.xlsx
