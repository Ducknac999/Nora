# Nora — a fully offline AI assistant for your Mac

Nora is a private, offline AI you run right on your Mac. **Chat by text or by voice**, and it answers out loud — like a local Jarvis. No account, no cloud, no data leaving your machine. After a one-time setup, **it needs no internet at all.**

- 🧠 **Smart local model** — picks the right size for your Mac automatically (8GB or 16GB RAM)
- 🎙️ **Talk to it** — voice in, voice out
- 🖼️ **Optional vision** — add image understanding with one extra click
- 🔒 **100% offline & private** — everything runs on your Mac
- 🖱️ **No setup skills needed** — download, double-click, done

> **For:** Apple Silicon Macs (M1, M2, M3, M4) running macOS 11 or newer, with **8GB or 16GB** of RAM.

---

## 📹 Video walkthrough

<!-- Add your video here: drag an .mp4/.mov right into this box when editing the README on GitHub, or paste a YouTube link. -->
*(Video guide goes here.)*

---

## ⬇️ Install (one time, ~15–30 min depending on your internet)

1. **Download** [`Nora-Installer.zip` from the latest Release](https://github.com/Ducknac999/Nora/releases/latest), then double-click it to unzip. *(Use this rather than the green "Code" button — it keeps the apps working correctly.)*
2. **Right-click** `Install Nora` → click **Open**.
   > 🛈 The first time, macOS shows *"can't be opened because Apple cannot check it…"* — that's normal for free apps. Just **right-click → Open** and choose **Open** on the popup. You only do this once.
3. Let it run. It **auto-detects your RAM** and downloads the right AI model, the voice engine, and everything else. *(Internet needed for this step only.)*
4. When it says **"NORA IS INSTALLED"**:
   - Drag **`Nora`** into your Dock → click it to turn Nora **on**.
   - Drag **`Stop Nora`** into your Dock → click it to turn Nora **off**.

You can delete the installer afterward if you like — Nora is fully set up in a folder called **`Nora`** in your home folder.

---

## 🕹️ Everyday use

| Action | What to do |
|---|---|
| **Turn Nora ON** | Click **`Nora`** (a window opens; give it a few seconds to wake up) |
| **Turn Nora OFF** | Click **`Stop Nora`** — or just close the black window |
| **Text chat** | Type in the box and hit Enter |
| **Voice** | Click the mic, talk, and Nora replies out loud |

Everything is offline. You can turn off Wi-Fi and Nora still works.

---

## 🖼️ Optional: add Vision (image understanding)

Vision is a separate add-on so the base app stays small and light. **Install the base Nora first.**

1. Download **`Vision-Update.zip`** from the [latest Release](https://github.com/Ducknac999/Nora/releases/latest) → unzip.
2. **Right-click** `Install Vision Update` → **Open**.
3. It downloads the right vision model for your RAM.
4. Next time you open **`Nora`**, there's a **Vision** tab at the top — attach an image and ask about it.

Don't want it? Just don't install it. To remove it later, delete the `~/Nora/vision` folder.

---

## ❓ Troubleshooting

- **"Apple cannot check it for malware"** → right-click the file → **Open** → **Open**. (One time only.)
- **The installer needs "developer tools"** → a macOS window pops up; click **Install**, wait, then run the installer again. (This provides `python3`, which Nora uses.)
- **Download stopped partway** → just run the installer again; it resumes where it left off.
- **Nothing happens when I click Nora** → wait ~10–20 seconds the first time; the model is loading.

---

## 🔧 What's under the hood

- Local LLM served by **llama.cpp** (Metal-accelerated), voice by **whisper.cpp**, all wired together by a tiny local bridge that also serves the web UI at `127.0.0.1`.
- Models are hosted on Hugging Face and pulled during install; the engines ship in this repo's Releases.
- Nothing connects out after install. The whole thing lives in `~/Nora`.

---

*Made for friends. Free to use. Runs entirely on your machine.*
