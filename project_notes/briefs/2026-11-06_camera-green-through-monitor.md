# Brief 2026-11-06 (from cisco-mm, on Dawid's request): webcam picture broken/green only through the P49w-30

Symptom (Dawid, verbatim summary): the USB camera works when plugged directly into the laptop. Plugged into the
Lenovo ThinkVision P49w-30 (its USB-C / hub), the picture is broken, cut off, sometimes green. Already tried:
restart laptop, restart monitor, restart camera, a different cable. Same result. Camera and cable look fine.
Today's laptop restart was done for this (agentic-system carry-over 2026-11-06T1338Z).

Do it as an RPI cycle in this repo: `rpi/camera-via-monitor-2026-11-06/` (skill `rpi-strategy-hierarchic`, small).
This repo knows the desk topology (which machine sits on which input, USB-C upstream, eKVM, PBP); use it.

## Research (logs first, no guessing)
- Identify the camera (vendor/product id, model) and the exact path in both cases:
  `system_profiler SPUSBDataType SPThunderboltDataType SPDisplaysDataType -json`, `ioreg -p IOUSB -l -w0`.
  Record negotiated USB speed (480 Mb/s vs 5/10 Gb/s), the hub chain and the power for direct vs through monitor.
- macOS logs around plug-in and camera start: `log show --last 2h --predicate 'subsystem CONTAINS "usb" OR
  process CONTAINS "VDCAssistant" OR process CONTAINS "UVC" OR subsystem CONTAINS "cmio"'` (narrow it; do not dump
  everything). Look for bandwidth, isochronous, frame-drop or format errors.
- Which formats/resolutions the camera offers and which one the app picks (ffmpeg `-f avfoundation -list_options`
  if installed, or the camera's own app).
- Monitor side: the P49w-30 user guide for USB-C and the hub. Lead hypothesis to prove or reject: with USB-C in
  DisplayPort alt mode at 5120x1440 the monitor uses all 4 lanes for video, so the hub falls back to USB 2.0
  (480 Mb/s). A camera sending high-resolution uncompressed/MJPEG frames over that link then breaks up or turns
  green. Check the OSD option for USB-C data vs display priority, the eKVM routing, and Lenovo firmware/known issues.
- Other causes to rule out: hub power, eKVM switching the hub to the other machine, a camera firmware issue.

## Implement
Dawid has to plug and unplug the hardware. Prepare small, exact test steps he can do (one change at a time), with
the command you run after each step, and ask him in the pane. Candidate fixes: monitor OSD USB setting, laptop on a
separate USB upstream cable, camera on a lower resolution/format, camera direct + monitor for video only, firmware.

## Rules
Do not remove or replace drivers or system extensions without asking Dawid. Install nothing that needs admin
rights without asking. Do not change the display-switch scripts (unrelated). Standing rule from
CISCO-LAPTOP-INSTRUCTIONS.md applies.
Report (project_notes/<date>_<time>_status.md + pane): root cause with evidence (log lines, USB speed both ways),
the fix, and what Dawid tested.
