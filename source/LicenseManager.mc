import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// 在线授权码管理器
// 调用 https://warehouse-hz.top/api/v1/garmin_code/verify 校验激活码与设备ID
class LicenseManager {

    private const STORAGE_KEY_ACTIVATED = "is_activated";
    private const STORAGE_KEY_LAST_CODE = "last_activation_code";

    private var mIsActivated as Boolean = false;
    private var mIsExpired as Boolean = false;
    private var mDeviceId as String = "";

    function initialize() {
        mDeviceId = _loadDeviceId();
        _syncDeviceIdToSettings();

        // 尝试从 Storage 加载本地已保存的激活状态
        mIsActivated = _loadSavedActivationStatus();

    }

    // 获取设备唯一标识
    function getDeviceId() as String {
        return mDeviceId;
    }

    // 获取当前激活状态
    function isActivated() as Boolean {
        return mIsActivated;
    }

    // 手动设置/更新激活状态（由后台通信服务完成验证后回调更新）
    function setActivationStatus(activated as Boolean, verifiedCode as String) as Void {
        var userCode = "";
        try {
            var val = Properties.getValue("licenseKey");
            if (val != null && val instanceof String) {
                userCode = _trim(val as String);
            }
        } catch (ex) {}
        // Ignore responses for a code replaced while the request was pending.
        if (!verifiedCode.equals(userCode)) { return; }
        mIsActivated = activated;
        _saveActivationStatus(activated, userCode);
    }

    // 获取当前是否已过期
    function isExpired() as Boolean {
        return mIsExpired;
    }

    // 重新验证授权码（设置变更或显式校验时调用）
    function revalidate() as Void {
        mIsActivated = _loadSavedActivationStatus();
        verifyOnline();
    }

    // 发起在线 API 校验
    function verifyOnline() as Void {
        var userCode = "";
        try {
            var val = Properties.getValue("licenseKey");
            if (val != null && val instanceof String) {
                userCode = _trim(val as String);
            }
        } catch (ex) {
            return;
        }

        if (userCode.equals("")) {
            mIsActivated = false;
            mIsExpired = false;
            _saveActivationStatus(false, "");
            try {
                WatchUi.requestUpdate();
            } catch (ex) {}
            return;
        }

        // 注意：Garmin Watch Face 前台环境无法使用 Toybox.Communications 模块。
        // 在线 HTTP 校验由 GarminMoreInfoApp 中的 BkgServiceDelegate 后台服务统一处理。
    }

    // 获取设备唯一标识
    private function _loadDeviceId() as String {
        var settings = System.getDeviceSettings();
        if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
            return settings.uniqueIdentifier as String;
        }
        return "";
    }

    // 将设备ID同步到 App Settings
    private function _syncDeviceIdToSettings() as Void {
        if (!mDeviceId.equals("")) {
            try {
                Properties.setValue("deviceId", mDeviceId);
            } catch (ex) {}
        }
    }

    // 加载已保存的本地激活状态
    private function _loadSavedActivationStatus() as Boolean {
        try {
            if (Storage has :getValue) {
                var savedCode = Storage.getValue(STORAGE_KEY_LAST_CODE);
                var isAct = Storage.getValue(STORAGE_KEY_ACTIVATED);

                var currentCode = "";
                var val = Properties.getValue("licenseKey");
                if (val != null && val instanceof String) {
                    currentCode = _trim(val as String);
                }

                // 当前输入的激活码与上次激活成功保存的激活码相匹配
                if (isAct == true && savedCode != null && savedCode.equals(currentCode) && !currentCode.equals("")) {
                    return true;
                }
            }
        } catch (ex) {}
        return false;
    }

    // 持久化保存本地激活状态
    private function _saveActivationStatus(activated as Boolean, code as String) as Void {
        try {
            if (Storage has :setValue) {
                Storage.setValue(STORAGE_KEY_ACTIVATED, activated);
                Storage.setValue(STORAGE_KEY_LAST_CODE, code);
            }
        } catch (ex) {}
    }

    // 清理字符串前后空白字符
    private function _trim(str as String) as String {
        var start = 0;
        var end = str.length();
        while (start < end && (str.substring(start, start + 1).equals(" ") || str.substring(start, start + 1).equals("\n") || str.substring(start, start + 1).equals("\r") || str.substring(start, start + 1).equals("\t"))) {
            start++;
        }
        while (end > start && (str.substring(end - 1, end).equals(" ") || str.substring(end - 1, end).equals("\n") || str.substring(end - 1, end).equals("\r") || str.substring(end - 1, end).equals("\t"))) {
            end--;
        }
        return str.substring(start, end);
    }
}
