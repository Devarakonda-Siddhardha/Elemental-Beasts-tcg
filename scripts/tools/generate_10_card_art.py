import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 600, 800

def create_radial_gradient(w, h, cx, cy, rad, c_inner, c_outer):
    y, x = np.ogrid[:h, :w]
    dist = np.sqrt((x - cx)**2 + (y - cy)**2)
    t = np.clip(dist / rad, 0.0, 1.0)
    # Smooth step
    t = t * t * (3.0 - 2.0 * t)
    
    img = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(3):
        img[:, :, i] = c_inner[i] * (1.0 - t) + c_outer[i] * t
    return img

def add_noise(img, strength=0.08):
    noise = np.random.uniform(-strength, strength, img.shape)
    return np.clip(img + noise, 0.0, 1.0)

def draw_polygon_aa(im, pts, fill_color, outline_color=None, width=1):
    draw = ImageDraw.Draw(im)
    draw.polygon(pts, fill=fill_color, outline=outline_color)
    if outline_color and width > 1:
        draw.line(pts + [pts[0]], fill=outline_color, width=width)

def draw_glow_circle(im, cx, cy, radius, color, blur=15):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    im.paste(overlay, (0, 0), overlay)

def draw_light_rays(im, cx, cy, count=16, length=450, color=(255, 230, 160, 45)):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for i in range(count):
        angle = (i / count) * math.tau + 0.1
        a_w = 0.08
        p1 = (cx + math.cos(angle - a_w) * length, cy + math.sin(angle - a_w) * length)
        p2 = (cx + math.cos(angle + a_w) * length, cy + math.sin(angle + a_w) * length)
        draw.polygon([(cx, cy), p1, p2], fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(8))
    im.paste(overlay, (0, 0), overlay)

# 1. Dragon's Hoard
def gen_dragon_hoard():
    base = create_radial_gradient(W, H, 300, 380, 500, (0.45, 0.32, 0.08), (0.05, 0.03, 0.08))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 300, 18, 500, (255, 215, 100, 50))
    draw_glow_circle(im, 300, 320, 140, (255, 200, 50, 140), 40)
    
    # Dragon silhouette in upper shadows
    draw.polygon([(180, 200), (300, 120), (420, 200), (370, 220), (300, 190), (230, 220)], fill=(20, 12, 28))
    draw.ellipse([270, 150, 285, 160], fill=(255, 120, 20)) # glowing eye
    draw.ellipse([315, 150, 330, 160], fill=(255, 120, 20))
    
    # Mountain of golden coins & gems
    import random
    cols = [
        (255, 215, 0), (240, 190, 40), (220, 170, 20), (255, 240, 150),
        (220, 30, 60), (30, 180, 240), (40, 220, 90), (180, 50, 230)
    ]
    for i in range(250):
        gx = np.random.randint(40, 560)
        gy = np.random.randint(420, 780)
        rad = np.random.randint(6, 18)
        col = random.choice(cols)
        draw.ellipse([gx - rad, gy - rad, gx + rad, gy + rad], fill=col, outline=(100, 70, 10))
    
    # Chest / chalice in center
    draw.rectangle([230, 460, 370, 560], fill=(70, 40, 15), outline=(230, 180, 50), width=4)
    draw.ellipse([230, 430, 370, 490], fill=(90, 50, 20), outline=(255, 215, 80), width=4)
    draw_glow_circle(im, 300, 470, 60, (255, 235, 120, 180), 20)
    im.save("assets/art/dragon_hoard.jpg", quality=95)
    print("Generated dragon_hoard.jpg")

# 2. Elemental Alchemy
def gen_elemental_alchemy():
    base = create_radial_gradient(W, H, 300, 400, 450, (0.12, 0.25, 0.35), (0.04, 0.05, 0.12))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 380, 12, 400, (150, 220, 255, 40))
    
    # Arcane transmutation circle
    cx, cy = 300, 380
    draw.ellipse([cx - 180, cy - 180, cx + 180, cy + 180], outline=(230, 200, 90), width=3)
    draw.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], outline=(180, 160, 70), width=2)
    # Hexagram
    for rot in [0, math.pi]:
        pts = [
            (cx + math.cos(rot + k * math.tau / 3) * 150, cy + math.sin(rot + k * math.tau / 3) * 150)
            for k in range(3)
        ]
        draw.polygon(pts, outline=(255, 225, 120), width=2)
    
    # 6 Elemental Orbs around the ring
    elements = [
        ("fire", (255, 70, 20)), ("lightning", (255, 220, 30)), ("wind", (60, 235, 140)),
        ("ice", (70, 200, 255)), ("shadow", (180, 70, 255)), ("mechanical", (220, 190, 160))
    ]
    for idx, (el, col) in enumerate(elements):
        angle = (idx / 6.0) * math.tau - math.pi / 2
        ox = cx + math.cos(angle) * 150
        oy = cy + math.sin(angle) * 150
        draw_glow_circle(im, ox, oy, 45, col + (180,), 20)
        draw.ellipse([ox - 22, oy - 22, ox + 22, oy + 22], fill=col, outline=(255, 255, 255), width=2)
    
    draw_glow_circle(im, cx, cy, 50, (255, 255, 255, 200), 25)
    im.save("assets/art/elemental_alchemy.jpg", quality=95)
    print("Generated elemental_alchemy.jpg")

