import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageOps

W, H = 768, 768

def create_radial_gradient(w, h, cx, cy, rad, c_inner, c_outer):
    y, x = np.ogrid[:h, :w]
    dist = np.sqrt((x - cx)**2 + (y - cy)**2)
    t = np.clip(dist / rad, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    img = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(3):
        img[:, :, i] = c_inner[i] * (1.0 - t) + c_outer[i] * t
    return img

def add_noise(img, strength=0.06):
    noise = np.random.uniform(-strength, strength, img.shape)
    return np.clip(img + noise, 0.0, 1.0)

def draw_glow_circle(im, cx, cy, radius, color, blur=20):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    im.paste(overlay, (0, 0), overlay)

def draw_light_rays(im, cx, cy, count=16, length=550, color=(200, 240, 255, 45)):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for i in range(count):
        angle = (i / float(count)) * math.tau + 0.1
        a_w = 0.07
        p1 = (cx + math.cos(angle - a_w) * length, cy + math.sin(angle - a_w) * length)
        p2 = (cx + math.cos(angle + a_w) * length, cy + math.sin(angle + a_w) * length)
        draw.polygon([(cx, cy), p1, p2], fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(10))
    im.paste(overlay, (0, 0), overlay)

# -------------------------------------------------------------
# 1. WATER DRAGON (water_dragon.jpg)
# -------------------------------------------------------------
def gen_water_dragon():
    print("Generating assets/art/water_dragon.jpg...")
    # Base: composite from tidal_surge.jpg and ice_dragon.jpg
    surge = Image.open("assets/art/tidal_surge.jpg").resize((W, H), Image.Resampling.LANCZOS)
    ice_drg = Image.open("assets/art/ice_dragon.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Recolor ice dragon to sapphire & deep oceanic teal
    drg_arr = np.array(ice_drg, dtype=np.float32)
    drg_arr[:, :, 0] *= 0.65 # less red
    drg_arr[:, :, 1] *= 0.95 # preserve cyan/teal
    drg_arr[:, :, 2] *= 1.15 # enhance deep blue
    drg_tinted = Image.fromarray(np.clip(drg_arr, 0, 255).astype(np.uint8))
    
    # Blend tidal surge background with dragon figure
    # We want the surging waves below and behind, dragon soaring above
    mask = Image.new("L", (W, H), 0)
    m_draw = ImageDraw.Draw(mask)
    # Dragon body in upper center
    m_draw.ellipse([100, 40, 680, 580], fill=240)
    mask = mask.filter(ImageFilter.GaussianBlur(40))
    
    im = Image.composite(drg_tinted, surge, mask)
    
    # Add dramatic luminous ocean lighting & water spray
    im_rgba = im.convert("RGBA")
    draw_light_rays(im_rgba, 384, 200, count=14, length=600, color=(160, 230, 255, 60))
    draw_glow_circle(im_rgba, 384, 280, 180, (40, 160, 240, 90), blur=45)
    draw_glow_circle(im_rgba, 384, 260, 90, (180, 245, 255, 140), blur=20)
    
    # Glowing water eyes & horns
    draw = ImageDraw.Draw(im_rgba)
    draw.ellipse([345, 245, 365, 258], fill=(220, 255, 255, 255))
    draw.ellipse([405, 245, 425, 258], fill=(220, 255, 255, 255))
    
    # Foaming crest waves across bottom
    for _ in range(250):
        fx = random.randint(20, W - 20)
        fy = random.randint(480, H - 10)
        r = random.randint(2, 6)
        draw.ellipse([fx - r, fy - r, fx + r, fy + r], fill=(220, 245, 255, random.randint(140, 230)))
        
    im_rgba.convert("RGB").save("assets/art/water_dragon.jpg", quality=95)
    print("Saved water_dragon.jpg")

# -------------------------------------------------------------
# 2. TIDAL SERPENT (tidal_serpent.jpg)
# -------------------------------------------------------------
def gen_tidal_serpent():
    print("Generating assets/art/tidal_serpent.jpg...")
    # Base: abyssal_drain.jpg + cyclone_serpent.jpg
    drain = Image.open("assets/art/abyssal_drain.jpg").resize((W, H), Image.Resampling.LANCZOS)
    serp = Image.open("assets/art/cyclone_serpent.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Recolor serpent to deep abyssal sea-emerald and marine sapphire
    s_arr = np.array(serp, dtype=np.float32)
    s_arr[:, :, 0] *= 0.40 # kill warm tones
    s_arr[:, :, 1] *= 1.10 # luminous aquatic emerald
    s_arr[:, :, 2] *= 1.25 # deep ocean indigo
    s_tinted = Image.fromarray(np.clip(s_arr, 0, 255).astype(np.uint8))
    
    # Blend whirlpool abyss with giant coiling sea serpent
    mask = Image.new("L", (W, H), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.ellipse([80, 100, 680, 680], fill=220)
    mask = mask.filter(ImageFilter.GaussianBlur(35))
    
    im = Image.composite(s_tinted, drain, mask).convert("RGBA")
    
    # Add deep ocean bioluminescence & bubbles
    draw_glow_circle(im, 384, 384, 160, (0, 220, 200, 80), blur=40)
    draw_glow_circle(im, 350, 320, 70, (140, 255, 230, 130), blur=15)
    
    draw = ImageDraw.Draw(im)
    # Floating abyssal bioluminescent motes & rising air bubbles
    for _ in range(180):
        bx = random.randint(40, W - 40)
        by = random.randint(40, H - 40)
        rad = random.randint(2, 7)
        alpha = random.randint(120, 240)
        draw.ellipse([bx - rad, by - rad, bx + rad, by + rad], outline=(120, 240, 255, alpha), width=2)
        draw.ellipse([bx - rad + 2, by - rad + 2, bx - rad + 4, by - rad + 4], fill=(240, 255, 255, alpha))
        
    im.convert("RGB").save("assets/art/tidal_serpent.jpg", quality=95)
    print("Saved tidal_serpent.jpg")

# -------------------------------------------------------------
# 3. TRANSCENDENT WATER DRAGON (transcendent_water_dragon.jpg)
# -------------------------------------------------------------
def gen_transcendent_water_dragon():
    print("Generating assets/art/transcendent_water_dragon.jpg...")
    # Colossal leviathan sovereign dragon commanding towering tidal wave
    surge = Image.open("assets/art/tidal_surge.jpg").resize((W, H), Image.Resampling.LANCZOS)
    god_drg = Image.open("assets/art/god_dragon.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Shift god dragon to celestial oceanic gold & aquamarine
    g_arr = np.array(god_drg, dtype=np.float32)
    g_arr[:, :, 0] *= 0.70
    g_arr[:, :, 1] *= 1.05
    g_arr[:, :, 2] *= 1.30
    g_tinted = Image.fromarray(np.clip(g_arr, 0, 255).astype(np.uint8))
    
    mask = Image.new("L", (W, H), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.ellipse([80, 50, 680, 600], fill=230)
    mask = mask.filter(ImageFilter.GaussianBlur(30))
    
    im = Image.composite(g_tinted, surge, mask).convert("RGBA")
    
    # Transcendent divine water aura & golden crown rays
    draw_light_rays(im, 384, 240, count=20, length=600, color=(255, 235, 160, 70))
    draw_glow_circle(im, 384, 240, 200, (60, 190, 255, 120), blur=50)
    draw_glow_circle(im, 384, 220, 100, (255, 240, 180, 180), blur=25)
    
    # Divine Water Crown / Crest
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 180
    crown_pts = [
        (cx - 80, cy + 20), (cx - 40, cy - 50), (cx - 15, cy - 10),
        (cx, cy - 80), (cx + 15, cy - 10), (cx + 40, cy - 50), (cx + 80, cy + 20)
    ]
    draw.polygon(crown_pts, outline=(255, 230, 120, 240), width=4)
    draw_glow_circle(im, cx, cy - 80, 40, (255, 255, 200, 220), blur=12)
    
    # Majestic cataclysmic waterfall particles
    for _ in range(300):
        px = random.randint(40, W - 40)
        py = random.randint(400, H - 10)
        draw.line([(px, py), (px, py + random.randint(8, 24))], fill=(210, 245, 255, random.randint(160, 240)), width=random.randint(1, 3))
        
    im.convert("RGB").save("assets/art/transcendent_water_dragon.jpg", quality=95)
    print("Saved transcendent_water_dragon.jpg")

# -------------------------------------------------------------
# 4. ABYSSAL TRENCH (abyssal_trench.jpg)
# -------------------------------------------------------------
def gen_abyssal_trench():
    print("Generating assets/art/abyssal_trench.jpg...")
    # Underwater sunken realm: abyssal_void_realm.jpg + glacial_citadel.jpg
    void_r = Image.open("assets/art/abyssal_void_realm.jpg").resize((W, H), Image.Resampling.LANCZOS)
    citadel = Image.open("assets/art/glacial_citadel.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Oceanic trench color grade (deep midnight sapphire + glowing hydrothermal turquoise)
    v_arr = np.array(void_r, dtype=np.float32)
    v_arr[:, :, 0] *= 0.45
    v_arr[:, :, 1] *= 0.90
    v_arr[:, :, 2] *= 1.35
    v_tinted = Image.fromarray(np.clip(v_arr, 0, 255).astype(np.uint8))
    
    im = Image.blend(v_tinted, citadel, 0.35).convert("RGBA")
    
    # Ethereal underwater light shafts descending from the sea surface
    draw_light_rays(im, 384, -50, count=12, length=850, color=(140, 230, 255, 55))
    
    # Glowing thermal vents in the abyss
    draw_glow_circle(im, 240, 580, 110, (0, 240, 220, 160), blur=35)
    draw_glow_circle(im, 520, 620, 130, (30, 180, 255, 160), blur=40)
    
    draw = ImageDraw.Draw(im)
    # Sunken draconic obelisks and undersea pillars
    for px, py, pw, ph in [(140, 360, 55, 280), (580, 320, 65, 320), (360, 420, 48, 220)]:
        draw.rectangle([px, py, px + pw, py + ph], fill=(8, 22, 42, 240), outline=(60, 160, 220, 200), width=3)
        # Ancient carved runes
        for ry in range(py + 25, py + ph - 25, 30):
            draw.line([(px + 10, ry), (px + pw - 10, ry)], fill=(120, 240, 255, 220), width=2)
            
    # Floating plankton & abyssal light motes
    for _ in range(150):
        mx = random.randint(20, W - 20)
        my = random.randint(100, H - 20)
        draw.ellipse([mx - 2, my - 2, mx + 2, my + 2], fill=(160, 255, 240, random.randint(140, 240)))
        
    im.convert("RGB").save("assets/art/abyssal_trench.jpg", quality=95)
    print("Saved abyssal_trench.jpg")

# -------------------------------------------------------------
# 5. TORRENTIAL BLAST (torrential_blast.jpg)
# -------------------------------------------------------------
def gen_torrential_blast():
    print("Generating assets/art/torrential_blast.jpg...")
    # Base: violent crushing geyser blast
    surge = Image.open("assets/art/tidal_surge.jpg").resize((W, H), Image.Resampling.LANCZOS)
    inf_surge = Image.open("assets/art/inferno_surge.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Recolor inferno surge blast to high-pressure turquoise water blast
    b_arr = np.array(inf_surge, dtype=np.float32)
    # Swap red and blue
    b_recolored = np.zeros_like(b_arr)
    b_recolored[:, :, 0] = b_arr[:, :, 2] * 0.5  # red becomes low
    b_recolored[:, :, 1] = b_arr[:, :, 1] * 1.1  # vibrant cyan/green
    b_recolored[:, :, 2] = b_arr[:, :, 0] * 1.2  # high blue
    b_tinted = Image.fromarray(np.clip(b_recolored, 0, 255).astype(np.uint8))
    
    im = Image.blend(surge, b_tinted, 0.65).convert("RGBA")
    
    # Concentrated hydro-cannon geyser core
    draw_glow_circle(im, 384, 400, 160, (0, 200, 255, 180), blur=40)
    draw_glow_circle(im, 384, 380, 90, (200, 250, 255, 240), blur=20)
    
    draw = ImageDraw.Draw(im)
    # Violent water stream lines bursting upward
    for _ in range(70):
        sx = 384 + random.randint(-40, 40)
        sy = 650 + random.randint(-50, 50)
        ex = 384 + random.randint(-280, 280)
        ey = 100 + random.randint(-80, 150)
        col = (random.randint(180, 255), random.randint(230, 255), 255, random.randint(140, 240))
        draw.line([(sx, sy), (ex, ey)], fill=col, width=random.randint(3, 8))
        
    # Shockwave water rings
    for r in [120, 200, 280, 360]:
        draw.ellipse([384 - r, 400 - int(r*0.5), 384 + r, 400 + int(r*0.5)], outline=(180, 240, 255, 160), width=4)
        
    im.convert("RGB").save("assets/art/torrential_blast.jpg", quality=95)
    print("Saved torrential_blast.jpg")

# -------------------------------------------------------------
# 6. TIDAL BLESSING (tidal_blessing.jpg)
# -------------------------------------------------------------
def gen_tidal_blessing():
    print("Generating assets/art/tidal_blessing.jpg...")
    # Sacred tranquil healing water spring
    base_bless = Image.open("assets/art/tailwind_blessing.jpg").resize((W, H), Image.Resampling.LANCZOS)
    elixir = Image.open("assets/art/dragon_elixir.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Recolor blessing to serene aqua/sea-green & sapphire
    arr = np.array(base_bless, dtype=np.float32)
    arr[:, :, 0] *= 0.50
    arr[:, :, 1] *= 1.15
    arr[:, :, 2] *= 1.30
    bless_tinted = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    
    im = Image.blend(bless_tinted, elixir, 0.40).convert("RGBA")
    
    # Luminous floating healing water orb in center
    draw_glow_circle(im, 384, 384, 180, (40, 220, 200, 140), blur=45)
    draw_glow_circle(im, 384, 384, 100, (180, 255, 245, 200), blur=25)
    
    draw = ImageDraw.Draw(im)
    # Giant glowing celestial pearl/water droplet
    drop_pts = [
        (384, 250), (450, 370), (450, 440), (384, 490), (318, 440), (318, 370)
    ]
    draw.polygon(drop_pts, fill=(160, 245, 255, 180), outline=(255, 255, 255, 240), width=4)
    
    # Soft concentric ripples
    for r in [70, 130, 200, 270]:
        draw.ellipse([384 - r, 460 - int(r*0.35), 384 + r, 460 + int(r*0.35)], outline=(140, 230, 255, 150), width=3)
        
    # Floating luminous healing water petals / droplets
    for _ in range(120):
        px = random.randint(80, W - 80)
        py = random.randint(120, H - 100)
        rad = random.randint(3, 9)
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(210, 255, 245, random.randint(150, 240)))
        
    im.convert("RGB").save("assets/art/tidal_blessing.jpg", quality=95)
    print("Saved tidal_blessing.jpg")

# -------------------------------------------------------------
# 7. OCEAN AMULET (ocean_amulet.jpg)
# -------------------------------------------------------------
def gen_ocean_amulet():
    print("Generating assets/art/ocean_amulet.jpg...")
    # Draconic relic talisman set with glowing sapphire pearl of vitality
    shield = Image.open("assets/art/elemental_shield.jpg").resize((W, H), Image.Resampling.LANCZOS)
    
    # Deep marine velvet background
    bg = create_radial_gradient(W, H, 384, 384, 480, (0.05, 0.22, 0.38), (0.02, 0.05, 0.12))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    # Glow behind amulet
    draw_light_rays(im, 384, 384, count=16, length=500, color=(120, 230, 255, 50))
    draw_glow_circle(im, 384, 384, 180, (30, 180, 255, 140), blur=40)
    draw_glow_circle(im, 384, 384, 90, (180, 240, 255, 220), blur=20)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 384
    
    # Golden ceremonial dragon pendant frame
    # Outer dragon claw ring
    draw.ellipse([cx - 160, cy - 160, cx + 160, cy + 160], outline=(235, 190, 80, 255), width=10)
    draw.ellipse([cx - 145, cy - 145, cx + 145, cy + 145], outline=(140, 105, 35, 255), width=3)
    
    # 4 Dragon Talons grasping the central jewel
    for rot in [0, math.pi/2, math.pi, 3*math.pi/2]:
        p_base = (cx + math.cos(rot) * 155, cy + math.sin(rot) * 155)
        p_tip = (cx + math.cos(rot) * 85, cy + math.sin(rot) * 85)
        p_left = (cx + math.cos(rot + 0.2) * 140, cy + math.sin(rot + 0.2) * 140)
        p_right = (cx + math.cos(rot - 0.2) * 140, cy + math.sin(rot - 0.2) * 140)
        draw.polygon([p_base, p_left, p_tip, p_right], fill=(255, 210, 95, 255), outline=(100, 75, 25, 255))
        
    # Glowing Sapphire Pearl in center
    for r in range(85, 0, -5):
        t = r / 85.0
        cr = int(15 * t + 220 * (1-t))
        cg = int(90 * t + 245 * (1-t))
        cb = int(180 * t + 255 * (1-t))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cr, cg, cb, 255))
        
    # Water dragon wave crest etched inside pearl
    w_icon = Image.open("assets/icons/water.png").convert("RGBA").resize((70, 70), Image.Resampling.LANCZOS)
    im.paste(w_icon, (cx - 35, cy - 35), w_icon)
    
    # Golden suspension chain at top
    for y in range(40, 225, 22):
        draw.ellipse([cx - 14, y, cx + 14, y + 26], outline=(240, 205, 90, 255), width=4)
        
    im.convert("RGB").save("assets/art/ocean_amulet.jpg", quality=95)
    print("Saved ocean_amulet.jpg")

# -------------------------------------------------------------
# 8. DRAGON CLAWS (dragon_claws.jpg)
# -------------------------------------------------------------
def gen_dragon_claws():
    print("Generating assets/art/dragon_claws.jpg...")
    bg = create_radial_gradient(W, H, 384, 384, 460, (0.42, 0.18, 0.06), (0.08, 0.03, 0.04))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 384, count=16, length=500, color=(255, 190, 90, 55))
    draw_glow_circle(im, 384, 384, 170, (255, 120, 20, 130), blur=40)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 400
    
    # Heavy draconic armor gauntlet wrist
    draw.polygon([(cx - 120, cy + 180), (cx + 120, cy + 180), (cx + 90, cy + 40), (cx - 90, cy + 40)], fill=(35, 20, 22, 255), outline=(245, 180, 50, 255), width=5)
    # Gauntlet scales
    for gy in range(cy + 60, cy + 170, 25):
        draw.line([(cx - 85, gy), (cx + 85, gy)], fill=(220, 150, 40, 255), width=3)
        
    # 4 Serrated lethal dragon talons
    claws = [
        (cx - 95, cy + 30, -0.45, 170),
        (cx - 35, cy + 10, -0.15, 210),
        (cx + 35, cy + 10, 0.15, 210),
        (cx + 95, cy + 30, 0.45, 170)
    ]
    for bx, by, ang, length in claws:
        tip_x = bx + math.sin(ang) * length
        tip_y = by - math.cos(ang) * length
        # Curved claw polygon
        p1 = (bx - 18, by)
        p2 = (bx + 18, by)
        p_mid1 = (bx - 12 + math.sin(ang)*length*0.5, by - math.cos(ang)*length*0.5)
        p_mid2 = (bx + 12 + math.sin(ang)*length*0.5, by - math.cos(ang)*length*0.5)
        draw.polygon([p1, p_mid1, (tip_x, tip_y), p_mid2, p2], fill=(245, 235, 220, 255), outline=(60, 25, 15, 255), width=3)
        # Molten edge highlight
        draw.line([p_mid2, (tip_x, tip_y)], fill=(255, 140, 20, 255), width=3)
        draw_glow_circle(im, int(tip_x), int(tip_y), 35, (255, 200, 60, 200), blur=12)
        
    im.convert("RGB").save("assets/art/dragon_claws.jpg", quality=95)
    print("Saved dragon_claws.jpg")

# -------------------------------------------------------------
# 9. AEGIS PLATING (aegis_plating.jpg)
# -------------------------------------------------------------
def gen_aegis_plating():
    print("Generating assets/art/aegis_plating.jpg...")
    bg = create_radial_gradient(W, H, 384, 384, 460, (0.24, 0.28, 0.35), (0.05, 0.06, 0.09))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 384, count=16, length=500, color=(140, 230, 255, 45))
    draw_glow_circle(im, 384, 384, 160, (60, 180, 240, 130), blur=40)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 384
    
    # Heavy hexagonal reinforced mech shield plate
    hex_pts = [
        (cx, cy - 200), (cx + 170, cy - 100), (cx + 170, cy + 100),
        (cx, cy + 200), (cx - 170, cy + 100), (cx - 170, cy - 100)
    ]
    draw.polygon(hex_pts, fill=(35, 45, 58, 255), outline=(190, 225, 255, 255), width=6)
    
    # Inner steel & brass layering
    inner_pts = [
        (cx, cy - 160), (cx + 135, cy - 80), (cx + 135, cy + 80),
        (cx, cy + 160), (cx - 135, cy + 80), (cx - 135, cy - 80)
    ]
    draw.polygon(inner_pts, fill=(50, 65, 82, 255), outline=(225, 185, 75, 255), width=4)
    
    # Heavy rivets along edges
    for pt in hex_pts:
        draw.ellipse([pt[0]-8, pt[1]-8, pt[0]+8, pt[1]+8], fill=(240, 200, 90, 255), outline=(40, 30, 10, 255), width=2)
        
    # Central glowing mechanical core gear & runic shield
    draw.ellipse([cx - 75, cy - 75, cx + 75, cy + 75], fill=(20, 30, 45, 255), outline=(80, 220, 255, 255), width=4)
    draw_glow_circle(im, cx, cy, 60, (0, 240, 255, 180), blur=20)
    
    # Cross energy conduits
    draw.line([(cx - 130, cy), (cx + 130, cy)], fill=(120, 240, 255, 255), width=4)
    draw.line([(cx, cy - 150), (cx, cy + 150)], fill=(120, 240, 255, 255), width=4)
    
    im.convert("RGB").save("assets/art/aegis_plating.jpg", quality=95)
    print("Saved aegis_plating.jpg")

# -------------------------------------------------------------
# 10. WINGS OF THE GALE (wings_of_the_gale.jpg)
# -------------------------------------------------------------
def gen_wings_of_the_gale():
    print("Generating assets/art/wings_of_the_gale.jpg...")
    bg = create_radial_gradient(W, H, 384, 384, 480, (0.10, 0.38, 0.28), (0.02, 0.08, 0.06))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 360, count=20, length=550, color=(160, 255, 220, 55))
    draw_glow_circle(im, 384, 360, 180, (80, 240, 180, 140), blur=45)
    draw_glow_circle(im, 384, 360, 80, (220, 255, 240, 220), blur=20)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 390
    
    # Majestic spirit wings spread wide
    for side in [-1, 1]:
        # Primary wing feathers
        for i in range(8):
            ang = -0.4 + i * 0.16
            f_len = 160 + i * 18
            bx = cx + side * 40
            by = cy - 20
            tx = cx + side * (math.cos(ang) * f_len + 50)
            ty = cy - math.sin(ang) * f_len
            f_pts = [
                (bx, by),
                (bx + side * 30, by - 40),
                (tx, ty),
                (bx + side * 20, by + 10)
            ]
            col = (200, 255, 230, 230) if i % 2 == 0 else (120, 240, 180, 230)
            draw.polygon(f_pts, fill=col, outline=(40, 160, 100, 255), width=2)
            draw_glow_circle(im, int(tx), int(ty), 25, (160, 255, 210, 180), blur=10)
            
    # Central wind talisman / heart crest
    draw.polygon([(cx, cy - 50), (cx + 35, cy), (cx, cy + 45), (cx - 35, cy)], fill=(240, 255, 240, 255), outline=(60, 220, 140, 255), width=3)
    
    im.convert("RGB").save("assets/art/wings_of_the_gale.jpg", quality=95)
    print("Saved wings_of_the_gale.jpg")

# -------------------------------------------------------------
# 11. MOLTEN COUNTER (molten_counter.jpg)
# -------------------------------------------------------------
def gen_molten_counter():
    print("Generating assets/art/molten_counter.jpg...")
    bg = create_radial_gradient(W, H, 384, 450, 480, (0.55, 0.18, 0.04), (0.10, 0.02, 0.02))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 420, count=20, length=550, color=(255, 180, 50, 65))
    draw_glow_circle(im, 384, 440, 180, (255, 80, 10, 180), blur=40)
    draw_glow_circle(im, 384, 420, 90, (255, 230, 100, 240), blur=20)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 440
    
    # Erupting volcanic fissure
    draw.polygon([(cx - 240, H), (cx - 80, cy + 40), (cx + 80, cy + 40), (cx + 240, H)], fill=(25, 10, 8, 255), outline=(255, 120, 20, 255), width=4)
    
    # Molten lava spouts bursting upward
    for _ in range(60):
        sx = cx + random.randint(-70, 70)
        sy = cy + 40 + random.randint(-10, 30)
        ex = cx + random.randint(-240, 240)
        ey = 120 + random.randint(-60, 160)
        draw.line([(sx, sy), (ex, ey)], fill=(255, random.randint(140, 230), 40, random.randint(180, 255)), width=random.randint(3, 8))
        
    # Floating fiery sparks
    for _ in range(160):
        fx = random.randint(40, W - 40)
        fy = random.randint(60, H - 40)
        r = random.randint(2, 6)
        draw.ellipse([fx - r, fy - r, fx + r, fy + r], fill=(255, random.randint(180, 245), 80, 230))
        
    im.convert("RGB").save("assets/art/molten_counter.jpg", quality=95)
    print("Saved molten_counter.jpg")

# -------------------------------------------------------------
# 12. ZEPHYR BARRIER (zephyr_barrier.jpg)
# -------------------------------------------------------------
def gen_zephyr_barrier():
    print("Generating assets/art/zephyr_barrier.jpg...")
    bg = create_radial_gradient(W, H, 384, 384, 480, (0.08, 0.35, 0.28), (0.02, 0.06, 0.05))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 384, count=18, length=520, color=(140, 255, 210, 50))
    draw_glow_circle(im, 384, 384, 180, (60, 230, 170, 150), blur=40)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 384
    
    # Spiraling storm barrier rings deflecting incoming dark rays
    for i in range(18):
        r = 60 + i * 16
        ang = i * 22
        col = (180, 255, 220, 220) if i % 2 == 0 else (80, 220, 150, 200)
        draw.arc([cx - r, cy - r, cx + r, cy + r], ang, ang + 200, fill=col, width=4)
        
    # Deflected spell sparks bouncing away
    for _ in range(40):
        bx = cx + random.choice([-1, 1]) * random.randint(180, 280)
        by = cy + random.randint(-180, 180)
        draw.line([(bx, by), (bx + random.randint(-40, 40), by - random.randint(30, 70))], fill=(255, 240, 140, 240), width=3)
        
    im.convert("RGB").save("assets/art/zephyr_barrier.jpg", quality=95)
    print("Saved zephyr_barrier.jpg")

# -------------------------------------------------------------
# 13. STATIC AMBUSH (static_ambush.jpg)
# -------------------------------------------------------------
def gen_static_ambush():
    print("Generating assets/art/static_ambush.jpg...")
    bg = create_radial_gradient(W, H, 384, 384, 460, (0.28, 0.24, 0.48), (0.04, 0.03, 0.12))
    im = Image.fromarray((add_noise(bg) * 255).astype(np.uint8)).convert("RGBA")
    
    draw_light_rays(im, 384, 384, count=20, length=540, color=(240, 230, 120, 60))
    draw_glow_circle(im, 384, 384, 170, (180, 160, 255, 150), blur=40)
    draw_glow_circle(im, 384, 384, 90, (255, 255, 180, 240), blur=20)
    
    draw = ImageDraw.Draw(im)
    cx, cy = 384, 384
    
    # Hidden electric ambush mine
    draw.ellipse([cx - 60, cy - 60, cx + 60, cy + 60], fill=(25, 20, 50, 255), outline=(255, 240, 90, 255), width=4)
    
    # 18 Crackling violent lightning bolts detonating outward
    for _ in range(22):
        pts = [(cx + random.randint(-25, 25), cy + random.randint(-25, 25))]
        for step in range(6):
            last = pts[-1]
            nxt = (last[0] + random.randint(-55, 55), last[1] + random.randint(-55, 55))
            pts.append(nxt)
        draw.line(pts, fill=(255, 255, 220, 255), width=4)
        draw.line(pts, fill=(160, 210, 255, 255), width=2)
        
    im.convert("RGB").save("assets/art/static_ambush.jpg", quality=95)
    print("Saved static_ambush.jpg")

if __name__ == "__main__":
    gen_water_dragon()
    gen_tidal_serpent()
    gen_transcendent_water_dragon()
    gen_abyssal_trench()
    gen_torrential_blast()
    gen_tidal_blessing()
    gen_ocean_amulet()
    gen_dragon_claws()
    gen_aegis_plating()
    gen_wings_of_the_gale()
    gen_molten_counter()
    gen_zephyr_barrier()
    gen_static_ambush()
    print("All 13 authentic card artworks generated successfully!")
