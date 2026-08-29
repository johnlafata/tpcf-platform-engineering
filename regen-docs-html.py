#!/usr/bin/env python3
"""
regen-docs-html.py

Regenerates a .html companion next to every .md file in this repo, so docs
are readable by double-clicking (opens in the default browser) on a Windows
jumphost with no Markdown-aware application associated with .md files.

Pure Python standard library only -- no pip installs, no pandoc, no
PowerShell. Supports the subset of Markdown actually used in this repo's
docs: headers, paragraphs, **bold**, *italic*, `inline code`, fenced code
blocks, GFM pipe tables, bullet/numbered/task lists, blockquotes,
horizontal rules, links (incl. auto-linked bare URLs), and images.

Usage:
    python regen-docs-html.py [root-dir]
    (or just run regen-docs-html.bat, which calls this from the repo root)

If root-dir is omitted, the current directory is used. Every *.md file
under root-dir is converted, except anything under a ".git" directory.
Internal links from one .md file to another are rewritten to point at the
sibling .html file instead, so clicking through between generated pages
works in a browser.

Markdown is the source of truth -- re-run this after editing any .md file.
"""

import html
import os
import re
import sys

CSS = """
body {
  font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
  max-width: 900px;
  margin: 2rem auto;
  padding: 0 1.5rem;
  line-height: 1.6;
  color: #1a1a1a;
}
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin-top: 1.8em; }
h1 { border-bottom: 2px solid #ddd; padding-bottom: 0.3em; }
h2 { border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
code {
  font-family: Consolas, "Courier New", monospace;
  background: #f3f3f3;
  padding: 0.15em 0.4em;
  border-radius: 3px;
  font-size: 0.92em;
}
pre {
  background: #f6f8fa;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 1em;
  overflow-x: auto;
}
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 0.5em 0.8em; text-align: left; }
th { background: #f6f8fa; }
blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 1em; color: #555; }
a { color: #0969da; }
hr { border: none; border-top: 1px solid #ddd; margin: 2em 0; }
img { max-width: 100%; }
"""

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>{title}</title>
<style>{css}</style>
</head>
<body>
{body}
</body>
</html>
"""

# ---------------------------------------------------------------------------
# Inline formatting (applied within a single block of text: paragraph,
# heading, list item, table cell, blockquote line)
# ---------------------------------------------------------------------------

INLINE_CODE_RE = re.compile(r"`([^`]+?)`")
IMAGE_RE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
BOLD_ITALIC_RE = re.compile(r"\*\*\*(.+?)\*\*\*")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
ITALIC_RE = re.compile(r"\*(.+?)\*")
BARE_URL_RE = re.compile(r"(?<![\"'(>])(https?://[^\s<>\")]+)")


def rewrite_md_link(target):
    """Point links at sibling .md files to the generated .html instead."""
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", target):
        return target  # absolute URL, leave alone
    m = re.match(r"^([^#]*)\.md(#.*)?$", target, re.IGNORECASE)
    if m:
        return f"{m.group(1)}.html{m.group(2) or ''}"
    return target


def format_inline(text):
    """Escape HTML, then apply inline Markdown formatting."""
    text = html.escape(text, quote=False)

    # Protect inline code spans first so formatting chars inside them
    # (e.g. CF_GROUPS_FILE, **not** bold) are left alone.
    code_spans = []

    def stash_code(m):
        code_spans.append(m.group(1))
        return f"\x00CODE{len(code_spans) - 1}\x00"

    text = INLINE_CODE_RE.sub(stash_code, text)

    # Images before links (images use a leading "!").
    text = IMAGE_RE.sub(lambda m: f'<img src="{m.group(2)}" alt="{m.group(1)}" />', text)

    # Links -- rewrite .md targets to .html.
    def link_repl(m):
        label, target = m.group(1), m.group(2)
        return f'<a href="{rewrite_md_link(target)}">{label}</a>'

    text = LINK_RE.sub(link_repl, text)

    # Bare URLs not already inside an <a> tag we just made.
    parts = re.split(r"(<a href=.*?</a>)", text)
    for i, part in enumerate(parts):
        if not part.startswith("<a "):
            parts[i] = BARE_URL_RE.sub(lambda m: f'<a href="{m.group(1)}">{m.group(1)}</a>', part)
    text = "".join(parts)

    text = BOLD_ITALIC_RE.sub(r"<strong><em>\1</em></strong>", text)
    text = BOLD_RE.sub(r"<strong>\1</strong>", text)
    text = ITALIC_RE.sub(r"<em>\1</em>", text)

    # Restore code spans (already HTML-escaped above).
    def restore_code(m):
        return f"<code>{code_spans[int(m.group(1))]}</code>"

    text = re.sub(r"\x00CODE(\d+)\x00", restore_code, text)

    # Hard line break: trailing two-plus spaces, or a trailing backslash.
    text = re.sub(r"( {2,}|\\)$", "<br />", text)

    return text


def strip_md(text):
    """Plain-text version of a heading, for slug generation."""
    text = INLINE_CODE_RE.sub(r"\1", text)
    text = IMAGE_RE.sub(r"\1", text)
    text = LINK_RE.sub(r"\1", text)
    text = re.sub(r"[*_]", "", text)
    return text


def slugify(text):
    text = strip_md(text).lower()
    text = re.sub(r"[^a-z0-9 -]", "", text)
    text = re.sub(r"\s+", "-", text.strip())
    text = re.sub(r"-{2,}", "-", text)
    return text


# ---------------------------------------------------------------------------
# Block-level parser
# ---------------------------------------------------------------------------

FENCE_RE = re.compile(r"^(```|~~~)\s*([\w+-]*)\s*$")
ATX_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
HR_RE = re.compile(r"^ {0,3}([-*_])( *\1){2,} *$")
TABLE_SEP_RE = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
UL_RE = re.compile(r"^(\s*)([-*+])\s+(.*)$")
OL_RE = re.compile(r"^(\s*)(\d+)[.)]\s+(.*)$")
TASK_RE = re.compile(r"^\[([ xX])\]\s+(.*)$")
BLOCKQUOTE_RE = re.compile(r"^\s{0,3}>\s?(.*)$")


def parse_table(lines, i):
    header_cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
    rows = []
    j = i + 2
    while j < len(lines) and "|" in lines[j] and lines[j].strip():
        rows.append([c.strip() for c in lines[j].strip().strip("|").split("|")])
        j += 1
    out = ["<table>", "<thead>", "<tr>"]
    for c in header_cells:
        out.append(f"<th>{format_inline(c)}</th>")
    out += ["</tr>", "</thead>", "<tbody>"]
    for row in rows:
        out.append("<tr>")
        for c in row:
            out.append(f"<td>{format_inline(c)}</td>")
        out.append("</tr>")
    out += ["</tbody>", "</table>"]
    return "\n".join(out), j


def list_item_html(text):
    m = TASK_RE.match(text)
    if m:
        box = "☑" if m.group(1).lower() == "x" else "☐"
        return f"{box} {format_inline(m.group(2))}"
    return format_inline(text)


def parse_list(lines, i, item_re, tag):
    items = []
    while i < len(lines):
        m = item_re.match(lines[i])
        if not m:
            break
        text = m.group(3)
        i += 1
        # Fold in indented continuation lines belonging to this item.
        while i < len(lines) and lines[i].strip() and (lines[i].startswith("  ") or lines[i].startswith("\t")) \
                and not item_re.match(lines[i]):
            text += " " + lines[i].strip()
            i += 1
        items.append(list_item_html(text))
    out = [f"<{tag}>"]
    out += [f"<li>{item}</li>" for item in items]
    out.append(f"</{tag}>")
    return "\n".join(out), i


def markdown_to_html(md_text):
    lines = md_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out = []
    para = []
    i = 0
    n = len(lines)
    seen_slugs = {}

    def unique_slug(text):
        base = slugify(text)
        if base not in seen_slugs:
            seen_slugs[base] = 0
            return base
        seen_slugs[base] += 1
        return f"{base}-{seen_slugs[base]}"

    def flush_para():
        if para:
            out.append(f"<p>{format_inline(' '.join(para))}</p>")
            para.clear()

    while i < n:
        line = lines[i]

        if not line.strip():
            flush_para()
            i += 1
            continue

        fence_m = FENCE_RE.match(line)
        if fence_m:
            flush_para()
            lang = fence_m.group(2)
            i += 1
            code_lines = []
            while i < n and not FENCE_RE.match(lines[i]):
                code_lines.append(lines[i])
                i += 1
            i += 1  # skip closing fence
            code = html.escape("\n".join(code_lines), quote=False)
            cls = f' class="language-{lang}"' if lang else ""
            out.append(f"<pre><code{cls}>{code}</code></pre>")
            continue

        atx_m = ATX_RE.match(line)
        if atx_m:
            flush_para()
            level = len(atx_m.group(1))
            text = atx_m.group(2)
            out.append(f'<h{level} id="{unique_slug(text)}">{format_inline(text)}</h{level}>')
            i += 1
            continue

        if HR_RE.match(line) and not TABLE_SEP_RE.match(line):
            flush_para()
            out.append("<hr />")
            i += 1
            continue

        if i + 1 < n and "|" in line and TABLE_SEP_RE.match(lines[i + 1]):
            flush_para()
            table_html, i = parse_table(lines, i)
            out.append(table_html)
            continue

        if UL_RE.match(line):
            flush_para()
            list_html, i = parse_list(lines, i, UL_RE, "ul")
            out.append(list_html)
            continue

        if OL_RE.match(line):
            flush_para()
            list_html, i = parse_list(lines, i, OL_RE, "ol")
            out.append(list_html)
            continue

        bq_m = BLOCKQUOTE_RE.match(line)
        if bq_m:
            flush_para()
            bq_lines = []
            while i < n and BLOCKQUOTE_RE.match(lines[i]):
                bq_lines.append(BLOCKQUOTE_RE.match(lines[i]).group(1))
                i += 1
            inner = markdown_to_html("\n".join(bq_lines))
            out.append(f"<blockquote>\n{inner}\n</blockquote>")
            continue

        para.append(line.strip())
        i += 1

    flush_para()
    return "\n".join(out)


def convert_file(md_path, root):
    with open(md_path, "r", encoding="utf-8", errors="replace") as f:
        md_text = f.read()
    body = markdown_to_html(md_text)
    title = os.path.splitext(os.path.basename(md_path))[0]
    page = HTML_TEMPLATE.format(title=html.escape(title, quote=False), css=CSS, body=body)
    html_path = os.path.splitext(md_path)[0] + ".html"
    with open(html_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    return html_path


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    root = os.path.abspath(root)
    converted = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for fn in filenames:
            if fn.lower().endswith(".md"):
                md_path = os.path.join(dirpath, fn)
                html_path = convert_file(md_path, root)
                converted.append(os.path.relpath(html_path, root))
    print(f"Converted {len(converted)} file(s):")
    for c in sorted(converted):
        print(f"  {c}")


if __name__ == "__main__":
    main()
