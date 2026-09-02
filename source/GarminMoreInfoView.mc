import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// ORBIT DATA: a round-screen-first, data-rich watch face.
class GarminMoreInfoView extends WatchUi.WatchFace {
    private const DATA_STEPS = 0;
    private const DATA_HEART_RATE = 1;
    private const DATA_BODY_BATTERY = 2;
    private const DATA_WATCH_BATTERY = 3;
    private const DATA_CALORIES = 4;
    private const DATA_DISTANCE = 5;

    private const COLOR_BACKGROUND = 0x000000;
    private const COLOR_PRIMARY = 0xF6F2EA;
    private const COLOR_ACCENT = 0xC6FF00;
    private const COLOR_MUTED = 0x8A8A8A;
    private const COLOR_TRACK = 0x2A2A2A;

    private var mLowPower = false;

    function initialize(licenseManager as LicenseManager?) {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {}
    function onShow() as Void {}
    function onHide() as Void {}

    function onEnterSleep() as Void {
        mLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mLowPower = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var edge = w < h ? w : h;
        var cx = w / 2;
        var cy = h / 2;
        var scale = edge.toFloat() / 240.0;

        dc.setColor(COLOR_BACKGROUND, COLOR_BACKGROUND);
        dc.clear();

        drawOrbit(dc, cx, cy, edge, scale);
        drawDate(dc, cx, h);
        drawTime(dc, cx, h);
        if (!mLowPower) {
            drawDataSlots(dc, cx, h, edge, scale);
        }
    }

    private function drawOrbit(dc as Dc, cx, cy, edge, scale) as Void {
        var radius = edge / 2 - px(8, scale);
        var battery = System.getSystemStats().battery;
        var sweep = (battery * 270 / 100).toNumber();

        dc.setPenWidth(px(5, scale));
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 225, 135);
        dc.setColor(mLowPower ? COLOR_MUTED : COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        var endAngle = 225 + sweep;
        if (endAngle <= 360) {
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 225, endAngle);
        } else {
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 225, 360);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 0, endAngle - 360);
        }

        dc.setPenWidth(px(3, scale));
        dc.drawLine(cx, px(4, scale), cx, px(12, scale));
        dc.drawLine(cx, edge - px(12, scale), cx, edge - px(4, scale));
        dc.drawLine(px(4, scale), cy, px(12, scale), cy);
        dc.drawLine(edge - px(12, scale), cy, edge - px(4, scale), cy);
    }

    private function drawDate(dc as Dc, cx, h) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var dateText = days[now.day_of_week - 1] + " " + now.day.format("%02d");
        drawText(dc, cx, (h * 0.105).toNumber(), Graphics.FONT_SMALL, dateText,
                 mLowPower ? COLOR_MUTED : COLOR_ACCENT, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTime(dc as Dc, cx, h) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeText = hour.format("%02d") + ":" + clock.min.format("%02d");
        drawText(dc, cx, (h * 0.205).toNumber(), Graphics.FONT_NUMBER_HOT, timeText,
                 COLOR_PRIMARY, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawDataSlots(dc as Dc, cx, h, edge, scale) as Void {
        // Garmin's built-in fonts do not scale linearly with screen resolution.
        // Keep both rows inside the circular safe zone instead of scaling a fixed
        // 240 px spacing value (which pushed row two off 390 px devices).
        var dx = (edge * 0.22).toNumber();
        var topY = (h * 0.49).toNumber();
        var bottomY = (h * 0.69).toNumber();
        var slotWidth = (edge * 0.35).toNumber();
        drawDataSlot(dc, cx - dx, topY, getSetting("dataSlot1", DATA_STEPS), scale, slotWidth);
        drawDataSlot(dc, cx + dx, topY, getSetting("dataSlot2", DATA_HEART_RATE), scale, slotWidth);
        drawDataSlot(dc, cx - dx, bottomY, getSetting("dataSlot3", DATA_BODY_BATTERY), scale, slotWidth);
        drawDataSlot(dc, cx + dx, bottomY, getSetting("dataSlot4", DATA_WATCH_BATTERY), scale, slotWidth);
    }

    private function drawDataSlot(dc as Dc, x, y, dataType, scale, slotWidth) as Void {
        var metric = readMetric(dataType) as Lang.Array;
        var value = metric[0];
        var label = metric[1];
        var valueFont = fitMetricFont(dc, value, slotWidth);
        drawText(dc, x, y, valueFont, value, COLOR_ACCENT,
                 Graphics.TEXT_JUSTIFY_CENTER);

        // Position labels from the actual device font metrics. This is stable
        // across MIP and AMOLED families whose font tables differ significantly.
        var labelY = y + dc.getFontHeight(valueFont) - px(2, scale);
        var labelWidth = dc.getTextWidthInPixels(label, Graphics.FONT_TINY);
        drawDiamond(dc, x - labelWidth / 2 - px(8, scale),
                    labelY + dc.getFontHeight(Graphics.FONT_TINY) / 2,
                    px(3, scale));
        drawText(dc, x + px(3, scale), labelY, Graphics.FONT_TINY, label, COLOR_PRIMARY,
                 Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function fitMetricFont(dc as Dc, value, slotWidth) {
        // NUMBER_MEDIUM is preferred when it fits. Long values fall back to
        // NUMBER_MILD so adjacent slots can never collide horizontally.
        if (dc.getTextWidthInPixels(value, Graphics.FONT_NUMBER_MEDIUM) <= slotWidth) {
            return Graphics.FONT_NUMBER_MEDIUM;
        }
        return Graphics.FONT_NUMBER_MILD;
    }

    private function readMetric(dataType) {
        var activity = null;
        try { activity = ActivityMonitor.getInfo(); } catch (ex) {}

        if (dataType == DATA_HEART_RATE) {
            var hr = 0;
            try {
                var active = Activity.getActivityInfo();
                if (active != null && active.currentHeartRate != null) { hr = active.currentHeartRate; }
            } catch (ex) {}
            return [hr > 0 ? hr.format("%d") : "--", "BPM"];
        }

        if (dataType == DATA_BODY_BATTERY) {
            var body = null;
            try {
                if (activity != null && activity has :bodyBattery && activity.bodyBattery != null) {
                    body = activity.bodyBattery;
                }
            } catch (ex) {}
            return [body == null ? "--" : body.format("%d"), "BODY"];
        }

        if (dataType == DATA_WATCH_BATTERY) {
            return [System.getSystemStats().battery.format("%d") + "%", "BAT"];
        }

        if (dataType == DATA_CALORIES) {
            var calories = 0;
            if (activity != null && activity.calories != null) { calories = activity.calories; }
            return [compactNumber(calories), "KCAL"];
        }

        if (dataType == DATA_DISTANCE) {
            var distance = 0.0;
            if (activity != null && activity.distance != null) {
                distance = activity.distance.toDouble() / 100000.0;
            }
            return [distance.format("%.1f"), "KM"];
        }

        var steps = 0;
        if (activity != null && activity.steps != null) { steps = activity.steps; }
        return [compactNumber(steps), "STEPS"];
    }

    private function getSetting(key, fallback) {
        try {
            var value = Application.Properties.getValue(key);
            if (value != null && value instanceof Lang.Number) { return value as Lang.Number; }
        } catch (ex) {}
        return fallback;
    }

    private function compactNumber(value) {
        if (value >= 10000) { return (value.toFloat() / 1000.0).format("%.1f") + "K"; }
        if (value >= 1000) {
            return (value / 1000).format("%d") + "," + (value % 1000).format("%03d");
        }
        return value.format("%d");
    }

    private function drawDiamond(dc as Dc, x, y, radius) as Void {
        dc.setColor(COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x, y - radius, x + radius, y);
        dc.drawLine(x + radius, y, x, y + radius);
        dc.drawLine(x, y + radius, x - radius, y);
        dc.drawLine(x - radius, y, x, y - radius);
    }

    private function drawText(dc as Dc, x, y, font, value, color, justify) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, justify);
    }

    private function px(value, scale) {
        var result = (value * scale).toNumber();
        return result < 1 ? 1 : result;
    }
}
