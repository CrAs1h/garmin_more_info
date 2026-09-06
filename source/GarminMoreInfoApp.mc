import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class ActivationServiceDelegate extends System.ServiceDelegate {
    private var mRequestCode as String = "";
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var code = Application.Properties.getValue("licenseKey");
        if (code == null || !(code instanceof String) || (code as String).equals("")) {
            Background.exit({ "valid" => false });
            return;
        }

        var rawCode = code as String;
        var start = 0;
        var end = rawCode.length();
        while (start < end && isWhitespace(rawCode.substring(start, start + 1))) { start++; }
        while (end > start && isWhitespace(rawCode.substring(end - 1, end))) { end--; }
        mRequestCode = rawCode.substring(start, end);
        if (mRequestCode.equals("")) {
            Background.exit(null);
            return;
        }
        var deviceId = "";
        var settings = System.getDeviceSettings();
        if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
            deviceId = settings.uniqueIdentifier as String;
        }

        Communications.makeWebRequest(
            "https://warehouse-hz.top/api/v1/garmin_code/verify",
            { "activation_code" => mRequestCode, "device_id" => deviceId },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    private function isWhitespace(value as String) as Boolean {
        return value.equals(" ") || value.equals("\n") || value.equals("\r") || value.equals("\t");
    }

    function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode != 200 || !(data instanceof Dictionary)) {
            Background.exit(null);
            return;
        }

        var valid = false;
        if (data instanceof Dictionary) {
            var response = data as Dictionary;
            if (response.hasKey("valid") && response.get("valid") == true) {
                valid = true;
            } else if (response.hasKey("activated") && response.get("activated") == true) {
                valid = true;
            } else if (response.hasKey("data") && response.get("data") instanceof Dictionary) {
                var result = response.get("data") as Dictionary;
                valid = (result.hasKey("valid") && result.get("valid") == true) ||
                        (result.hasKey("activated") && result.get("activated") == true);
            }
        }
        Background.exit({ "valid" => valid, "activation_code" => mRequestCode });
    }
}

(:background)
class GarminMoreInfoApp extends Application.AppBase {
    private var mLicenseManager as LicenseManager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}

    function onStop(state) {}

    function getInitialView() {
        return [new GarminMoreInfoView(getLicenseManager())];
    }

    function getServiceDelegate() {
        return [new ActivationServiceDelegate()];
    }

    function onSettingsChanged() as Void {
        getLicenseManager().revalidate();
        requestActivationCheckOnce();
        WatchUi.requestUpdate();
    }

    function onBackgroundData(data) as Void {
        if (data instanceof Dictionary && data.hasKey("valid") && data.hasKey("activation_code")) {
            getLicenseManager().setActivationStatus(data.get("valid") == true, data.get("activation_code") as String);
        }
        WatchUi.requestUpdate();
    }

    private function getLicenseManager() as LicenseManager {
        if (mLicenseManager == null) {
            mLicenseManager = new LicenseManager();
        }
        return mLicenseManager as LicenseManager;
    }

    // The temporal event is one-shot: one settings save, one verification.
    private function requestActivationCheckOnce() as Void {
        try {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        } catch (ex) {}
    }
}

(:background)
function getApp() as GarminMoreInfoApp {
    return Application.getApp() as GarminMoreInfoApp;
}
