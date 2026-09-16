import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "P49w30DisplaySwitch.ahk").read_text(encoding="utf-8")
MAC_SCRIPT_PATH = ROOT / "P49w30DisplaySwitch.lua"


MAC_INPUT_BYTE = 49
LAPTOP_DP_BYTE = 0x0F
LAPTOP_HDMI_BYTE = 0x11
HDMI1_VALUE = 4401
DISPLAYPORT_VALUE = 3889
KNOWN_VALUES = {HDMI1_VALUE, DISPLAYPORT_VALUE}


def is_valid_laptop_byte(high_byte: int) -> bool:
    return high_byte in (LAPTOP_DP_BYTE, LAPTOP_HDMI_BYTE)


def toggle_value(value: int) -> int | None:
    """Reference model for the script's pure 16-bit read-modify-write logic."""
    if value not in KNOWN_VALUES:
        return None
    low_byte = value % 256
    high_byte = value // 256
    next_high_byte = LAPTOP_DP_BYTE if high_byte == LAPTOP_HDMI_BYTE else LAPTOP_HDMI_BYTE
    return low_byte + next_high_byte * 256


def restore_mac_pane(value: int) -> int | None:
    low_byte = value % 256
    high_byte = value // 256
    if low_byte == MAC_INPUT_BYTE or not is_valid_laptop_byte(high_byte):
        return None
    restored = MAC_INPUT_BYTE + high_byte * 256
    return restored if restored in KNOWN_VALUES else None


def pane_connection_state(value: int) -> str | None:
    """macOS connection state the right PBP half should have once `value` is live."""
    if value < 0 or value > 65535:
        return None
    high_byte = value // 256
    if high_byte == LAPTOP_DP_BYTE:
        return "on"
    if high_byte == LAPTOP_HDMI_BYTE:
        return "off"
    return None


def plan_action(value: int) -> tuple[str, int] | None:
    low_byte = value % 256
    high_byte = value // 256
    if not is_valid_laptop_byte(high_byte):
        return None
    if low_byte == MAC_INPUT_BYTE:
        next_value = toggle_value(value)
        return ("toggle", next_value) if next_value is not None else None
    restored = restore_mac_pane(value)
    return ("restore", restored) if restored is not None else None


class ToggleContractTests(unittest.TestCase):
    def test_verified_values_toggle_bidirectionally(self) -> None:
        self.assertEqual(toggle_value(4401), 3889)
        self.assertEqual(toggle_value(3889), 4401)

    def test_low_byte_is_preserved(self) -> None:
        for value in (4401, 3889):
            result = toggle_value(value)
            self.assertIsNotNone(result)
            self.assertEqual(result % 256, value % 256)
            self.assertEqual(result % 256, 49)

    def test_invalid_and_plausible_stale_values_are_rejected(self) -> None:
        for value in (0, 15, 17, 256, 4402, 4145, 65535):
            self.assertIsNone(toggle_value(value))

    def test_corrupted_mac_pane_is_restored_not_toggled(self) -> None:
        self.assertEqual(restore_mac_pane(3857), 3889)
        self.assertEqual(restore_mac_pane(4369), 4401)
        self.assertIsNone(restore_mac_pane(3889))
        self.assertIsNone(restore_mac_pane(4401))

    def test_plan_action_restores_stuck_mac_then_toggles_laptop(self) -> None:
        self.assertEqual(plan_action(3857), ("restore", 3889))
        self.assertEqual(plan_action(4369), ("restore", 4401))
        self.assertEqual(plan_action(4401), ("toggle", 3889))
        self.assertEqual(plan_action(3889), ("toggle", 4401))
        self.assertIsNone(plan_action(4145))

    def test_pane_connection_follows_the_high_byte(self) -> None:
        self.assertEqual(pane_connection_state(DISPLAYPORT_VALUE), "on")
        self.assertEqual(pane_connection_state(HDMI1_VALUE), "off")
        # The low byte never decides ownership of the right half.
        self.assertEqual(pane_connection_state(3857), "on")
        self.assertEqual(pane_connection_state(4369), "off")
        for value in (0, 4145, 70000, -1):
            self.assertIsNone(pane_connection_state(value))

    def test_script_contains_safety_interlocks(self) -> None:
        for required in (
            "STABILITY_WAIT_MS := 6000",
            "second != first",
            "FileDelete(ReadFile)",
            'RegExMatch(output, "^\\d{1,5}$")',
            "value = HDMI1_VALUE || value = DISPLAYPORT_VALUE",
            "lowByte + nextHighByte * 256",
        ):
            self.assertIn(required, SCRIPT)

    def test_mac_hotkey_has_same_safe_toggle_contract(self) -> None:
        mac_script = MAC_SCRIPT_PATH.read_text(encoding="utf-8")
        for required in (
            '{"ctrl", "cmd", "shift"}',
            'hs.hotkey.bind(MODIFIERS, "d"',
            "STABILITY_WAIT_SECONDS = 6",
            "secondValue ~= firstValue",
            "KNOWN_VALUES[value]",
            "lowByte + nextHighByte * 256",
            "MAC_INPUT_BYTE = 49",
            "restoreMacPane",
            "planAction",
            "paneConnectionState",
            "rightPaneID",
            "applyPaneConnection(nextValue",
            "hs.task.new(PANE_CONNECT",
            "rescueStrandedWindows",
            "hs.screen.watcher.new",
            "PANE_MINE_BYTE = 0x0F",
            "PANE_OTHER_BYTE = 0x11",
            "Left pane restored to USB-C",
            '"-vcp=0x60"',
        ):
            self.assertIn(required, mac_script)


if __name__ == "__main__":
    unittest.main()
