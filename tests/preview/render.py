#!/usr/bin/env python3
"""Tiny orthographic raycaster for previewing part-built Roblox models.

Reads the JSON emitted by tests/preview/dump.luau:
  {"models": [{"name": str, "parts": [{"shape", "p", "r", "s", "c", "t", "neon"}]}]}
and writes a PNG contact sheet (one tile per model) or a single large render.

Supports Block, Ball, Cylinder (axis = local X) and Wedge parts.
"""
import argparse
import json
import math

import numpy as np
from PIL import Image, ImageDraw

LIGHT = np.array([-0.45, 0.8, 0.35])
LIGHT /= np.linalg.norm(LIGHT)


def camera_basis(azimuth, elevation):
    az, el = math.radians(azimuth), math.radians(elevation)
    # Direction the camera looks along (from camera towards scene).
    d = -np.array([math.cos(el) * math.sin(az), math.sin(el), math.cos(el) * math.cos(az)])
    d /= np.linalg.norm(d)
    right = np.cross(d, [0.0, 1.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, d)
    return d, right, up


def intersect(part, o, d):
    """Returns (t, normal_world) arrays for rays o + t d (N,3); t = inf when missed."""
    R = np.array(part["r"], dtype=float).reshape(3, 3)
    p = np.array(part["p"], dtype=float)
    s = np.array(part["s"], dtype=float)
    ol = (o - p) @ R  # world -> local (R columns are local axes)
    dl = d @ R
    n = o.shape[0]
    t = np.full(n, np.inf)
    nl = np.zeros((n, 3))
    shape = part["shape"]
    eps = 1e-9

    def slabs(half):
        with np.errstate(divide="ignore", invalid="ignore"):
            inv = 1.0 / np.where(np.abs(dl) < eps, eps, dl)
            t1 = (-half - ol) * inv
            t2 = (half - ol) * inv
        tmin = np.minimum(t1, t2)
        tmax = np.maximum(t1, t2)
        enter = tmin.max(axis=1)
        exit_ = tmax.min(axis=1)
        axis = tmin.argmax(axis=1)
        return enter, exit_, axis

    if shape in ("Block", "Wedge"):
        half = s / 2
        enter, exit_, axis = slabs(half)
        normal = np.zeros((n, 3))
        idx = np.arange(n)
        normal[idx, axis] = -np.sign(dl[idx, axis])
        if shape == "Wedge":
            h, dep = s[1], s[2]
            g0 = (ol[:, 1] + h / 2) / h - (ol[:, 2] + dep / 2) / dep
            gd = dl[:, 1] / h - dl[:, 2] / dep
            with np.errstate(divide="ignore", invalid="ignore"):
                tp = -g0 / np.where(np.abs(gd) < eps, eps, gd)
            plane_enter = np.where(gd < 0, tp, -np.inf)
            plane_exit = np.where(gd > 0, tp, np.inf)
            outside = (np.abs(gd) < eps) & (g0 > 0)
            pn = np.array([0.0, 1.0 / h, -1.0 / dep])
            pn /= np.linalg.norm(pn)
            use_plane = plane_enter > enter
            enter = np.maximum(enter, plane_enter)
            exit_ = np.minimum(exit_, plane_exit)
            normal[use_plane] = pn
            enter[outside] = np.inf
        hit = (enter <= exit_) & (exit_ > 0)
        t = np.where(hit, np.maximum(enter, 0), np.inf)
        nl = normal
    elif shape == "Ball":
        r = s.min() / 2
        b = (ol * dl).sum(1)
        c = (ol * ol).sum(1) - r * r
        a = (dl * dl).sum(1)
        disc = b * b - a * c
        ok = disc >= 0
        tt = (-b - np.sqrt(np.where(ok, disc, 0))) / a
        t = np.where(ok & (tt > 0), tt, np.inf)
        nl = ol + dl * np.where(np.isfinite(t), t, 0)[:, None]
    elif shape == "Cylinder":
        r = min(s[1], s[2]) / 2
        hx = s[0] / 2
        # Side: y^2 + z^2 = r^2
        a = dl[:, 1] ** 2 + dl[:, 2] ** 2
        b = ol[:, 1] * dl[:, 1] + ol[:, 2] * dl[:, 2]
        c = ol[:, 1] ** 2 + ol[:, 2] ** 2 - r * r
        disc = b * b - a * c
        ok = (disc >= 0) & (a > eps)
        ts = (-b - np.sqrt(np.where(ok, disc, 0))) / np.where(a > eps, a, 1)
        xs = ol[:, 0] + dl[:, 0] * ts
        side = ok & (ts > 0) & (np.abs(xs) <= hx)
        # Caps: x = +-hx
        with np.errstate(divide="ignore", invalid="ignore"):
            tc1 = (hx - ol[:, 0]) / np.where(np.abs(dl[:, 0]) < eps, eps, dl[:, 0])
            tc2 = (-hx - ol[:, 0]) / np.where(np.abs(dl[:, 0]) < eps, eps, dl[:, 0])
        tc = np.minimum(np.where(tc1 > 0, tc1, np.inf), np.where(tc2 > 0, tc2, np.inf))
        pc = ol + dl * np.where(np.isfinite(tc), tc, 0)[:, None]
        cap = np.isfinite(tc) & (pc[:, 1] ** 2 + pc[:, 2] ** 2 <= r * r)
        t_side = np.where(side, ts, np.inf)
        t_cap = np.where(cap, tc, np.inf)
        t = np.minimum(t_side, t_cap)
        hitp = ol + dl * np.where(np.isfinite(t), t, 0)[:, None]
        nl = np.where((t_side <= t_cap)[:, None], hitp * np.array([0, 1, 1]), np.stack([np.sign(hitp[:, 0]), np.zeros(n), np.zeros(n)], 1))
    else:
        return t, nl
    nw = nl @ R.T
    norm = np.linalg.norm(nw, axis=1, keepdims=True)
    nw = nw / np.where(norm == 0, 1, norm)
    return t, nw


def bounds(parts):
    pts = []
    for part in parts:
        R = np.array(part["r"]).reshape(3, 3)
        h = np.array(part["s"]) / 2
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    pts.append(np.array(part["p"]) + R @ (h * [sx, sy, sz]))
    pts = np.array(pts)
    return pts.min(0), pts.max(0)


def render(parts, size, azimuth=35, elevation=28, background=(236, 240, 247), lo=None, hi=None, shadows=True):
    parts = [p for p in parts if p.get("t", 0) < 0.6]
    if not parts:
        return Image.new("RGB", (size, size), background)
    if lo is None:
        lo, hi = bounds(parts)
    center = (lo + hi) / 2
    radius = np.linalg.norm(hi - lo) / 2 * 1.05
    d, right, up = camera_basis(azimuth, elevation)
    w = h = size
    us = (np.arange(w) + 0.5) / w * 2 - 1
    vs = 1 - (np.arange(h) + 0.5) / h * 2
    U, V = np.meshgrid(us, vs)
    origins = center - d * radius * 4 + (U.reshape(-1, 1) * right + V.reshape(-1, 1) * up) * radius
    dirs = np.broadcast_to(d, origins.shape)

    # Screen-space culling per part.
    best_t = np.full(w * h, np.inf)
    best_n = np.zeros((w * h, 3))
    best_c = np.zeros((w * h, 3))
    best_neon = np.zeros(w * h, dtype=bool)
    for part in parts:
        R = np.array(part["r"]).reshape(3, 3)
        ext = np.abs(R) @ (np.array(part["s"]) / 2)
        pc = np.array(part["p"]) - center
        pr = np.linalg.norm(ext)
        cu, cv = pc @ right / radius, pc @ up / radius
        rr = pr / radius
        x0 = int(max(0, ((cu - rr) + 1) / 2 * w - 1))
        x1 = int(min(w, ((cu + rr) + 1) / 2 * w + 2))
        y0 = int(max(0, (1 - (cv + rr)) / 2 * h - 1))
        y1 = int(min(h, (1 - (cv - rr)) / 2 * h + 2))
        if x0 >= x1 or y0 >= y1:
            continue
        idx = (np.arange(y0, y1)[:, None] * w + np.arange(x0, x1)[None, :]).reshape(-1)
        t, nrm = intersect(part, origins[idx], dirs[idx])
        closer = t < best_t[idx]
        sel = idx[closer]
        best_t[sel] = t[closer]
        best_n[sel] = nrm[closer]
        best_c[sel] = np.array(part["c"])
        best_neon[sel] = bool(part.get("neon"))

    hit = np.isfinite(best_t)
    lam = np.clip((best_n * LIGHT).sum(1), 0, 1)
    shade = 0.55 + 0.55 * lam
    if shadows and hit.any():
        # One shadow ray per hit pixel toward the light.
        hp = origins[hit] + dirs[hit] * best_t[hit][:, None] + best_n[hit] * 0.03
        ld = np.broadcast_to(LIGHT, hp.shape)
        blocked = np.zeros(hp.shape[0], dtype=bool)
        for part in parts:
            if part.get("neon"):
                continue
            t, _ = intersect(part, hp, ld)
            blocked |= np.isfinite(t)
        sh = np.ones(w * h)
        sh[np.where(hit)[0][blocked]] = 0.72
        shade = shade * sh
    # Rim light for a toon feel.
    rim = np.clip(1 - np.abs((best_n * -d).sum(1)), 0, 1) ** 3 * 0.25
    col = best_c * shade[:, None] + rim[:, None]
    col[best_neon] = np.clip(best_c[best_neon] * 1.25 + 0.15, 0, 1)
    img = np.tile(np.array(background, dtype=float) / 255, (w * h, 1))
    img[hit] = np.clip(col[hit], 0, 1)
    # Dark outline where depth jumps (silhouette + creases), toon-style.
    depth = np.where(hit, best_t, 1e9).reshape(h, w)
    edge = np.zeros((h, w), dtype=bool)
    jump = radius * 0.04
    edge[:, 1:] |= np.abs(depth[:, 1:] - depth[:, :-1]) > jump
    edge[1:, :] |= np.abs(depth[1:, :] - depth[:-1, :]) > jump
    img = img.reshape(h, w, 3)
    img[edge] *= 0.35
    return Image.fromarray((img * 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--tile", type=int, default=220)
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--az", type=float, default=215)
    ap.add_argument("--el", type=float, default=25)
    ap.add_argument("--single", action="store_true", help="render all models into one image")
    ap.add_argument("--size", type=int, default=900)
    ap.add_argument("--noshadow", action="store_true")
    args = ap.parse_args()
    data = json.load(open(args.input))
    models = data["models"]
    if args.single:
        parts = [p for m in models for p in m["parts"]]
        img = render(parts, args.size, args.az, args.el, shadows=not args.noshadow)
        img.save(args.output)
        print(f"rendered {len(parts)} parts -> {args.output}")
        return
    cols = min(args.cols, len(models))
    rows = math.ceil(len(models) / cols)
    sheet = Image.new("RGB", (cols * args.tile, rows * (args.tile + 18)), (40, 40, 48))
    draw = ImageDraw.Draw(sheet)
    for i, model in enumerate(models):
        img = render(model["parts"], args.tile, args.az, args.el, shadows=not args.noshadow)
        x, y = (i % cols) * args.tile, (i // cols) * (args.tile + 18)
        sheet.paste(img, (x, y))
        draw.text((x + 4, y + args.tile + 3), f"{model['name']} ({len(model['parts'])})", fill=(255, 255, 255))
    sheet.save(args.output)
    print(f"rendered {len(models)} models -> {args.output}")


if __name__ == "__main__":
    main()
