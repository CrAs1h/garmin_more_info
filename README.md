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

## ORBIT DATA 表盘

当前表盘采用面向小圆屏的 ORBIT DATA 设计：

- OLED 黑色背景、醒目的大号时间和高对比酸性绿色数据
- 外圈以粗进度轨道显示手表电量
- 下方四个数据槽可以由用户分别配置
- 每个槽均可选择步数、心率、身体电量、手表电量、卡路里或距离
- 布局按屏幕短边缩放，覆盖 208×208 至 454×454 的圆形屏幕
- `manifest.xml` 仅保留 Garmin SDK 标记为 `round` 的设备，矩形与 `semi-octagon` 异形屏已移除

四个数据槽可在 Garmin Connect / Connect IQ 的表盘设置中修改。身体电量在不提供该字段的旧设备上显示 `--`，不会影响其他数据。

设计参考稿位于 `design/orbit-data-concept-v2-small-screen.png`。

## 构建

```powershell
.\scripts\Export-Device.ps1 -deviceId vivoactive5
```

验证全部圆形设备：

```powershell
.\scripts\Test-AllDevices.ps1 -Mode build -NoDedup
```

应用已使用独立 Connect IQ ID，不会覆盖 `garmin_flower`。