# 3. Draconic Resurgence
def gen_draconic_resurgence():
    base = create_radial_gradient(W, H, 300, 480, 480, (0.35, 0.15, 0.38), (0.05, 0.02, 0.10))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 450, 16, 500, (255, 190, 230, 45))
    
    # Golden phoenix-dragon spirit rising
    draw_glow_circle(im, 300, 360, 160, (255, 215, 120, 160), 40)
    # Spectral wings
    wing_l = [(300, 380), (140, 260), (110, 160), (190, 200), (220, 170), (260, 230)]
    wing_r = [(300, 380), (460, 260), (490, 160), (410, 200), (380, 170), (340, 230)]
    draw.polygon(wing_l, fill=(255, 240, 180), outline=(255, 180, 60))
    draw.polygon(wing_r, fill=(255, 240, 180), outline=(255, 180, 60))
    # Dragon head / neck
    draw.polygon([(280, 380), (320, 380), (310, 240), (330, 180), (300, 160), (270, 180), (290, 240)], fill=(255, 255, 230))
    # Eye
    draw.ellipse([295, 170, 305, 180], fill=(255, 90, 30))
    
    # Floating soul orbs
    for _ in range(40):
        sx = np.random.randint(80, 520)
        sy = np.random.randint(180, 720)
        draw_glow_circle(im, sx, sy, np.random.randint(10, 28), (255, 220, 150, 150), 10)
    
    im.save("assets/art/draconic_resurgence.jpg", quality=95)
    print("Generated draconic_resurgence.jpg")

# 4. Dragon Call to Arms
def gen_call_to_arms():
    base = create_radial_gradient(W, H, 300, 300, 500, (0.42, 0.28, 0.12), (0.08, 0.05, 0.14))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 260, 14, 520, (255, 220, 140, 55))
    
    # Majestic golden war horn
    pts = [(200, 480), (260, 460), (360, 360), (410, 260), (440, 230), (420, 200), (370, 240), (290, 340), (190, 450)]
    draw.polygon(pts, fill=(230, 180, 60), outline=(255, 235, 140), width=3)
    # Horn bell opening
    draw.ellipse([390, 190, 450, 250], fill=(120, 70, 15), outline=(255, 240, 160), width=4)
    draw_glow_circle(im, 420, 220, 70, (255, 220, 100, 190), 25)
    
    # Soundwave rings radiating outwards
    for r in [60, 110, 170, 240]:
        draw.arc([420 - r, 220 - r, 420 + r, 220 + r], -60, 80, fill=(255, 240, 180), width=3)
        
    # Dragons flying in sky formation
    dragons = [(160, 180), (220, 140), (310, 110), (110, 220)]
    for dx, dy in dragons:
        draw.polygon([(dx-25, dy+6), (dx, dy), (dx+25, dy+6), (dx+10, dy+12), (dx, dy+8), (dx-10, dy+12)], fill=(40, 25, 55))
    
    im.save("assets/art/call_to_arms.jpg", quality=95)
    print("Generated call_to_arms.jpg")

# 5. Elemental Transmutation
def gen_elemental_transmutation():
    base = create_radial_gradient(W, H, 300, 400, 420, (0.28, 0.15, 0.42), (0.04, 0.04, 0.10))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 380, 20, 450, (230, 180, 255, 50))
    
    # Floating prismatic crystal octahedron
    cx, cy = 300, 380
    top = (cx, cy - 140)
    bot = (cx, cy + 140)
    left = (cx - 100, cy)
    right = (cx + 100, cy)
    front = (cx, cy + 30)
    
    # Facets
    draw.polygon([top, left, front], fill=(120, 190, 255), outline=(255, 255, 255), width=2)
    draw.polygon([top, front, right], fill=(255, 140, 200), outline=(255, 255, 255), width=2)
    draw.polygon([bot, left, front], fill=(80, 220, 160), outline=(255, 255, 255), width=2)
    draw.polygon([bot, front, right], fill=(255, 200, 80), outline=(255, 255, 255), width=2)
    
    draw_glow_circle(im, cx, cy, 110, (255, 255, 255, 170), 30)
    
    # Prismatic light arcs
    colors = [(255, 70, 70), (255, 180, 50), (255, 240, 60), (70, 230, 120), (60, 180, 255), (190, 70, 255)]
    for i, c in enumerate(colors):
        rad = 160 + i * 16
        draw.arc([cx - rad, cy - rad, cx + rad, cy + rad], 30 + i * 45, 150 + i * 45, fill=c, width=3)
    
    im.save("assets/art/elemental_transmutation.jpg", quality=95)
    print("Generated elemental_transmutation.jpg")

