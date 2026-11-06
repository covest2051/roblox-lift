#!/usr/bin/env python3
"""Рисует поездку ботов из build/ride.json → docs/img/ride.png (нужен Pillow).

Слева — шахта лифта: 10 остановок снизу вверх, цвет — категория этажа. У каждой остановки:
как выбран этаж (кнопки голосования — категории, выбранная обведена; или сюрприз/босс),
вид сверху на этаж — те же детали из примитивов, что строит сервер (FloorKit), и итог:
звёзды каждого участника (бот — серым)."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1] if len(sys.argv) > 1 else "build/ride.json"
dst = sys.argv[2] if len(sys.argv) > 2 else "build/ride.png"
d = json.load(open(src))

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f12, f14, f16, f18, f26 = (ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 14),
                           ImageFont.truetype(FONTB, 16), ImageFont.truetype(FONTB, 18),
                           ImageFont.truetype(FONTB, 26))
CAT = {"fire": (255, 110, 70), "race": (90, 190, 255), "brain": (200, 130, 255), "coop": (110, 225, 130),
       "calm": (255, 205, 120), "boss": (255, 205, 70), "secret": (150, 150, 170)}
BG, PANEL, TEXT, DIM, BRASS, TEAL = (16, 30, 36), (28, 50, 58), (240, 246, 255), (160, 176, 200), (205, 160, 70), (60, 170, 165)
WHY = {"rare": "сюрприз: редкий этаж", "basement": "сюрприз: Подвал", "boss": "этаж-босс", "bought": "куплен Подвал",
       "debug": "отладка", "fallback": "лифт решил сам"}

stops = d["stops"]
ROW = 118
W = 1500
H = 120 + ROW * len(stops) + 40
img = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(img, "RGBA")
dr.text((30, 20), "«Лифт-сюрприз»: поездка ботов (seed %d)" % d["seed"], font=f26, fill=TEXT)
dr.text((30, 56), "Тот же код, что в игре: модель Ride, подбор Picker, этажи floors/*, головы ботов. "
        "Поездка %.1f мин, самое долгое ожидание на балконе %.0f с." % (d["time"] / 60, d["maxBalcony"]),
        font=f14, fill=DIM)

# шахта
SX, SW = 30, 70
top = 100
dr.rectangle([SX, top - 6, SX + SW, top + ROW * len(stops)], fill=(40, 70, 78), outline=BRASS, width=3)
for i, st in enumerate(reversed(stops)):
    y = top + i * ROW
    col = CAT.get(st["cat"], DIM)
    dr.rounded_rectangle([SX + 8, y + 10, SX + SW - 8, y + ROW - 14], radius=8, fill=col)
    dr.text((SX + SW / 2, y + ROW / 2 - 2), str(st["stop"]), font=f26, fill=(20, 20, 30), anchor="mm")
    X0 = SX + SW + 20
    dr.rounded_rectangle([X0, y + 6, W - 20, y + ROW - 8], radius=10, fill=PANEL)
    dr.text((X0 + 12, y + 14), st["name"], font=f18, fill=col)
    dr.text((X0 + 12, y + 38), st["catName"], font=f14, fill=DIM)
    # как выбран
    opts = st.get("options") or []
    if isinstance(opts, dict):
        opts = []
    if opts:
        dr.text((X0 + 12, y + 60), "голос:", font=f12, fill=DIM)
        ox = X0 + 58
        for o in opts:
            c = CAT.get(o["cat"], DIM)
            w = dr.textlength(o["name"] + " ?", font=f12) + 14
            dr.rounded_rectangle([ox, y + 58, ox + w, y + 78], radius=6, fill=c + (90,),
                                 outline=(255, 255, 255) if o["chosen"] else None, width=2)
            dr.text((ox + 7, y + 61), o["name"] + " ?", font=f12, fill=TEXT)
            ox += w + 6
    else:
        dr.text((X0 + 12, y + 60), WHY.get(st.get("why") or "", ""), font=f14, fill=BRASS)
    # вид сверху из деталей этажа
    MX, MW, MH = X0 + 400, 220, ROW - 22
    dr.rectangle([MX, y + 8, MX + MW, y + 8 + MH], fill=(10, 18, 22))
    b = st.get("bounds") or [-30, 30, 0, 60]
    bx0, bx1, bz0, bz1 = b[0] - 4, b[1] + 4, b[2] - 4, b[3] + 4
    sc = min(MW / (bx1 - bx0), MH / (bz1 - bz0))
    cx = MX + MW / 2 - (bx0 + bx1) / 2 * sc
    cz = y + 8 + MH / 2 + (bz0 + bz1) / 2 * sc
    for p in sorted(st["parts"], key=lambda p: p["y"]):
        if p["y"] < -40 or p["a"] >= 0.95:
            continue
        x0, x1 = cx + (p["x"] - p["sx"] / 2) * sc, cx + (p["x"] + p["sx"] / 2) * sc
        z0, z1 = cz - (p["z"] + p["sz"] / 2) * sc, cz - (p["z"] - p["sz"] / 2) * sc
        if p["shape"] in ("Disc", "Ball"):
            r = p["sx"] / 2 * sc
            z0, z1 = cz - p["z"] * sc - r, cz - p["z"] * sc + r
            dr.ellipse([x0, z0, x1, z1], fill=tuple(p["c"]) + (int(255 * (1 - p["a"] * 0.7)),))
        else:
            dr.rectangle([x0, min(z0, z1), x1, max(z0, z1)], fill=tuple(p["c"]) + (int(255 * (1 - p["a"] * 0.7)),))
    dr.text((MX + MW + 8, y + 10), "%d деталей" % len(st["parts"]), font=f12, fill=DIM)
    if st.get("time"):
        dr.text((MX + MW + 8, y + 26), "%.0f с" % st["time"], font=f12, fill=DIM)
    # итоги
    RX = MX + MW + 90
    for k, r in enumerate(st.get("rows", [])):
        rx = RX + (k % 2) * 260
        ry = y + 14 + (k // 2) * 44
        stars = "★" * r["stars"] + "☆" * (3 - r["stars"])
        name = ("бот · " if r["bot"] else "") + r["name"]
        dr.text((rx, ry), name, font=f14, fill=DIM if r["bot"] else TEXT)
        dr.text((rx, ry + 18), stars + ("" if r["passed"] else "  (на балконе)"), font=f14,
                fill=(255, 205, 70) if r["passed"] else (255, 140, 140))
ly = H - 32
dr.text((30, ly), "Цвет — категория: выживание · гонка · смекалка · вместе · спокойный · босс. "
        "Вид сверху — детали этажа, которые строит сервер. ★ — звёзды за этаж (прошёл, топ-3, без падений).",
        font=f12, fill=DIM)
img.save(dst)
print("saved", dst, img.size)
