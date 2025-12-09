"""
daaymn_post_prep.py

Usage:
1) Install Pillow:
   pip install Pillow

2) Prepare folders next to this script:
   ./input_images/      <-- put your screenshots here (PNG/JPG)
   ./assets/logo.png    <-- optional: your app logo (transparent PNG recommended)
   ./output_images/     <-- script will create if missing
   ./output.csv         <-- produced by script (filename, caption, hashtags)

3) Run:
   python daaymn_post_prep.py

What it does:
- Loads each image in input_images
- Generates overlay text (shortened from selected caption)
- Places the overlay text and your logo on the image, matching brand colors
- Saves ready-to-post JPEG in output_images
- Writes output.csv with filename, caption, hashtags (randomly selected)
"""

import os
import csv
import random
from PIL import Image, ImageDraw, ImageFont

# ---------- CONFIG ----------
APP_NAME = "Daaymn"
BRAND_COLORS = {
    "pink": "#FFF0F1",
    "purple": "#C034F7",
    "purple2": "#BF35F7",
    "lavender": "#D9D3FA",
    "cyan": "#3EA5E6",
    "black": "#000000",
}
TAGLINES = [
    "Find your spark. ✨", "Meet. Match. Daaymn. 💘", "Swipe less. Connect more.",
    "Real people. Real conversations.", "Your vibe, your match."
]
HASHTAGS_POOL = ["#Daaymn", "#DatingApp", "#FindLove", "#MeetLocal", "#Romance",
                 "#DatingTips", "#DatingAdvice", "#SwipeRight", "#NewApp", "#DatingLife"]
# Captions (30) - will be rotated randomly when assigning to images
CAPTIONS = [
"Find your spark today — download Daaymn. 💘",
"Honest profiles. Real conversations. Try Daaymn.",
"Swipe less. Match better. #Daaymn",
"Meet someone who gets your jokes (and your timing).",
"Your next great date is one tap away.",
"Try the app that makes meeting people simple.",
"Real people. Real connections. #FindLove",
"Your vibe, your match — only on Daaymn.",
"Make your first move — we’ll handle the rest.",
"Stop searching. Start connecting.",
"New in your area? Say hello to Daaymn.",
"Dates that feel like more than just a swipe.",
"Your next story starts with a match.",
"Profiles that actually tell a story. #DatingLife",
"Curated matches, better conversations.",
"Meet people doing what you like.",
"Don’t just match — meet someone memorable.",
"Simple. Smooth. Daaymn.",
"Love doesn’t wait — why should you?",
"Be bold. Make the first move today.",
"Find people who share your weekend plans.",
"Quality matches for quality conversations.",
"Make dating easier — download Daaymn now.",
"Your new favorite icebreaker is waiting.",
"Stop swiping endlessly — start meaningful chats.",
"Get out of the app and into a date.",
"One tap, one match, one story.",
"Find local connections with real depth.",
"Meet someone who laughs at your memes.",
"Match smarter — date happier."
]

INPUT_DIR = "input_images"
OUTPUT_DIR = "output_images"
ASSETS_DIR = "assets"
OUTPUT_CSV = "output.csv"
# path to a ttf font file; default to DejaVuSans if available
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# on Windows, user may point to "C:/Windows/Fonts/arial.ttf"
# ---------- END CONFIG ----------