# 6. Solar Flare
def gen_solar_flare():
    base = create_radial_gradient(W, H, 300, 380, 480, (0.55, 0.22, 0.04), (0.12, 0.02, 0.02))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 360, 24, 520, (255, 200, 60, 70))
    
    # Radiant solar core
    cx, cy = 300, 360
    draw_glow_circle(im, cx, cy, 160, (255, 120, 20, 220), 40)
    draw_glow_circle(im, cx, cy, 100, (255, 220, 80, 240), 20)
    draw.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], fill=(255, 255, 230))
    
    # Solar flares / prominence loops
    for i in range(8):
        ang = (i / 8.0) * math.tau + 0.3
        px1 = cx + math.cos(ang) * 90
        py1 = cy + math.sin(ang) * 90
        px2 = cx + math.cos(ang + 0.4) * 200
        py2 = cy + math.sin(ang + 0.4) * 200
        px3 = cx + math.cos(ang + 0.7) * 110
        py3 = cy + math.sin(ang + 0.7) * 110
        draw.line([px1, py1, px2, py2, px3, py3], fill=(255, 160, 40), width=6)
    
    # Molten fire particles
    for _ in range(80):
        fx = np.random.randint(60, 540)
        fy = np.random.randint(120, 700)
        draw.ellipse([fx-4, fy-4, fx+4, fy+4], fill=(255, 230, 100))
    
    im.save("assets/art/solar_flare.jpg", quality=95)
    print("Generated solar_flare.jpg")

# 7. Static Prison
def gen_static_prison():
    base = create_radial_gradient(W, H, 300, 400, 450, (0.15, 0.28, 0.48), (0.03, 0.05, 0.14))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 390, 16, 450, (140, 230, 255, 50))
    
    cx, cy = 300, 390
    draw_glow_circle(im, cx, cy, 140, (80, 200, 255, 170), 35)
    
    # Electric cage / concentric plasma rings
    draw.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], outline=(180, 240, 255), width=3)
    draw.ellipse([cx - 120, cy - 120, cx + 120, cy + 120], outline=(255, 230, 90), width=2)
    
    # Crackling lightning bolts
    for _ in range(14):
        p_start = (cx + np.random.randint(-140, 140), cy + np.random.randint(-140, 140))
        pts = [p_start]
        for step in range(5):
            last = pts[-1]
            nxt = (last[0] + np.random.randint(-40, 40), last[1] + np.random.randint(-40, 40))
            pts.append(nxt)
        draw.line(pts, fill=(240, 255, 255), width=3)
        draw.line(pts, fill=(80, 220, 255), width=1)
    
    # Central trapped sphere
    draw.ellipse([cx - 45, cy - 45, cx + 45, cy + 45], fill=(20, 40, 80), outline=(255, 255, 255), width=3)
    draw_glow_circle(im, cx, cy, 50, (255, 255, 180, 200), 15)
    im.save("assets/art/static_prison.jpg", quality=95)
    print("Generated static_prison.jpg")

# 8. Frost Armor
def gen_frost_armor():
    base = create_radial_gradient(W, H, 300, 380, 460, (0.12, 0.32, 0.52), (0.02, 0.06, 0.16))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 370, 18, 480, (190, 240, 255, 50))
    
    cx, cy = 300, 370
    draw_glow_circle(im, cx, cy, 150, (120, 220, 255, 180), 35)
    
    # Crystalline diamond ice shield
    shield_pts = [
        (cx, cy - 160), (cx + 120, cy - 100), (cx + 100, cy + 80), (cx, cy + 180),
        (cx - 100, cy + 80), (cx - 120, cy - 100)
    ]
    draw.polygon(shield_pts, fill=(160, 230, 255), outline=(255, 255, 255), width=4)
    
    # Inner crystalline facets
    inner_pts = [
        (cx, cy - 110), (cx + 70, cy - 70), (cx + 60, cy + 50), (cx, cy + 120),
        (cx - 60, cy + 50), (cx - 70, cy - 70)
    ]
    draw.polygon(inner_pts, fill=(210, 245, 255), outline=(255, 255, 255), width=2)
    
    # Ice spikes radiating outward
    for side in [-1, 1]:
        for k in range(4):
            sy = cy - 80 + k * 50
            spk = [(cx + side * 110, sy), (cx + side * 170, sy - 15), (cx + side * 110, sy + 25)]
            draw.polygon(spk, fill=(225, 250, 255), outline=(130, 210, 255), width=2)
    
    # Snowflake crest in center
    draw.line([(cx, cy - 50), (cx, cy + 50)], fill=(255, 255, 255), width=4)
    draw.line([(cx - 50, cy), (cx + 50, cy)], fill=(255, 255, 255), width=4)
    draw.line([(cx - 35, cy - 35), (cx + 35, cy + 35)], fill=(255, 255, 255), width=3)
    draw.line([(cx - 35, cy + 35), (cx + 35, cy - 35)], fill=(255, 255, 255), width=3)
    
    im.save("assets/art/frost_armor.jpg", quality=95)
    print("Generated frost_armor.jpg")

