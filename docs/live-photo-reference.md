# 各品牌动态照片 SDK / 识别方案参考

> 用于 RePhoto 项目的跨厂商 Live Photo / Motion Photo 识别

---

## 小米 (Xiaomi)

| 项目 | 内容 |
|---|---|
| 文档地址 | https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2003 |
| SDK | `com.xiaomi.camera:livephoto:1.0.3`（需申请账号） |
| 识别方式 | 查 MediaStore `XMP` 列含 `MicroVideo` / `MotionPhoto` 关键字 |
| 视频提取 | 单文件内嵌 MP4，`MiLivePhotoInfo.videoOffset` 指定偏移 |
| 备注 | SDK 需审核通过后获取 maven 账号密码 |

### 无需 SDK 的实现要点

```kotlin
// 检测：查 XMP 列
contentResolver.query(uri, arrayOf(MediaStore.Images.Media.XMP), null, null, null)
// 判断 xmp.contains("MicroVideo") || xmp.contains("MotionPhoto")
```

```java
// 批量查询所有动图（官方示例）
String selection = MediaStore.Images.Media.MIME_TYPE + " IN (?, ?) AND (" +
    MediaStore.Images.Media.XMP + " LIKE ? OR " +
    MediaStore.Images.Media.XMP + " LIKE ?)";
String[] selectionArgs = {"image/jpeg", "image/heic", "%MicroVideo%", "%MotionPhoto%"};
```

---

## 华为 (Huawei)

| 项目 | 内容 |
|---|---|
| 文档地址 | 待补充 |
| SDK | 待补充 |
| 识别方式 | 待补充 |
| 备注 | 待补充 |

---

## OPPO

| 项目 | 内容 |
|---|---|
| 文档地址 | 待补充 |
| SDK | 待补充 |
| 识别方式 | 待补充 |
| 备注 | 待补充 |

---

## vivo

| 项目 | 内容 |
|---|---|
| 文档地址 | 待补充 |
| SDK | 待补充 |
| 识别方式 | 待补充 |
| 备注 | 待补充 |

---

## 荣耀 (Honor)

| 项目 | 内容 |
|---|---|
| 文档地址 | 待补充 |
| SDK | 待补充 |
| 识别方式 | 待补充 |
| 备注 | 待补充 |

---

## 三星 (Samsung)

| 项目 | 内容 |
|---|---|
| 文档地址 | 待补充 |
| SDK | 待补充 |
| 识别方式 | 待补充 |
| 备注 | 待补充 |

---

## Google Pixel

| 项目 | 内容 |
|---|---|
| 识别方式 | Android 12+ `MediaStore.IS_MOTION_PHOTO` 列；XMP `<MotionPhoto>1</MotionPhoto>` |
| 视频提取 | JPEG 末尾嵌入 MP4（`ftyp` box 标记） |
| 备注 | 原生 Android API，无额外 SDK |

---

## Apple (iPhone)

| 项目 | 内容 |
|---|---|
| 识别方式 | `PHAsset.mediaSubtypes.contains(.photoLive)` / `photo_manager.isLivePhoto` |
| 视频提取 | `PHAssetResourceType.pairedVideo` / `photo_manager.getMediaUrl()` |
| 备注 | `photo_manager` 已封装，无需额外 SDK |

---

## 通用兜底方案

| 方案 | 说明 |
|---|---|
| JPEG 尾部 MP4 检测 | 搜 `FFD9`(JPEG 结束) 之后或 `ftyp`(MP4 开头) 的数据 |
| 配对同名文件 | JPEG 同目录找同名 `.mp4`，验证 `DATE_TAKEN` 时间差 ≤ 1s |
| 文件大小 | 动图文件通常 > 3MB（不可靠，仅辅助） |

---

## 当前 RePhoto 实现状态

| 品牌 | 检测 | 视频播放 | 备注 |
|---|---|---|---|
| Apple | ✅ `isLivePhoto` | ✅ `getMediaUrl` | photo_manager 原生支持 |
| 小米 | ✅ XMP 列 | 🟡 内嵌 MP4 提取中 | 检测已通，播放调试中 |
| Google Pixel | 🟡 IS_MOTION_PHOTO + 内嵌 MP4 | — | 部分兼容 |
| 华为 | ❌ | ❌ | 待适配 |
| OPPO/vivo/荣耀 | ❌ | ❌ | 待适配 |
