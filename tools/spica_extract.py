#!/usr/bin/env python3
"""원안 기획서(Spica_v0.9.docx)에서 표와 문단과 이미지 목록을 꺼낸다.

원안은 저자 자산이라 저장소에 커밋하지 않는다(docs/design/.gitignore). 그래서
"기획서에 무엇이 있었나"를 되묻는 일이 매번 docx를 여는 일이 되어 버렸다. 이
스크립트는 그 안을 **다시 돌릴 수 있는 마크다운**으로 굳혀, 원안을 1차 사료로
인용할 수 있게 한다 (docs/plans/aldebaran-6-source-mining.md).

표준 라이브러리만 쓴다. 산출물은 결정적이다 — 같은 docx면 같은 바이트가 나온다.

    python3 tools/spica_extract.py                  # 마크다운 셋
    python3 tools/spica_extract.py --media          # 이미지 바이너리도 꺼낸다
    python3 tools/spica_extract.py --check          # 세기만 하고 쓰지 않는다

이미지 바이너리는 **커밋 대상이 아니다**(저자 자산). --media는 검토용이며
산출 디렉터리의 .gitignore가 막는다.
"""

import argparse
import shutil
import struct
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
V = "{urn:schemas-microsoft-com:vml}"

# 목차 항목의 스타일. 본문이 아니라 자동 생성된 목차라 걸러 낸다.
TOC_STYLES = {"10", "20", "30", "40"}
# 제목 스타일 → 깊이. 워드가 남긴 숫자 그대로다.
HEADING_STYLES = {"1": 1, "2": 2, "3": 3, "4": 4}


def para_text(el):
    """문단 하나의 글자. 줄바꿈(<w:br/>)은 공백으로 접는다."""
    out = []
    for node in el.iter():
        if node.tag == W + "t":
            out.append(node.text or "")
        elif node.tag in (W + "br", W + "cr"):
            out.append(" ")
        elif node.tag == W + "tab":
            out.append(" ")
    return "".join(out).strip()


def para_style(el):
    pPr = el.find(W + "pPr")
    if pPr is None:
        return ""
    st = pPr.find(W + "pStyle")
    return st.get(W + "val") if st is not None else ""


def image_rels(el):
    """이 블록이 참조하는 이미지 관계 id들. DrawingML과 VML 둘 다 본다."""
    ids = []
    for blip in el.iter(A + "blip"):
        rid = blip.get(R + "embed")
        if rid and rid not in ids:
            ids.append(rid)
    for data in el.iter(V + "imagedata"):
        rid = data.get(R + "id")
        if rid and rid not in ids:
            ids.append(rid)
    return ids


def cell_text(tc):
    """셀 하나. 여러 문단이면 <br>로 잇는다 (표 안에서 줄이 살아 있어야 읽힌다)."""
    parts = [para_text(p) for p in tc.findall(W + "p")]
    parts = [p for p in parts if p]
    return "<br>".join(parts)


def cell_span(tc):
    """가로 병합 칸 수."""
    tcPr = tc.find(W + "tcPr")
    if tcPr is None:
        return 1
    gs = tcPr.find(W + "gridSpan")
    return int(gs.get(W + "val")) if gs is not None else 1


def cell_vmerge(tc):
    """세로 병합: 'restart'면 시작, 'continue'(또는 값 없음)면 위 칸의 연속."""
    tcPr = tc.find(W + "tcPr")
    if tcPr is None:
        return None
    vm = tcPr.find(W + "vMerge")
    if vm is None:
        return None
    return vm.get(W + "val") or "continue"


def table_grid(tbl):
    """표를 문자열 2차원 배열로.

    마크다운에는 병합이 없다. 열 수는 원본 그대로 두되 **병합의 연속 칸은 비워**
    둔다. 같은 값을 복사해 채우면 표 하나가 같은 문장을 여섯 번 반복하게 되어
    읽을 수 없다 (원안 표 39가 그렇다).
    """
    grid = []
    for tr in tbl.findall(W + "tr"):
        row = []
        for tc in tr.findall(W + "tc"):
            txt = "" if cell_vmerge(tc) == "continue" else cell_text(tc)
            span = cell_span(tc)
            row.append(txt)
            row.extend([""] * (span - 1))   # 가로 병합의 나머지 칸
        grid.append(row)
    width = max((len(r) for r in grid), default=0)
    for r in grid:
        r.extend([""] * (width - len(r)))
    return grid


