# Concept (low-poly pets): the comparison page. Reads the cells and counts lowpoly_render.py wrote and
# today's counts from lowpoly_measure.py (all 720 pets), writes a page (index.html, one sheet page a
# kind for screenshots, cells as JPEG) into <outdir>/page.
#
# Run headless from the repo root (Blender's Python, for its image saving):
#   blender --background --factory-startup --python assets/blender/concepts/lowpoly/lowpoly_page.py -- <render outdir> <current_all.json>

import html
import json
import os
import re
import shutil
import statistics
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC, CURRENT = ARGS[0], ARGS[1]
OUT = os.path.join(SRC, "page")
KINDS = [("slimeWarden", "Слизень-сторож", "слизень"), ("crabDrone", "Краб-дрон", "краб"), ("spaceWhale", "Космический кит", "кит")]
TIERS = [("0", "Обычный"), ("3", "Эпический"), ("4", "Легендарный")]
STYLES = [("today", "Сегодня"), ("faceted", "А · Гранёный"), ("toy", "Б · Игрушка"), ("sharp", "В · Острый")]
# Measured from assets/aliens/*.rbxm (2026-11-13): MeshParts without the markers the game turns into
# points, and distinct MeshIds among them.
TODAY_PARTS, TODAY_MESHES = 20743, 16693
# The 30-pet bench in game (optimization-measurements.md, D): scene triangles added by the pets.
BENCH_TRIS = 1_038_000
# Rough mesh memory per triangle (vertex positions, normals, colours, indices; CPU and GPU copies).
BYTES_PER_TRI = 40
# Today's three families have their library measured; the other three families and the 24 posts'
# signatures add pieces, mostly the same shapes.
LIBRARY_ALL = 50


def jpeg(name):
    src = os.path.join(SRC, "cells", name + ".png")
    image = bpy.data.images.load(src)
    image.file_format = "JPEG"
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 86
    dst = os.path.join(OUT, "cells", name + ".jpg")
    image.save_render(dst, scene=scene)
    return f"cells/{name}.jpg"


def png_far(name):
    shutil.copyfile(os.path.join(SRC, "cells", name + ".png"), os.path.join(OUT, "cells", name + ".png"))
    return f"cells/{name}.png"


def load():
    with open(CURRENT, encoding="utf-8") as file:
        today = json.load(file)
    styles = {}
    for style, _ in STYLES[1:]:
        with open(os.path.join(SRC, style + ".json"), encoding="utf-8") as file:
            styles[style] = json.load(file)
    return today, styles


def fmt(n):
    return f"{n:,.0f}".replace(",", " ")


