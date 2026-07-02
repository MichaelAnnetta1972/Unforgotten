import Foundation
import Supabase

/// Resolves a stored photo reference (path or legacy URL) into a usable image URL.
///
/// During the public→private bucket migration there are two formats in the DB:
///   - Path (new):  "profiles/<uuid>/photo.jpg"
///   - URL  (legacy): "https://...supabase.co/storage/v1/object/public/<bucket>/<path>?t=..."
///
/// New code stores paths only. This service generates short-lived signed URLs
/// for paths and passes legacy URLs through unchanged. Once the URL→path
/// migration runs (Phase 4), the legacy branch will see no traffic.
final class SignedImageURLService {
    static let shared = SignedImageURLService()

    private let supabase = SupabaseManager.shared.client
    private let signedURLLifetime: Int = 3600
    private let cacheLifetime: TimeInterval = 50 * 60

    private struct CachedURL {
        let url: URL
        let expiresAt: Date
    }

    private var cache: [String: CachedURL] = [:]
    private let cacheQueue = DispatchQueue(label: "com.unforgotten.signedurl.cache", attributes: .concurrent)

    private init() {}

    /// Resolves a stored photo reference into a URL ready for display.
    /// Returns nil if the reference is empty or can't be resolved.
    func resolveURL(reference: String?) async -> URL? {
        guard let reference, !reference.isEmpty else { return nil }

        if reference.hasPrefix("http") {
            return URL(string: reference)
        }

        guard let bucket = bucketForPath(reference) else {
            #if DEBUG
            print("⚠️ SignedImageURLService: cannot infer bucket for path: \(reference)")
            #endif
            return nil
        }

        return await signedURL(bucket: bucket, path: reference)
    }

    /// Generates (or returns cached) signed URL for a known bucket+path pair.
    func signedURL(bucket: String, path: String) async -> URL? {
        let cacheKey = "\(bucket)|\(path)"

        if let cached = readCache(cacheKey), cached.expiresAt > Date() {
            return cached.url
        }

        do {
            let url = try await supabase.storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: signedURLLifetime)
            writeCache(cacheKey, url: url)
            return url
        } catch {
            #if DEBUG
            print("⚠️ SignedImageURLService: createSignedURL failed for \(bucket)/\(path): \(error)")
            #endif
            return nil
        }
    }

    /// Drops a cache entry — call after re-uploading to the same path so the
    /// next display generates a fresh URL (which the storage backend may already
    /// be returning, but this avoids stale caching surprises).
    func invalidate(bucket: String, path: String) {
        let cacheKey = "\(bucket)|\(path)"
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: cacheKey)
        }
    }

    /// Clears the entire cache. Call on sign-out.
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    // MARK: - Bucket inference

    /// Maps a stored path's first segment to its bucket name.
    /// Path layout convention: <subfolder>/<parent_record_uuid>/photo.jpg
    private func bucketForPath(_ path: String) -> String? {
        guard let firstSegment = path.split(separator: "/").first else { return nil }
        switch firstSegment {
        case "profiles": return SupabaseConfig.profilePhotosBucket
        case "medications": return SupabaseConfig.medicationPhotosBucket
        case "appointments": return SupabaseConfig.appointmentPhotosBucket
        case "countdowns": return SupabaseConfig.countdownPhotosBucket
        case "recipes": return SupabaseConfig.recipePhotosBucket
        case "accounts": return SupabaseConfig.accountPhotosBucket
        case "useful-contacts": return SupabaseConfig.usefulContactPhotosBucket
        default: return nil
        }
    }

    // MARK: - Cache access

    private func readCache(_ key: String) -> CachedURL? {
        cacheQueue.sync { cache[key] }
    }

    private func writeCache(_ key: String, url: URL) {
        let entry = CachedURL(url: url, expiresAt: Date().addingTimeInterval(cacheLifetime))
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = entry
        }
    }
}
