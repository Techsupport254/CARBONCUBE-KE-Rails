#!/usr/bin/env python3
"""Merge catalog expansion staging files into the *_filtered.json catalogs.

Append-only expansion plus non-destructive repairs:
  - append items from output/expansion/*.json (dedupe by slug + normalized title)
  - backfill missing `slug` (slugified title) so items appear in model dropdowns
  - relabel data `subcategory` values to the post-migration taxonomy names
  - relocate laptop-schema rows out of phones_filtered.json into laptops_filtered.json
  - drop clearly misplaced/empty rows (feature phones in watches, a laptop in
    tablets, empty-title Apple rows in phones)
  - fix known data defects: Case IH double-brand titles, concatenated
    imperial+metric spec values in agriculture, verbatim hardware duplicates

Usage: python3 merge_catalog_expansion.py [--dry-run]
"""

import json
import os
import re
import sys
from collections import Counter

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
DRY_RUN = "--dry-run" in sys.argv
_stage_dirs = [a for a in sys.argv[1:] if not a.startswith("-")]
EXPANSION_DIRS = [os.path.join(OUTPUT_DIR, d) for d in (_stage_dirs or ["expansion"])]


def slugify(title):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", str(title).lower())).strip("_")


def load(path):
    with open(path) as f:
        return json.load(f)


def save(name, data):
    path = os.path.join(OUTPUT_DIR, name)
    if DRY_RUN:
        return
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def load_expansion(name):
    items = []
    found = False
    for d in EXPANSION_DIRS:
        path = os.path.join(d, name)
        if os.path.exists(path):
            found = True
            items += load(path)
    if not found:
        print(f"  ! no staging file {name} (skipped)")
    return items


def norm_title(t):
    return re.sub(r"\s+", " ", str(t or "").lower()).strip()


def dedupe_and_slug(items, stats_label):
    """Dedupe by slug then by normalized title+brand; backfill slugs."""
    seen_slugs = set()
    seen_titles = set()
    out = []
    dup_slug = dup_title = slug_filled = 0
    for item in items:
        title = norm_title(item.get("title"))
        brand = norm_title(item.get("brand"))
        slug = str(item.get("slug") or "").strip()

        if slug and slug in seen_slugs:
            dup_slug += 1
            continue
        if (title, brand) in seen_titles:
            dup_title += 1
            continue
        if not slug:
            slug = slugify(title)
            if not slug:
                continue  # untitled junk — drop
            base, n = slug, 2
            while slug in seen_slugs:
                slug = f"{base}_{n}"
                n += 1
            item["slug"] = slug
            slug_filled += 1
        seen_slugs.add(slug)
        seen_titles.add((title, brand))
        out.append(item)
    print(f"  {stats_label}: -{dup_slug} dup slugs, -{dup_title} dup titles, +{slug_filled} backfilled slugs")
    return out


def merge(name, expansion_file=None, transform=None):
    """Load file, apply per-item transform, merge expansion items, dedupe."""
    path = os.path.join(OUTPUT_DIR, name)
    data = load(path)
    before = len(data)

    if transform:
        data = [x for x in (transform(i) for i in data) if x is not None]
        print(f"  {name}: transform {before} -> {len(data)}")

    additions = load_expansion(expansion_file) if expansion_file else []
    if additions:
        existing_keys = {(norm_title(i.get("title")), norm_title(i.get("brand"))) for i in data}
        existing_slugs = {i.get("slug") for i in data if i.get("slug")}
        kept = []
        for item in additions:
            item.setdefault("slug", slugify(item.get("title")))
            if (norm_title(item.get("title")), norm_title(item.get("brand"))) in existing_keys or item["slug"] in existing_slugs:
                continue
            kept.append(item)
            existing_keys.add((norm_title(item.get("title")), norm_title(item.get("brand"))))
            existing_slugs.add(item["slug"])
        print(f"  {name}: +{len(kept)} appended ({len(additions) - len(kept)} skipped as dupes)")
        data += kept

    data = dedupe_and_slug(data, name)
    save(name, data)
    return data


# ---------------- per-file transforms ----------------

PHONE_BRAND_FIX = {
    # scraper brand-offset bug: brand field -> actual brand in title
    "hmd": "Cubot",
    "poco": "HMD",
    "motorola": "Mitsubishi",
    "casio": "NEC",
    "intex": "Archos",
    "virgin": "i-mate",
}
LAPTOP_SPEC_SIG = ("Model Name", "Processor")
moved_laptops = []


def phone_item(item):
    title = str(item.get("title") or "").strip()
    if not title or title == "(Core 2 Duo)":
        return None  # junk Apple rows
    spec = item.get("specifications") or {}
    if not item.get("gsmarena_url") and any(k in spec for k in LAPTOP_SPEC_SIG):
        moved_laptops.append(item)
        return None  # relocate to laptops_filtered.json
    brand_key = str(item.get("brand") or "").strip().lower()
    fixed = PHONE_BRAND_FIX.get(brand_key)
    if fixed and title.lower().startswith(fixed.lower()):
        item["brand"] = fixed
        if str(item.get("manufacturer") or "").strip().lower() == brand_key:
            item["manufacturer"] = fixed
    return item


