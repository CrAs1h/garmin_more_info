import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class BkgServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        makeOnlineVerifyRequest();
    }

    function makeOnlineVerifyRequest() as Void {
        var userCode = "";
        try {
            var val = Application.Properties.getValue("licenseKey");
            if (val != null && val instanceof String) {
                userCode = val as String;
            }
        } catch (ex) {
            Background.exit(null);
            return;
        }

        if (userCode.equals("")) {
            Background.exit({ "valid" => false });
            return;
        }

        var deviceId = "";
        var settings = System.getDeviceSettings();
        if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
            deviceId = settings.uniqueIdentifier as String;
        }

        var payload = {
            "activation_code" => userCode,
            "device_id" => deviceId
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            "https://warehouse-hz.top/api/v1/garmin_code/verify",
            payload,
            options,
            method(:onVerifyResponse)
        );
    }

    function onVerifyResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            var dict = data as Dictionary;
            var isValid = false;

            if (dict.hasKey("code") && dict.get("code") == 200 && dict.hasKey("data") && dict.get("data") instanceof Dictionary) {
                var innerData = dict.get("data") as Dictionary;
                if ((innerData.hasKey("valid") && innerData.get("valid") == true) ||
                    (innerData.hasKey("activated") && innerData.get("activated") == true)) {
                    isValid = true;
                }
            } else if (dict.hasKey("valid") && dict.get("valid") == true) {
                isValid = true;
            } else if (dict.hasKey("activated") && dict.get("activated") == true) {
                isValid = true;
            } else if (dict.hasKey("status") && (dict.get("status").equals("success") || dict.get("status") == 200)) {
                isValid = true;
            }

            Background.exit({ "valid" => isValid });
        } else {
            Background.exit(null);
        }
    }
}

(:background)
class GarminMoreInfoApp extends Application.AppBase {

    private var mLicenseManager as LicenseManager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _triggerBackgroundVerify();
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [ new GarminMoreInfoView(getLicenseManager()) ];
    }

    function onSettingsChanged() as Void {
        getLicenseManager().revalidate();
        _triggerBackgroundVerify();
        WatchUi.requestUpdate();
    }

    function onBackgroundData(data) as Void {
        if (data != null && data instanceof Dictionary) {
            if (data.hasKey("valid")) {
                var isValid = data.get("valid") as Boolean;
                getLicenseManager().setActivationStatus(isValid);
            }
        }
        WatchUi.requestUpdate();
    }

    function getServiceDelegate() {
        return [ new BkgServiceDelegate() ];
    }

    function getLicenseManager() as LicenseManager {
        if (mLicenseManager == null) {
            mLicenseManager = new LicenseManager();
        }
        return mLicenseManager as LicenseManager;
    }

    private function _triggerBackgroundVerify() as Void {
        if (Toybox has :Background) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            } catch (ex) {}
        }
    }
}

function getApp() {
    return Application.getApp();
}
