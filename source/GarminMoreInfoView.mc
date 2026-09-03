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

    private const LANG_ENGLISH = 1;
    private const LANG_CHINESE = 2;

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
        // The usable bottom edge of a round display is higher at the two column
        // centers than it is on the vertical center line. Reserve a conservative
        // circular safe area and split it evenly between both rows.
        var dx = (edge * 0.22).toNumber();
        var dataTop = (h * 0.48).toNumber();
        var dataBottom = (h * 0.84).toNumber();
        var rowHeight = (dataBottom - dataTop) / 2;
        var topY = dataTop;
        var bottomY = dataTop + rowHeight;
        var slotWidth = (edge * 0.35).toNumber();
        var lang = getSetting("labelLanguage", LANG_ENGLISH);
        drawDataSlot(dc, cx - dx, topY, getSetting("dataSlot1", DATA_STEPS), scale, slotWidth, rowHeight, lang);
        drawDataSlot(dc, cx + dx, topY, getSetting("dataSlot2", DATA_HEART_RATE), scale, slotWidth, rowHeight, lang);
        drawDataSlot(dc, cx - dx, bottomY, getSetting("dataSlot3", DATA_BODY_BATTERY), scale, slotWidth, rowHeight, lang);
        drawDataSlot(dc, cx + dx, bottomY, getSetting("dataSlot4", DATA_WATCH_BATTERY), scale, slotWidth, rowHeight, lang);
    }

    private function drawDataSlot(dc as Dc, x, y, dataType, scale, slotWidth, rowHeight, lang) as Void {
        var metric = readMetric(dataType, lang) as Lang.Array;
        var value = metric[0];
        var label = metric[1];
        var labelHeight = dc.getFontHeight(Graphics.FONT_TINY);
        var valueHeight = rowHeight - labelHeight - px(2, scale);
        var valueFont = fitMetricFont(dc, value, slotWidth, valueHeight);
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

    private function fitMetricFont(dc as Dc, value, slotWidth, maxHeight) {
        // Garmin font tables vary between MIP and AMOLED devices. A font must
        // satisfy both axes; width-only fitting can still clip the lower row.
        if (dc.getTextWidthInPixels(value, Graphics.FONT_NUMBER_MEDIUM) <= slotWidth &&
            dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM) <= maxHeight) {
            return Graphics.FONT_NUMBER_MEDIUM;
        }
        if (dc.getTextWidthInPixels(value, Graphics.FONT_NUMBER_MILD) <= slotWidth &&
            dc.getFontHeight(Graphics.FONT_NUMBER_MILD) <= maxHeight) {
            return Graphics.FONT_NUMBER_MILD;
        }
        if (dc.getTextWidthInPixels(value, Graphics.FONT_LARGE) <= slotWidth &&
            dc.getFontHeight(Graphics.FONT_LARGE) <= maxHeight) {
            return Graphics.FONT_LARGE;
        }
        if (dc.getTextWidthInPixels(value, Graphics.FONT_MEDIUM) <= slotWidth &&
            dc.getFontHeight(Graphics.FONT_MEDIUM) <= maxHeight) {
            return Graphics.FONT_MEDIUM;
        }
        return Graphics.FONT_SMALL;
    }

    private function readMetric(dataType, lang) {
        var activity = null;
        try { activity = ActivityMonitor.getInfo(); } catch (ex) {}

        if (dataType == DATA_HEART_RATE) {
            var hr = 0;
            try {
                var active = Activity.getActivityInfo();
                if (active != null && active.currentHeartRate != null) { hr = active.currentHeartRate; }
            } catch (ex) {}
            var label = (lang == LANG_CHINESE) ? "心率" : "BPM";
            return [hr > 0 ? hr.format("%d") : "--", label];
        }

        if (dataType == DATA_BODY_BATTERY) {
            var body = null;
            try {
                if (activity != null && activity has :bodyBattery && activity.bodyBattery != null) {
                    body = activity.bodyBattery;
                }
            } catch (ex) {}
            var label = (lang == LANG_CHINESE) ? "身电" : "BODY";
            return [body == null ? "--" : body.format("%d"), label];
        }

        if (dataType == DATA_WATCH_BATTERY) {
            var label = (lang == LANG_CHINESE) ? "电量" : "BAT";
            return [System.getSystemStats().battery.format("%d") + "%", label];
        }

        if (dataType == DATA_CALORIES) {
            var calories = 0;
            if (activity != null && activity.calories != null) { calories = activity.calories; }
            var label = (lang == LANG_CHINESE) ? "卡路里" : "KCAL";
            return [compactNumber(calories), label];
        }

        if (dataType == DATA_DISTANCE) {
            var distance = 0.0;
            if (activity != null && activity.distance != null) {
                distance = activity.distance.toDouble() / 100000.0;
            }
            var label = (lang == LANG_CHINESE) ? "距离" : "KM";
            return [distance.format("%.1f"), label];
        }

        var steps = 0;
        if (activity != null && activity.steps != null) { steps = activity.steps; }
        var label = (lang == LANG_CHINESE) ? "步数" : "STEPS";
        return [compactNumber(steps), label];
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