SUB_RELABEL = {
    "automotive_filtered.json": {
        "spare parts": "Automotive Spare Parts",
        "accessories": "Automotive Accessories",
    },
    "agriculture_filtered.json": {
        "spare parts": "Agriculture Spare Parts",
        "accessories": "Agriculture Accessories",
    },
    "electronics_accessories_filtered.json": {
        "projectors": "Projectors & Screens",
        "printers": "Printers",
        "copiers": "Copiers",
        "scanners": "Scanners",
        "pos systems": "POS Systems",
        "shredders": "Shredders",
    },
}


def relabeler(filename):
    mapping = SUB_RELABEL.get(filename, {})

    def _t(item):
        sub = norm_title(item.get("subcategory"))
        if sub in mapping:
            item["subcategory"] = mapping[sub]
        return item

    return _t


CONCAT_RE = re.compile(r"^(\d[\d.,]*\s*[A-Za-z°/%\"' ()]+?)(\d[\d.,]+\s*[A-Za-z°/%\"' ()]+)$")


def agriculture_item(item):
    title = str(item.get("title") or "")
    if "Case IH CaseIH" in title:
        item["title"] = title.replace("Case IH CaseIH", "Case IH")
    specs = item.get("specifications") or {}
    for k, v in specs.items():
        if isinstance(v, str):
            m = CONCAT_RE.match(v)
            if m:
                specs[k] = f"{m.group(1).strip()} / {m.group(2).strip()}"
    return relabeler("agriculture_filtered.json")(item)


WATCH_DROP_TITLES = {
    "samsung galaxy view2",
    "samsung galaxy fit s5670",
    "samsung w169 duos",
    "samsung w259 duos",
    "samsung w299 duos",
    "samsung watch phone",
}


def watch_item(item):
    title = norm_title(item.get("title"))
    if title in WATCH_DROP_TITLES:
        return None
    spec = item.get("specifications") or {}
    if not item.get("gsmarena_url") and ("Processor" in spec or "Model Name" in spec):
        return None  # laptop/tablet rows scraped in by mistake
    return item


def tablet_item(item):
    spec = item.get("specifications") or {}
    if not item.get("gsmarena_url") and ("Model Name" in spec or "Processor" in spec):
        return None  # ASUS TUF laptop row
    return item


def tv_item(item):
    if norm_title(item.get("brand")) == "vizio":
        return None  # US-only brand, not sold in Kenya
    if norm_title(item.get("category")) == "tvs & home entertainment":
        item["category"] = "TVs & Audio and Electronics"
    if not item.get("subcategory"):
        disp = norm_title((item.get("specifications") or {}).get("Display Type", ""))
        if any(t in disp for t in ("oled", "qled", "qd-oled", "mini-led", "mini led")):
            item["subcategory"] = "OLED & QLED TVs"
        else:
            item["subcategory"] = "LED & LCD TVs"
    return item


def laptop_item(item):
    if norm_title(item.get("brand")) == "dynabook toshiba":
        item["brand"] = "Toshiba"
    return item


# ---------------- run ----------------

def main():
    print("=== phones_filtered.json ===")
    merge("phones_filtered.json", "phones.json", transform=phone_item)

    if moved_laptops:
        print(f"=== laptops_filtered.json (+{len(moved_laptops)} relocated laptop rows) ===")
        path = os.path.join(OUTPUT_DIR, "laptops_filtered.json")
        data = load(path)
        data.extend(moved_laptops)
        if not DRY_RUN:
            with open(path, "w") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")

    jobs = [
        ("laptops_filtered.json", "laptops.json", laptop_item),
        ("computers_filtered.json", "computers.json", None),
        ("computer_accessories_filtered.json", "computer_accessories.json", None),
        ("tablets_filtered.json", "tablets.json", tablet_item),
        ("watches_filtered.json", "watches.json", watch_item),
        ("tvs_filtered.json", "tvs.json", tv_item),
        ("tv_audio_streaming_filtered.json", "tv_audio_streaming.json", relabeler("tv_audio_streaming_filtered.json")),
        ("electronics_accessories_filtered.json", "electronics_accessories.json", relabeler("electronics_accessories_filtered.json")),
        ("automotive_filtered.json", "automotive.json", relabeler("automotive_filtered.json")),
        ("filtration_filtered.json", "filtration.json", None),
        ("agriculture_filtered.json", "agriculture.json", agriculture_item),
        ("hardware_tools_filtered.json", "hardware.json", None),
        ("ipads_filtered.json", None, None),
    ]
    for name, expansion, transform in jobs:
        print(f"=== {name} ===")
        merge(name, expansion, transform=transform)

    print("\nDone." + (" (dry run — nothing written)" if DRY_RUN else ""))


if __name__ == "__main__":
    main()
