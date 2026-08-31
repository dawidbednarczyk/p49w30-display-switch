import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "P49w30DisplaySwitch.ahk").read_text(encoding="utf-8")
MAC_SCRIPT_PATH = ROOT / "P49w30DisplaySwitch.lua"


def toggle_value(value: int) -> int | None:
    """Reference model for the script's pure 16-bit read-modify-write logic."""
    if value not in (4401, 3889):
        return None
    low_byte = value % 256
    high_byte = value // 256
    next_high_byte = 0x0F if high_byte == 0x11 else 0x11
    return low_byte + next_high_byte * 256


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
            '"-vcp=0x60"',
        ):
            self.assertIn(required, mac_script)


if __name__ == "__main__":
    unittest.main()
