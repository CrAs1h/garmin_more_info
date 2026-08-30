import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

// 最小表盘 DEMO：黑色背景，仅显示当前时间。
class GarminMoreInfoView extends WatchUi.WatchFace {

    function initialize(licenseManager as LicenseManager?) {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;

        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }

        var timeText = hour.format("%02d") + ":" + clockTime.min.format("%02d");

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_NUMBER_MEDIUM,
            timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function onHide() as Void {
    }
}