def md_cell(s):
    return s.replace("\\", "\\\\").replace("|", "\\|") or " "


def grid_to_markdown(grid):
    if not grid:
        return "_(빈 표)_"
    head, *rest = grid
    lines = ["| " + " | ".join(md_cell(c) for c in head) + " |",
             "|" + "|".join("---" for _ in head) + "|"]
    for row in rest:
        lines.append("| " + " | ".join(md_cell(c) for c in row) + " |")
    return "\n".join(lines)


class Section:
    """제목 스택으로 유지하는 '지금 절'. 문서가 번호를 글자로 달고 있어 그대로 쓴다."""

    def __init__(self):
        self.stack = []

    def push(self, depth, title):
        self.stack = self.stack[: depth - 1]
        while len(self.stack) < depth - 1:
            self.stack.append("")
        self.stack.append(title)

    def label(self):
        for title in reversed(self.stack):
            if title:
                return title
        return "(머리말)"

    def number(self):
        """절 번호만. 제목이 '4.2.1.2 배경의 특징'이면 '4.2.1.2'."""
        label = self.label()
        head = label.split(" ", 1)[0]
        return head.rstrip(".") if head[:1].isdigit() else ""


def walk(docx):
    """문서를 순서대로 훑어 블록 목록을 만든다.

    블록은 {'kind': 'heading'|'para'|'table'|'image', ...}이며 문서 순서를
    보존한다. 표와 이미지에는 그 자리의 절 번호가 붙는다.
    """
    z = zipfile.ZipFile(docx)
    rels = ET.fromstring(z.read("word/_rels/document.xml.rels"))
    relmap = {r.get("Id"): r.get("Target") for r in rels}
    body = ET.fromstring(z.read("word/document.xml")).find(W + "body")

    blocks = []
    sec = Section()
    table_no = 0
    for el in body:
        # 표와 문단 어디에 박혀 있든 이미지를 먼저 줍는다.
        images = image_rels(el)

        if el.tag == W + "p":
            style = para_style(el)
            text = para_text(el)
            if style in TOC_STYLES:
                continue  # 자동 생성된 목차. 본문에 같은 내용이 다시 나온다.
            if style in HEADING_STYLES and text:
                sec.push(HEADING_STYLES[style], text)
                blocks.append({"kind": "heading", "depth": HEADING_STYLES[style],
                               "text": text, "section": sec.number()})
            elif text:
                blocks.append({"kind": "para", "text": text,
                               "section": sec.number(), "label": sec.label()})
        elif el.tag == W + "tbl":
            table_no += 1
            blocks.append({"kind": "table", "no": table_no,
                           "grid": table_grid(el),
                           "section": sec.number(), "label": sec.label()})

        for rid in images:
            blocks.append({"kind": "image", "target": relmap.get(rid, "?"),
                           "section": sec.number(), "label": sec.label()})
    return blocks


def nearest_caption(blocks, i):
    """표 바로 앞의 설명 문단. 없으면 그 절의 제목이 설명을 대신한다."""
    for b in reversed(blocks[:i]):
        if b["kind"] == "para":
            return b["text"]
        if b["kind"] == "heading":
            return b["text"]
    return ""


HEADER = ("<!-- tools/spica_extract.py가 만든 파일이다. 손으로 고치지 말고 다시 돌려라. -->\n"
          "<!-- 원본: docs/design/Spica_v0.9.docx (저자 자산, 커밋 금지) -->\n")


def write_text_md(blocks, out):
    lines = [HEADER, "# 스피카 원안: 본문\n",
             "> 원안 `Spica_v0.9.docx`의 문단을 문서 순서대로 옮긴 것이다. 표는 자리만 표시하고\n"
             "> 내용은 [tables.md](tables.md)에, 이미지는 [media.md](media.md)에 있다.\n"]
    for i, b in enumerate(blocks):
        if b["kind"] == "heading":
            lines.append("\n" + "#" * (b["depth"] + 1) + " " + b["text"] + "\n")
        elif b["kind"] == "para":
            lines.append(b["text"] + "\n")
        elif b["kind"] == "table":
            rows, cols = len(b["grid"]), len(b["grid"][0]) if b["grid"] else 0
            lines.append(f"_[표 {b['no']}] {rows}행 {cols}열 → [tables.md](tables.md#표-{b['no']})_\n")
        elif b["kind"] == "image":
            lines.append(f"_[그림 {Path(b['target']).name}] → [media.md](media.md)_\n")
    (out / "text.md").write_text("\n".join(lines), encoding="utf-8")