def ensure_dirs():
    os.makedirs(INPUT_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(ASSETS_DIR, exist_ok=True)

def load_font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        # fallback to default PIL font
        return ImageFont.load_default()

def short_overlay_text(caption, max_chars=40):
    # Simple: take first sentence or truncate
    if "." in caption:
        return caption.split(".")[0][:max_chars].strip()
    return caption[:max_chars].strip()

def choose_hashtags(n=4):
    return " ".join(random.sample(HASHTAGS_POOL, min(n, len(HASHTAGS_POOL))))

def process_image(path, out_path, logo_path=None):
    im = Image.open(path).convert("RGBA")
    w, h = im.size

    # Prepare canvas
    canvas = Image.new("RGBA", (w, h))
    canvas.paste(im, (0,0))

    draw = ImageDraw.Draw(canvas)

    # pick caption
    caption = random.choice(CAPTIONS)
    overlay = short_overlay_text(caption, max_chars=36)

    # overlay rectangle (semi-transparent) at bottom area
    rect_h = int(h * 0.22)
    rect_y = h - rect_h - int(h*0.03)
    rect_x = int(w*0.06)
    rect_w = int(w*0.88)
    # color using brand purple with alpha
    rect_color = tuple(int(BRAND_COLORS["purple"].lstrip("#")[i:i+2], 16) for i in (0,2,4)) + (220,)
    radius = int(rect_h*0.18)

    # draw rounded rectangle
    def round_rect(drawobj, xy, radius, fill):
        x0,y0,x1,y1 = xy
        drawobj.rounded_rectangle(xy, radius=radius, fill=fill)

    round_rect(draw, (rect_x, rect_y, rect_x+rect_w, rect_y+rect_h), radius, rect_color)

    # overlay text (centered in the rect)
    font_size = max(22, int(h * 0.035))
    font = load_font(font_size)
    text_w, text_h = draw.textsize(overlay, font=font)
    text_x = rect_x + (rect_w - text_w)//2
    text_y = rect_y + (rect_h - text_h)//2 - 2
    # text color white or brand pink depending on contrast
    text_color = tuple(int(BRAND_COLORS["pink"].lstrip("#")[i:i+2], 16) for i in (0,2,4))
    draw.text((text_x, text_y), overlay, font=font, fill=text_color)

    # place small app name at top-left
    small_font = load_font(max(14, int(h*0.02)))
    logo_text = APP_NAME
    draw.text((int(w*0.06), int(h*0.05)), logo_text, font=small_font, fill=(255,255,255,255))

    # optionally place logo on top-right if provided
    if logo_path and os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path).convert("RGBA")
            # scale logo
            max_logo_w = int(w * 0.18)
            logo_w = min(logo.size[0], max_logo_w)
            logo_h = int(logo_w * (logo.size[1]/logo.size[0]))
            logo = logo.resize((logo_w, logo_h), Image.ANTIALIAS)
            logo_x = int(w*0.86) - logo_w
            logo_y = int(h*0.04)
            canvas.paste(logo, (logo_x, logo_y), logo)
        except Exception as e:
            print("Logo paste error:", e)

    # save as JPG
    rgb = canvas.convert("RGB")
    rgb.save(out_path, quality=90)

    hashtags = choose_hashtags()
    return os.path.basename(out_path), caption, hashtags

def main():
    ensure_dirs()
    logo_path = os.path.join(ASSETS_DIR, "logo.png")
    input_files = [f for f in os.listdir(INPUT_DIR) if f.lower().endswith((".png",".jpg",".jpeg"))]
    if not input_files:
        print("No input images found. Place screenshots in the 'input_images' folder and re-run.")
        return

    rows = []
    for i, fname in enumerate(sorted(input_files)):
        in_path = os.path.join(INPUT_DIR, fname)
        out_name = f"daaymn_post_{i+1:02d}.jpg"
        out_path = os.path.join(OUTPUT_DIR, out_name)
        print("Processing:", fname, "->", out_name)
        row = process_image(in_path, out_path, logo_path if os.path.exists(logo_path) else None)
        rows.append(row)

    # write CSV
    with open(OUTPUT_CSV, "w", newline='', encoding='utf-8') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["filename", "caption", "hashtags"])
        for r in rows:
            writer.writerow(r)

    print(f"Done. {len(rows)} images generated in '{OUTPUT_DIR}' and details in '{OUTPUT_CSV}'")

if __name__ == "__main__":
    main()