# 9. Gale Barrier
def gen_gale_barrier():
    base = create_radial_gradient(W, H, 300, 390, 460, (0.12, 0.38, 0.32), (0.02, 0.08, 0.06))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 380, 16, 480, (160, 255, 210, 50))
    
    cx, cy = 300, 380
    draw_glow_circle(im, cx, cy, 160, (100, 240, 180, 170), 40)
    
    # Spiraling hurricane wind arcs
    for i in range(12):
        r = 50 + i * 16
        start_a = i * 30
        end_a = start_a + 220
        col = (180, 255, 220) if i % 2 == 0 else (120, 230, 160)
        draw.arc([cx - r, cy - r, cx + r, cy + r], start_a, end_a, fill=col, width=3)
        
    # Floating jade feathers & spirit wind leaves
    for _ in range(25):
        lx = cx + np.random.randint(-160, 160)
        ly = cy + np.random.randint(-160, 160)
        draw.polygon([(lx, ly), (lx+12, ly-8), (lx+28, ly), (lx+12, ly+8)], fill=(210, 255, 230), outline=(80, 210, 140))
        
    draw_glow_circle(im, cx, cy, 60, (255, 255, 255, 210), 20)
    im.save("assets/art/gale_barrier.jpg", quality=95)
    print("Generated gale_barrier.jpg")

# 10. Shadow Pact
def gen_shadow_pact():
    base = create_radial_gradient(W, H, 300, 380, 460, (0.28, 0.08, 0.38), (0.03, 0.01, 0.06))
    im = Image.fromarray((add_noise(base) * 255).astype(np.uint8))
    draw = ImageDraw.Draw(im)
    draw_light_rays(im, 300, 360, 16, 500, (180, 80, 255, 45))
    
    cx, cy = 300, 360
    draw_glow_circle(im, cx, cy, 150, (160, 40, 240, 180), 35)
    
    # Eclipsed black sun / void portal
    draw.ellipse([cx - 80, cy - 80, cx + 80, cy + 80], fill=(8, 4, 15), outline=(220, 140, 255), width=4)
    # Eclipsed corona ring
    draw_glow_circle(im, cx, cy, 95, (230, 100, 255, 210), 20)
    
    # Ancient demonic/draconic skull horns
    horn_l = [(cx - 30, cy - 40), (cx - 70, cy - 120), (cx - 120, cy - 140), (cx - 80, cy - 90), (cx - 40, cy - 20)]
    horn_r = [(cx + 30, cy - 40), (cx + 70, cy - 120), (cx + 120, cy - 140), (cx + 80, cy - 90), (cx + 40, cy - 20)]
    draw.polygon(horn_l, fill=(20, 10, 30), outline=(200, 120, 255), width=2)
    draw.polygon(horn_r, fill=(20, 10, 30), outline=(200, 120, 255), width=2)
    
    # Runic altar pedestal below
    draw.polygon([(160, 560), (440, 560), (490, 680), (110, 680)], fill=(30, 16, 45), outline=(180, 90, 240), width=3)
    draw.line([(200, 620), (400, 620)], fill=(220, 140, 255), width=2)
    
    # Floating purple soul motes
    for _ in range(50):
        px = np.random.randint(80, 520)
        py = np.random.randint(140, 720)
        draw_glow_circle(im, px, py, np.random.randint(6, 18), (210, 100, 255, 170), 8)
        
    im.save("assets/art/shadow_pact.jpg", quality=95)
    print("Generated shadow_pact.jpg")

if __name__ == "__main__":
    gen_dragon_hoard()
    gen_elemental_alchemy()
    gen_draconic_resurgence()
    gen_call_to_arms()
    gen_elemental_transmutation()
    gen_solar_flare()
    gen_static_prison()
    gen_frost_armor()
    gen_gale_barrier()
    gen_shadow_pact()
    print("All 10 card artworks generated successfully!")
