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
    private const DATA_STRESS = 6;
    private const DATA_OXYGEN = 7;
    private const DATA_ELEVATION = 8;
    private const DATA_PRESSURE = 9;
    private const DATA_TEMPERATURE = 10;

    private const STYLE_ENGLISH = 1;
    private const STYLE_CHINESE = 2;
    private const STYLE_ICONS = 3;

    private const COLOR_BACKGROUND = 0x000000;
    private const COLOR_PRIMARY = 0xF6F2EA;
    private var mAccentColor = 0xC6FF00;
    private var mWatchBatteryColor = 0xC6FF00;
    private var mBodyBatteryColor = 0xC6FF00;
    private const COLOR_MUTED = 0x8A8A8A;
    private const COLOR_TRACK = 0x2A2A2A;

    private var mLowPower = false;
    private var mCustomLabelFont as WatchUi.FontResource? = null;
    private var mCollegeTime;
    private var mCollegeValue;
    private var mCollegeSmall;
    private var mCollegeLabel;
    private var mFontStyle = -1;

    function initialize(licenseManager as LicenseManager?) {
        WatchFace.initialize();
        updateFonts();
        try {
            mCustomLabelFont = WatchUi.loadResource(Rez.Fonts.CustomLabelFont) as WatchUi.FontResource;
        } catch (ex) {
            mCustomLabelFont = null;
        }
    }

    function onLayout(dc as Dc) as Void {}

    private function updateFonts() as Void {
        var selected = getSetting("fontStyle", 0);
        if (selected < 0 || selected > 3) { selected = 0; }
        if (selected == mFontStyle) { return; }
        var ids = [Rez.Fonts.CollegeTime, Rez.Fonts.CollegeValue,
                   Rez.Fonts.CollegeSmall, Rez.Fonts.CollegeLabel];
        if (selected == 1) {
            ids = [Rez.Fonts.BreeSerifTime, Rez.Fonts.BreeSerifValue,
                   Rez.Fonts.BreeSerifSmall, Rez.Fonts.BreeSerifLabel];
        } else if (selected == 2) {
            ids = [Rez.Fonts.GorditasTime, Rez.Fonts.GorditasValue,
                   Rez.Fonts.GorditasSmall, Rez.Fonts.GorditasLabel];
        } else if (selected == 3) {
            ids = [Rez.Fonts.LumberjackTime, Rez.Fonts.LumberjackValue,
                   Rez.Fonts.LumberjackSmall, Rez.Fonts.LumberjackLabel];
        }
        // Release the previous family before loading the selected resources.
        mCollegeTime = null;
        mCollegeValue = null;
        mCollegeSmall = null;
        mCollegeLabel = null;
        mCollegeTime = WatchUi.loadResource(ids[0]);
        mCollegeValue = WatchUi.loadResource(ids[1]);
        mCollegeSmall = WatchUi.loadResource(ids[2]);
        mCollegeLabel = WatchUi.loadResource(ids[3]);
        mFontStyle = selected;
    }
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
        updateFonts();
        updateTheme();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var edge = w < h ? w : h;
        var cx = w / 2;
        var cy = h / 2;
        var scale = edge.toFloat() / 240.0;

        dc.setColor(COLOR_BACKGROUND, COLOR_BACKGROUND);
        dc.clear();

        drawOrbit(dc, cx, cy, edge, scale);
        drawDate(dc, cx, h, scale);
        drawTime(dc, cx, h, scale);
        if (!mLowPower) {
            drawDataSlots(dc, cx, h, edge, scale);
        }
    }

    // Invalid/stale selections fall back to a supported default; missing samples
    // leave only the track visible instead of displaying another metric's value.
    private function getOrbitValue(key, fallback) {
        if (!isMetricSupported(fallback)) { fallback = DATA_WATCH_BATTERY; }
        var selected = getSetting(key, fallback);
        if ((selected != DATA_WATCH_BATTERY && selected != DATA_BODY_BATTERY &&
             selected != DATA_STRESS && selected != DATA_OXYGEN) ||
            !isMetricSupported(selected)) {
            selected = fallback;
        }
        try {
            if (selected == DATA_WATCH_BATTERY) { return System.getSystemStats().battery; }
            if (selected == DATA_BODY_BATTERY) { return getBodyBattery(); }
            return latestSensorValue(selected);
        } catch (ex) {}
        return null;
    }

    private function drawOrbit(dc as Dc, cx, cy, edge, scale) as Void {
        var radius = edge / 2 - px(8, scale);
        var penWidth = px(5, scale);
        var activeColor = mLowPower ? COLOR_MUTED : mAccentColor;
        var watchColor = mLowPower ? COLOR_MUTED : mWatchBatteryColor;
        var bodyColor = mLowPower ? COLOR_MUTED : mBodyBatteryColor;

        dc.setPenWidth(penWidth);

        // 1. 左侧自定义数据轨：从 6点钟(264°) 顺时针延伸至 12点钟(96°)，总跨度 168°
        // 暗灰底轨
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 264, 96);

        // 左侧所选数据的 0–100 进度
        var watchBattery = getOrbitValue("leftArcData", DATA_WATCH_BATTERY);
        if (watchBattery != null && watchBattery > 0) {
            if (watchBattery > 100) { watchBattery = 100; }
            var watchSweep = (watchBattery * 168 / 100).toNumber();
            if (watchSweep < 1) { watchSweep = 1; }
            var watchEnd = 264 - watchSweep;
            dc.setColor(watchColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 264, watchEnd);
        }

        // 2. 右侧自定义数据轨：从 6点钟(276°) 逆时针延伸至 12点钟(84°)，总跨度 168°
        // 暗灰底轨
        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, 276, 84);

        // 右侧所选数据的 0–100 进度
        var bodyBattery = getOrbitValue("rightArcData", DATA_BODY_BATTERY);
        if (bodyBattery != null && bodyBattery > 0) {
            if (bodyBattery > 100) { bodyBattery = 100; }
            var bodySweep = (bodyBattery * 168 / 100).toNumber();
            if (bodySweep < 1) { bodySweep = 1; }
            var bodyEnd = 276 + bodySweep;
            dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
            if (bodyEnd <= 360) {
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, 276, bodyEnd);
            } else {
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, 276, 360);
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, 0, bodyEnd - 360);
            }
        }

        // Eight segments place the middle gap directly at the 3/9 o'clock ticks.
        // Mask after drawing progress so partial segments still show the exact
        // battery level, and empty track segments have the same spacing.
        dc.setPenWidth(penWidth + px(2, scale));
        dc.setColor(COLOR_BACKGROUND, Graphics.COLOR_TRANSPARENT);
        // Only the explicit solid value disables segmentation. Both styles
        // retain clearance around the side ticks to avoid overlapping them.
        var segmented = getSetting("batteryBarStyle", 0) != 1;
        for (var segment = 1; segment < 8; segment++) {
            if (!segmented && segment != 4) { continue; }
            var offset = segment * 21;
            // Extra clearance keeps the tick separate from both arc ends.
            var halfGap = segment == 4 ? 4 : 2;
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE,
                       264 - offset + halfGap, 264 - offset - halfGap);
            if (segment == 4) {
                // Split the right tick gap at the 360/0 degree boundary.
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                           360 - halfGap, 360);
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                           0, halfGap);
            } else {
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                           (276 + offset - halfGap) % 360, (276 + offset + halfGap) % 360);
            }
        }

        // 3. 四方方位刻度线（Tick Marks）
        // 12点与6点方向小短线居中分隔左右双轨；3点与9点小短线指示左右轨 50% 标线
        dc.setPenWidth(px(3, scale));
        dc.setColor(activeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, px(4, scale), cx, px(12, scale));
        dc.drawLine(cx, edge - px(12, scale), cx, edge - px(4, scale));
        dc.drawLine(px(4, scale), cy, px(12, scale), cy);
        dc.drawLine(edge - px(12, scale), cy, edge - px(4, scale), cy);
    }

    private function drawDate(dc as Dc, cx, h, scale) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var style = getSetting("labelLanguage", STYLE_ENGLISH);
        var font = mCollegeLabel;
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

        drawText(dc, cx, (h * 0.13).toNumber() + px(5, scale), font, dateText,
                 mLowPower ? COLOR_MUTED : mWatchBatteryColor, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTime(dc as Dc, cx, h, scale) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        var timeText = hour.format("%02d") + ":" + clock.min.format("%02d");
        drawText(dc, cx, (h * 0.23).toNumber() + px(5, scale), mCollegeTime, timeText,
                 COLOR_PRIMARY, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawDataSlots(dc as Dc, cx, h, edge, scale) as Void {
        // The usable bottom edge of a round display is higher at the two column
        // centers than it is on the vertical center line. Reserve a conservative
        // circular safe area and split it evenly between both rows.
        var dx = (edge * 0.22).toNumber() - px(13, scale);
        var dataTop = (h * 0.48).toNumber() + px(9, scale);
        var dataBottom = (h * 0.84).toNumber() + px(9, scale);
        var rowHeight = (dataBottom - dataTop) / 2;
        var topY = dataTop;
        var bottomY = dataTop + rowHeight;
        var slotWidth = (edge * 0.35).toNumber();
        var style = getSetting("labelLanguage", STYLE_ENGLISH);
        var slot1 = getSetting("dataSlot1", DATA_STEPS);
        if (!isMetricSupported(slot1)) {
            slot1 = DATA_STEPS;
        }
        var slot2 = getSetting("dataSlot2", DATA_HEART_RATE);
        if (!isMetricSupported(slot2)) {
            slot2 = DATA_HEART_RATE;
        }
        var slot3 = getSetting("dataSlot3", DATA_CALORIES);
        if (!isMetricSupported(slot3)) {
            slot3 = DATA_CALORIES;
        }
        var slot4 = getSetting("dataSlot4", DATA_DISTANCE);
        if (!isMetricSupported(slot4)) {
            slot4 = DATA_DISTANCE;
        }

        drawDataSlot(dc, cx - dx, topY, slot1, scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx + dx, topY, slot2, scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx - dx, bottomY, slot3, scale, slotWidth, rowHeight, style);
        drawDataSlot(dc, cx + dx, bottomY, slot4, scale, slotWidth, rowHeight, style);
    }

    private function drawDataSlot(dc as Dc, x, y, dataType, scale, slotWidth, rowHeight, style) as Void {
        var metric = readMetric(dataType, style) as Lang.Array;
        var value = metric[0];
        var label = metric[1];
        var isTwoTone = mWatchBatteryColor != mBodyBatteryColor;
        var columnColor = x < dc.getWidth() / 2 ? mWatchBatteryColor : mBodyBatteryColor;
        var labelColor = isTwoTone ? columnColor : COLOR_PRIMARY;
        var decorationColor = isTwoTone ? columnColor : mAccentColor;
        var labelFont = mCollegeLabel;
        if ((style == STYLE_CHINESE || style == STYLE_ICONS) && mCustomLabelFont != null) {
            labelFont = mCustomLabelFont;
        }

        var labelHeight = dc.getFontHeight(labelFont);
        var labelGap = px(3, scale);
        var valueHeight = rowHeight - labelHeight - labelGap;
        var valueFont = fitMetricFont(dc, value, slotWidth, valueHeight);
        var valHeight = dc.getFontHeight(valueFont);

        // 垂直居中排布数值与字段名称，并赋予舒适的上下间距
        var totalHeight = valHeight + labelGap + labelHeight;
        var valueY = y;
        if (rowHeight > totalHeight) {
            valueY = y + (rowHeight - totalHeight) / 2;
        }
        var labelY = valueY + valHeight + labelGap;

        drawText(dc, x, valueY, valueFont, value, mAccentColor,
                 Graphics.TEXT_JUSTIFY_CENTER);

        if (style == STYLE_ICONS) {
            // 图标模式：居中以强调色绘制图标符号
            drawText(dc, x, labelY, labelFont, label, decorationColor,
                     Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // 文本模式（中文或英文）：居中绘制字段名称（已去掉前置菱形）
            drawText(dc, x, labelY, labelFont, label, labelColor,
                     Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function fitMetricFont(dc as Dc, value, slotWidth, maxHeight) {
        if (dc.getTextWidthInPixels(value, mCollegeValue) <= slotWidth &&
            dc.getFontHeight(mCollegeValue) <= maxHeight) {
            return mCollegeValue;
        }
        if (dc.getTextWidthInPixels(value, mCollegeSmall) <= slotWidth &&
            dc.getFontHeight(mCollegeSmall) <= maxHeight) {
            return mCollegeSmall;
        }
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

    // Check capability, not sample availability: an unworn watch may return null.
    private function isMetricSupported(dataType) as Boolean {
        if (dataType == DATA_BODY_BATTERY) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory);
        }
        if (dataType == DATA_STRESS) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory);
        }
        if (dataType == DATA_OXYGEN) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getOxygenSaturationHistory);
        }
        if (dataType == DATA_ELEVATION) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory);
        }
        if (dataType == DATA_PRESSURE) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory);
        }
        if (dataType == DATA_TEMPERATURE) {
            return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory);
        }
        return dataType == DATA_STEPS || dataType == DATA_HEART_RATE ||
               dataType == DATA_WATCH_BATTERY || dataType == DATA_CALORIES ||
               dataType == DATA_DISTANCE;
    }

    private function readMetric(dataType, style) {
        if (dataType >= DATA_STRESS && dataType <= DATA_TEMPERATURE) {
            return readSensorMetric(dataType, style);
        }
        var activity = null;
        try { activity = ActivityMonitor.getInfo(); } catch (ex) {}

        if (dataType == DATA_HEART_RATE) {
            var hr = 0;
            try {
                var active = Activity.getActivityInfo();
                if (active != null && (active has :currentHeartRate) && active.currentHeartRate != null) { hr = active.currentHeartRate; }
            } catch (ex) {}
            var label = "BPM";
            if (style == STYLE_CHINESE) { label = "心率"; }
            else if (style == STYLE_ICONS) { label = "B"; }
            return [hr > 0 ? hr.format("%d") : "--", label];
        }

        if (dataType == DATA_BODY_BATTERY) {
            var body = getBodyBattery();
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
            if (activity != null && (activity has :calories) && activity.calories != null) { calories = activity.calories; }
            var label = "KCAL";
            if (style == STYLE_CHINESE) { label = "卡路里"; }
            else if (style == STYLE_ICONS) { label = "E"; }
            return [compactNumber(calories), label];
        }

        if (dataType == DATA_DISTANCE) {
            var distance = 0.0;
            if (activity != null && (activity has :distance) && activity.distance != null) {
                distance = activity.distance.toDouble() / 100000.0;
            }
            var label = "KM";
            if (style == STYLE_CHINESE) { label = "距离"; }
            else if (style == STYLE_ICONS) { label = "F"; }
            return [distance.format("%.1f"), label];
        }

        var steps = 0;
        if (activity != null && (activity has :steps) && activity.steps != null) { steps = activity.steps; }
        var label = "STEPS";
        if (style == STYLE_CHINESE) { label = "步数"; }
        else if (style == STYLE_ICONS) { label = "A"; }
        return [formatWithCommas(steps), label];
    }

    private function readSensorMetric(dataType, style) {
        var label = "STRESS";
        var chinese = "压力";
        var icon = "G";
        if (dataType == DATA_OXYGEN) { label = "SPO2"; chinese = "血氧"; icon = "H"; }
        else if (dataType == DATA_ELEVATION) { label = "ALT M"; chinese = "海拔"; icon = "I"; }
        else if (dataType == DATA_PRESSURE) { label = "HPA"; chinese = "气压"; icon = "J"; }
        else if (dataType == DATA_TEMPERATURE) { label = "TEMP C"; chinese = "温度"; icon = "K"; }
        if (style == STYLE_CHINESE) { label = chinese; }
        else if (style == STYLE_ICONS) { label = icon; }
        var value = latestSensorValue(dataType);
        if (value == null) { return ["--", label]; }
        if (dataType == DATA_OXYGEN) { return [value.format("%.0f") + "%", label]; }
        if (dataType == DATA_PRESSURE) { return [(value / 100.0).format("%.0f"), label]; }
        if (dataType == DATA_TEMPERATURE) { return [value.format("%.1f"), label]; }
        return [value.format("%.0f"), label];
    }

    // Read only the latest sample, never scan history on every screen refresh.
    private function latestSensorValue(dataType) {
        try {
            if (!isMetricSupported(dataType)) { return null; }
            var iterator = null;
            var options = {:period => 1};
            if (dataType == DATA_STRESS && (Toybox.SensorHistory has :getStressHistory)) {
                iterator = Toybox.SensorHistory.getStressHistory(options);
            }
            if (dataType == DATA_OXYGEN && (Toybox.SensorHistory has :getOxygenSaturationHistory)) {
                iterator = Toybox.SensorHistory.getOxygenSaturationHistory(options);
            }
            if (dataType == DATA_ELEVATION && (Toybox.SensorHistory has :getElevationHistory)) {
                iterator = Toybox.SensorHistory.getElevationHistory(options);
            }
            if (dataType == DATA_PRESSURE && (Toybox.SensorHistory has :getPressureHistory)) {
                iterator = Toybox.SensorHistory.getPressureHistory(options);
            }
            if (dataType == DATA_TEMPERATURE && (Toybox.SensorHistory has :getTemperatureHistory)) {
                iterator = Toybox.SensorHistory.getTemperatureHistory(options);
            }
            if (iterator == null) { return null; }
            var sample = iterator.next();
            if (sample == null || sample.data == null) { return null; }
            var value = sample.data.toFloat();
            // Keep zero stress and negative elevation/temperature valid.
            if (dataType == DATA_STRESS && (value < 0 || value > 100)) { return null; }
            if (dataType == DATA_OXYGEN && (value <= 0 || value > 100)) { return null; }
            if (dataType == DATA_PRESSURE && value <= 0) { return null; }
            return value;
        } catch (ex) {}
        return null;
    }

    // Read on refresh so settings changes apply without recreating the view.
    // Missing or unsupported values retain the original theme.
    private function updateTheme() as Void {
        var theme = getSetting("colorTheme", 0);
        // Neutral values and ticks balance the colored arcs, date and labels.
        mAccentColor = COLOR_PRIMARY;
        switch (theme) {
            case 9:
                mAccentColor = 0x99DDCC;
                break;
            case 10:
                mAccentColor = 0xDDAABB;
                break;
            case 11:
                mAccentColor = 0xEEDD99;
                break;
            case 12:
                mAccentColor = 0xAABB99;
                break;
            case 13:
                mAccentColor = 0xEEAA99;
                break;
            case 14:
                mAccentColor = 0xAAAADD;
                break;
            case 15:
                mWatchBatteryColor = 0xAABB99;
                mBodyBatteryColor = 0xDDAABB;
                return;
            case 16:
                mWatchBatteryColor = 0x99BBDD;
                mBodyBatteryColor = 0xEEDD99;
                return;
            case 17:
                mWatchBatteryColor = 0xEEAA99;
                mBodyBatteryColor = 0xAAAADD;
                return;
            case 18:
                mWatchBatteryColor = 0x99DDCC;
                mBodyBatteryColor = 0xCCAACC;
                return;
            case 19:
                mWatchBatteryColor = 0xDDBBBB;
                mBodyBatteryColor = 0x88BBBB;
                return;
            case 20:
                mWatchBatteryColor = 0xDDBB88;
                mBodyBatteryColor = 0x99BB99;
                return;
            case 5:
                mWatchBatteryColor = 0x99CCCC;
                mBodyBatteryColor = 0xFFCC99;
                return;
            case 6:
                mWatchBatteryColor = 0x99CCBB;
                mBodyBatteryColor = 0xDDAABB;
                return;
            case 7:
                mWatchBatteryColor = 0xBBAADD;
                mBodyBatteryColor = 0xDDCC99;
                return;
            case 8:
                mWatchBatteryColor = 0x99BBDD;
                mBodyBatteryColor = 0xDDAA99;
                return;
            case 1:
                mAccentColor = 0x66CCFF;
                break;
            case 2:
                mAccentColor = 0xFFAA33;
                break;
            case 3:
                mAccentColor = 0xCC99FF;
                break;
            case 4:
                mAccentColor = 0xF6F2EA;
                break;
            default:
                mAccentColor = 0xC6FF00;
                break;
        }
        // Reset both arcs when returning from a two-tone to a solid theme.
        mWatchBatteryColor = mAccentColor;
        mBodyBatteryColor = mAccentColor;
    }

    private function getSetting(key, fallback) {
        try {
            var value = Application.Properties.getValue(key);
            if (value != null && value instanceof Lang.Number) { return value as Lang.Number; }
        } catch (ex) {}
        return fallback;
    }

    private function formatWithCommas(value) {
        if (value < 0) {
            return "-" + formatWithCommas(-value);
        }
        if (value < 1000) {
            return value.format("%d");
        }
        var s = "";
        var temp = value;
        while (temp >= 1000) {
            var rem = temp % 1000;
            s = "," + rem.format("%03d") + s;
            temp = temp / 1000;
        }
        return temp.format("%d") + s;
    }

    private function compactNumber(value) {
        if (value >= 10000) { return (value.toFloat() / 1000.0).format("%.1f") + "K"; }
        if (value >= 1000) {
            return (value / 1000).format("%d") + "," + (value % 1000).format("%03d");
        }
        return value.format("%d");
    }

    private function drawText(dc as Dc, x, y, font, value, color, justify) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, justify);
    }

    private function px(value, scale) {
        var result = (value * scale).toNumber();
        return result < 1 ? 1 : result;
    }

    private function getBodyBattery() as Lang.Number? {
        try {
            if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var bbIter = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                if (bbIter != null) {
                    var sample = bbIter.next();
                    if (sample != null && sample.data != null) {
                        return sample.data.toNumber();
                    }
                }
            }
        } catch (ex) {}
        return null;
    }
}
