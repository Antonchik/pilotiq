#!/usr/bin/env python3
"""Export the register of ULC exam questions (air law) to an Excel workbook.

The workbook is meant to be shared with ULC. It lists every question variant of the
subject with the ULC answer key, the analysis status, the legal acts the question
depends on, and the places where the key looks inconsistent with the current law.
It contains NO explanation texts and NO quotations from the acts (only locators).

Usage:
  python3 -I tool/materials/export_register.py [--out docs/ulc/rejestr-pytan-air-law.xlsx] [--date YYYY-MM-DD]

Sources of data: tool/materials/air_law/{inventory,topics}.json, air_law/src/P*.json,
tool/materials/sources.json. Needs openpyxl.
"""
import argparse
import glob
import json
import os
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

FONT = "Arial"
LICENCE_NAMES = {"ppla": "PPL(A)", "pplh": "PPL(H)", "spl": "SPL", "bpl": "BPL"}
KIND_NAMES = {
    "statute": "Akt prawa krajowego",
    "eu_reg": "Rozporządzenie UE",
    "convention": "Konwencja",
    "icao_pl": "Załącznik ICAO / dokument ICAO (tekst polski, publikacja ULC)",
    "icao": "ICAO (tekst angielski, odniesienie)",
    "easa": "EASA Easy Access Rules (odniesienie)",
    "aip": "AIP Polska (PANSA)",
    "itu": "ITU (odniesienie)",
}

ST_OK = "Podstawa prawna ustalona"
ST_DISP = "Do weryfikacji: rozbieżność z przepisami"
ST_OLD = "Oparte na nieaktualnych przepisach"
ST_NONE = "Nie ustalono podstawy prawnej"
STATUS_FILL = {
    ST_OK: "E2EFDA",
    ST_DISP: "FFE699",
    ST_OLD: "F8CBAD",
    ST_NONE: "D9D9D9",
}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


VERSION_OVERRIDES = {
    "EASA-EAR-SERA": "Easy Access Rules for SERA, wersja z sierpnia 2025",
    "EASA-EAR-AIRCREW": "Easy Access Rules for Aircrew, wersja z października 2026",
    "EASA-EAR-AIROPS": "Easy Access Rules for Air Operations, rewizja 24, marzec 2026",
    "EASA-EAR-AERODROMES": "Easy Access Rules for Aerodromes, wersja z marca 2026",
    "EASA-EAR-SAILPLANE": "Sailplane Rule Book (Easy Access Rules), publikacja z listopada 2022; starsza niż aktualne rozporządzenie skonsolidowane",
    "AIP-PL": "AIP Polska, wybrane rozdziały (AIRAC AMDT 07/26–11/26)",
    "ITU-RR-2020-AP18": "Radio Regulations 2020 (Rev. WRC-19), tylko Appendix 18",
}


def public_version(src):
    """Version text for the register without internal notes about how files were obtained."""
    import re

    if src["id"] in VERSION_OVERRIDES:
        return VERSION_OVERRIDES[src["id"]]
    v = src.get("version", "") or ""
    v = v.replace("consolidated PL text (CELLAR XHTML)", "tekst skonsolidowany (EUR-Lex)")
    v = re.sub(r";?\s*plik (dostarczony przez właściciela|ze strony ULC)[^;)]*", "", v)
    v = re.sub(r";\s*status ELI: [^;)]*", "", v)
    v = re.sub(r"\s*\(status ELI: [^)]*\)", "", v)
    v = re.sub(r"\(([^()]*?);\s*status ELI: [^()]*\)", r"(\1)", v)
    return v.strip(" ;")


def status_label(entry):
    if entry["status"] == "verified":
        return ST_OK
    if entry["status"] == "disputed":
        return ST_DISP
    if entry.get("basis") == "outdated":
        return ST_OLD
    return ST_NONE


