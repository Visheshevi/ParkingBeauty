# Model card — Parking Beauty detectors

> **Status:** B1.1 survey (2026-11-01). No model is chosen yet; the final choice, thresholds and sizes go in ADR-0003 (B1.4).
> Every model the project ships must have its **weights licence** and **training-data licence** recorded here (CLAUDE.md hard rules).

## What we need

| Detector | Runs on | Purpose |
|---|---|---|
| Licence plate | Phone (TFLite) + server (ONNX) | Blur plates before upload; server re-check |
| Face | Phone: Google ML Kit (already decided). Server: ONNX/TFLite | Blur faces; server re-check |
| Vehicle | Phone + server | "No car in photo" warning |

**Hard rules for every candidate:**
1. Weights under MIT, Apache-2.0, BSD or similar. GPL/AGPL (incl. all Ultralytics YOLO), CC-BY-NC or "research only" = fail.
2. Training data usable commercially (or at least not explicitly non-commercial). Undocumented = risk.
3. Exports to both ONNX and TFLite with matching results (parity: IoU ≥ 0.9, confidence ±0.05).
4. Phone-sized: ideally < 20–30 MB.

Verdicts: **PASS** = meets all rules · **RISK** = usable only with a documented caveat · **FAIL** = ruled out.

---

## 1. Licence-plate detectors

**Result: no off-the-shelf model passes.** The popular options are either GPL/AGPL-derived or trained on undocumented data; the one clean licence chain is too large for phones and unproven.

