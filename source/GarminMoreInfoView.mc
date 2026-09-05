import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
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

    private const STYLE_ENGLISH = 1;
    private const STYLE_CHINESE = 2;
    private const STYLE_ICONS = 3;

    private const COLOR_BACKGROUND = 0x000000;
    private const COLOR_PRIMARY = 0xF6F2EA;
    private const COLOR_ACCENT = 0xC6FF00;
    private const COLOR_MUTED = 0x8A8A8A;
    private const COLOR_TRACK = 0x2A2A2A;

    private var mLowPower = false;
    private var mCustomLabelFont as WatchUi.FontResource? = null;

    function initialize(licenseManager as LicenseManager?) {
        WatchFace.initialize();
        try {
            mCustomLabelFont = WatchUi.loadResource(Rez.Fonts.CustomLabelFont) as WatchUi.FontResource;
        } catch (ex) {
            mCustomLabelFont = null;
        }
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
        var style = getSetting("labelLanguage", STYLE_ENGLISH);
        var font = Graphics.FONT_SMALL;
        var dateText = "";

        if (style == STYLE_CHINESE) {
            var daysCn = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
            dateText = daysCn[now.day_of_week - 1] + " " + now.day.format("%02d");
            if (mCustomLabelFont != null) {
                font = mCustomLabelFont;
            }
        } else {
            var daysEn = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
            dateText = daysEn[now.day_of_week - 1] + " " + now.day.format("%02d");
        }

        drawText(dc, cx, (h * 0.105).toNumber(), font, dateText,
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
        var style = getSetting("labelLanguage", STYLE_ENGLISH);
        drawDataSlot(dc, cx - dx, topY, getSetting("dataSlot1", DATA_STEPS), scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx + dx, topY, getSetting("dataSlot2", DATA_HEART_RATE), scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx - dx, bottomY, getSetting("dataSlot3", DATA_BODY_BATTERY), scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx + dx, bottomY, getSetting("dataSlot4", DATA_WATCH_BATTERY), scale, slotWidth, rowHeight, style);
    }

    private function drawDataSlot(dc as Dc, x, y, dataType, scale, slotWidth, rowHeight, style) as Void {
        var metric = readMetric(dataType, style) as Lang.Array;
        var value = metric[0];
        var label = metric[1];
        var labelFont = Graphics.FONT_TINY;
        if ((style == STYLE_CHINESE || style == STYLE_ICONS) && mCustomLabelFont != null) {
            labelFont = mCustomLabelFont;
        }

        var labelHeight = dc.getFontHeight(labelFont);
        var valueHeight = rowHeight - labelHeight - px(2, scale);
        var valueFont = fitMetricFont(dc, value, slotWidth, valueHeight);
        drawText(dc, x, y, valueFont, value, COLOR_ACCENT,
                 Graphics.TEXT_JUSTIFY_CENTER);

        // Position labels from the actual device font metrics. This is stable
        // across MIP and AMOLED families whose font tables differ significantly.
        var labelY = y + dc.getFontHeight(valueFont) - px(2, scale);

        if (style == STYLE_ICONS) {
            // 图标模式：居中以高亮色绘制图标符号
            drawText(dc, x, labelY, labelFont, label, COLOR_ACCENT,
                     Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // 文本模式（中文或英文）：在左侧带有小菱形装饰点
            var labelWidth = dc.getTextWidthInPixels(label, labelFont);
            drawDiamond(dc, x - labelWidth / 2 - px(8, scale),
                        labelY + labelHeight / 2,
                        px(3, scale));
            drawText(dc, x + px(3, scale), labelY, labelFont, label, COLOR_PRIMARY,
                     Graphics.TEXT_JUSTIFY_CENTER);
        }
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

    private function readMetric(dataType, style) {
        var activity = null;
        try { activity = ActivityMonitor.getInfo(); } catch (ex) {}

        if (dataType == DATA_HEART_RATE) {
            var hr = 0;
            try {
                var active = Activity.getActivityInfo();
                if (active != null && active.currentHeartRate != null) { hr = active.currentHeartRate; }
            } catch (ex) {}
            var label = "BPM";
            if (style == STYLE_CHINESE) { label = "心率"; }
            else if (style == STYLE_ICONS) { label = "B"; }
            return [hr > 0 ? hr.format("%d") : "--", label];
        }

        if (dataType == DATA_BODY_BATTERY) {
            var body = null;
            try {
                if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                    var bbIter = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                    if (bbIter != null) {
                        var sample = bbIter.next();
                        if (sample != null && sample.data != null) {
                            body = sample.data.toNumber();
                        }
                    }
                }
            } catch (ex) {}
            var label = "BODY";
            if (style == STYLE_CHINESE) { label = "身电"; }
            else if (style == STYLE_ICONS) { label = "C"; }
            return [body == null ? "--" : body.format("%d"), label];
        }

        if (dataType == DATA_WATCH_BATTERY) {
            var label = "BAT";
            if (style == STYLE_CHINESE) { label = "电量"; }
            else if (style == STYLE_ICONS) { label = "D"; }
            return [System.getSystemStats().battery.format("%d") + "%", label];
        }

        if (dataType == DATA_CALORIES) {
            var calories = 0;
            if (activity != null && activity.calories != null) { calories = activity.calories; }
            var label = "KCAL";
            if (style == STYLE_CHINESE) { label = "卡路里"; }
            else if (style == STYLE_ICONS) { label = "E"; }
            return [compactNumber(calories), label];
        }

        if (dataType == DATA_DISTANCE) {
            var distance = 0.0;
            if (activity != null && activity.distance != null) {
                distance = activity.distance.toDouble() / 100000.0;
            }
            var label = "KM";
            if (style == STYLE_CHINESE) { label = "距离"; }
            else if (style == STYLE_ICONS) { label = "F"; }
            return [distance.format("%.1f"), label];
        }

        var steps = 0;
        if (activity != null && activity.steps != null) { steps = activity.steps; }
        var label = "STEPS";
        if (style == STYLE_CHINESE) { label = "步数"; }
        else if (style == STYLE_ICONS) { label = "A"; }
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
