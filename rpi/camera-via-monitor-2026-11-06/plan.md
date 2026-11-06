# Plan: plug tests (one change at a time). After every step: `./camtest <label>` (10 s, logs path, speed, frames, errors)

Pass = a steady stream over the full 10 s (direct gave 150 frames = 15 fps, which is the rate the camera picks itself, likely because of the light) and 0 isoch errors. Dawid also looks at the Webex self-view.

| # | Dawid does | Splits | Label |
|---|---|---|---|
| T0 | done: camera in the monitor, current port | baseline: 15 frames, ~200 errors | baseline-via-monitor |
| T1 | camera directly into a MacBook port, same cable | control: **PASS** 16:41, 150 frames, 0 errors at 1080p and at 360p | direct |
| T2 | camera into a **different** USB-A port on the monitor (rear 2/4/5 if it is in a bottom/side port now, or the other way round) | one monitor port/inner hub vs the whole monitor | monitor-otherport | (skipped: no free monitor port)
| T3 | camera into a free port on the **OWC Thunderbolt 5 hub** | monitor hubs vs the OWC tunnel | owc-hub | (skipped: not needed)
| T4 | USB 2.0-only cable camera→monitor, same monitor port | **PASS = FIX** 17:34, 480 Mb/s, 286 frames (~29 fps), 0 errors; 720p 270 frames, 0 errors | usb2 |

Fix candidates, by result: keep the camera on the port that passes (T1/T3 most likely); monitor firmware update from
Lenovo (needs Dawid; installer may need admin); camera firmware via the Webex app (Settings → Devices) or Cisco
accessory updater. No drivers touched. Not changed: display-switch scripts.
