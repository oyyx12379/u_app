# U-App (DND5e 辅助工具)

本项目是一个基于 **Flutter** 的桌面 & 移动端应用，用于跑团（DND5e）过程中的 **蓝牙设备连接、角色卡管理、骰盘投掷** 等功能。  
ESP32-S3 硬件作为外设，APP 通过蓝牙向其传输角色信息和图片。

---

## 🚀 功能概览

- **蓝牙连接**
    - 扫描并连接 ESP32-S3 设备
    - 自动重连、全局保持连接（退出界面不再断开）
    - 数据协议：数值发送 / 图片传输 / 名字传输

- **角色卡管理（Character Builder Wizard）**
    - 支持选择职业、种族、背景（外置 JSON 数据）
    - 属性分配（标准购点 / 标准数组）
    - 自动计算：
        - 种族加值
        - 技能熟练项（来自职业/种族/背景）
        - 关键战斗数值（HP、DC、PP、FT）
    - 一键发送角色数值到 ESP32

- **骰盘（Dice Page）**
    - 支持 D4 / D6 / D8 / D10 / D12 / D20
    - 可自由添加骰子、Roll、Clear、保存历史
    - 显示公式与结果（如 `2d4+1d8 = 2+2+6 = 10`）


---

## 📂 项目结构

lib/
├── main.dart # 入口，包含底部导航

├── scan_screen.dart # 蓝牙扫描与连接界面

├── esp32_device_screen.dart # 蓝牙设备交互界面

├── dice_page.dart # 骰盘界面

├── character_builder_wizard.dart # 角色卡向导（核心页面）

├── ble/

│ └── ble_session.dart # BLE 全局会话封装（连接、写入、订阅）

├── data/

│ ├── srd_models.dart # 数据模型（ClassData/RaceData/BackgroundData）

│ ├── srd_repository.dart # 从 JSON 加载 SRD 数据

│ └── srd_json/ # 外置的官方 SRD 数据（职业/种族/背景）


---

## 🔗 蓝牙通信协议

APP ↔ ESP32 之间的数据包采用自定义格式：

### 1. 数值传输
[0x01, type, high, low, 0x00]

- `type`：数值类别 (例：0x07 = 当前HP, 0x14 = DC)
- `high/low`：数值的高低字节
- 示例：`0x01 0x07 0x00 0x64 0x00` → 设置 HP=100
- （末位0x00在DM端是对图标状态的改动位，例如专注状态0和1，会发送专注状态的type=0x03，末位0x00或0x01，因为APP端暂时没有状态改动的需求，所以暂时为0x00，具体可以看DM端关于蓝牙接收部分的代码）

### 2. 批量传输（角色关键数据）
[0x02, type1, high1, low1, 0x00,type2, high2, low2, 0x00, ...] 

- 顺序：最大HP → 当前HP → DC → PP → FT → 临时HP

### 3. 名字传输
[0x03, ascii bytes...]
- 只支持英文字符
- 用于显示角色名字

---

## 🧱 主要类/组件

- `BleSession`  
  封装蓝牙会话（connectAndBind、sendStat、writeRaw）

- `CharacterBuilderWizardPage`
    - Step0：选择职业/种族/背景
    - Step1：背景人格特质选择
    - Step2：属性分配（购点 / 数组）
    - Step3：汇总 + 一键发送

- `DicePage`  
  动态骰盘，可添加骰子、Roll 结果、保存历史

---

## 🛠️ 扩展方法

1. **扩展职业/种族/背景**
    - 在 `lib/data/srd_json/` 添加/修改 JSON 文件
    - 格式包含：`id`, `name`, `traits`, `ability_bonuses`, `features` 等字段
    - `SrdRepository` 会自动加载

2. **扩展蓝牙指令**
    - 在 `ble_session.dart` 中新增 `sendXXX` 方法
    - 在 ESP32 固件里对应解析

3. **适配更多 UI**
    - 小屏手机布局已做 `LayoutBuilder` 自适应
    - 可以继续在 `character_builder_wizard.dart` 中优化 Wrap/Grid

---

## 📌 注意事项

- **角色名字**：发送到 ESP32 时仅支持英文（避免中文编码错误）。
- **蓝牙保持连接**：不要在页面 `dispose` 时调用 `disconnect()`，让连接贯穿整个应用。
- **图片格式**：推荐 PNG（发送前转为字节流）。

---

## 📷 运行效果

- 角色卡构建：可选职业/种族/背景 → 自动计算 → 一键发送
- 骰盘：点击骰子 → Roll → 显示公式与结果
- 蓝牙：连接 ESP32-S3 → 同步数值 → TFT 显示角色数据与图片
