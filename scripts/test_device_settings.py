"""Validate every generated device profile against its SDK and font resources."""
import os
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

from generate_device_settings import ROOT, FIELDS


class DeviceSettingsTests(unittest.TestCase):
    def test_all_device_options_match_sdk(self):
        devices = Path(os.environ["APPDATA"]) / "Garmin/ConnectIQ/Devices"
        jungle = (ROOT / "monkey.jungle").read_text(encoding="utf-8")
        labels = {e.get("id") for e in ET.parse(ROOT / "resources/strings/strings.xml").iter("string")}
        defaults = {e.get("id"): int(e.text) for e in
                    ET.parse(ROOT / "resources/settings/properties.xml").iter("property")
                    if e.get("id").startswith("dataSlot")}
        for product in ET.parse(ROOT / "manifest.xml").findall(".//{*}product"):
            device = product.get("id")
            with self.subTest(device=device):
                api = ET.parse(devices / device / f"{device}.api.debug.xml")
                methods = {(e.get("parent"), e.get("name")) for e in api.iter("functionEntry")}
                expected = [n for n, _, parent, method in FIELDS if (parent, method) in methods]
                matches = re.findall(rf"^{device}\.resourcePath = (.+)$", jungle, re.M)
                self.assertEqual(len(matches), 1)
                profile = matches[0].strip().split(";")[-1]
                all_settings = ET.parse(ROOT / profile / "settings/data-fields.xml").findall("setting")
                slots = [s for s in all_settings if s.get("propertyKey").startswith("@Properties.dataSlot")]
                arcs = [s for s in all_settings if s not in slots]
                self.assertEqual({s.get("propertyKey") for s in arcs}, {"@Properties.leftArcData", "@Properties.rightArcData"})
                arc_defaults = {e.get("id"): int(e.text) for e in ET.parse(ROOT / profile / "settings/arc-properties.xml").iter("property")}
                for arc in arcs:
                    values = [int(e.get("value")) for e in arc.findall("./settingConfig/listEntry")]
                    self.assertEqual(values, [n for n in (3, 2, 6, 7) if n in expected])
                    self.assertIn(arc_defaults[arc.get("propertyKey").split(".")[-1]], values)
                self.assertEqual(arc_defaults["leftArcData"], 3)
                self.assertEqual(arc_defaults["rightArcData"], 2 if 2 in expected else 3)
                self.assertEqual(len(slots), 4)
                self.assertEqual(len({s.get("propertyKey") for s in slots}), 4)
                for slot in slots:
                    entries = slot.findall("./settingConfig/listEntry")
                    self.assertEqual([int(e.get("value")) for e in entries], expected)
                    self.assertIn(defaults[slot.get("propertyKey").split(".")[-1]], expected)
                    self.assertTrue(all(e.text.split(".")[-1] in labels for e in entries))

    def test_new_labels_have_glyphs(self):
        font = (ROOT / "resources/fonts/custom_label.fnt").read_text(encoding="utf-8")
        glyphs = set(map(int, re.findall(r"^char id=(\d+)", font, re.M)))
        self.assertTrue(set(map(ord, "压力血氧海拔气温度GHIJK")).issubset(glyphs))


if __name__ == "__main__":
    unittest.main()
