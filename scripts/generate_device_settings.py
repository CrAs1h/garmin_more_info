"""Generate phone settings from installed Garmin device API definitions.

Run after SDK device updates or manifest changes. Generated resources are committed
so IDE builds also select the correct settings without a pre-build hook.
"""
import argparse
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
# Stable persisted IDs; only expose metrics implemented by readMetric.
FIELDS = [
    (0, "DataSteps", "ActivityMonitor", "getInfo"),
    (1, "DataHeartRate", "Activity", "getActivityInfo"),
    (2, "DataBodyBattery", "SensorHistory", "getBodyBatteryHistory"),
    (3, "DataWatchBattery", "System", "getSystemStats"),
    (4, "DataCalories", "ActivityMonitor", "getInfo"),
    (5, "DataDistance", "ActivityMonitor", "getInfo"),
    (6, "DataStress", "SensorHistory", "getStressHistory"),
    (7, "DataOxygen", "SensorHistory", "getOxygenSaturationHistory"),
    (8, "DataElevation", "SensorHistory", "getElevationHistory"),
    (9, "DataPressure", "SensorHistory", "getPressureHistory"),
    (10, "DataTemperature", "SensorHistory", "getTemperatureHistory"),
]


def generate(devices):
    profiles = {}
    assignments = {}
    # Validate all SDK inputs before writing anything. Missing SDK data must not
    # silently publish a device with an incomplete settings list.
    for product in ET.parse(ROOT / "manifest.xml").findall(".//{*}product"):
        device = product.attrib["id"]
        api = ET.parse(devices / device / f"{device}.api.debug.xml")
        functions = {(e.get("parent"), e.get("name"))
                     for e in api.iter("functionEntry")}
        fields = tuple(value for value, _, parent, method in FIELDS
                       if (parent, method) in functions)
        if not {0, 1, 4, 5}.issubset(fields):
            raise ValueError(f"{device}: missing required baseline APIs/defaults")
        profile = "resources-fields-" + "-".join(map(str, fields))
        profiles[profile] = fields
        assignments[device] = profile

    jungle_path = ROOT / "monkey.jungle"
    jungle = jungle_path.read_text(encoding="utf-8")
    for device, profile in assignments.items():
        pattern = rf"(?m)^({re.escape(device)}\.resourcePath\s*=\s*)(.*)$"
        def replace(match):
            paths = [p for p in match[2].strip().split(";")
                     if not p.startswith("resources-fields-")]
            return match[1] + ";".join(paths + [profile])
        jungle, count = re.subn(pattern, replace, jungle)
        if count != 1:
            raise ValueError(f"{device}: expected exactly one resourcePath assignment")

    for profile, fields in profiles.items():
        settings = ET.Element("settings")
        group = ET.SubElement(settings, "group", {
            "id": "data", "title": "@Strings.DataGroupTitle"})
        # Properties are profile-specific so every default exists in its list.
        properties = ET.Element("properties")
        arc_fields = [value for value in (3, 2, 6, 7) if value in fields]
        labels = {value: label for value, label, _, _ in FIELDS}
        for key, title, default in (
            ("leftArcData", "LeftArcDataTitle", 3),
            ("rightArcData", "RightArcDataTitle", 2 if 2 in fields else 3),
        ):
            ET.SubElement(properties, "property", {"id": key, "type": "number"}).text = str(default)
            setting = ET.SubElement(group, "setting", {
                "propertyKey": "@Properties." + key, "title": "@Strings." + title})
            config = ET.SubElement(setting, "settingConfig", {"type": "list"})
            for value in arc_fields:
                ET.SubElement(config, "listEntry", {"value": str(value)}).text = "@Strings." + labels[value]
        for slot in range(1, 5):
            setting = ET.SubElement(group, "setting", {
                "propertyKey": f"@Properties.dataSlot{slot}",
                "title": f"@Strings.DataSlot{slot}Title"})
            config = ET.SubElement(setting, "settingConfig", {"type": "list"})
            for value, label, _, _ in FIELDS:
                if value in fields:
                    ET.SubElement(config, "listEntry", {"value": str(value)}).text = "@Strings." + label
        ET.indent(properties, space="    ")
        ET.indent(settings, space="    ")
        folder = ROOT / profile / "settings"
        folder.mkdir(parents=True, exist_ok=True)
        ET.ElementTree(settings).write(folder / "data-fields.xml", encoding="utf-8", xml_declaration=True)
        ET.ElementTree(properties).write(folder / "arc-properties.xml", encoding="utf-8", xml_declaration=True)
    jungle_path.write_text(jungle, encoding="utf-8")
    print(f"Generated {len(profiles)} field profiles for {len(assignments)} devices")
    for profile in profiles:
        print(f"  {profile}: {sum(p == profile for p in assignments.values())} devices")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--devices", type=Path, default=Path(os.environ.get("APPDATA", "")) / "Garmin/ConnectIQ/Devices")
    generate(parser.parse_args().devices)