def main():
    os.makedirs(os.path.join(OUT, "cells"), exist_ok=True)
    today, styles = load()
    today_by = {(r["kind"], r["variant"]): r for r in today}
    all_tris = [r["triangles"] for r in today]
    today_total = sum(all_tris)
    today_avg = statistics.mean(all_tris)

    def cell_stats(kind, variant, style):
        if style == "today":
            r = today_by[(kind, variant)]
            return r["triangles"], r["meshParts"] - r["markerParts"], r["meshParts"] - r["markerParts"], "все свои"
        r = next(p for p in styles[style]["pets"] if p["kind"] == kind and p["variant"] == variant)
        return r["triangles"], r["mergedParts"], len(r["meshes"]), "общие"

    summary = []
    sample_today = [today_by[(k, v)]["triangles"] for k, _, _ in KINDS for v in ["0", "1", "2", "3", "4", "m0", "m1", "m2", "m3", "m4"]]
    for style, title in STYLES:
        if style == "today":
            summary.append({"style": style, "title": title, "avg": today_avg, "range": (min(all_tris), max(all_tris)),
                            "sampleAvg": statistics.mean(sample_today),
                            "parts": TODAY_PARTS / 720, "meshes720": TODAY_MESHES, "uniqueTris": today_total,
                            "bench": BENCH_TRIS})
            continue
        pets = styles[style]["pets"]
        tris = [p["triangles"] for p in pets]
        library = styles[style]["library"]
        groups = statistics.mean(p["mergedGroups"] for p in pets if p["variant"] == "0")
        kind_tris = statistics.mean(p["triangles"] for p in pets if p["variant"] == "0")
        meshes720 = round(72 * groups + LIBRARY_ALL)
        unique_tris = 72 * kind_tris + sum(library.values()) * LIBRARY_ALL / len(library)
        summary.append({"style": style, "title": title, "avg": statistics.mean(tris), "range": (min(tris), max(tris)),
                        "sampleAvg": statistics.mean(tris),
                        "parts": statistics.mean(p["mergedParts"] for p in pets), "meshes720": meshes720,
                        "kitMeshes": len(library), "uniqueTris": unique_tris, "bench": 30 * statistics.mean(tris)})
    with open(os.path.join(OUT, "summary.json"), "w", encoding="utf-8") as file:
        json.dump(summary, file, ensure_ascii=False, indent=1)

    images = {}
    for kind, _, _ in KINDS:
        for variant, _ in TIERS:
            for style, _ in STYLES:
                name = f"{kind}-{variant}-{style}"
                images[name] = (jpeg(name + "-near"), png_far(name + "-far"))

    def kind_section(kind, title, family):
        rows = []
        head = "".join(f"<th>{html.escape(t)}</th>" for _, t in STYLES)
        for variant, tier in TIERS:
            cells = []
            for style, _ in STYLES:
                near, far = images[f"{kind}-{variant}-{style}"]
                tris, parts, meshes, shared = cell_stats(kind, variant, style)
                ratio = "" if style == "today" else f'<span class="ratio">{tris / today_by[(kind, variant)]["triangles"] * 100:.0f}%</span>'
                cells.append(
                    f'<td><div class="cell"><img class="near" src="{near}" alt="">'
                    f'<div class="far"><img class="x1" src="{far}" alt=""><img class="x3" src="{far}" alt=""></div></div>'
                    f'<div class="stats"><b>{fmt(tris)}</b> треуг. {ratio}<br>{parts} частей · {meshes} мешей, {shared}</div></td>')
            rows.append(f'<tr><th class="tier t{variant}">{tier}</th>{"".join(cells)}</tr>')
        return (f'<section class="kind" id="{kind}"><h2>{html.escape(title)} <small>{family}</small></h2>'
                f'<table class="grid"><tr><th></th>{head}</tr>{"".join(rows)}</table></section>')

    def summary_table():
        rows = []
        for s in summary:
            low, high = s["range"]
            # A full server: 8 islands of 30 pets, all different. Today each brings its own meshes; low-poly
            # ones share, so they can never need more than the meshes of all 72 kinds.
            mem = min(240 * s["avg"], s["uniqueTris"]) * BYTES_PER_TRI / 1e6
            rows.append(
                f'<tr class="{s["style"]}"><th>{html.escape(s["title"])}</th>'
                f'<td>{fmt(s["avg"])}<small> ({fmt(low)}–{fmt(high)})</small></td>'
                f'<td>{s["parts"]:.0f}</td>'
                f'<td>{fmt(s["meshes720"])}</td>'
                f'<td>{fmt(s["uniqueTris"])}</td>'
                f'<td>~{mem:,.1f} МБ</td>'
                f'<td>{fmt(s["bench"])}</td></tr>')
        return ('<table class="summary"><tr><th></th><th>Треугольников на питомца<br><small>среднее (мин–макс)</small></th>'
                '<th>Частей на питомца</th><th>Уникальных мешей<br><small>все 720</small></th>'
                '<th>Треугольников в уникальных мешах<br><small>все 720</small></th><th>Память мешей<br><small>оценка, полный сервер: 240 питомцев</small></th>'
                '<th>Треугольников в кадре<br><small>30 питомцев</small></th></tr>' + "".join(rows) + "</table>")

    today_s, faceted = summary[0], summary[1]

    def mem(s):
        return min(240 * s["avg"], s["uniqueTris"]) * BYTES_PER_TRI / 1e6

    fills = {
        "FACETED_RANGE": f"{fmt(faceted['range'][0])}–{fmt(faceted['range'][1])}",
        "TODAY_RANGE": f"{fmt(today_s['range'][0])}–{fmt(today_s['range'][1])}",
        "TODAY_MESHES": fmt(TODAY_MESHES), "FACETED_MESHES": fmt(faceted["meshes720"]),
        "TODAY_AVG": fmt(today_s["avg"]), "FACETED_AVG": fmt(faceted["avg"]),
        "FACETED_X": f"{today_s['avg'] / faceted['avg']:.0f}",
        "TODAY_MEM": fmt(mem(today_s)), "FACETED_MEM": f"{mem(faceted):.0f}",
    }
    template = TEMPLATE
    for key, value in fills.items():
        template = template.replace("{{" + key + "}}", value)
    dress_html, dress_sheets = dress_section()
    template = template.replace("{{DRESS}}", dress_html)
    sections = "".join(kind_section(*k) for k in KINDS)
    page = template.replace("{{SUMMARY}}", summary_table()).replace("{{SECTIONS}}", sections)
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as file:
        file.write(page)
    # The sheets (for screenshots) keep the title and one block, without the recommendation and notes.
    bare = re.sub(r'<section id="pick">.*?</main>', "</main>", template, flags=re.S)
    for k in KINDS:
        sheet = bare.replace("{{SUMMARY}}", "").replace("{{SECTIONS}}", kind_section(*k)).replace('<main class="page">', '<main class="page sheet">')
        with open(os.path.join(OUT, f"sheet-{k[0]}.html"), "w", encoding="utf-8") as file:
            file.write(sheet)
    for name, block in dress_sheets.items():
        with open(os.path.join(OUT, f"sheet-{name}.html"), "w", encoding="utf-8") as file:
            file.write(bare.replace("{{SUMMARY}}", "").replace("{{SECTIONS}}", block).replace('<main class="page">', '<main class="page sheet">'))
    with open(os.path.join(OUT, "sheet-summary.html"), "w", encoding="utf-8") as file:
        file.write(bare.replace("{{SUMMARY}}", summary_table()).replace("{{SECTIONS}}", "").replace('<main class="page">', '<main class="page sheet">'))
    print("Wrote", OUT)
    for s in summary:
        print("SUMMARY", json.dumps(s, ensure_ascii=False))


