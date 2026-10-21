"""Build one continuous, vertical, code-evidenced Smart Parking system flowchart."""

from dataclasses import dataclass
from html import escape
from pathlib import Path
from xml.etree import ElementTree as ET


OUT = Path(__file__).resolve().parent
W, H = 2500, 8680
FONT = "Thonburi, ThonburiUI, Noto Sans Thai, Arial, sans-serif"
HEAD_TEXT = "SYSTEM FLOWCHART · SMART PARKING"
SUBHEAD_TEXT = "เส้นทางหลักต่อเนื่องจากเริ่มระบบ → จอง → เข้า → ตรวจช่อง → ชำระ → ออก → จบรายการ"
LEGEND_SYMBOLS = "สัญลักษณ์: วงรี เริ่ม/จบ · สี่เหลี่ยม กระบวนการ · ขนาน ข้อมูลเข้า/ออก · ข้าวหลามตัด ตัดสินใจ · ทรงกระบอก ฐานข้อมูล · เอกสาร QR/ผลลัพธ์ · วงกลม จุดเชื่อม"
LEGEND_EVIDENCE = "เส้นประ = การทำงานจริงของ ESP32/LED/Servo ที่ยังไม่มีเฟิร์มแวร์ให้ยืนยัน · เส้นทึบ = พฤติกรรมที่อ่านได้จากโค้ด"
FOOTER_LINES = (
    "อุปกรณ์: ESP32-CAM ถอดกล้อง · IR1–IR6 · Servo ตัวเดียวทางเข้า/ออก · ESP32-WROOM · RGB LED ช่อง M/N/O · Webcam บริเวณช่องจอด",
    "ตำแหน่งที่ผู้ใช้ระบุ: IR1/2 ตรงข้าม IR3 · IR3 ตรงข้าม IR4/5 · IR4/5 ตรงข้าม IR6 · IR6 ตรงข้าม IR1/2",
    "paid คือสถานะที่ Backend บันทึก; ไม่พบการตรวจชำระจากธนาคารหรือ gateway · ไม่มีเฟิร์มแวร์ ESP32 หรือไฟล์ calibration/runtime ในชุดโค้ดที่ตรวจ",
    "หลักฐานจากไฟล์และเลขบรรทัดอยู่ใน README.md · ไม่มีข้อมูลจำลองหรืออุปกรณ์สแกน QR ที่สมมติขึ้น",
)


@dataclass(frozen=True)
class Node:
    key: str
    kind: str
    x: int
    y: int
    w: int
    h: int
    lines: tuple[str, ...]
    lane: str = "backend"
    uncertain: bool = False


@dataclass(frozen=True)
class Edge:
    a: str
    b: str
    ap: str = "right"
    bp: str = "left"
    via: tuple[tuple[int, int], ...] = ()
    label: str = ""
    lx: int = 0
    ly: int = 0
    dashed: bool = False


from continuous_data import build

nodes, edges = build(Node, Edge)
N = {n.key: n for n in nodes}