def write_tables_md(blocks, out):
    tables = [(i, b) for i, b in enumerate(blocks) if b["kind"] == "table"]
    lines = [HEADER, "# 스피카 원안: 표 전부\n",
             f"> 표 {len(tables)}개. 원안 `Spica_v0.9.docx`에서 문서 순서대로 꺼냈다.\n"
             "> 병합된 칸은 같은 값을 채워 표 모양을 지켰다.\n",
             "\n## 찾아보기\n",
             "| 표 | 절 | 크기 | 설명 |", "|---|---|---|---|"]
    for i, b in tables:
        rows = len(b["grid"])
        cols = len(b["grid"][0]) if b["grid"] else 0
        cap = nearest_caption(blocks, i)
        lines.append(f"| [{b['no']}](#표-{b['no']}) | {b['section'] or '-'} | {rows}x{cols} "
                     f"| {md_cell(cap[:60])} |")
    for i, b in tables:
        cap = nearest_caption(blocks, i)
        lines.append(f"\n## 표 {b['no']}\n")
        lines.append(f"- 절: {b['label']}")
        lines.append(f"- 설명: {cap}\n")
        lines.append(grid_to_markdown(b["grid"]))
    (out / "tables.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


EMF_NOTE = ("`.emf`는 윈도우 메타파일이라 macOS에서 바로 못 본다. 원안의 EMF 넷은 전부 "
            "비트맵 하나를 감싸고만 있어서(`EMR_STRETCHDIBITS` 한 장), 그 DIB를 꺼내 "
            "BMP로 쓰고 `sips`로 PNG를 만든다. libreoffice가 있으면 그쪽을 먼저 쓴다.")

EMR_STRETCHDIBITS = 81


def emf_embedded_dib(data):
    """EMF 안의 DIB 한 장을 꺼내 BMP 바이트로 돌려준다. 없으면 None.

    원안의 EMF는 벡터 도형이 아니라 스크린샷을 감싼 것이라 이 한 record만 보면 된다.
    진짜 벡터 EMF라면 이 방법으로는 안 되고, 그때는 libreoffice가 필요하다.
    """
    off = 0
    while off + 8 <= len(data):
        rec_type, size = struct.unpack_from("<II", data, off)
        if size < 8 or off + size > len(data):
            return None
        if rec_type == EMR_STRETCHDIBITS:
            rec = data[off:off + size]
            # Type, Size, Bounds(16), xDest, yDest, xSrc, ySrc, cxSrc, cySrc,
            # offBmiSrc, cbBmiSrc, offBitsSrc, cbBitsSrc  — 오프셋은 record 시작 기준
            off_bmi, cb_bmi, off_bits, cb_bits = struct.unpack_from("<IIII", rec, 48)
            if not cb_bmi or not cb_bits:
                return None
            bmi = rec[off_bmi:off_bmi + cb_bmi]
            bits = rec[off_bits:off_bits + cb_bits]
            if len(bmi) != cb_bmi or len(bits) != cb_bits:
                return None
            offset = 14 + cb_bmi
            header = b"BM" + struct.pack("<IHHI", offset + cb_bits, 0, 0, offset)
            return header + bmi + bits
        off += size
    return None


def convert_emf(src, dst_dir):
    """EMF를 볼 수 있는 그림으로. 못 하면 이유를 돌려준다."""
    soffice = shutil.which("soffice") or shutil.which("libreoffice")
    mac = Path("/Applications/LibreOffice.app/Contents/MacOS/soffice")
    if not soffice and mac.exists():
        soffice = str(mac)
    if soffice:
        try:
            subprocess.run([soffice, "--headless", "--convert-to", "png",
                            "--outdir", str(dst_dir), str(src)],
                           capture_output=True, timeout=180, check=False)
        except (OSError, subprocess.SubprocessError):
            pass
        got = dst_dir / (src.stem + ".png")
        if got.exists():
            return got, ""

    bmp_bytes = emf_embedded_dib(src.read_bytes())
    if bmp_bytes is None:
        return None, "libreoffice 없음, 감싼 비트맵도 없음 (벡터 EMF로 보인다)"
    bmp = dst_dir / (src.stem + ".bmp")
    bmp.write_bytes(bmp_bytes)
    sips = shutil.which("sips")
    if sips:
        png = dst_dir / (src.stem + ".png")
        r = subprocess.run([sips, "-s", "format", "png", str(bmp), "--out", str(png)],
                           capture_output=True, timeout=120, check=False)
        if png.exists():
            bmp.unlink()
            return png, ""
        return bmp, f"sips 실패({r.returncode}), BMP까지만"
    return bmp, "sips 없음, BMP까지만"


def write_media_md(blocks, docx, out, extract):
    z = zipfile.ZipFile(docx)
    seen, rows = [], []
    for b in blocks:
        if b["kind"] != "image" or b["target"] in seen:
            continue
        seen.append(b["target"])
        rows.append(b)

    media_dir = out / "media"
    if extract:
        media_dir.mkdir(parents=True, exist_ok=True)

    # 마크다운은 --media 여부와 무관하게 같은 바이트여야 한다 (커밋되는 파일이라
    # 플래그에 따라 내용이 흔들리면 diff가 거짓말을 한다). 변환의 성패는 표준
    # 출력으로만 알린다.
    lines = [HEADER, "# 스피카 원안: 이미지\n",
             f"> 이미지 {len(rows)}장. 문서 순서이며, 그 자리의 절을 함께 적었다.\n"
             "> **바이너리는 저자 자산이라 저장소에 넣지 않는다.** 예외는 세계 지도\n"
             "> `image6.png` 하나이며 저자가 반입을 승인했다 (2026-08-23). `--media`로 꺼내면\n"
             f"> 전부 `spica-source/media/`에 놓이고 지도 말고는 gitignore가 막는다. {EMF_NOTE}\n",
             "| 파일 | 절 | 크기(바이트) | 형식 | 비고 |", "|---|---|---|---|---|"]
    results = []
    for b in rows:
        name = Path(b["target"]).name
        info = z.getinfo("word/" + b["target"])
        if extract:
            (media_dir / name).write_bytes(z.read("word/" + b["target"]))
            if name.endswith(".emf"):
                got, why = convert_emf(media_dir / name, media_dir)
                results.append(f"  {name} → {got.name}" if got else f"  {name} → 실패: {why}")
        note = "감싼 비트맵을 꺼내 PNG로 만든다" if name.endswith(".emf") else ""
        lines.append(f"| `{name}` | {b['label']} | {info.file_size:,} | "
                     f"{Path(name).suffix.lstrip('.')} | {note} |")
    (out / "media.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    for line in results:
        print(line)
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--docx", default="docs/design/Spica_v0.9.docx")
    ap.add_argument("--out", default="docs/design/spica-source")
    ap.add_argument("--media", action="store_true", help="이미지 바이너리도 꺼낸다 (커밋 금지)")
    ap.add_argument("--check", action="store_true", help="세기만 하고 쓰지 않는다")
    args = ap.parse_args()

    docx = Path(args.docx)
    if not docx.exists():
        print(f"원안을 찾지 못했다: {docx}", file=sys.stderr)
        print("원안은 저자 자산이라 저장소에 없다. 직접 놓고 다시 돌려라.", file=sys.stderr)
        return 2

    blocks = walk(docx)
    tables = [b for b in blocks if b["kind"] == "table"]
    paras = [b for b in blocks if b["kind"] == "para"]
    heads = [b for b in blocks if b["kind"] == "heading"]
    images = {b["target"] for b in blocks if b["kind"] == "image"}

    if not args.check:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        write_text_md(blocks, out)
        write_tables_md(blocks, out)
        write_media_md(blocks, docx, out, args.media)

    print(f"제목 {len(heads)}개, 문단 {len(paras)}개, 표 {len(tables)}개, 이미지 {len(images)}장")
    if not args.check:
        print(f"→ {args.out}/text.md, tables.md, media.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
