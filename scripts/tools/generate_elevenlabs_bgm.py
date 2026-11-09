#!/usr/bin/env python3
"""
generate_elevenlabs_bgm.py
Generates an authentic cinematic dark-fantasy BGM track using ElevenLabs AI Sound Generation API.

API Endpoint:
    POST https://api.elevenlabs.io/v1/sound-generation

Usage:
    export ELEVENLABS_API_KEY="your_api_key_here"
    python3 scripts/tools/generate_elevenlabs_bgm.py

Or:
    python3 scripts/tools/generate_elevenlabs_bgm.py --api-key "your_api_key_here" --prompt "Epic dark fantasy orchestral battle theme, strings, brass horns, timpani"
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.error
import subprocess

DEFAULT_PROMPT = (
    "Epic dark fantasy orchestral battle card game theme, cinematic strings, "
    "deep brass horns, war timpani, mysterious and heroic dragon anthem"
)

DEFAULT_OUTPUT_PATH = "assets/audio/bgm/main_menu_theme.mp3"

def main():
    parser = argparse.ArgumentParser(description="Generate Elemental Beasts TCG BGM using ElevenLabs API")
    parser.add_argument("--api-key", help="ElevenLabs API key (or set ELEVENLABS_API_KEY / XI_API_KEY env var)")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Prompt text describing the desired music/audio")
    parser.add_argument("--duration", type=float, default=22.0, help="Duration in seconds (max 30.0 for sound generation)")
    parser.add_argument("--output", default=DEFAULT_OUTPUT_PATH, help="Target MP3 file path")
    parser.add_argument("--influence", type=float, default=0.5, help="Prompt influence (0.0 to 1.0)")
    parser.add_argument("--loop", action="store_true", default=True, help="Create a seamless looping audio clip")
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get("ELEVENLABS_API_KEY") or os.environ.get("XI_API_KEY")

    if not api_key:
        print("[!] No ElevenLabs API key provided.")
        print("    Please set the ELEVENLABS_API_KEY environment variable or pass --api-key <YOUR_KEY>.")
        print("    You can generate an API key at https://elevenlabs.io/app/settings/api-keys")
        sys.exit(1)

    url = "https://api.elevenlabs.io/v1/sound-generation"
    headers = {
        "Content-Type": "application/json",
        "xi-api-key": api_key,
        "User-Agent": "ElementalBeastsTCG-AudioGenerator/1.0"
    }

    payload = {
        "text": args.prompt,
        "duration_seconds": min(args.duration, 30.0),
        "prompt_influence": args.influence,
        "loop": args.loop
    }

    print(f"[*] Requesting ElevenLabs Sound Generation...")
    print(f"    Prompt:   \"{args.prompt}\"")
    print(f"    Duration: {payload['duration_seconds']}s")
    print(f"    Loop:     {payload['loop']}")

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            audio_data = response.read()
            status_code = response.getcode()
            print(f"[+] HTTP {status_code}: Received {len(audio_data)} bytes from ElevenLabs API.")

            temp_output = "/tmp/elevenlabs_raw.mp3"
            with open(temp_output, "wb") as f:
                f.write(audio_data)

            # Master and normalize with ffmpeg
            os.makedirs(os.path.dirname(args.output), exist_ok=True)
            norm_cmd = [
                "ffmpeg", "-y", "-i", temp_output,
                "-af", "loudnorm=I=-14:LRA=11:TP=-1.5",
                "-ar", "44100", "-b:a", "192k",
                args.output
            ]
            print(f"[*] Normalizing and mastering to {args.output} (44.1kHz 192k MP3)...")
            subprocess.check_call(norm_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            final_size = os.path.getsize(args.output)
            print(f"[SUCCESS] ElevenLabs BGM saved to {args.output} ({final_size} bytes).")

    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"[-] ElevenLabs API Error {e.code}: {e.reason}")
        print(f"    Details: {err_body}")
        sys.exit(2)
    except Exception as e:
        print(f"[-] Unexpected error: {e}")
        sys.exit(3)

if __name__ == "__main__":
    main()
