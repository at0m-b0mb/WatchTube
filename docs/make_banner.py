#!/usr/bin/env python3
"""Generates docs/banner.svg + docs/banner.png — the WatchTube hero.

Frames the real app screenshots inside Apple Watch Ultra mockups on the
app's own brand gradient (matches Sources/Support/Theme.swift). Run from
the repo root:  python3 docs/make_banner.py
"""
import base64, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"

def b64(name):
    data = (SHOTS / name).read_bytes()
    return "data:image/png;base64," + base64.b64encode(data).decode()

HOME = b64("home.png")
SEARCH = b64("search.png")

W, H = 1500, 600

def watch(cx, cy, scale, rot, img, sid):
    """An Apple Watch Ultra mockup, screen filled with `img`, centred on (cx,cy)."""
    bw, bh = 360, 426          # titanium body box
    return f'''
    <g transform="translate({cx},{cy}) rotate({rot}) scale({scale}) translate({-bw/2},{-bh/2})">
      <!-- soft drop shadow -->
      <rect x="-6" y="14" width="{bw+12}" height="{bh}" rx="86" fill="#000" opacity="0.55" filter="url(#soft)"/>
      <!-- band stubs -->
      <path d="M70,-70 L290,-70 L300,30 L60,30 Z" fill="#24211f"/>
      <path d="M60,396 L300,396 L290,496 L70,496 Z" fill="#1d1a18"/>
      <!-- titanium body -->
      <rect x="0" y="0" width="{bw}" height="{bh}" rx="78" fill="url(#ti)"/>
      <rect x="0" y="0" width="{bw}" height="{bh}" rx="78" fill="none" stroke="#5b5b5d" stroke-width="2"/>
      <rect x="3" y="3" width="{bw-6}" height="{bh-6}" rx="75" fill="none" stroke="#000" stroke-opacity="0.4" stroke-width="2"/>
      <!-- action button (Ultra orange) -->
      <rect x="-13" y="183" width="15" height="60" rx="5" fill="#ff5a1f"/>
      <!-- digital crown -->
      <rect x="357" y="146" width="9" height="50" rx="3" fill="#3a3a3c"/>
      <rect x="358" y="150" width="15" height="44" rx="6" fill="url(#crown)" stroke="#1b1b1d" stroke-width="1"/>
      <circle cx="365.5" cy="172" r="4.4" fill="#d23b2a"/>
      <!-- side button -->
      <rect x="358" y="214" width="12" height="58" rx="6" fill="url(#crown)" stroke="#1b1b1d" stroke-width="1"/>
      <!-- black glass faceplate -->
      <rect x="16" y="16" width="{bw-32}" height="{bh-32}" rx="66" fill="#000"/>
      <!-- screen -->
      <clipPath id="clip{sid}"><rect x="30" y="30" width="300" height="366" rx="54"/></clipPath>
      <image href="{img}" x="30" y="30" width="300" height="366"
             preserveAspectRatio="xMidYMid slice" clip-path="url(#clip{sid})"/>
      <!-- glass glare -->
      <path d="M30,30 h300 a54,54 0 0 1 54,54 v40 q-180,70 -354,-10 v-30 a54,54 0 0 1 54,-54 z"
            fill="url(#glare)" clip-path="url(#clip{sid})" opacity="0.5"/>
    </g>'''

pill_x = 96
def pill(label):
    global pill_x
    w = 34 + len(label) * 15
    s = f'''<g transform="translate({pill_x},452)">
      <rect x="0" y="0" width="{w}" height="50" rx="25" fill="#ff2d2d" fill-opacity="0.10" stroke="#ff3b3b" stroke-opacity="0.55" stroke-width="1.5"/>
      <text x="{w/2}" y="33" text-anchor="middle" font-family="'Helvetica Neue',Helvetica,Arial,sans-serif" font-size="24" font-weight="600" fill="#ff8a8a">{label}</text>
    </g>'''
    pill_x += w + 16
    return s

pills = "".join(pill(p) for p in ["Standalone", "Keyless", "Private", "Free"])

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="'Helvetica Neue',Helvetica,Arial,sans-serif">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0" stop-color="#2a070c"/>
      <stop offset="0.55" stop-color="#0c0405"/>
      <stop offset="1" stop-color="#000000"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.78" cy="0.42" r="0.55">
      <stop offset="0" stop-color="#ff1f1f" stop-opacity="0.42"/>
      <stop offset="0.5" stop-color="#c11414" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="ti" x1="0" y1="0" x2="0.3" y2="1">
      <stop offset="0" stop-color="#54545a"/>
      <stop offset="0.5" stop-color="#37373b"/>
      <stop offset="1" stop-color="#202024"/>
    </linearGradient>
    <linearGradient id="crown" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#8a8a8d"/>
      <stop offset="0.5" stop-color="#e6e6e8"/>
      <stop offset="1" stop-color="#7a7a7d"/>
    </linearGradient>
    <linearGradient id="logo" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ff4242"/>
      <stop offset="1" stop-color="#c20a0a"/>
    </linearGradient>
    <linearGradient id="glare" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="22"/>
    </filter>
  </defs>

  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#glow)"/>

  <!-- ===== watches (right) ===== -->
  {watch(905, 322, 0.80, -9, SEARCH, "s")}
  {watch(1165, 300, 1.0, 5, HOME, "h")}

  <!-- ===== branding (left) ===== -->
  <!-- app-icon squircle + play glyph -->
  <g transform="translate(96,96)">
    <rect x="0" y="0" width="116" height="116" rx="28" fill="url(#logo)"/>
    <rect x="0" y="0" width="116" height="116" rx="28" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="2"/>
    <path d="M44,34 L86,58 L44,82 Z" fill="#ffffff"/>
  </g>

  <!-- wordmark -->
  <text x="232" y="158" font-size="92" font-weight="bold" letter-spacing="-3">
    <tspan fill="#ffffff">Watch</tspan><tspan fill="#ff2d2d">Tube</tspan>
  </text>

  <!-- tagline -->
  <text x="98" y="252" font-size="36" font-weight="600" fill="#f2eaec">Keyless YouTube, native on your Apple&#160;Watch.</text>
  <text x="98" y="312" font-size="27" fill="#a89ea1">Search &amp; play video + audio on the watch &#8212; no phone,</text>
  <text x="98" y="350" font-size="27" fill="#a89ea1">no Google account, no API key, no analytics.</text>

  <!-- spec line -->
  <text x="98" y="410" font-size="22" font-weight="600" fill="#6f6669" letter-spacing="2">watchOS 10+   ·   SwiftUI   ·   ZERO DEPENDENCIES</text>

  {pills}
</svg>'''

out_svg = ROOT / "docs" / "banner.svg"
out_svg.write_text(svg)
print("wrote", out_svg)

png = ROOT / "docs" / "banner.png"
subprocess.run(["rsvg-convert", "-z", "2", str(out_svg), "-o", str(png)], check=True)
print("wrote", png)