KIND_TITLES = {"slimeWarden": "Слизень-сторож", "acidSlime": "Кислотный слизень", "crabDrone": "Краб-дрон", "violetCrab": "Лиловый краб",
               "blimpWhale": "Кит-дирижабль", "spaceWhale": "Космический кит"}
TIER_TITLES = ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный"]


def dress_section():
    """The rolled outfit: three sheets and the text around them. Returns the page block and the
    sheets alone (for screenshots)."""
    path = os.path.join(SRC, "dress.json")
    if not os.path.exists(path):
        return "", {}
    with open(path, encoding="utf-8") as file:
        data = json.load(file)
    cells = data["cells"]

    def cell(c, caption):
        near, far = jpeg(c["name"] + "-near"), png_far(c["name"] + "-far")
        return (f'<td><div class="cell"><img class="near" src="{near}" alt="">'
                f'<div class="far"><img class="x1" src="{far}" alt=""></div></div>'
                f'<div class="stats">{caption}</div></td>')

    def picks(c):
        p = c.get("picks", {})
        parts = [p[s] for s in ("head", "aura", "back") if p.get(s) and p[s] != "—"]
        return " · ".join(parts) or "без украшений"

    def rolled_caption(c):
        return picks(c) + "<br><b>" + fmt(c["triangles"]) + "</b> треуг."

    kinds_today = [c for c in cells if c["sheet"] == "kinds" and c["row"] == "today"]
    kinds_rolled = [c for c in cells if c["sheet"] == "kinds" and c["row"] == "rolled"]
    head = "".join(f"<th>{KIND_TITLES[c['kind']]}</th>" for c in kinds_today)
    kinds = (f'<section class="kind" id="dress-kinds"><h2>Эпический на шести видах <small>сегодня и с общей библиотекой</small></h2>'
             f'<table class="grid"><tr><th></th>{head}</tr>'
             f'<tr><th class="tier">Сегодня</th>{"".join(cell(c, "стрекоза — у всех") for c in kinds_today)}</tr>'
             f'<tr><th class="tier t3">Бросок</th>{"".join(cell(c, rolled_caption(c)) for c in kinds_rolled)}</tr>'
             f'</table><p class="lead">Семена для этой строки подобраны так, чтобы показать все четыре вида крыльев; лист ниже — броски подряд, как выпали.</p></section>')
    rolls_cells = [c for c in cells if c["sheet"] == "rolls"]
    rows = []
    for start in range(0, len(rolls_cells), 4):
        rows.append("<tr>" + "".join(cell(c, f"uid {c['seed']}: {picks(c)}") for c in rolls_cells[start:start + 4]) + "</tr>")
    rolls = (f'<section class="kind" id="dress-rolls"><h2>Восемь бросков подряд <small>{KIND_TITLES[rolls_cells[0]["kind"]]}, эпический, uid 1–8</small></h2>'
             f'<table class="grid">{"".join(rows)}</table></section>')
    tier_rows = []
    for tier in range(5):
        row = [c for c in cells if c["sheet"] == "tiers" and c["tier"] == tier]
        tier_rows.append(f'<tr><th class="tier t{tier}">{TIER_TITLES[tier]}</th>' + "".join(cell(c, picks(c)) for c in row) + "</tr>")
    tiers = (f'<section class="kind" id="dress-tiers"><h2>По ступеням <small>{KIND_TITLES["spaceWhale"]}, три броска на ступень</small></h2>'
             f'<table class="grid"><tr><th></th><th>uid 1</th><th>uid 2</th><th>uid 3</th></tr>{"".join(tier_rows)}</table></section>')

    library = data["library"]
    dress_meshes = ["feather", "mech_frame", "mech_panel", "crystal_wing", "shards", "orbits", "horns", "crest", "feelers"]
    dress_tris = sum(library.get(name, 0) for name in dress_meshes)
    text = DRESS_TEXT.replace("{{DRESS_MESHES}}", str(len(dress_meshes))).replace("{{DRESS_TRIS}}", fmt(dress_tris))
    return text + kinds + rolls + tiers, {"dress-kinds": kinds, "dress-rolls": rolls, "dress-tiers": tiers}


