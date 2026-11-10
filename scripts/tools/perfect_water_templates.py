import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageOps

W_TPL, H_TPL = 512, 711

def load_font(size, bold=True):
    paths = [
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
        "/usr/share/fonts/opentype/urw-base35/P052-Bold.otf" if bold else "/usr/share/fonts/opentype/urw-base35/P052-Roman.otf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()

# -----------------------------------------------------------------
# 1. PERFECT stone_water.png
# -----------------------------------------------------------------
def make_stone_water():
    print("Crafting perfect stone_water.png...")
    base = Image.open("assets/templates/stone_ice.png").convert("RGBA")
    
    # 1. Monolith Central Area (x: 44..468, y: 114..456)
    mw, mh = 468 - 44, 456 - 114
    mono_crop = base.crop((44, 114, 468, 456))
    
    arr = np.array(mono_crop, dtype=np.float32)
    arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.60, 0, 255)
    arr[:, :, 1] = np.clip(arr[:, :, 1] * 0.90, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.15, 0, 255)
    mono_tinted = Image.fromarray(arr.astype(np.uint8))
    
    surge = Image.open("assets/art/tidal_surge.jpg").resize((mw, mh), Image.Resampling.LANCZOS)
    mask = Image.new("L", (mw, mh), 0)
    m_draw = ImageDraw.Draw(mask)
    for y in range(mh):
        if y > int(mh * 0.55):
            val = int(255 * (y - mh * 0.55) / (mh * 0.45))
            m_draw.line([(0, y), (mw, y)], fill=val)
    mono_blended = Image.composite(surge, mono_tinted, mask)
    
    w_icon = Image.open("assets/icons/water.png").convert("RGBA").resize((64, 64), Image.Resampling.LANCZOS)
    mono_blended.paste(w_icon, (mw // 2 - 32, 115), w_icon)
    
    glow = Image.new("RGBA", (mw, mh), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.ellipse([mw // 2 - 80, 100, mw // 2 + 80, 260], fill=(40, 180, 255, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(25))
    mono_final = Image.alpha_composite(mono_blended.convert("RGBA"), glow)
    base.paste(mono_final, (44, 114))

    # 2. Golden Hexagon Water Icon (x: 25..105, y: 25..105)
    hex_icon = Image.open("assets/icons/water.png").convert("RGBA").resize((70, 70), Image.Resampling.LANCZOS)
    mask = Image.new("L", (70, 70), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, 68, 68], fill=255)
    base.paste(hex_icon, (30, 30), mask)

    # 3. Golden Ribbon Banner: Cleanly cover entire old ribbon region (x: 105..465, y: 42..98)
    banner_w, banner_h = 465 - 105, 105 - 42
    banner = Image.new("RGBA", (banner_w, banner_h), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(banner)
    for y in range(banner_h):
        t = y / float(banner_h)
        r = int(230 * (1-t) + 175 * t)
        g = int(205 * (1-t) + 145 * t)
        b = int(145 * (1-t) + 95 * t)
        b_draw.line([(0, y), (banner_w, y)], fill=(r, g, b, 255))
    b_draw.rectangle([2, 2, banner_w - 3, banner_h - 3], outline=(95, 70, 30, 255), width=2)
    b_draw.rectangle([4, 4, banner_w - 5, banner_h - 5], outline=(255, 240, 180, 180), width=1)
    
    font = load_font(18, bold=True)
    text = "WATER ELEMENT STONE"
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (banner_w - tw) // 2
    ty = (banner_h - th) // 2 - 2
    b_draw.text((tx + 1, ty + 1), text, font=font, fill=(255, 235, 170, 220))
    b_draw.text((tx, ty), text, font=font, fill=(8, 20, 38, 255))
    base.paste(banner, (105, 42))

    # 4. Clean Parchment with Water Droplet Watermark (x: 54..458, y: 465..670)
    sup = Image.open("assets/templates/template_support.png")
    clean_parch = sup.crop((60, 470, 456, 665)).resize((458 - 54, 670 - 465), Image.Resampling.LANCZOS).convert("RGBA")
    
    wm = w_icon.resize((95, 95), Image.Resampling.LANCZOS)
    wm_arr = np.array(wm, dtype=np.float32)
    wm_arr[:, :, 3] = wm_arr[:, :, 3] * 0.22
    wm_faint = Image.fromarray(wm_arr.astype(np.uint8))
    pw, ph = clean_parch.size
    clean_parch.paste(wm_faint, ((pw - 95)//2, (ph - 95)//2), wm_faint)
    
    base.paste(clean_parch, (54, 465))
    base.convert("RGB").save("assets/templates/stone_water.png", quality=95)
    print("Saved perfect stone_water.png.")

# -----------------------------------------------------------------
# 2. PERFECT realm_water.png
# -----------------------------------------------------------------
def make_realm_water():
    print("Crafting perfect realm_water.png...")
    base = Image.open("assets/templates/realm_ice.png").convert("RGBA")
    
    arr = np.array(base, dtype=np.float32)
    arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.70, 0, 255)
    arr[:, :, 1] = np.clip(arr[:, :, 1] * 0.90, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.15, 0, 255)
    base = Image.fromarray(arr.astype(np.uint8))
    
    # Top left hexagon (x: 25..105, y: 25..105): water icon
    w_icon = Image.open("assets/icons/water.png").convert("RGBA").resize((70, 70), Image.Resampling.LANCZOS)
    mask = Image.new("L", (70, 70), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, 68, 68], fill=255)
    base.paste(w_icon, (30, 30), mask)
    
    # Top right hexagon (x: 407..487, y: 25..105): replace snowflake with water icon
    base.paste(w_icon, (412, 30), mask)
    
    # Bottom Center Crest (x: 232..280, y: 636..684): glowing water crest
    w_crest = w_icon.resize((48, 48), Image.Resampling.LANCZOS)
    mask_crest = Image.new("L", (48, 48), 0)
    ImageDraw.Draw(mask_crest).ellipse([2, 2, 46, 46], fill=255)
    base.paste(w_crest, (256 - 24, 660 - 24), mask_crest)

    base.save("assets/templates/realm_water.png")
    print("Saved perfect realm_water.png.")

# -----------------------------------------------------------------
# 3. PERFECT spell_water.png
# -----------------------------------------------------------------
def make_spell_water():
    print("Crafting perfect spell_water.png...")
    base = Image.open("assets/templates/spell_ice.png").convert("RGBA")
    
    arr = np.array(base, dtype=np.float32)
    arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.75, 0, 255)
    arr[:, :, 1] = np.clip(arr[:, :, 1] * 0.92, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.12, 0, 255)
    base = Image.fromarray(arr.astype(np.uint8))
    
    w_icon = Image.open("assets/icons/water.png").convert("RGBA").resize((66, 66), Image.Resampling.LANCZOS)
    mask = Image.new("L", (66, 66), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, 64, 64], fill=255)
    base.paste(w_icon, (32, 32), mask)
    
    # Clean Parchment Box covering the entire ability box (x: 54..458, y: 430..665)
    sup = Image.open("assets/templates/template_support.png")
    clean_parch = sup.crop((60, 470, 456, 665)).resize((458 - 54, 665 - 430), Image.Resampling.LANCZOS).convert("RGBA")
    
    wm = w_icon.resize((100, 100), Image.Resampling.LANCZOS)
    wm_arr = np.array(wm, dtype=np.float32)
    wm_arr[:, :, 3] = wm_arr[:, :, 3] * 0.22
    wm_faint = Image.fromarray(wm_arr.astype(np.uint8))
    pw, ph = clean_parch.size
    clean_parch.paste(wm_faint, ((pw - 100)//2, (ph - 100)//2), wm_faint)
    
    base.paste(clean_parch, (54, 430))
    base.convert("RGB").save("assets/templates/spell_water.png", quality=95)
    print("Saved perfect spell_water.png.")

if __name__ == "__main__":
    make_stone_water()
    make_realm_water()
    make_spell_water()