| Candidate | Architecture | Weights licence | Training data | ONNX / TFLite | Size | Verdict |
|---|---|---|---|---|---|---|
| `open-image-models` / `fast-alpr` plate models | YOLOv9-t/s (NMS in graph) | **None stated.** Repo code MIT, but the maintainer says the models were trained with a fork of WongKinYiu/yolov9, which is **GPL-3.0** ([issue #22](https://github.com/ankandrew/open-image-models/issues/22)); statements contradict each other ([#14](https://github.com/ankandrew/open-image-models/issues/14)) | **Undocumented** (~11k images "scraped from the web") | ONNX published; TFLite medium (in-graph NMS is fragile) | 7.8 MB (t) | **FAIL** |
| [Topurrra/rtdetr-license-plate-detection-onnx](https://huggingface.co/Topurrra/rtdetr-license-plate-detection-onnx) | RT-DETRv2-R18 | Apache-2.0 | Open Images V7 "Vehicle registration plate" (~3k images; images CC BY 2.0, annotations CC BY 4.0) | ONNX published; TFLite hard (`GridSample`) | 81 MB FP32 | **RISK**: cleanest chain found, but one-person upload, weak eval (mean IoU 0.74), too big for phones. Useful as a server baseline / labelling aid |
| Ultralytics YOLOv5/v8/11 plate models on HF (e.g. `keremberke/*`) | YOLO | Tagged MIT/Apache on HF, but derived from **AGPL-3.0** Ultralytics | Mostly unlicensed Roboflow sets | Easy | 6–50 MB | **FAIL** |
| `KienNguyen2k1/DEIMv2_nano_license_plate` | DEIMv2-nano | Tagged MIT, but base DEIMv2 is now **non-commercial** ([LICENSE](https://github.com/Intellindust-AI-Lab/DEIMv2/blob/main/LICENSE.md)) | Roboflow, CC BY 4.0 | ONNX | 16 MB | **FAIL** |
| `Rickkosse/rfdetr_licences_plate_detector` | RF-DETR-L | Apache-2.0 | Card says **CC-BY-NC** / synthetic | ONNX | 128 MB | **FAIL** |
| `justjuu`, `merve`, `nickmuchi` HF plate models | RT-DETRv2 / YOLOS | Apache-2.0 | Unclear provenance, undocumented, or tiny (433 CC0 images) | Mostly no ONNX; transformers convert poorly | 80–171 MB | **RISK** (too big, data unclear) |
| OpenVINO `vehicle-license-plate-detection-barrier-0106` / `-0123` | MobileNetV2-SSD | Apache-2.0 | **Undocumented**; Chinese, front-facing, close-up plates | IR only (0106); 0123 has a community int8 TFLite | 1.5–4.4 MB | **RISK**: wrong domain for parked-car photos |
| PaddleDetection PP-Vehicle plate model | DB text segmentation (not a box detector) | Apache-2.0 | CCPD (MIT) | via paddle2onnx | few MB | **RISK**: Chinese plates, heatmap output |

### Recommended route: train our own plate detector

- **Architecture:** **YOLOX-Nano or YOLOX-Tiny** ([Megvii, Apache-2.0](https://github.com/Megvii-BaseDetection/YOLOX/blob/main/LICENSE)). Plain convolutions, NMS kept outside the graph, official ONNX export, well-trodden onnx2tf → TFLite path. 1–5 M params, < 20 MB.
- **Data (all commercially usable):**
  - **Open Images V7 "Vehicle registration plate"** class: annotations CC BY 4.0 (Google), images listed as CC BY 2.0. Mixed countries and natural angles. Attribution required.
  - **CCPD** ([MIT](https://github.com/detectRecog/CCPD)): ~250k Chinese parking-lot images.
  - **Kaggle andrewmvd/car-plate-detection** (CC0, 433 images).
  - Our own photos (fixtures, later app data, labelled internally).
- **Exclude:** UFPR-ALPR, RodoSol-ALPR (academic-only agreements), any CC-BY-NC Roboflow / platesmania data.
- **Baseline to beat:** the Topurrra RT-DETRv2 model on our fixtures.

---

## 2. Face detectors (server side)

Most open face detectors are trained on **WIDER FACE**, which is **CC BY-NC-ND 4.0** ([source](https://huggingface.co/datasets/CUHK-CSE/wider_face)): non-commercial.

| Model | Weights licence | Training data | ONNX / TFLite | Size | Small/distant faces | Verdict |
|---|---|---|---|---|---|---|
| **MediaPipe BlazeFace full-range** | Apache-2.0 ([model card](https://storage.googleapis.com/mediapipe-assets/MediaPipe%20BlazeFace%20Model%20Card%20(Full%20Range).pdf)) | Google in-house, consented images (100k+) | Official TFLite; ONNX via tf2onnx | 1.1 MB | Partly: up to ~5 m, face ≥ 5% of image side, ~10 detections max. **Run on overlapping tiles** to cover distant faces | **PASS** (licence) / RISK (small faces, to test in B1.3) |
| BlazeFace short-range | Apache-2.0 | Same | Official TFLite | 224 KB | No (selfies, < 2 m) | **FAIL** for our photos |
| OpenCV Zoo **YuNet** | MIT | WIDER FACE (NC) | Native ONNX; TFLite via onnx2tf | 227 KB | Yes (≥ ~10 px) | **RISK**: best technically, NC training data |
| UltraFace (1MB) | MIT | WIDER FACE (NC) | ONNX | ~1 MB | Moderate | **RISK** |
| InsightFace SCRFD / RetinaFace | **Non-commercial** ([README](https://github.com/deepinsight/insightface)) | WIDER FACE (NC) | ONNX | 2.5–17 MB | Excellent | **FAIL** |

**Shortlist:** BlazeFace full-range with tiling. YuNet only if the owner accepts the WIDER FACE risk.

---

## 3. Vehicle detectors (phone + server)

All candidates are trained on **COCO**: annotations CC BY 4.0, images from Flickr under mixed CC licences ("users of the images accept full responsibility"). Commercial use of COCO-trained detectors is widespread; the residual legal risk is low to moderate.

| Model | Weights licence | ONNX / TFLite | Size | Verdict |
|---|---|---|---|---|
| **EfficientDet-Lite0** (TF / MediaPipe) | Apache-2.0 (per [HF litert-community](https://huggingface.co/litert-community/efficientdet) / Kaggle; no model card) | **Official TFLite**; ONNX via tf2onnx is awkward, so run the TFLite on the server too | ~4.5 MB | **PASS** (COCO caveat) |
| **YOLOX-Nano / Tiny** | Apache-2.0 | Official ONNX; TFLite via onnx2tf | 3.7–20 MB | **PASS** (COCO caveat). Same family as the proposed plate model |
| PP-PicoDet S/M/L | Apache-2.0 | Official ONNX; TFLite via onnx2tf | 1–6 M params | **PASS** (COCO caveat); Paddle tooling friction |
| RT-DETR R18 (COCO-only weights) | Apache-2.0 | ONNX; poor on phones | ~80 MB | **PASS server-only.** Avoid `_coco_o365` variants (Objects365 is academic-only) |
| SSD MobileNetV2 (MediaPipe) | Undocumented on source page | Official TFLite | small | **RISK** |

**Shortlist:** YOLOX-Nano/Tiny, the same family as the plate detector, so one export and parity pipeline covers both. EfficientDet-Lite0 is the fallback.

---

## Open uncertainties

1. Whether GPL/NC terms on code or training data carry over to trained weights is legally unsettled. We treat it as a blocker for plates (GPL code + undocumented data) and as a risk for faces (WIDER FACE).
2. Open Images images are "listed as" CC BY 2.0 without warranty; attribution needed.
3. BlazeFace full-range input size: 160×192 (model card) vs 128×128 (MediaPipe guide). Check the actual file.
4. No conversion (onnx2tf, tf2onnx) has been tested yet; B1.3 measures parity.
5. Plates are personal data under GDPR; server-side processing needs a privacy review before launch.
