# Third-party code in a release

The release tarball holds code from these projects besides Frametop's and this repo's (both MIT).

| What | Where in the release | License |
|---|---|---|
| [FrameEyeCameraFeed](https://github.com/Curtis-VL/FrameEyeCameraFeed): camera discovery, adapted | `hands/build/ft-camd` | MIT, `licenses/LICENSE.FrameEyeCameraFeed` |
| [ncnn](https://github.com/Tencent/ncnn) | `hands/build/ft-hands` (static) | BSD 3-Clause |
| [JsonCpp](https://github.com/open-source-parsers/jsoncpp) | `hands/build/ft-hands` (static) | MIT |
| MediaPipe's palm detector and hand landmark models, from the [OpenCV Zoo](https://github.com/opencv/opencv_zoo) ONNX ports, converted to ncnn | `hands/models/ncnn/` | Apache 2.0, `hands/models/NOTICE` |
| [OpenVR](https://github.com/ValveSoftware/openvr) header | `hands/rec/build/ft-handpanel` (it loads SteamVR's own `libopenvr_api.so`) | BSD 3-Clause |
| [stb_truetype, stb_image](https://github.com/nothings/stb) | `hands/rec/build/ft-handpanel` | MIT or public domain |
| [GNU C Library](https://www.gnu.org/software/libc/) 2.39 (Ubuntu 24.04) | `ft-camd` and `ft-hands` (static) | LGPL 2.1 or later |
| GCC's runtime libraries (libgomp, libstdc++, libgcc) | `ft-hands` (static) | GPL 3 with the GCC Runtime Library Exception |

The GNU C Library is linked statically into `ft-camd` and `ft-hands`, so they run on any SteamOS version. The LGPL lets you relink them against another version of it. All of their sources and the build are public: `scripts/build.sh` in this repo, with Frametop at the commit in `standalone.json`.

The installer gets the window's Python packages from PyPI into a venv, pinned with hashes in `requirements.txt`. The release doesn't include them. They include Qt for Python ([PySide6](https://pypi.org/project/PySide6-Essentials/), LGPL 3) and [huggingface_hub](https://github.com/huggingface/huggingface_hub) (Apache 2.0).
