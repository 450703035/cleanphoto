import SwiftUI
import Photos

/// Single source of truth for the photo asset list.
///
/// Both `ScanViewModel` and `LibraryViewModel` write their scored asset lists here
/// via `setAssets(_:)`.  All physical deletions go through `deleteAssets(_:)`, which:
///   1. Removes the photos from the system library
///   2. Prunes the store's canonical list
///   3. Scrubs scores from the database and logs the deletion
///   4. Publishes `lastDeletedIds` so every subscriber can clean up its own state
///
/// This eliminates the stale-data problem that occurred when one tab deleted photos
/// and the other tab's ViewModel still held the old asset array.
@MainActor
final class PhotoStore: ObservableObject {

    static let shared = PhotoStore()

    /// Canonical, up-to-date list of all photo assets.
    @Published private(set) var allAssets: [PhotoAsset] = []

    /// Local identifiers removed in the most-recent deletion event.
    /// ScanViewModel and LibraryViewModel observe this to prune their derived arrays.
    @Published private(set) var lastDeletedIds: Set<String> = []

    private init() {}

    // MARK: - Write

    /// Replace the full asset list after a scan or initial library load.
    func setAssets(_ assets: [PhotoAsset]) {
        allAssets = assets
    }

    // MARK: - Delete

    /// Physically remove `assets` from the photo library, update the store,
    /// clean the score cache, log the records, then fire `lastDeletedIds`.
    func deleteAssets(_ assets: [PhotoAsset]) async throws {
        guard !assets.isEmpty else { return }
        try await PhotoLibraryService.shared.deleteAssets(assets)
        let ids = Set(assets.map { $0.id })
        allAssets.removeAll { ids.contains($0.id) }
        await DatabaseService.shared.removeScores(for: Array(ids))
        await DatabaseService.shared.saveDeleteRecords(assets)
        await DatabaseService.shared.markAssetsDeleted(Array(ids))
        lastDeletedIds = ids        // triggers all subscriptions
    }
}