def style_header(ws, row, ncols):
    thin = Side(style="thin", color="BFBFBF")
    for c in range(1, ncols + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = Font(name=FONT, bold=True, color="FFFFFF", size=10)
        cell.fill = PatternFill("solid", start_color="1F3864")
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        cell.border = Border(top=thin, bottom=thin, left=thin, right=thin)


def style_body(ws, first_row, last_row, ncols, wrap_cols=()):
    thin = Side(style="thin", color="D9D9D9")
    for r in range(first_row, last_row + 1):
        for c in range(1, ncols + 1):
            cell = ws.cell(row=r, column=c)
            cell.font = Font(name=FONT, size=10)
            cell.alignment = Alignment(
                wrap_text=c in wrap_cols, vertical="top"
            )
            cell.border = Border(top=thin, bottom=thin, left=thin, right=thin)


def set_widths(ws, widths):
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w


def build(out_path, date):
    inv = load(os.path.join(HERE, "air_law", "inventory.json"))
    topics = load(os.path.join(HERE, "air_law", "topics.json"))
    srcs_raw = load(os.path.join(HERE, "sources.json"))
    srcs_list = srcs_raw if isinstance(srcs_raw, list) else srcs_raw["sources"]
    srcs = {s["id"]: s for s in srcs_list}

    entries = {}
    for f in sorted(glob.glob(os.path.join(HERE, "air_law", "src", "P*.json"))):
        for e in load(f):
            entries[e["key"]] = e

    topic_of = {}
    topic_name = {}
    for t in topics:
        topic_name[t["id"]] = t["title"]["pl"]
        for k in t["order"]:
            topic_of[k] = t["id"]

    def resolve(key):
        e = entries[key]
        seen = set()
        while e.get("sameAs") and e["sameAs"] not in seen:
            seen.add(e["sameAs"])
            e = entries[e["sameAs"]]
        return e

    rows = []
    deps = []  # (key, number, src, locs, status label)
    for q in sorted(inv, key=lambda x: (x["number"], x["key"])):
        key = q["key"]
        e = resolve(key)
        label = status_label(e)
        note = ""
        if e["status"] == "disputed":
            note = e.get("disputeNote") or ""
        elif e.get("basisNote"):
            note = e["basisNote"]
        note = note.replace(" Na egzaminie ULC zaliczana jest odpowiedź z klucza.", "").strip()
        note = note[:1].upper() + note[1:]
        by_src = {}
        for r in e.get("refs") or []:
            by_src.setdefault(r["src"], [])
            if r["loc"] not in by_src[r["src"]]:
                by_src[r["src"]].append(r["loc"])
        basis = []
        for s, locs in by_src.items():
            name = srcs.get(s, {}).get("title_pl", s)
            basis.append(f"{name}: {', '.join(locs)}")
            deps.append((key, q["number"], s, "; ".join(locs), label))
        answers = q["a_pl"] + [""] * (4 - len(q["a_pl"]))
        tid = topic_of.get(key, "")
        rows.append(
            [
                q["number"],
                key.split("#", 1)[1] if "#" in key else "",
                f"{tid} {topic_name.get(tid, '')}".strip(),
                ", ".join(LICENCE_NAMES.get(l, l) for l in q["licences"]),
                q["q_pl"],
                answers[0],
                answers[1],
                answers[2],
                answers[3],
                label,
                "\n".join(basis),
                note,
            ]
        )

    wb = Workbook()

    # ---- Instrukcja
    ws0 = wb.active
    ws0.title = "Instrukcja"

    # ---- Rejestr pytań
    ws1 = wb.create_sheet("Rejestr pytań")
    head1 = [
        "Nr pytania (NUMER)",
        "Wariant (ID)",
        "Podtemat",
        "Licencje",
        "Pytanie",
        "Odpowiedź wg klucza ULC (ODP1)",
        "ODP2",
        "ODP3",
        "ODP4",
        "Status analizy",
        "Przepisy, od których zależy pytanie",
        "Uwaga",
        "Decyzja / komentarz ULC",
    ]
    ws1.append(head1)
    for r in rows:
        ws1.append(r + [""])
    style_header(ws1, 1, len(head1))
    style_body(ws1, 2, len(rows) + 1, len(head1), wrap_cols=(3, 5, 6, 7, 8, 9, 10, 11, 12, 13))
    for i in range(2, len(rows) + 2):
        lab = ws1.cell(row=i, column=10).value
        ws1.cell(row=i, column=10).fill = PatternFill(
            "solid", start_color=STATUS_FILL[lab]
        )
    set_widths(ws1, [14, 11, 28, 18, 50, 38, 28, 28, 28, 26, 55, 60, 30])
    ws1.freeze_panes = "C2"
    ws1.auto_filter.ref = f"A1:{get_column_letter(len(head1))}{len(rows) + 1}"

    # ---- Do weryfikacji
    ws2 = wb.create_sheet("Do weryfikacji")
    head2 = [
        "Nr pytania (NUMER)",
        "Wariant (ID)",
        "Licencje",
        "Pytanie",
        "Odpowiedź wg klucza ULC (ODP1)",
        "Rodzaj uwagi",
        "Przepisy",
        "Uwaga",
        "Decyzja ULC (zmiana klucza / bez zmian / usunięcie / inne)",
        "Komentarz ULC",
    ]
    ws2.append(head2)
    flagged = [r for r in rows if r[9] in (ST_DISP, ST_OLD)]
    flagged.sort(key=lambda r: (r[9] != ST_DISP, r[0], r[1]))
    for r in flagged:
        ws2.append([r[0], r[1], r[3], r[4], r[5], r[9], r[10], r[11], "", ""])
    style_header(ws2, 1, len(head2))
    style_body(ws2, 2, len(flagged) + 1, len(head2), wrap_cols=(3, 4, 5, 6, 7, 8, 9, 10))
    for i in range(2, len(flagged) + 2):
        lab = ws2.cell(row=i, column=6).value
        ws2.cell(row=i, column=6).fill = PatternFill(
            "solid", start_color=STATUS_FILL[lab]
        )
    set_widths(ws2, [14, 11, 18, 50, 38, 26, 50, 70, 30, 30])
    ws2.freeze_panes = "C2"
    ws2.auto_filter.ref = f"A1:{get_column_letter(len(head2))}{len(flagged) + 1}"

    # ---- Zależności
    ws4 = wb.create_sheet("Zależności")
    head4 = ["Klucz pytania", "Nr pytania", "Kod aktu", "Nazwa aktu", "Jednostki redakcyjne", "Status analizy"]
    ws4.append(head4)
    for key, number, s, locs, label in deps:
        ws4.append([key, number, s, srcs.get(s, {}).get("title_pl", s), locs, label])
    style_header(ws4, 1, len(head4))
    style_body(ws4, 2, len(deps) + 1, len(head4), wrap_cols=(4, 5, 6))
    set_widths(ws4, [24, 14, 26, 60, 50, 36])
    ws4.freeze_panes = "A2"
    ws4.auto_filter.ref = f"A1:F{len(deps) + 1}"
    dep_last = len(deps) + 1

    # ---- Akty prawne
    ws3 = wb.create_sheet("Akty prawne")
    head3 = [
        "Kod",
        "Nazwa",
        "Rodzaj",
        "Wersja / publikacja",
        "Stan prawny na",
        "Pobrano",
        "Adres źródła",
        "Liczba powiązanych pytań",
        "w tym: do weryfikacji",
        "w tym: nieaktualne przepisy",
        "Uwagi (np. zmiana aktu)",
    ]
    ws3.append(head3)
    used = sorted({d[2] for d in deps})
    for s in used:
        sr = srcs.get(s, {})
        r = ws3.max_row + 1
        ws3.append(
            [
                s,
                sr.get("title_pl", s),
                KIND_NAMES.get(sr.get("kind", ""), sr.get("kind", "")),
                public_version(sr) if sr else "",
                sr.get("legalState", ""),
                sr.get("fetched", ""),
                sr.get("url", ""),
                f"=COUNTIF('Zależności'!$C$2:$C${dep_last},A{r})",
                f"=COUNTIFS('Zależności'!$C$2:$C${dep_last},A{r},'Zależności'!$F$2:$F${dep_last},\"{ST_DISP}\")",
                f"=COUNTIFS('Zależności'!$C$2:$C${dep_last},A{r},'Zależności'!$F$2:$F${dep_last},\"{ST_OLD}\")",
                "",
            ]
        )
    style_header(ws3, 1, len(head3))
    style_body(ws3, 2, len(used) + 1, len(head3), wrap_cols=(2, 3, 4, 7, 11))
    set_widths(ws3, [26, 55, 30, 45, 14, 12, 45, 14, 14, 14, 40])
    ws3.freeze_panes = "C2"
    ws3.auto_filter.ref = f"A1:{get_column_letter(len(head3))}{len(used) + 1}"

    # ---- Instrukcja content
    n_last = len(rows) + 1
    lines = [
        ("Rejestr pytań egzaminacyjnych ULC: prawo lotnicze (PL010, PL099, PL100, PL102)", "title"),
        ("", None),
        ("Cel", "h"),
        (
            "Zestawienie wszystkich wariantów pytań z przedmiotu „Prawo lotnicze” wraz z przepisami, od których zależy poprawna "
            "odpowiedź. Ułatwia sprawdzanie aktualności pytań po zmianie przepisów oraz wskazuje miejsca, w których klucz "
            "odpowiedzi może wymagać weryfikacji.",
            None,
        ),
        ("", None),
        ("Skąd pochodzą pytania", "h"),
        (
            "Z plików „Przykładowe pytania egzaminacyjne” opublikowanych przez ULC (PPL(A), PPL(H), SPL, BPL; pliki z 26.07.2024). "
            "Odpowiedź ODP1 jest odpowiedzią z klucza w tych plikach. Wariantem nazywamy każdą odmienną treść pod tym samym numerem (NUMER).",
            None,
        ),
        ("", None),
        ("Jak powstała analiza", "h"),
        (
            "Treść każdej odpowiedzi porównano z tekstem aktów prawnych (arkusz „Akty prawne”). Analiza została przygotowana "
            "z pomocą narzędzi AI i niezależnej kontroli; nie została jeszcze zweryfikowana przez eksperta (instruktora). "
            "Nie jest opinią prawną ani stanowiskiem ULC. Status oznacza ocenę autora zestawienia i wymaga potwierdzenia.",
            None,
        ),
        ("", None),
        ("Statusy", "h"),
        (ST_OK + ": znaleziono przepis potwierdzający odpowiedź z klucza.", None),
        (ST_DISP + ": odpowiedź z klucza budzi wątpliwość względem aktualnego przepisu (inna odpowiedź też jest zgodna z przepisem, klucz nie oddaje przepisu w pełni albo jest z nim niezgodny). Opis w kolumnie „Uwaga”.", None),
        (ST_OLD + ": pytanie zakłada przepis, który został uchylony lub zmieniony. Opis w kolumnie „Uwaga”.", None),
        (ST_NONE + ": pytanie dotyczy wiedzy praktycznej lub nie znaleziono przepisu, który rozstrzyga odpowiedź.", None),
        ("", None),
        ("Arkusze", "h"),
        ("Rejestr pytań: wszystkie warianty, z kolumną na decyzję ULC.", None),
        ("Do weryfikacji: pytania ze statusem „Do weryfikacji” lub „Nieaktualne przepisy”, z kolumnami na decyzję i komentarz ULC.", None),
        ("Akty prawne: wykaz aktów, ich wersja i stan prawny oraz liczba pytań od nich zależnych (formuły). Po zmianie aktu wystarczy filtrować arkusz „Zależności”.", None),
        ("Zależności: jedna linia na parę pytanie–akt, z jednostkami redakcyjnymi (artykuły, punkty).", None),
        ("", None),
        ("Podsumowanie (formuły)", "h"),
    ]
    r = 1
    for text, kind in lines:
        c = ws0.cell(row=r, column=1, value=text)
        if kind == "title":
            c.font = Font(name=FONT, bold=True, size=14)
        elif kind == "h":
            c.font = Font(name=FONT, bold=True, size=11, color="1F3864")
        else:
            c.font = Font(name=FONT, size=10)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        r += 1
    summary = [
        ("Wszystkie warianty", f"=COUNTA('Rejestr pytań'!$A$2:$A${n_last})"),
        (ST_OK, f"=COUNTIF('Rejestr pytań'!$J$2:$J${n_last},\"{ST_OK}\")"),
        (ST_DISP, f"=COUNTIF('Rejestr pytań'!$J$2:$J${n_last},\"{ST_DISP}\")"),
        (ST_OLD, f"=COUNTIF('Rejestr pytań'!$J$2:$J${n_last},\"{ST_OLD}\")"),
        (ST_NONE, f"=COUNTIF('Rejestr pytań'!$J$2:$J${n_last},\"{ST_NONE}\")"),
    ]
    for label, formula in summary:
        ws0.cell(row=r, column=1, value=label).font = Font(name=FONT, size=10)
        c = ws0.cell(row=r, column=2, value=formula)
        c.font = Font(name=FONT, size=10, bold=True)
        r += 1
    r += 1
    ws0.cell(row=r, column=1, value=f"Data zestawienia: {date}").font = Font(name=FONT, size=10)
    r += 1
    ws0.cell(row=r, column=1, value="Kontakt: [imię i nazwisko, adres e-mail]").font = Font(name=FONT, size=10)
    ws0.column_dimensions["A"].width = 120
    ws0.column_dimensions["B"].width = 12

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    wb.save(out_path)
    counts = {}
    for row in rows:
        counts[row[9]] = counts.get(row[9], 0) + 1
    return len(rows), counts, len(flagged), len(deps), len(used)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "ulc", "rejestr-pytan-air-law.xlsx"))
    ap.add_argument("--date", default="2026-11-26")
    args = ap.parse_args()
    n, counts, flagged, deps, acts = build(args.out, args.date)
    print(f"{args.out}: {n} wariantów, do weryfikacji/nieaktualne {flagged}, zależności {deps}, akty {acts}")
    for k, v in counts.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    sys.exit(main())
