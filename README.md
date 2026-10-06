# Frametop Hand Recorder

Record your hands with a Steam Frame for Frametop's open hand dataset ([DeeJanuz/frametop-hands](https://huggingface.co/datasets/DeeJanuz/frametop-hands) on Hugging Face), without installing [Frametop](https://github.com/DeeJanuz/frametop). The recordings help train a hand tracking model for the Frame's cameras.

The recorder runs in SteamVR's dashboard. A panel in the headset guides you through hand poses, gestures, typing, objects and a few moves, while the headset's tracking cameras record. Afterwards you watch what was recorded, delete anything you don't want to share, export it, and upload it as a pull request from your own Hugging Face account. Nothing leaves the headset until you press Upload.

While you record, the dashboard stays closed. Use the button on the right side of the headset: press it to start each step or to pause, press it twice to record a step again, and hold it to stop.

**Status:** not released yet. The first release is being tested on the headset.

## Install

You need a Steam Frame with SteamOS and SteamVR, about 1.2 GB free for the install, and about 10 GB for each round of recording.

1. In the headset, open the dashboard, then **Launch a program** → **Konsole**.
2. Run:
   ```
   curl -fsSL https://github.com/DeeJanuz/frametop-hand-recorder/releases/latest/download/get-hand-recorder.sh | bash
   ```
3. It asks for your password once. If you've never set one, run `passwd` first, then the command again.
4. Open the dashboard, then **Launch a program** → **Frametop Hand Recorder**.

Run the same command again to update.

### What the installer changes

- It installs into `~/.local/share/frametop-hand-recorder`: the release in `versions/`, with `current` pointing at the one in use, and a Python environment in `venv/` with PySide6 and huggingface_hub from PyPI, pinned with hashes in `requirements.txt`.
- It gives the camera broker `ft-camd` three file capabilities with `sudo setcap`: `cap_sys_ptrace`, `cap_perfmon` and `cap_dac_read_search`. ft-camd copies the camera images from SteamVR's camera service, read-only, and drops the capabilities once it has set up. This is the only step that needs your password.
- It adds the menu entry `~/.local/share/applications/frametop-hand-recorder.desktop`.
- Recordings go to `~/.local/share/frametop/hands/contrib`, the same folder Frametop's own recorder uses. Your Hugging Face login, once you make one, goes to `~/.cache/huggingface/token`.

### Uninstall

```
curl -fsSL https://github.com/DeeJanuz/frametop-hand-recorder/releases/latest/download/get-hand-recorder.sh | bash -s -- --uninstall
```

This removes the install, its Python environment and the menu entry. Your recordings and your Hugging Face login stay. The command says where they are, so you can delete them too.

## How it fits together

The recorder is Frametop's: the session runner, the review and export code, the camera broker `ft-camd`, the tracker `ft-hands` and the headset panel `ft-handpanel` all live in [Frametop's `hands/`](https://github.com/DeeJanuz/frametop/tree/main/hands) (see `hands/rec/DESIGN.md` there). This repo pins Frametop as the `frametop/` submodule and adds what the standalone recorder needs:

| Here | What it is |
|---|---|
| `app/main.qml` | The window, in Qt Quick Controls, sized for the dashboard and a laser pointer (Frametop's own window uses Kirigami, which can't load into PySide6's Qt) |
| `bin/frametop-hand-recorder` | The launcher: Frametop's backend `ft_handrec.py` with this window, from the venv |
| `scripts/build.sh` | Builds the binaries for the SteamOS host on Ubuntu 24.04 (glibc 2.39): ft-camd and ft-hands statically, ft-handpanel against SteamVR's `libopenvr_api` |
| `scripts/check-binaries.sh` | Checks they'll run on SteamOS: static, or only libraries and symbol versions SteamOS has |
| `scripts/package.sh` | The release tarball, in Frametop's layout plus `standalone.json`, `get-hand-recorder.sh` and `SHA256SUMS` |
| `get-hand-recorder.sh` | The installer |
| `spike/` | A test window for what works in the dashboard (below) |

`standalone.json` at the top of the release tells Frametop's code that it runs standalone: `session.py` then starts ft-hands directly rather than in Frametop's dev container, records the release's version in each session, and its repair hints point at the install command.

A change to how the recorder records, reviews or uploads goes into Frametop first. Then this repo moves its submodule to that commit:

```
git -C frametop fetch origin && git -C frametop checkout <commit>
git add frametop && git commit
```

## Development

On a Frame, in a checkout with its submodule (`git clone --recursive`):

```
python3 -m venv .venv
.venv/bin/pip install --require-hashes -r requirements.txt
frame-job --local -- scripts/build-in-container.sh             # the binaries, on Ubuntu 24.04 (podman)
frame-job --local -- scripts/build-in-container.sh --package   # and the release in dist/
```

Leave out `frame-job --local --` on a machine without frame-job.

- **The window in a dry run:** `bin/frametop-hand-recorder --dry-run --hub-dry-run --base /tmp/hr`. Sessions start no processes, and Upload makes no network calls.
- **Tests:** `QT_QPA_PLATFORM=offscreen .venv/bin/python -m unittest discover -s tests`, and `FT_HANDREC_QML=$PWD/app/main.qml .venv/bin/python frametop/hands/rec/tests/test_qml_backend.py`. The second checks every backend property and slot the window uses.
- **Installing a local build:** `./get-hand-recorder.sh --from dist/frametop-hand-recorder-*-aarch64.tar.gz`.
- **The dashboard spike:** `spike/install.sh` adds "Hand Recorder spike" and "Hand Recorder (dev, dry run)" to Launch a program, and `spike/install.sh --remove` takes them away. The spike logs what it sees to `~/.local/state/frametop-hand-recorder/spike.log`: clicks, scrolling, keyboard text, the browser, the clipboard, the headset panel with the dashboard closed, the headset button, and the sleep block.
- **Python pins:** edit `requirements.in`, then run `scripts/lock-requirements.sh` on the Frame.

### Releasing

There's no CI yet, so releases are built on a Frame.

1. Move the submodule to the Frametop commit to ship, and push.
2. Tag `vX.Y.Z` and push the tag.
3. At the tag, with nothing uncommitted: `frame-job --local -- scripts/build-in-container.sh --package` (the version comes from the tag), then run the tests above.
4. `gh release create vX.Y.Z dist/* --draft --verify-tag --title "Frametop Hand Recorder X.Y.Z"`.
5. Install the draft's tarball on a Frame with `--from`, and record a quick round.
6. Publish the release. `releases/latest/download/get-hand-recorder.sh` then points at it.

## License

MIT, like Frametop. See [LICENSE](LICENSE). A release also contains third-party code: see [THIRD-PARTY.md](THIRD-PARTY.md). The recordings you contribute are covered by the consent text the recorder shows before your first session.
