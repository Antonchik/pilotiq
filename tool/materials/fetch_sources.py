#!/usr/bin/env python3
"""Download the primary sources listed in sources.json and verify their SHA-256.

Downloaded files are untrusted data: they land in tool/materials/sources/<id>/
(git-ignored), one directory per source, and are never executed or imported.

Usage:
  fetch_sources.py [--id ID ...] [--pin]   download missing sources, verify the pinned hash
  fetch_sources.py --check [--id ID ...]   re-download into a temp dir and compare with the pin
                                           (exit 1 on any change or error; nothing is overwritten)

A source without a pinned sha256 is refused unless --pin is given; with --pin the hash,
size and fetch date are written into sources.json. A pinned source whose downloaded
bytes do not match the pin is never written to sources/ and the run exits non-zero.
Sources with status != "available" are skipped (they are listed as unavailable).
"""
import argparse
import datetime
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SOURCES_JSON = os.path.join(HERE, "sources.json")
DEFAULT_SOURCES_DIR = os.path.join(HERE, "sources")
MAX_BYTES = 400 * 1024 * 1024
TIMEOUT = 180
USER_AGENT = "materials-fetch/1.0"

EXIT_OK = 0
EXIT_CHANGED = 1
EXIT_MISMATCH = 2
EXIT_ERROR = 3


class FetchError(Exception):
    pass


def load_sources(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise FetchError("%s: expected a JSON array" % path)
    return data


def save_sources(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def source_path(sources_dir, src):
    return os.path.join(sources_dir, src["id"], "%s.%s" % (src["id"], src["format"]))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url, dest):
    """Download url to dest (single attempt). Returns (sha256, size)."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    h = hashlib.sha256()
    size = 0
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            status = getattr(resp, "status", 200)
            if status != 200:
                raise FetchError("%s: HTTP %s (expected 200; an anti-bot challenge answers 202 "
                                 "with an empty body)" % (url, status))
            with open(dest, "wb") as out:
                while True:
                    chunk = resp.read(1 << 20)
                    if not chunk:
                        break
                    size += len(chunk)
                    if size > MAX_BYTES:
                        raise FetchError("%s: larger than %d bytes" % (url, MAX_BYTES))
                    h.update(chunk)
                    out.write(chunk)
    except urllib.error.HTTPError as e:
        raise FetchError("%s: HTTP %s %s" % (url, e.code, e.reason))
    except urllib.error.URLError as e:
        raise FetchError("%s: %s" % (url, e.reason))
    except OSError as e:
        raise FetchError("%s: %s" % (url, e))
    if size == 0:
        raise FetchError("%s: empty response" % url)
    return h.hexdigest(), size


def check_magic(src, path):
    with open(path, "rb") as f:
        head = f.read(8)
    if src["format"] == "pdf" and not head.startswith(b"%PDF"):
        raise FetchError("%s: not a PDF (first bytes %r)" % (src["url"], head))


def selected(sources, ids):
    if not ids:
        return sources
    by_id = {s["id"]: s for s in sources}
    unknown = [i for i in ids if i not in by_id]
    if unknown:
        raise FetchError("unknown source id: %s" % ", ".join(unknown))
    return [by_id[i] for i in ids]


def is_available(src):
    return src.get("status", "available") == "available"


def cmd_fetch(sources, chosen, sources_json, sources_dir, pin, out):
    code = EXIT_OK
    changed_json = False
    for src in chosen:
        sid = src["id"]
        if not is_available(src):
            out("SKIP     %s (unavailable: %s)" % (sid, src.get("unavailable_reason", "")))
            continue
        dest = source_path(sources_dir, src)
        pinned = src.get("sha256") or ""
        if os.path.exists(dest) and pinned and sha256_file(dest) == pinned:
            out("OK       %s (already present, sha256 matches)" % sid)
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        part = dest + ".part"
        try:
            digest, size = download(src["url"], part)
            check_magic(src, part)
        except FetchError as e:
            _unlink(part)
            out("ERROR    %s: %s" % (sid, e))
            code = max(code, EXIT_ERROR)
            continue
        if pinned and digest != pinned:
            _unlink(part)
            out("MISMATCH %s: online sha256 %s != pinned %s (file not written)" % (sid, digest, pinned))
            code = max(code, EXIT_MISMATCH)
            continue
        if not pinned and not pin:
            _unlink(part)
            out("ERROR    %s: no pinned sha256 in sources.json; re-run with --pin to record %s"
                % (sid, digest))
            code = max(code, EXIT_ERROR)
            continue
        os.replace(part, dest)
        if not pinned:
            src["sha256"] = digest
            src["bytes"] = size
            src["fetched"] = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
            changed_json = True
            out("PINNED   %s sha256=%s bytes=%d" % (sid, digest, size))
        else:
            out("FETCHED  %s sha256=%s bytes=%d" % (sid, digest, size))
    if changed_json:
        save_sources(sources_json, sources)
    return code


def cmd_check(chosen, out):
    code = EXIT_OK
    tmpdir = tempfile.mkdtemp(prefix="materials-check-")
    try:
        for src in chosen:
            sid = src["id"]
            if not is_available(src):
                out("SKIP     %s (unavailable)" % sid)
                continue
            pinned = src.get("sha256") or ""
            if not pinned:
                out("ERROR    %s: not pinned" % sid)
                code = max(code, EXIT_CHANGED)
                continue
            part = os.path.join(tmpdir, sid)
            try:
                digest, _ = download(src["url"], part)
            except FetchError as e:
                out("ERROR    %s: %s" % (sid, e))
                code = max(code, EXIT_CHANGED)
                continue
            finally:
                _unlink(part)
            if digest == pinned:
                out("OK       %s unchanged" % sid)
            else:
                out("CHANGED  %s: online sha256 %s != pinned %s (norms may have changed; "
                    "re-verify affected entries)" % (sid, digest, pinned))
                code = max(code, EXIT_CHANGED)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
    return code


def _unlink(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass


def main(argv=None, out=print):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--id", action="append", default=[], help="source id (repeatable); default: all")
    ap.add_argument("--check", action="store_true", help="compare online versions with the pinned hashes")
    ap.add_argument("--pin", action="store_true", help="record sha256/size/date for sources not yet pinned")
    ap.add_argument("--sources-json", default=DEFAULT_SOURCES_JSON)
    ap.add_argument("--sources-dir", default=DEFAULT_SOURCES_DIR)
    args = ap.parse_args(argv)
    try:
        sources = load_sources(args.sources_json)
        chosen = selected(sources, args.id)
    except (FetchError, OSError, ValueError) as e:
        out("ERROR: %s" % e)
        return EXIT_ERROR
    if args.check:
        return cmd_check(chosen, out)
    return cmd_fetch(sources, chosen, args.sources_json, args.sources_dir, args.pin, out)


if __name__ == "__main__":
    sys.exit(main())