DRESS_TEXT = """
<section id="dress">
<h2>Случайный наряд из пула ступени</h2>
<p>Сейчас все эпические и легендарные на местах стоят в одних и тех же крыльях стрекозы, поэтому краб и кит одной ступени выглядят одинаково. С дешёвыми общими деталями наряд можно не назначать, а <b>выбрасывать</b>: каждый вылупившийся питомец получает случайный набор из пула своей ступени. Форма деталей разная, а цвет всегда цвета ступени: серый, зелёный, синий, фиолетовый, золото (у метеоритного — огонь). Редкость читается по цвету и по богатству набора.</p>
<div class="wrap"><table class="summary">
<tr><th>Ступень</th><th>Голова</th><th>Аура</th><th>Спина</th><th>Наборов</th></tr>
<tr><th class="t0">Обычный</th><td>рожки / гребень / усики / ничего</td><td>—</td><td>—</td><td>4</td></tr>
<tr><th class="t1">Необычный</th><td>рожки / гребень / усики</td><td>нимб / осколки</td><td>—</td><td>6</td></tr>
<tr><th class="t2">Редкий</th><td>рожки / гребень / усики</td><td>нимб / осколки / кольца</td><td>ранец / крылышки</td><td>18</td></tr>
<tr><th class="t3">Эпический</th><td>рожки / гребень / усики</td><td>нимб / осколки / кольца</td><td>стрекоза / перья / механика / кристаллы</td><td>36</td></tr>
<tr><th class="t4">Легендарный</th><td>корона (всегда)</td><td>нимб / осколки / кольца / звезда</td><td>те же четыре, золотые</td><td>16</td></tr>
</table></div>
<p>Чем выше ступень, тем больше мест (1 → 2 → 3) и тем богаче детали: крылья только с эпического, звезда-медаль только у легендарного, корона — его постоянный знак. Пулы легко расширять: ещё типы крыльев (летучая мышь, пламя), ауры, хвосты, плавники на спине.</p>
<h3>Как это работает (описание, кода нет)</h3>
<ul>
<li><b>Бросок — функция, а не сохранение.</b> Семя = хэш от <code>UserId</code> владельца и <code>uid</code> пришельца (оба уже есть: <code>uid</code> в записи пришельца и в атрибуте <code>Uid</code> модели). Из семени — по номеру детали в пуле каждого места. Новое поле в профиле не нужно. Только <code>uid</code> без <code>UserId</code> не годится: <code>uid</code> идёт 1, 2, 3… у каждого игрока, и первые питомцы у всех были бы одинаковыми.</li>
<li><b>Один и тот же вид везде.</b> Тот же расчёт на сервере и у каждого клиента: после перезахода, на стеллаже, на местах, у других игроков питомец одинаковый. Наряд надевает клиент (<code>AlienDress</code>), как сейчас частицы; сервер держит только тело.</li>
<li><b>Пулы не перемешивать.</b> Бросок — номер в пуле: если вставить или убрать деталь, сменят наряд и уже вылупившиеся. Пулы только дополнять в конце, с «версией пула» у ступени (старые питомцы бросают по старой длине), или, если пулы придётся переделывать, тогда завести в записи поле с выпавшими деталями и заполнить его миграцией.</li>
<li><b>Если появится обмен питомцами</b> — у нового владельца наряд сменится. Тогда (и только тогда) нужно сохранять семя в записи пришельца — одно число.</li>
<li><b>Скрещивание</b> даёт нового пришельца с новым <code>uid</code> — значит новый бросок, само собой. Унаследовать одну деталь можно, но это уже сохраняемое поле — предлагаю новый бросок.</li>
<li><b>Иконки</b> (<code>AlienIcons</code>, вид × ступень) остаются как есть: тело в цветах ступени и корона у легендарного, без случайных деталей — ноль новой работы. Рисовать иконку на каждый бросок не нужно.</li>
</ul>
<h3>Цена</h3>
<p>Вся библиотека нарядов на эскизе — {{DRESS_MESHES}} новых мешей (перья, механика ×2, кристаллы, осколки, кольца, рожки, гребень, усики), вместе {{DRESS_TRIS}} треугольников — на все 720 питомцев сразу. С расширенными пулами (6 крыльев, 4 ауры, 6 на голову) — около 25–30 мешей. Питомец по-прежнему 1–2,5 тыс. треугольников: деталей на нём столько же, только разные.</p>
</section>
"""


TEMPLATE = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "lowpoly_page.html"), encoding="utf-8").read()

if __name__ == "__main__":
    main()
