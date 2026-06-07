package com.rephoto.rephoto

import android.content.ContentUris
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rephoto.rephoto/motion_photo"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMotionPhoto" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    val results = mutableMapOf<String, Boolean>()
                    for (id in ids) results[id] = isMotionPhoto(id)
                    result.success(results)
                }
                "extractMotionVideo" -> {
                    val id = call.argument<String>("id") ?: ""
                    val path = extractMotionVideo(id)
                    if (path != null) result.success(path)
                    else result.error("EXTRACT_FAILED", "无法提取动图视频", null)
                }
                "debugCheck" -> {
                    val id = call.argument<String>("id") ?: ""
                    result.success(debugCheck(id))
                }
                "scanMotionPhotos" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    result.success(scanMotionPhotos(ids))
                }
                else -> result.notImplemented()
            }
        }
    }

    // ═══════════════════════════════════
    //  核心逻辑
    // ═══════════════════════════════════

    private fun contentUriFor(id: String): Uri? {
        val longId = id.toLongOrNull() ?: return null
        return ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, longId)
    }

    /** 查找配对 MP4 的 Content URI（可靠检测：同目录+同名+同拍摄时间+MIME验证） */
    private fun findPairedVideoUri(id: String): String? {
        val uri = contentUriFor(id) ?: return null
        contentResolver.query(uri, arrayOf(
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DATE_TAKEN,
        ), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val jpgPath = c.getString(0) ?: return null
                val jpgTaken = c.getLong(1)

                // 只检查相机目录
                val jpgDir = jpgPath.lowercase()
                if (!jpgDir.contains("/dcim/camera") && !jpgDir.contains("/camera/")) return null

                val mp4Path = jpgPath.replace(Regex("\\.(jpg|jpeg|heic|heif)$", RegexOption.IGNORE_CASE), ".mp4")
                val mp4File = File(mp4Path)
                if (!mp4File.exists()) return null

                // 查出 MP4 在 MediaStore 中的完整信息（URI + DATE_TAKEN + MIME）
                val mp4Info = getVideoInfo(mp4Path) ?: return null
                val (mp4Uri, mp4Taken, mp4Mime) = mp4Info

                // 必须注册为视频类型
                if (mp4Mime == null || !mp4Mime.startsWith("video/")) return null

                // 拍摄时间差 ≤ 1 秒才是动图配对
                if (kotlin.math.abs(jpgTaken - mp4Taken) > 1000) return null

                return mp4Uri.toString()
            }
        }
        return null
    }

    /** 返回 (Uri, DATE_TAKEN, MIME_TYPE)，查不到返回 null */
    private fun getVideoInfo(path: String): Triple<Uri, Long, String?>? {
        contentResolver.query(
            MediaStore.Files.getContentUri("external"),
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DATE_TAKEN, MediaStore.MediaColumns.MIME_TYPE),
            "${MediaStore.MediaColumns.DATA} = ?",
            arrayOf(path),
            null
        )?.use { c ->
            if (c.moveToFirst()) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Files.getContentUri("external"), c.getLong(0))
                val taken = c.getLong(1)
                val mime = c.getString(2)
                return Triple(uri, taken, mime)
            }
        }
        return null
    }

    /** 检测是否为动图：XMP 列(小米官方方案) → 配对 MP4 */
    private fun isMotionPhoto(id: String): Boolean {
        val uri = contentUriFor(id) ?: return false

        // 1. 查路径：非相机目录直接排除（DATA 为 null 时跳过此检查）
        val jpgPath = getDataColumn(uri)
        if (jpgPath != null) {
            val jpgDir = jpgPath.lowercase()
            if (!jpgDir.contains("/dcim/camera") && !jpgDir.contains("/camera/")) return false
        }

        // 2. 小米官方方案：查 XMP 列是否含 MicroVideo / MotionPhoto
        try {
            contentResolver.query(uri, arrayOf(MediaStore.Images.Media.XMP), null, null, null)?.use {
                if (it.moveToFirst()) {
                    val xmp = readXmpColumn(it, 0)
                    if (xmp != null && (xmp.contains("MicroVideo") || xmp.contains("MotionPhoto"))) return true
                }
            }
        } catch (_: Exception) {}

        // 3. 兜底：配对 MP4
        return findPairedVideoUri(id) != null
    }

    /** 安全读取 XMP 列（小米存为 BLOB，先 getBlob 再转 UTF-8） */
    private fun readXmpColumn(cursor: android.database.Cursor, index: Int): String? {
        return try {
            val blob = cursor.getBlob(index)
            if (blob != null) String(blob, Charsets.UTF_8) else cursor.getString(index)
        } catch (_: Exception) {
            null
        }
    }

    /** 从 Content URI 读取 SIZE 列（文件大小） */
    private fun getFileSize(uri: Uri): Long {
        contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.SIZE), null, null, null)?.use {
            if (it.moveToFirst()) return it.getLong(0)
        }
        return 0
    }

    /** 从 Content URI 读取 DATA 列（文件路径） */
    private fun getDataColumn(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0)
        }
        return null
    }

    /** 提取动图视频：配对 MP4 → ftyp 搜索 → videoOffset 兜底 */
    private fun extractMotionVideo(id: String): String? {
        val paired = findPairedVideoUri(id)
        if (paired != null) return paired

        val uri = contentUriFor(id) ?: return null
        return try {
            val fileSize = getFileSize(uri)
            if (fileSize <= 0) return null

            val ftypResult = extractEmbeddedMp4(uri, fileSize)
            if (ftypResult != null) return ftypResult

            val videoOffset = getVideoOffsetFromXmp(uri)
            if (videoOffset != null && videoOffset > 0 && videoOffset < fileSize) {
                val startPos = fileSize - videoOffset
                val tempFile = File(cacheDir, "motion_${id}.mp4")
                contentResolver.openInputStream(uri)?.use { stream ->
                    stream.skip(startPos)
                    stream.copyTo(tempFile.outputStream())
                }
                if (tempFile.length() > 512) return tempFile.absolutePath
            }
            null
        } catch (_: Exception) { null }
    }

    /** 从 MediaStore XMP 列或文件头解析 videoOffset */
    private fun getVideoOffsetFromXmp(uri: Uri): Long? {
        // 先从 MediaStore 读 XMP
        val xmp = try {
            contentResolver.query(uri, arrayOf(MediaStore.Images.Media.XMP), null, null, null)?.use {
                if (it.moveToFirst()) readXmpColumn(it, 0) else null
            }
        } catch (_: Exception) { null }

        if (xmp != null) {
            return parseVideoOffset(xmp)
        }

        // MediaStore 没有 → 读文件头部 XMP（前 64KB）
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                val head = ByteArray(65536)
                val read = stream.read(head)
                if (read > 0) {
                    val xmpStr = String(head, 0, read, Charsets.UTF_8)
                    parseVideoOffset(xmpStr)
                } else null
            }
        } catch (_: Exception) { null }
    }

    /** 从 XMP 字符串中解析 videoOffset（单位：字节） */
    private fun parseVideoOffset(xmp: String): Long? {
        // 小米/Google Motion Photo: Item:Length where Item:Semantic="MotionPhoto"
        val itemLengthPattern = Regex("""Item:Length="(\d+)"""")
        val semPattern = Regex("""Item:Semantic="MotionPhoto"""")
        val semIndex = semPattern.find(xmp)?.range?.last ?: -1
        if (semIndex >= 0) {
            val lengthMatch = itemLengthPattern.find(xmp, semIndex)
            if (lengthMatch != null) return lengthMatch.groupValues[1].toLongOrNull()
        }
        val offsetPattern = Regex("""(\w+)?[Oo]ffset[="\s]+(\d+)""")
        val match = offsetPattern.find(xmp)
        if (match != null) return match.groupValues[2].toLongOrNull()
        return null
    }

    /** 兜底：从 JPEG 文件尾部搜 ftyp 提取 MP4 */
    private fun extractEmbeddedMp4(uri: Uri, fileSize: Long): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                // 只读最后 1MB 找到 ftyp（动图视频通常在文件尾）
                val tailSize = minOf(fileSize, 1_048_576L).toInt()
                stream.skip(fileSize - tailSize)
                val tail = ByteArray(tailSize)
                var offset = 0
                while (offset < tail.size) {
                    val n = stream.read(tail, offset, tail.size - offset)
                    if (n == -1) break
                    offset += n
                }
                val mp4Start = findFtypInBytes(tail)
                if (mp4Start == -1) return null
                // mp4Start 是相对于 tail 的偏移，实际在文件中的位置是 fileSize - tailSize + mp4Start
                val tempFile = File(cacheDir, "motion_${uri.lastPathSegment}.mp4")
                // 重新打开流读取完整 MP4
                contentResolver.openInputStream(uri)?.use { stream2 ->
                    stream2.skip(fileSize - tailSize + mp4Start)
                    stream2.copyTo(tempFile.outputStream())
                }
                if (tempFile.length() > 512) tempFile.absolutePath else null
            }
        } catch (_: Exception) { null }
    }

    private fun findFtypInBytes(bytes: ByteArray): Int {
        for (i in 0 until bytes.size - 8) {
            if (bytes[i] == 'f'.code.toByte() && bytes[i+1] == 't'.code.toByte() &&
                bytes[i+2] == 'y'.code.toByte() && bytes[i+3] == 'p'.code.toByte()) {
                return (i - 4).coerceAtLeast(0)
            }
        }
        return -1
    }

    // ═══════════════════════════════════
    //  批量扫描（从 MediaStore 直接查所有动图，不走文件）
    // ═══════════════════════════════════

    /** 从给定 ID 列表中筛选出所有动图 */
    private fun scanMotionPhotos(ids: List<String>): List<String> {
        val result = mutableListOf<String>()
        for (id in ids) {
            if (isMotionPhoto(id)) result.add(id)
        }
        return result
    }

    // ═══════════════════════════════════
    //  诊断
    // ═══════════════════════════════════

    private fun debugCheck(id: String): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        map["buildVersion"] = "v3-trycatch"  // ← 验证 APK 版本
        map["id"] = id
        val longId = id.toLongOrNull()
        map["longId"] = longId
        if (longId == null) { map["error"] = "not a Long"; return map }

        val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, longId)
        map["uri"] = uri.toString()

        // IS_MOTION_PHOTO
        if (Build.VERSION.SDK_INT >= 31) {
            try {
                contentResolver.query(uri, arrayOf("is_motion_photo"), null, null, null)?.use {
                    if (it.moveToFirst()) map["is_motion_photo"] = it.getInt(0)
                }
            } catch (e: Exception) {
                map["is_motion_photo_error"] = e.message
            }
        } else { map["is_motion_photo"] = "N/A (API<31)" }

        // XMP 列
        try {
            contentResolver.query(uri, arrayOf(MediaStore.Images.Media.XMP), null, null, null)?.use {
                if (it.moveToFirst()) {
                    val xmp = readXmpColumn(it, 0)
                    if (xmp != null) {
                        map["xmpLength"] = xmp.length
                        map["xmpPreview"] = if (xmp.length > 200) xmp.take(200) + "..." else xmp
                        map["xmpHasMicroVideo"] = xmp.contains("MicroVideo")
                        map["xmpHasMotionPhoto"] = xmp.contains("MotionPhoto")
                    }
                }
            }
        } catch (e: Exception) {
            map["xmpError"] = e.message
        }

        // 文件信息
        contentResolver.query(uri, arrayOf(
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DISPLAY_NAME,
        ), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                map["fileSize"] = c.getLong(0)
                map["dataPath"] = c.getString(1)
                map["displayName"] = c.getString(2)
            }
        }

        // 配对文件
        val pairedUri = findPairedVideoUri(id)
        map["pairedMp4Uri"] = pairedUri

        // 解析 videoOffset
        try {
            val vo = getVideoOffsetFromXmp(uri)
            map["videoOffset"] = vo
        } catch (e: Exception) {
            map["videoOffsetError"] = e.message
        }

        map["sdkInt"] = Build.VERSION.SDK_INT
        map["device"] = "${Build.MANUFACTURER} ${Build.MODEL}"
        return map
    }
}
