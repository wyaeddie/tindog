"""Replace the Suspension Tuner screenshot on the Whole Stack Solutions Projects page.

    # 1. look first (changes nothing):
    python3 tools/update_website_image.py --site "/Volumes/MyDrive/Whole Stack Solutions" --image suspension-tuner.png
    # 2. then apply:
    python3 tools/update_website_image.py --site "/Volumes/MyDrive/Whole Stack Solutions" --image suspension-tuner.png --apply

It finds the Projects page (an .html/.htm/.php file whose name or <title> mentions "project"),
finds the <img> used in the Suspension Tuner card, backs the old image up next to it
(<name>.backup-YYYYMMDD-HHMM.<ext>) and writes the new image in its place, resized to the old
image's width so the page layout doesn't change. Transparency is kept: if the old image was a
JPEG (which can't be transparent) the new one is saved as PNG and the page's src is updated
(the page is backed up first too). Needs Pillow:  pip3 install pillow
"""
import argparse
import datetime
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

PAGE_EXTS = {".html", ".htm", ".php"}
NEEDLE = re.compile(r"suspension[\s\-_]*tuner", re.I)
IMG = re.compile(r"<img\b[^>]*>", re.I | re.S)
SRC = re.compile(r"""\bsrc\s*=\s*(["'])(.*?)\1""", re.I | re.S)
SKIP_DIRS = {"node_modules", ".git", "vendor", "dist-cache"}


def find_project_pages(site: Path):
    pages = []
    for p in site.rglob("*"):
        if p.suffix.lower() not in PAGE_EXTS or any(part in SKIP_DIRS for part in p.parts):
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        title = re.search(r"<title>(.*?)</title>", text, re.I | re.S)
        is_projects = "project" in p.name.lower() or (title and "project" in title.group(1).lower())
        if NEEDLE.search(text):
            pages.append((0 if is_projects else 1, p, text))
    return [(p, t) for _, p, t in sorted(pages, key=lambda x: (x[0], str(x[1])))]


def find_image_tag(text: str):
    """The <img> closest to a 'Suspension Tuner' mention (alt/src naming it wins outright)."""
    imgs = list(IMG.finditer(text))
    for m in imgs:
        if NEEDLE.search(m.group(0)):
            return m
    mentions = [m.start() for m in NEEDLE.finditer(text)]
    best, best_dist = None, 4000          # only accept images within ~4000 chars of the mention
    for m in imgs:
        for pos in mentions:
            d = abs(m.start() - pos)
            if d < best_dist:
                best, best_dist = m, d
    return best


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--site", required=True, help="website folder, e.g. '/Volumes/MyDrive/Whole Stack Solutions'")
    ap.add_argument("--image", required=True, help="new image (transparent PNG from web_screenshot.py)")
    ap.add_argument("--apply", action="store_true", help="actually make the change (default: just report)")
    args = ap.parse_args()

    site, new_image = Path(args.site).expanduser(), Path(args.image).expanduser()
    if not site.is_dir():
        sys.exit(f"✗ Website folder not found: {site}\n  Tip: in Finder, drag the folder into Terminal to paste its exact path.")
    if not new_image.is_file():
        sys.exit(f"✗ New image not found: {new_image}")

    pages = find_project_pages(site)
    if not pages:
        sys.exit("✗ No page in that folder mentions 'Suspension Tuner'.")
    page, text = pages[0]
    tag = find_image_tag(text)
    if not tag:
        sys.exit(f"✗ Found {page} but no <img> near the Suspension Tuner text.")
    src_match = SRC.search(tag.group(0))
    src = src_match.group(2) if src_match else ""
    if not src or src.startswith(("http://", "https://", "data:")):
        sys.exit(f"✗ The image tag uses '{src[:60]}', not a file in the folder — replace it by hand:\n  {tag.group(0)}")

    clean_src = src.split("?")[0].split("#")[0]
    old_path = (site / clean_src.lstrip("/")) if clean_src.startswith("/") else (page.parent / clean_src)
    old_path = old_path.resolve()

    print(f"Page:      {page}")
    print(f"Image tag: {' '.join(tag.group(0).split())}")
    print(f"Old image: {old_path}" + ("" if old_path.exists() else "  (missing)"))

    new = Image.open(new_image).convert("RGBA")
    target_w = new.width
    if old_path.exists():
        with Image.open(old_path) as old:
            print(f"           {old.width}×{old.height} {old.mode}")
            target_w = old.width
    if target_w != new.width:
        new = new.resize((target_w, round(new.height * target_w / new.width)), Image.LANCZOS)
    print(f"New image: {new.width}×{new.height} with transparent background")

    keeps_alpha = old_path.suffix.lower() in {".png", ".webp"}
    out_path = old_path if keeps_alpha else old_path.with_suffix(".png")
    if not keeps_alpha:
        print(f"Note:      {old_path.suffix} can't be transparent → saving as {out_path.name} and updating the page")

    if not args.apply:
        print("\nNothing changed. Re-run with --apply to replace the image.")
        return

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M")
    if old_path.exists():
        backup = old_path.with_name(f"{old_path.stem}.backup-{stamp}{old_path.suffix}")
        shutil.copy2(old_path, backup)
        print(f"Backed up old image → {backup.name}")
    new.save(out_path, optimize=True)
    print(f"✓ Wrote {out_path}")

    if out_path != old_path:
        page_backup = page.with_name(f"{page.stem}.backup-{stamp}{page.suffix}")
        shutil.copy2(page, page_backup)
        new_src = src.replace(Path(clean_src).name, out_path.name, 1)
        new_tag = tag.group(0).replace(src, new_src, 1)
        page.write_text(text[: tag.start()] + new_tag + text[tag.end():], encoding="utf-8")
        print(f"✓ Updated src in {page.name} (backup: {page_backup.name})")
    print("Open the page in your browser and refresh (⌘⇧R) to check it.")


if __name__ == "__main__":
    main()