def anchor(n: Node, side: str) -> tuple[int, int]:
    return {
        "left": (n.x, n.y + n.h // 2),
        "right": (n.x + n.w, n.y + n.h // 2),
        "top": (n.x + n.w // 2, n.y),
        "bottom": (n.x + n.w // 2, n.y + n.h),
    }[side]


def shape_svg(n: Node) -> str:
    x, y, w, h = n.x, n.y, n.w, n.h
    cls = f"node {n.lane}" + (" uncertain" if n.uncertain else "")
    if n.kind in {"start", "end", "connector"}:
        body = f'<ellipse cx="{x+w/2}" cy="{y+h/2}" rx="{w/2}" ry="{h/2}"/>'
    elif n.kind == "decision":
        body = f'<polygon points="{x+w//2},{y} {x+w},{y+h//2} {x+w//2},{y+h} {x},{y+h//2}"/>'
    elif n.kind == "io":
        body = f'<polygon points="{x+36},{y} {x+w},{y} {x+w-36},{y+h} {x},{y+h}"/>'
    elif n.kind == "document":
        body = f'<path d="M{x} {y} H{x+w} V{y+h-17} Q{x+w*3//4} {y+h+8} {x+w//2} {y+h-17} Q{x+w//4} {y+h-42} {x} {y+h-17} Z"/>'
    elif n.kind == "database":
        body = (f'<path d="M{x} {y+17} A{w//2} 17 0 0 1 {x+w} {y+17} '
                f'V{y+h-17} A{w//2} 17 0 0 1 {x} {y+h-17} Z"/>'
                f'<path class="db-arc" d="M{x} {y+17} A{w//2} 17 0 0 0 {x+w} {y+17}"/>')
    else:
        body = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8"/>'
    line_h = 31 if n.kind == "decision" else 30
    base = y + h / 2 - (len(n.lines)-1)*line_h/2 + 7
    txt = "".join(
        f'<text x="{x+w/2}" y="{base+i*line_h}" text-anchor="middle" '
        f'class="node-text {"secondary" if i else "primary"}">{escape(line)}</text>'
        for i, line in enumerate(n.lines)
    )
    return f'<g id="{n.key}" class="{cls}"><title>{n.key}: {escape(" | ".join(n.lines))}</title>{body}{txt}</g>'


def edge_svg(e: Edge) -> str:
    pts = [anchor(N[e.a], e.ap), *e.via, anchor(N[e.b], e.bp)]
    p = " ".join(f"{x},{y}" for x, y in pts)
    klass = "edge uncertain-edge" if e.dashed else "edge"
    line = f'<polyline class="{klass}" points="{p}" marker-end="url(#arrow)"/>'
    if not e.label:
        return line
    # Labels have a white backing so arrows stay readable over colored lanes.
    text_w = min(390, max(95, len(e.label)*12 + 32))
    return (line + f'<g class="edge-label"><rect x="{e.lx-text_w//2}" '
            f'y="{e.ly-22}" width="{text_w}" height="29" rx="8"/>'
            f'<text x="{e.lx}" y="{e.ly}" text-anchor="middle">{escape(e.label)}</text></g>')


svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
    '<title id="title">Continuous Smart Parking System Flowchart</title>',
    '<desc id="desc">ผังงานแนวตั้งต่อเนื่องตั้งแต่เริ่มระบบถึงจบรายการจอด พร้อมกิ่งทางเลือกและงานคู่ขนาน</desc>',
    '<defs><marker id="arrow" markerWidth="13" markerHeight="13" refX="10" refY="6.5" orient="auto" markerUnits="userSpaceOnUse"><path d="M1,1 L11,6.5 L1,12" fill="none" stroke="#334b64" stroke-width="2.5"/></marker></defs>',
    f'<style><![CDATA[text{{font-family:{FONT}}} .bg{{fill:#f5f7fb}} .node>rect,.node>ellipse,.node>polygon,.node>path{{stroke:#25425c;stroke-width:2.5;fill:#fff}} .node.app>rect,.node.app>ellipse,.node.app>polygon,.node.app>path{{fill:#e8f3ff}} .node.vision>rect,.node.vision>ellipse,.node.vision>polygon,.node.vision>path{{fill:#e7f7ee}} .node.hardware>rect,.node.hardware>ellipse,.node.hardware>polygon,.node.hardware>path{{fill:#fff0e7}} .node.database>rect,.node.database>ellipse,.node.database>polygon,.node.database>path{{fill:#eeeafb}} .uncertain>rect,.uncertain>ellipse,.uncertain>polygon,.uncertain>path{{stroke-dasharray:10 7}} .db-arc{{fill:none!important;stroke:#25425c;stroke-width:2}} .node-text.primary{{font-size:21px;font-weight:700;fill:#15334b}} .node-text.secondary{{font-size:19px;fill:#344e61}} .edge{{fill:none;stroke:#334b64;stroke-width:3;stroke-linecap:round;stroke-linejoin:round}} .uncertain-edge{{stroke-dasharray:9 7}} .edge-label rect{{fill:#fff;stroke:#d7e2eb;stroke-width:1}} .edge-label text{{font-size:18px;font-weight:700;fill:#27465f}} .head{{font-size:43px;font-weight:750;fill:#112b44}} .subhead{{font-size:22px;fill:#536b80}} .legend{{font-size:18px;fill:#35516a}} .foot{{font-size:18px;fill:#536b80}}]]></style>',
    f'<rect class="bg" width="{W}" height="{H}"/>',
    f'<text x="78" y="84" class="head">{escape(HEAD_TEXT)}</text>',
    f'<text x="78" y="126" class="subhead">{escape(SUBHEAD_TEXT)}</text>',
    f'<text x="78" y="178" class="legend">{escape(LEGEND_SYMBOLS)}</text>',
    f'<text x="78" y="210" class="legend">{escape(LEGEND_EVIDENCE)}</text>',
    '<g id="edges">',
    *[edge_svg(e) for e in edges],
    '</g><g id="nodes">',
    *[shape_svg(n) for n in nodes],
    '</g>',
    *[f'<text x="78" y="{8430 + i*43}" class="foot">{escape(line)}</text>' for i, line in enumerate(FOOTER_LINES)],
    '</svg>',
]
(OUT / "system_flowchart.svg").write_text("\n".join(svg), encoding="utf-8")


def drawio_style(n: Node) -> str:
    base = "whiteSpace=wrap;html=1;align=center;verticalAlign=middle;fontSize=17;"
    bg = {"app": "#E8F3FF", "vision": "#E7F7EE", "hardware": "#FFF0E7", "backend": "#FFFFFF"}[n.lane]
    base += f"fillColor={bg};strokeColor=#25425C;strokeWidth=2;"
    if n.uncertain:
        base += "dashed=1;dashPattern=8 5;"
    shape = {"start": "ellipse", "end": "ellipse", "connector": "ellipse", "process": "rectangle", "io": "parallelogram", "decision": "rhombus", "database": "cylinder", "document": "document"}[n.kind]
    return base + f"shape={shape};"


mxfile = ET.Element("mxfile", {"host": "app.diagrams.net", "agent": "Codex"})
diagram = ET.SubElement(mxfile, "diagram", {"id": "continuous", "name": "Smart Parking Continuous System Flowchart"})
model = ET.SubElement(diagram, "mxGraphModel", {"dx": str(W), "dy": str(H), "grid": "1", "gridSize": "10", "page": "1", "pageScale": "1", "pageWidth": str(W), "pageHeight": str(H), "math": "0", "shadow": "0"})
root = ET.SubElement(model, "root")
ET.SubElement(root, "mxCell", {"id": "0"})
ET.SubElement(root, "mxCell", {"id": "1", "parent": "0"})


def add_drawio_box(key: str, value: str, x: int, y: int, w: int, h: int, style: str) -> None:
    cell = ET.SubElement(root, "mxCell", {
        "id": key, "value": value, "style": style, "vertex": "1", "parent": "1",
    })
    ET.SubElement(cell, "mxGeometry", {
        "x": str(x), "y": str(y), "width": str(w), "height": str(h), "as": "geometry",
    })


add_drawio_box("background", "", 0, 0, W, H,
               "shape=rectangle;fillColor=#F5F7FB;strokeColor=none;locked=1;")
for key, value, y, font_size, color in (
    ("heading", HEAD_TEXT, 31, 43, "#112B44"),
    ("subheading", SUBHEAD_TEXT, 98, 22, "#536B80"),
    ("legend-symbols", LEGEND_SYMBOLS, 151, 18, "#35516A"),
    ("legend-evidence", LEGEND_EVIDENCE, 183, 18, "#35516A"),
):
    add_drawio_box(key, value, 78, y, 2300, 44,
                   f"text;html=1;align=left;verticalAlign=middle;fontSize={font_size};"
                   f"fontColor={color};strokeColor=none;fillColor=none;")
for i, line in enumerate(FOOTER_LINES):
    add_drawio_box(f"foot-{i+1}", line, 78, 8405 + i*43, 2300, 35,
                   "text;html=1;align=left;verticalAlign=middle;fontSize=18;"
                   "fontColor=#536B80;strokeColor=none;fillColor=none;")
for n in nodes:
    cell = ET.SubElement(root, "mxCell", {"id": n.key, "value": "<br/>".join(escape(line) for line in n.lines), "style": drawio_style(n), "vertex": "1", "parent": "1"})
    ET.SubElement(cell, "mxGeometry", {"x": str(n.x), "y": str(n.y), "width": str(n.w), "height": str(n.h), "as": "geometry"})
for i, e in enumerate(edges, 1):
    ports = {"left": (0, 0.5), "right": (1, 0.5), "top": (0.5, 0), "bottom": (0.5, 1)}
    ex, ey = ports[e.ap]
    ix, iy = ports[e.bp]
    style = (
        "edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;"
        "endFill=1;strokeColor=#334B64;strokeWidth=2;"
        f"exitX={ex};exitY={ey};entryX={ix};entryY={iy};"
    )
    if e.dashed:
        style += "dashed=1;dashPattern=8 5;"
    cell = ET.SubElement(root, "mxCell", {"id": f"e{i}", "value": escape(e.label), "style": style, "edge": "1", "parent": "1", "source": e.a, "target": e.b})
    geom = ET.SubElement(cell, "mxGeometry", {"relative": "1", "as": "geometry"})
    if e.via:
        arr = ET.SubElement(geom, "Array", {"as": "points"})
        for x, y in e.via:
            ET.SubElement(arr, "mxPoint", {"x": str(x), "y": str(y)})
(OUT / "system_flowchart.drawio").write_bytes(ET.tostring(mxfile, encoding="utf-8", xml_declaration=True))

print(f"Built {len(nodes)} nodes and {len(edges)} edges")
