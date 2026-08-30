# Garmin More Info

基于 `garmin_flower` 项目骨架初始化的 Connect IQ 表盘项目。

## 保留的能力

- 前台表盘与后台服务架构
- 设备 ID 展示和激活码设置
- 在线激活校验与本地激活状态缓存
- 单设备导出、商店包导出和批量设备测试脚本

## 主要入口

- `source/GarminMoreInfoApp.mc`：应用生命周期和后台激活校验
- `source/GarminMoreInfoView.mc`：表盘内容与样式，可在这里重新设计
- `source/LicenseManager.mc`：激活状态管理
- `resources/settings/`：设备 ID 与激活码设置项
- `monkey.jungle`：最小项目路径配置

当前视图为无图片、无自定义字体的最小 DEMO，只在黑色背景中央显示系统时间。

## 构建

```powershell
.\scripts\Export-Device.ps1 -deviceId vivoactive5
```

应用已使用独立 Connect IQ ID，不会覆盖 `garmin_flower`。
