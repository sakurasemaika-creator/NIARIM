package com.niarim.niarim

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Copies a file opened from another app into the app's cache a chunk at a time, so neither side
 * holds the whole file in memory: Dart reads the work from the copy and then deletes it.
 */
internal object SharedFileIntake {
    /** The file is larger than the caller accepts. */
    class TooLargeException : Exception()

    /** The device lacks [missingBytes] of free space for the copy and the work saved from it. */
    class NoSpaceException(val missingBytes: Long) : Exception()

    private const val CHUNK_BYTES = 256 * 1024

    /** Checks the free space again after this much has been copied (the size may be unknown). */
    private const val SPACE_CHECK_BYTES = 16L * 1024 * 1024

    /** Left free beyond the copy and the work imported from it. */
    private const val RESERVE_BYTES = 32L * 1024 * 1024

    /**
     * Copies [uri] to [target] (inside the app's cache) and returns the number of bytes written. A
     * file over [maxBytes], or one the free space cannot hold twice (the copy and the work saved
     * from it), is refused before it is read when its size is known and as soon as the copy shows
     * it otherwise. A refused or failed copy leaves nothing behind.
     */
    fun copy(context: Context, uri: Uri, target: File, maxBytes: Long): Long {
        if (uri.scheme != "content" && uri.scheme != "file") {
            throw IllegalArgumentException("unsupported URI scheme")
        }
        val cacheRoot = context.cacheDir.canonicalFile.path + File.separator
        val file = target.canonicalFile
        if (!file.path.startsWith(cacheRoot)) {
            throw IllegalArgumentException("the copy must stay inside the app cache")
        }
        val folder = file.parentFile ?: throw IllegalArgumentException("no folder for the copy")
        val declared = declaredSize(context, uri)
        if (declared != null && declared > maxBytes) throw TooLargeException()
        folder.mkdirs()
        if (declared != null) requireSpace(folder, declared, alreadyCopied = 0)
        var total = 0L
        var writing = false
        try {
            val input =
                context.contentResolver.openInputStream(uri)
                    ?: throw IOException("input stream unavailable")
            input.use { source ->
                FileOutputStream(file).use { output ->
                    val buffer = ByteArray(CHUNK_BYTES)
                    var nextSpaceCheck = SPACE_CHECK_BYTES
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > maxBytes) throw TooLargeException()
                        writing = true
                        output.write(buffer, 0, read)
                        writing = false
                        if (total >= nextSpaceCheck) {
                            requireSpace(folder, maxOf(declared ?: 0L, total), total)
                            nextSpaceCheck = total + SPACE_CHECK_BYTES
                        }
                    }
                }
            }
            return total
        } catch (error: Exception) {
            // A write that failed with the storage full (another app filled it while copying).
            val full = writing && error is IOException && folder.usableSpace < RESERVE_BYTES
            file.delete()
            if (full) {
                val missing = missingFor(folder, maxOf(declared ?: 0L, total), 0)
                throw NoSpaceException(maxOf(missing, CHUNK_BYTES.toLong()))
            }
            throw error
        }
    }

    /** The size the provider reports for [uri], or null when it does not know it. */
    private fun declaredSize(context: Context, uri: Uri): Long? {
        if (uri.scheme == "file") {
            val path = uri.path ?: return null
            val file = File(path)
            return if (file.isFile) file.length() else null
        }
        return try {
            context.contentResolver
                .query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) {
                        cursor.getLong(0).takeIf { it >= 0 }
                    } else {
                        null
                    }
                }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Throws [NoSpaceException] unless [folder] has room for the rest of a [size]-byte copy (of
     * which [alreadyCopied] bytes are written) and for the work saved from it.
     */
    private fun requireSpace(folder: File, size: Long, alreadyCopied: Long) {
        val missing = missingFor(folder, size, alreadyCopied)
        if (missing > 0) throw NoSpaceException(missing)
    }

    private fun missingFor(folder: File, size: Long, alreadyCopied: Long): Long {
        val needed = (size - alreadyCopied) + size + RESERVE_BYTES
        return needed - folder.usableSpace
    }
}
