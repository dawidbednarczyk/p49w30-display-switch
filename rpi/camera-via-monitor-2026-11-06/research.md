# Camera green/broken through the P49w-30: research (2026-11-06)

Brief: `project_notes/briefs/2026-11-06_camera-green-through-monitor.md`. Evidence: `evidence/`.

## Device
Cisco Desk Camera 1080p, USB `05a6:0025`, fw bcdDevice `0x0821`, serial ATK26241520, 4.48 W bus power.
It offers only uncompressed formats (YUV422 `yuvs` and NV12 `420v`, 256x144 up to 1920x1080, 15/30 fps; no MJPEG):
`evidence/camera_formats.txt`. Webex starts it at 1920x1080 NV12 30 fps, about 750 Mb/s of isochronous traffic.

## Path through the monitor (ioreg/system_profiler, `evidence/ioreg_usb_now.txt`)
MacBook Pro (Mac16,8) → USB4 80 Gb/s → OWC Thunderbolt 5 Hub → USB4 20 Gb/s → P49w-30 TBT4
→ Intel USB3 hub `8087:0b40` (10 Gb/s, tunnelled) → Genesys `17ef:108f` (5 Gb/s) → internal Genesys `17ef:1091`
(5 Gb/s, non-removable) → camera **at 5 Gb/s**, location `0x00222340`. Four hub tiers plus a USB3 tunnel.

Direct: `usb-drd2-port-ss@02200000`, camera **at 5 Gb/s**, no hub.

## Lead hypothesis (USB 2.0 fallback because of DP alt mode): REJECTED
The monitor is on USB4/Thunderbolt, not DP alt mode, and the camera negotiates 5 Gb/s in both cases
(`enumerated 0x05a6/0025/0821 (Cisco Desk Camera 1080p / 19) at 5 Gbps` at 14:55:18, 16:19:27, 16:20:37 via the monitor;
`usb-drd2-port-ss@02200000 ... at 5 Gbps` at 16:18:03 direct). Bandwidth is not the limit.

## What the logs show (`evidence/isoch_errors.txt`, `evidence/log_camera_4h.txt`)
Kernel isochronous failures on the camera's video endpoint, only on the monitor path:
`AppleUSBXHCIIsochronousRequest: AppleUSBIORequest::complete: device 19 (Cisco Desk Camera 1080p@00222340) endpoint 0x81: status 0xe00002ed (transaction error)`

| Session (today) | Path | Stream | Isoch errors |
|---|---|---|---|
| 14:59:34–14:59:52 | monitor `00222340` | 1080p NV12 | 242 |
| 16:18:51–16:19:00 | **direct** `02200000` | 1080p NV12 | **0** while streaming (3 at the unplug instant 16:19:00.957) |
| 16:19:37–16:20:17 | monitor | 1080p NV12, Webex restarting the stream every 5–10 s | 254 + 135 |

Reproduced by me with `./camtest` (10 s, ffmpeg, `evidence/camtest_results.txt`):
1080p via monitor: 15 frames delivered of ~300, 187–224 errors. 720p: 128 errors. 360p: 15 frames, 70–100 errors.
Lower resolution does **not** fix it, so this is not a bandwidth limit: the isochronous path through the monitor's
hub chain loses packets at any rate. A lost packet leaves part of an uncompressed NV12 frame at zero, which renders
**green**: that is the symptom.

## Root cause (current confidence: high for "where", open for "which tier")
SuperSpeed isochronous transfers to the camera fail inside the P49w-30's USB3 hub chain (Intel TBT4 USB3 hub →
two Genesys hubs) behind the OWC hub. Same camera, cable, format and speed work directly. Not yet split: whether the
fault is the monitor's inner hub/port, the monitor's hubs in general, or the OWC→monitor tunnel. The plug tests split it.

## Ruled out
- Hub power: 4.48 W allocated on both paths, no over-current or power messages in the log.
- eKVM: the camera stayed enumerated on the Mac during every failing stream (no terminate between start/stop).
  The one hub drop at 16:20:21 (`USB3.0 Hub: hardware connection lost`, whole monitor hub) was a monitor-side reset.
- Camera/cable: direct path clean with the same cable.
- Drivers: stock Apple UVC (`UVCAssistant`), no third-party camera driver involved.

## What changed since it worked (added 16:55)
- Lighting: not the cause. Light on, via monitor, 16:52: 16 frames, 242 errors (same as with the light off).
  Light only changes the camera's own frame rate (15 vs 30 fps).
- 31.08 record (commit 8f9d7ac, GUIDE.md): the monitor's hub was one single tree, with the Realtek LAN, the Logi receiver,
  the sub-hub with **TIE mic + Desk Camera** and the monitor HID together at `0x0312xxxx`. The LAN (a USB3 device) and the camera
  sitting in the same tree as the USB 2.0 devices means that hub was running **USB 2.0 only**, so the camera was at 480 Mb/s.
  Today the monitor's hub is split: LAN + camera in the USB3 tree at 5 Gb/s, receiver/mic/HID in the USB2 tree.
  Inference, not proof: no link speed was written down on 31.08.
- What gives the monitor a real USB3 link: the MacBook → OWC Thunderbolt 5 hub → Thunderbolt to the monitor
  (USB3 tunnelled over USB4), in place since at least 2026-09-03 (STATUS.md).
- macOS 27.0 (2026-09-26) and 27.0.1 (2026-10-05) are also new since 31.08. Their USB stack could matter too; not provable from the logs
  (the unified log only goes back to today).
- Conclusion: the camera works at USB 2.0 through the monitor and directly at 5 Gb/s. It fails at 5 Gb/s isochronous through the monitor's USB3 hubs.

## Result (17:35): fixed with a USB 2.0-only cable between the camera and the monitor
The camera now sits in the monitor's USB2 tree (`17ef:1092` sub-hub, next to the TIE mic, location `0x00133340`) at **480 Mb/s**.
At High-Speed it sends 1080p and 720p as **MJPEG** (`Setting Active format ... [1920 * 1080 (MJPEG)]`), so it is compressed and no
uncompressed frame can turn green. `./camtest`: 1080p 286 frames in 10 s, 720p 270 frames, **0 isoch errors** (`evidence/camtest_results.txt`).
Formats at USB 2.0: `evidence/camera_formats_usb2.txt`. This matches the 31.08 layout (camera next to the mic in the USB 2.0 tree).
