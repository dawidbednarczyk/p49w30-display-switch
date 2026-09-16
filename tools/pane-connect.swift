// pane-connect <display-id> on|off
// Enables or disables one macOS display via the private CGSConfigureDisplayEnabled call — the
// same mechanism BetterDisplay Pro sells as "disconnect". Takes the CGDirectDisplayID
// (hs.screen:id() in Hammerspoon) because a disabled display no longer resolves by UUID.
// Exit 0 on success, 1 when the call fails, 2 on bad arguments.
// Build: swiftc -O -o tools/pane-connect tools/pane-connect.swift
import Foundation
import CoreGraphics

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ config: CGDisplayConfigRef, _ display: CGDirectDisplayID, _ enabled: Bool) -> CGError

let args = CommandLine.arguments
guard args.count == 3, let id = CGDirectDisplayID(args[1]), ["on", "off"].contains(args[2]) else {
    FileHandle.standardError.write("usage: pane-connect <display-id> on|off\n".data(using: .utf8)!)
    exit(2)
}
var config: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&config) == .success, let config else { exit(1) }
let rc = CGSConfigureDisplayEnabled(config, id, args[2] == "on")
guard rc == .success, CGCompleteDisplayConfiguration(config, .permanently) == .success else {
    CGCancelDisplayConfiguration(config)
    FileHandle.standardError.write("CGSConfigureDisplayEnabled(\(id)) failed: \(rc.rawValue)\n".data(using: .utf8)!)
    exit(1)
}
print("display \(id) \(args[2])")
