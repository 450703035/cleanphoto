import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVKit
import AVFoundation
import UIKit

// MARK: - Duplicates
struct DuplicatesView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var groups: [PhotoGroup]
    @State private var done = false
    @State private var deleting = false
    @State private var mergingGroupIDs: Set<UUID> = []
    @State private var viewerRequest: DuplicateViewerRequest? = nil
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    var deletableCount: Int { groups.reduce(0) { $0 + $1.assets.dropFirst().count } }
    var deletableSize: Int64 { groups.flatMap { $0.assets.dropFirst() }.reduce(0) { $0 + $1.sizeBytes } }

    init(groups: [PhotoGroup], vm: ScanViewModel) {
        self.vm = vm
        _groups = State(initialValue: groups)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: deletableCount, label: L10n.dupLabel(deletableCount)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: L10n.duplicateAndSimilarTitle,
                                    subtitle: L10n.groups(groups.count),
                                    onBack: { dismiss() })
                    if showBanner {
                        InfoBanner(text: L10n.cancelMergeHint, color: AppColors.amber)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: BannerScrollOffsetKey.self,
                                    value: geo.frame(in: .named("dupScroll")).minY)
                            })
                        LazyVStack(spacing: 16) {
                            ForEach(groups) { group in
                                SwipeCancelMergeGroupCard(onCancel: { cancelGroup(group.id) }) {
                                    DuplicateGroupCard(
                                        group: group,
                                        isMerging: mergingGroupIDs.contains(group.id),
                                        onMerge: { merge(group) },
                                        onPhotoTap: { photoIndex in
                                            viewerRequest = DuplicateViewerRequest(groupID: group.id, startIndex: photoIndex)
                                        },
                                        onPromoteBest: { assetID in
                                            promoteAsset(assetID, in: group.id)
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: "dupScroll")
                    .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                        guard showBanner, offset < -10 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBanner = false
                        }
                    }
                    .simultaneousGesture(bannerHideGesture)
                }
                .background(AppColors.darkBG)

                if deletableCount > 0 {
                    BottomDeleteBar(
                        count: deletableCount,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: deletableSize, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            do {
                                try await vm.deleteGroups(groups)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.setDetailInteraction(true) }
        .onDisappear { vm.setDetailInteraction(false) }
        .overlay((deleting || !mergingGroupIDs.isEmpty) ? ProgressView(L10n.processing).padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            if let binding = bindingForGroupAssets(groupID: request.groupID) {
                FullScreenPhotoViewer(assets: binding, startIndex: request.startIndex)
            }
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }

    private func merge(_ group: PhotoGroup) {
        guard !mergingGroupIDs.contains(group.id), group.assets.count > 1 else { return }
        mergingGroupIDs.insert(group.id)
        Task {
            do {
                try await vm.deleteGroups([group])
                await MainActor.run {
                    groups.removeAll { $0.id == group.id }
                    mergingGroupIDs.remove(group.id)
                    if groups.isEmpty { done = true }
                }
            } catch {
                await MainActor.run {
                    mergingGroupIDs.remove(group.id)
                }
            }
        }
    }

    private func cancelGroup(_ groupID: UUID) {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let removedGroup = groups.remove(at: gIdx)

        for asset in removedGroup.assets where !asset.asset.isFavorite {
            if !vm.behaviorAssets.contains(where: { $0.id == asset.id }) {
                var behaviorItem = asset
                behaviorItem.isSelected = false
                vm.behaviorAssets.append(behaviorItem)
            }
        }
        vm.behaviorAssets.sort { $0.creationDate < $1.creationDate }
        vm.duplicateGroups = groups.filter { $0.groupType == .duplicate }
        vm.similarGroups = groups.filter { $0.groupType == .similar }
        if groups.isEmpty { done = true }
    }

    private func promoteAsset(_ assetID: String, in groupID: UUID) {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard let aIdx = groups[gIdx].assets.firstIndex(where: { $0.id == assetID }) else { return }
        guard aIdx > 0 else { return }
        let picked = groups[gIdx].assets.remove(at: aIdx)
        groups[gIdx].assets.insert(picked, at: 0)
    }

    private func bindingForGroupAssets(groupID: UUID) -> Binding<[PhotoAsset]>? {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return nil }
        return Binding<[PhotoAsset]>(
            get: { groups[gIdx].assets },
            set: { groups[gIdx].assets = $0 }
        )
    }
}

struct DuplicateGroupCard: View {
    let group: PhotoGroup
    let isMerging: Bool
    let onMerge: () -> Void
    let onPhotoTap: (Int) -> Void
    let onPromoteBest: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.groupType == .duplicate ? "🔁 \(L10n.duplicate)" : "✨ \(L10n.similar)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: onMerge) {
                    if isMerging {
                        ProgressView().tint(AppColors.purple)
                    } else {
                        Text(L10n.merge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.lightPurple)
                    }
                }
                .disabled(isMerging)
                .frame(width: 52, height: 26)
                .background(AppColors.purple.opacity(0.15))
                .cornerRadius(8)
            }

            // Best large, others small
            HStack(alignment: .top, spacing: 4) {
                // Best photo – 2x height
                ZStack(alignment: .topLeading) {
                    PhotoThumbnail(asset: group.assets[0].asset, size: 160)
                        .frame(width: 160, height: 160)
                        .clipped()
                        .cornerRadius(10)
                        .onTapGesture { onPhotoTap(0) }
                        .onDrop(of: [UTType.text], delegate: BestDropDelegate { droppedID in
                            onPromoteBest(droppedID)
                        })
                    Text("⭐ \(L10n.best)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "7c2d00"))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(AppColors.amber).cornerRadius(5).padding(5)
                    VStack(alignment: .trailing, spacing: 2) {
                        ScoreBadge(score: group.assets[0].score, fontSize: 9)
                        Text(group.assets[0].formattedSize)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
                }

                // Others in 2-col grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(Array(group.assets.dropFirst().enumerated()), id: \.element.id) { offset, asset in
                        ZStack(alignment: .topTrailing) {
                            PhotoThumbnail(asset: asset.asset, size: 76)
                                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fill).clipped()
                                .cornerRadius(8).opacity(0.55)
                                .onTapGesture { onPhotoTap(offset + 1) }
                                .onDrag {
                                    NSItemProvider(object: asset.id as NSString)
                                }
                            Circle().fill(AppColors.purple).frame(width: 14, height: 14)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 7)).foregroundColor(.white))
                                .padding(3)
                            VStack(alignment: .trailing, spacing: 2) {
                                ScoreBadge(score: asset.score, fontSize: 8)
                                Text(asset.formattedSize)
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(3)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(3)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .appleCardStyle()
    }
}

private struct DuplicateViewerRequest: Identifiable {
    let id = UUID()
    let groupID: UUID
    let startIndex: Int
}

private struct SwipeCancelMergeGroupCard<Content: View>: View {
    private let actionWidth: CGFloat = 108
    private let autoTriggerThreshold: CGFloat = 72

    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    @State private var isOpen = false
    @State private var isHorizontalDrag: Bool? = nil

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.red.opacity(0.22))
                .overlay(
                    Text(L10n.cancelMerge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.red)
                        .padding(.trailing, 12),
                    alignment: .trailing
                )

            content()
                .offset(x: offsetX)
                .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.9), value: offsetX)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    // Lock direction on first detection to avoid fighting with ScrollView
                    if isHorizontalDrag == nil {
                        isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                    }
                    guard isHorizontalDrag == true else { return }
                    if value.translation.width < 0 {
                        offsetX = max(-actionWidth, value.translation.width)
                    } else if isOpen {
                        offsetX = min(0, -actionWidth + value.translation.width)
                    }
                }
                .onEnded { value in
                    defer { isHorizontalDrag = nil }
                    guard isHorizontalDrag == true else { return }
                    if value.translation.width <= -autoTriggerThreshold {
                        withAnimation(.easeOut(duration: 0.12)) { offsetX = -actionWidth }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            onCancel()
                            offsetX = 0
                            isOpen = false
                        }
                    } else if value.translation.width <= -actionWidth * 0.4 {
                        offsetX = -actionWidth
                        isOpen = true
                    } else {
                        offsetX = 0
                        isOpen = false
                    }
                }
        )
        .overlay(alignment: .trailing) {
            if isOpen {
                Button(L10n.cancelMerge) {
                    onCancel()
                    offsetX = 0
                    isOpen = false
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.red)
                .frame(width: actionWidth, height: 48)
            }
        }
    }
}

private struct BestDropDelegate: DropDelegate {
    let onDropID: (String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            if let data = item as? Data, let id = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onDropID(id) }
            } else if let text = item as? String {
                DispatchQueue.main.async { onDropID(text) }
            } else if let ns = item as? NSString {
                DispatchQueue.main.async { onDropID(ns as String) }
            }
        }
        return true
    }
}

// MARK: - Screenshots
struct ScreenshotCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filterCategory: ScreenshotCategory? = nil
    @State private var categoryMap: [String: ScreenshotCategory] = [:]
    @State private var classifying = false
    @State private var classifyProgress: Double = 0
    @State private var viewerRequest: ScreenshotViewerRequest? = nil
    @State private var gridColumnCount: Int = AppConfig.screenshotGridColumns
    @State private var done = false
    @State private var doneCount = 0
    @State private var deleting = false
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: gridColumnCount)
    }
    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            guard let c = filterCategory else { return true }
            return categoryMap[assets[idx].id] == c
        }
    }
    private var selectionTargetIndices: [Int] { filteredIndices }
    private var currentFilterTotalCount: Int { selectionTargetIndices.count }
    private var currentFilterRecommendedCount: Int {
        selectionTargetIndices.reduce(0) { partial, idx in
            partial + (assets[idx].score < 45 ? 1 : 0)
        }
    }
    private var selectedInCurrentFilter: [PhotoAsset] {
        selectionTargetIndices.compactMap { idx in
            guard assets.indices.contains(idx), assets[idx].isSelected else { return nil }
            return assets[idx]
        }
    }
    private var isAllSelected: Bool {
        !selectionTargetIndices.isEmpty && selectionTargetIndices.allSatisfy { assets[$0].isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: doneCount, label: L10n.screenshotsDone(doneCount)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.screenshotTitle,
                        subtitle: L10n.screenshotSubtitle(currentFilterTotalCount, currentFilterRecommendedCount),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in selectionTargetIndices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple).font(AppTypography.body)
                        )
                    )

                    if showBanner {
                        InfoBanner(text: L10n.autoSelectedLow, color: AppColors.red)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: L10n.all, isActive: filterCategory == nil) { filterCategory = nil }
                            ForEach(ScreenshotCategory.allCases, id: \.self) { c in
                                FilterChip(label: c.chipLabel, isActive: filterCategory == c) { filterCategory = c }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    if classifying {
                        HStack(spacing: 8) {
                            ProgressView(value: classifyProgress).tint(AppColors.purple)
                            Text(L10n.classifying(Int(classifyProgress * 100)))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: BannerScrollOffsetKey.self,
                                    value: geo.frame(in: .named("screenshotScroll")).minY)
                            })
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                ScreenshotGridCell(
                                    asset: $assets[idx],
                                    category: categoryMap[assets[idx].id],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = ScreenshotViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: "screenshotScroll")
                    .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                        guard showBanner, offset < -10 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBanner = false
                        }
                    }
                    .simultaneousGesture(bannerHideGesture)
                    .simultaneousGesture(gridPinchGesture)
                    .animation(.easeInOut(duration: 0.18), value: gridColumnCount)
                }
                .background(AppColors.darkBG)

                if !selectedInCurrentFilter.isEmpty {
                    BottomDeleteBar(
                        count: selectedInCurrentFilter.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selectedInCurrentFilter.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            let targetIds = Set(selectedInCurrentFilter.map(\.id))
                            guard !targetIds.isEmpty else { return }
                            deleting = true
                            doneCount = targetIds.count
                            var scopedSelection = assets
                            for i in scopedSelection.indices {
                                scopedSelection[i].isSelected = targetIds.contains(scopedSelection[i].id)
                            }
                            do {
                                try await vm.deleteSelected(from: scopedSelection)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.setDetailInteraction(true) }
        .onDisappear { vm.setDetailInteraction(false) }
        .task { await classifyScreenshots() }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }

    private var gridPinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                // Apple-like direction:
                // spread fingers (>1) => larger thumbnails => fewer columns
                // pinch inward (<1)   => smaller thumbnails => more columns
                if value > 1.06 {
                    setGridColumns(2)
                } else if value < 0.94 {
                    setGridColumns(3)
                }
            }
    }

    private func setGridColumns(_ newValue: Int) {
        let clamped = min(3, max(2, newValue))
        guard clamped != gridColumnCount else { return }
        gridColumnCount = clamped
        AppConfig.screenshotGridColumns = clamped
    }

    private func classifyScreenshots() async {
        guard !assets.isEmpty else { return }
        assets.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.creationDate > rhs.creationDate
        }

        let ids = assets.map(\.id)
        let cachedRows = await DatabaseService.shared.loadScreenshotCategories(for: ids)
        var cachedMap: [String: ScreenshotCategory] = [:]
        cachedMap.reserveCapacity(cachedRows.count)
        for (id, raw) in cachedRows {
            if let category = ScreenshotCategory(rawValue: raw) {
                cachedMap[id] = category
            }
        }
        categoryMap = cachedMap

        let total = max(assets.count, 1)
        let missingIndices = assets.indices.filter { categoryMap[assets[$0].id] == nil }
        guard !missingIndices.isEmpty else {
            classifyProgress = 1
            classifying = false
            return
        }

        classifying = true
        classifyProgress = Double(categoryMap.count) / Double(total)

        var pendingMap: [String: ScreenshotCategory] = [:]
        var pendingEntries: [DatabaseService.ScreenshotCategoryEntry] = []
        var lastCommitAt = Date.distantPast
        let commitStride = 20
        let commitInterval: TimeInterval = 0.25

        let cachedCount = categoryMap.count
        var classifiedCount = 0
        for idx in missingIndices {
            let item = assets[idx]
            let c = await PhotoLibraryService.shared.classifyScreenshot(item.asset)
            pendingMap[item.id] = c
            pendingEntries.append(.init(localId: item.id, categoryRawValue: c.rawValue))

            classifiedCount += 1
            let done = cachedCount + classifiedCount
            let now = Date()
            let reachedStride = classifiedCount % commitStride == 0
            let reachedInterval = now.timeIntervalSince(lastCommitAt) >= commitInterval
            let finished = done == total
            if reachedStride || reachedInterval || finished {
                if !pendingMap.isEmpty {
                    categoryMap.merge(pendingMap) { _, new in new }
                    pendingMap.removeAll(keepingCapacity: true)
                }
                if !pendingEntries.isEmpty {
                    await DatabaseService.shared.saveScreenshotCategories(pendingEntries)
                    pendingEntries.removeAll(keepingCapacity: true)
                }
                classifyProgress = Double(done) / Double(total)
                lastCommitAt = now
                await Task.yield()
            }
        }

        if !pendingMap.isEmpty {
            categoryMap.merge(pendingMap) { _, new in new }
        }
        if !pendingEntries.isEmpty {
            await DatabaseService.shared.saveScreenshotCategories(pendingEntries)
        }
        classifyProgress = 1
        classifying = false
    }
}

// MARK: - Temporary records
struct TemporaryRecordCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var viewerRequest: TemporaryRecordViewerRequest? = nil
    @State private var gridColumnCount: Int = AppConfig.temporaryGridColumns
    @State private var done = false
    @State private var doneCount = 0
    @State private var deleting = false
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: gridColumnCount)
    }
    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var recommendedCount: Int { assets.reduce(0) { $0 + ($1.score < 55 ? 1 : 0) } }
    private var isAllSelected: Bool { !assets.isEmpty && assets.allSatisfy { $0.isSelected } }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: doneCount, label: L10n.temporaryDone(doneCount)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.temporaryTitle,
                        subtitle: L10n.temporarySubtitle(assets.count, recommendedCount),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )

                    if showBanner {
                        InfoBanner(text: L10n.temporaryBanner, color: AppColors.blue)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: BannerScrollOffsetKey.self,
                                    value: geo.frame(in: .named("temporaryScroll")).minY)
                            })
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(assets.indices, id: \.self) { idx in
                                TemporaryRecordGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = TemporaryRecordViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: "temporaryScroll")
                    .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                        guard showBanner, offset < -10 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBanner = false
                        }
                    }
                    .simultaneousGesture(bannerHideGesture)
                    .simultaneousGesture(gridPinchGesture)
                    .animation(.easeInOut(duration: 0.18), value: gridColumnCount)
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            doneCount = selected.count
                            do {
                                try await vm.deleteSelected(from: assets)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.setDetailInteraction(true)
            assets.sort { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.creationDate > rhs.creationDate
            }
        }
        .onDisappear { vm.setDetailInteraction(false) }
        .overlay(deleting ? ProgressView(L10n.processing).padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }

    private var gridPinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                if value > 1.06 {
                    setGridColumns(2)
                } else if value < 0.94 {
                    setGridColumns(3)
                }
            }
    }

    private func setGridColumns(_ newValue: Int) {
        let clamped = min(3, max(2, newValue))
        guard clamped != gridColumnCount else { return }
        gridColumnCount = clamped
        AppConfig.temporaryGridColumns = clamped
    }
}

private struct TemporaryRecordGridCell: View {
    @Binding var asset: PhotoAsset
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 120)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(10)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(L10n.temporaryRecords, fontSize: 8)
                    Spacer()
                    SelectionStatusBadge(isSelected: asset.isSelected, size: 20)
                }
            }
            .padding(4)

            if asset.isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onSingleTap() }
    }
}

private struct TemporaryRecordViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Videos
struct VideoCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var done = false
    @State private var deleting = false
    @State private var playingAssetID: String? = nil
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool { !assets.isEmpty && assets.allSatisfy { $0.isSelected } }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: L10n.videosDone(selected.count)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.videoTitle,
                        subtitle: L10n.videoSubtitle(assets.count),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )
                    if showBanner {
                        InfoBanner(text: L10n.videoBanner, color: AppColors.amber)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    GeometryReader { geo in
                        let colWidth = max(120, (geo.size.width - 34) / 2)
                        let columns = waterfallColumns(itemWidth: colWidth)

                        ScrollView {
                            Color.clear.frame(height: 0)
                                .background(GeometryReader { g in
                                    Color.clear.preference(key: BannerScrollOffsetKey.self,
                                        value: g.frame(in: .named("videoScroll")).minY)
                                })
                            HStack(alignment: .top, spacing: 10) {
                                LazyVStack(spacing: 12) {
                                    ForEach(columns.left, id: \.self) { idx in
                                        VideoGridCell(
                                            asset: $assets[idx],
                                            itemWidth: colWidth,
                                            isPlaying: playingAssetID == assets[idx].id,
                                            onPlayToggle: {
                                                if playingAssetID == assets[idx].id {
                                                    playingAssetID = nil
                                                } else {
                                                    playingAssetID = assets[idx].id
                                                }
                                            },
                                            onToggleSelect: { assets[idx].isSelected.toggle() }
                                        )
                                        .id(assets[idx].id)
                                        .frame(width: colWidth)
                                    }
                                }
                                LazyVStack(spacing: 12) {
                                    ForEach(columns.right, id: \.self) { idx in
                                        VideoGridCell(
                                            asset: $assets[idx],
                                            itemWidth: colWidth,
                                            isPlaying: playingAssetID == assets[idx].id,
                                            onPlayToggle: {
                                                if playingAssetID == assets[idx].id {
                                                    playingAssetID = nil
                                                } else {
                                                    playingAssetID = assets[idx].id
                                                }
                                            },
                                            onToggleSelect: { assets[idx].isSelected.toggle() }
                                        )
                                        .id(assets[idx].id)
                                        .frame(width: colWidth)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, selected.isEmpty ? 20 : 90)
                        }
                        .coordinateSpace(name: "videoScroll")
                        .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                            guard showBanner, offset < -10 else { return }
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showBanner = false
                            }
                        }
                        .simultaneousGesture(bannerHideGesture)
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            do {
                                try await vm.deleteSelected(from: assets)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.setDetailInteraction(true)
            assets.sort { $0.sizeBytes > $1.sizeBytes }
        }
        .onDisappear {
            playingAssetID = nil
            vm.setDetailInteraction(false)
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }

    private func waterfallColumns(itemWidth: CGFloat) -> (left: [Int], right: [Int]) {
        var left: [Int] = []
        var right: [Int] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for idx in assets.indices {
            let cardHeight = estimatedCardHeight(for: assets[idx], itemWidth: itemWidth)
            if leftHeight <= rightHeight {
                left.append(idx)
                leftHeight += cardHeight
            } else {
                right.append(idx)
                rightHeight += cardHeight
            }
        }
        return (left, right)
    }

    private func estimatedCardHeight(for asset: PhotoAsset, itemWidth: CGFloat) -> CGFloat {
        let w = CGFloat(max(1, asset.asset.pixelWidth))
        let h = CGFloat(max(1, asset.asset.pixelHeight))
        let mediaHeight = itemWidth * (h / w)
        return mediaHeight + 54 // bottom meta row + spacing
    }
}

struct VideoGridCell: View {
    @Binding var asset: PhotoAsset
    let itemWidth: CGFloat
    let isPlaying: Bool
    let onPlayToggle: () -> Void
    let onToggleSelect: () -> Void
    @State private var player: AVPlayer?
    @State private var loadingPlayer = false
    private var videoAspectRatio: CGFloat {
        let w = CGFloat(max(1, asset.asset.pixelWidth))
        let h = CGFloat(max(1, asset.asset.pixelHeight))
        return w / h
    }
    private var videoDisplayHeight: CGFloat {
        itemWidth / max(videoAspectRatio, 0.1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if isPlaying, let player {
                        InlineVideoPlayer(player: player)
                            .onAppear { player.play() }
                    } else {
                        PhotoThumbnail(
                            asset: asset.asset,
                            size: itemWidth,
                            height: videoDisplayHeight,
                            contentMode: .fill
                        )
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white.opacity(0.92))
                            )
                    }
                }
                .frame(width: itemWidth, height: videoDisplayHeight)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.subtleBorder, lineWidth: 1)
                )
                .onTapGesture { onPlayToggle() }

                if loadingPlayer && isPlaying {
                    ProgressView().tint(.white).padding(6)
                }

                Text(formattedDuration(asset.duration))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(6)
            }

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(asset.asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? L10n.unknownDate)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(asset.formattedSize)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button(action: onToggleSelect) {
                    videoSelectCircle(isSelected: asset.isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                Task { await ensurePlayerReadyAndPlay() }
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            player?.pause()
            if !isPlaying { player = nil }
        }
    }

    @ViewBuilder
    private func videoSelectCircle(isSelected: Bool) -> some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(AppColors.selectionBlue)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        } else {
            Circle()
                .stroke(AppColors.textSecondary, lineWidth: 2)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.black.opacity(0.2)))
        }
    }

    private func ensurePlayerReadyAndPlay() async {
        if let player {
            player.play()
            return
        }
        loadingPlayer = true
        if let avAsset = await requestVideoAsset(for: asset.asset) {
            let item = AVPlayerItem(asset: avAsset)
            let newPlayer = AVPlayer(playerItem: item)
            await MainActor.run {
                self.player = newPlayer
                self.loadingPlayer = false
                newPlayer.play()
            }
        } else {
            await MainActor.run { self.loadingPlayer = false }
        }
    }

    private func requestVideoAsset(for asset: PHAsset) async -> AVAsset? {
        await withCheckedContinuation { cont in
            let opts = PHVideoRequestOptions()
            opts.deliveryMode = .automatic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                cont.resume(returning: avAsset)
            }
        }
    }

    private func formattedDuration(_ secs: TimeInterval) -> String {
        let m = Int(secs / 60), s = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Lightweight inline video renderer based on AVPlayerLayer.
/// Avoids AVPlayerViewController's status-bar/fullscreen side effects in scrolling grids.
private struct InlineVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.playerLayer.player = nil
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

// MARK: - Low Quality
struct LowQualityCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filterReason: LowQualityReason? = nil
    @State private var viewerRequest: LowQualityViewerRequest? = nil
    @State private var gridColumnCount: Int = AppConfig.lowQualityGridColumns
    @State private var done = false
    @State private var doneCount = 0
    @State private var deleting = false
    @Environment(\.dismiss) var dismiss

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: gridColumnCount)
    }
    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            guard let r = filterReason else { return true }
            return assets[idx].reason == r
        }
    }
    private var selectionTargetIndices: [Int] { filteredIndices }
    private var currentFilterTotalCount: Int { selectionTargetIndices.count }
    private var currentFilterRecommendedCount: Int {
        selectionTargetIndices.reduce(0) { partial, idx in
            partial + (assets[idx].score < 45 ? 1 : 0)
        }
    }
    private var selectedInCurrentFilter: [PhotoAsset] {
        selectionTargetIndices.compactMap { idx in
            guard assets.indices.contains(idx), assets[idx].isSelected else { return nil }
            return assets[idx]
        }
    }
    private var isAllSelected: Bool {
        !selectionTargetIndices.isEmpty && selectionTargetIndices.allSatisfy { assets[$0].isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: doneCount, label: L10n.lowQualityDone(doneCount)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.lowQualityTitle,
                        subtitle: L10n.lowQualitySubtitle(currentFilterTotalCount, currentFilterRecommendedCount),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in selectionTargetIndices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: L10n.all, isActive: filterReason == nil) { filterReason = nil }
                            ForEach(LowQualityReason.allCases, id: \.self) { r in
                                FilterChip(label: r.displayName, isActive: filterReason == r) { filterReason = r }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }

                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                LowQualityGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = LowQualityViewerRequest(startIndex: idx) }
                                )
                                    .id(assets[idx].id)
                            }
                        }
                        .padding(3).padding(.bottom, 80)
                    }
                    .simultaneousGesture(gridPinchGesture)
                    .animation(.easeInOut(duration: 0.18), value: gridColumnCount)
                }
                .background(AppColors.darkBG)

                if !selectedInCurrentFilter.isEmpty {
                    BottomDeleteBar(count: selectedInCurrentFilter.count, sizeLabel: "") {
                        Task {
                            let targetIds = Set(selectedInCurrentFilter.map(\.id))
                            guard !targetIds.isEmpty else { return }
                            deleting = true
                            doneCount = targetIds.count
                            var scopedSelection = assets
                            for i in scopedSelection.indices {
                                scopedSelection[i].isSelected = targetIds.contains(scopedSelection[i].id)
                            }
                            do {
                                try await vm.deleteSelected(from: scopedSelection)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.setDetailInteraction(true) }
        .onDisappear { vm.setDetailInteraction(false) }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var gridPinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                if value > 1.06 {
                    setGridColumns(2)
                } else if value < 0.94 {
                    setGridColumns(3)
                }
            }
    }

    private func setGridColumns(_ newValue: Int) {
        let clamped = min(3, max(2, newValue))
        guard clamped != gridColumnCount else { return }
        gridColumnCount = clamped
        AppConfig.lowQualityGridColumns = clamped
    }
}

private struct LowQualityGridCell: View {
    @Binding var asset: PhotoAsset
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 120)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(10)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(asset.reason?.displayName ?? mediaTypeTag(asset.asset), fontSize: 8)
                    Spacer()
                    SelectionStatusBadge(isSelected: asset.isSelected, size: 20)
                }
            }
            .padding(4)

            if asset.isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onSingleTap() }
    }
}

private struct LowQualityViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Favorites
struct FavoritesCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var viewerRequest: FavoritesViewerRequest? = nil
    @State private var done = false
    @State private var deleting = false
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool {
        !assets.isEmpty && assets.allSatisfy { $0.isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: L10n.favoritesDone(selected.count)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.favoritesTitle,
                        subtitle: L10n.favoritesSubtitle(assets.count),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )
                    if showBanner {
                        InfoBanner(text: L10n.favoriteBanner, color: AppColors.red)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: BannerScrollOffsetKey.self,
                                    value: geo.frame(in: .named("favoritesScroll")).minY)
                            })
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                            ForEach(assets.indices, id: \.self) { idx in
                                LowQualityGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = FavoritesViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: "favoritesScroll")
                    .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                        guard showBanner, offset < -10 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBanner = false
                        }
                    }
                    .simultaneousGesture(bannerHideGesture)
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            do {
                                try await vm.deleteSelected(from: assets)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.setDetailInteraction(true) }
        .onDisappear { vm.setDetailInteraction(false) }
        .overlay(deleting ? ProgressView(L10n.processing).padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }
}

private struct FavoritesViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Cold photo cleanup (behavioral signals)

struct BehaviorCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filterTier: ColdTier? = nil   // nil = 全部
    @State private var viewerRequest: BehaviorViewerRequest? = nil
    @State private var done = false
    @State private var doneCount = 0
    @State private var deleting = false
    @State private var showBanner = true
    @Environment(\.dismiss) var dismiss

    private let gridCols = [GridItem(.flexible(), spacing: 3),
                             GridItem(.flexible(), spacing: 3),
                             GridItem(.flexible(), spacing: 3)]

    private var frozenCount: Int { assets.filter { $0.coldTier == .frozen }.count }
    private var coldCount:   Int { assets.filter { $0.coldTier == .cold   }.count }

    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            guard let tier = filterTier else { return true }
            return assets[idx].coldTier == tier
        }
    }
    private var selectedInFilter: [PhotoAsset] {
        filteredIndices.compactMap { idx in
            assets.indices.contains(idx) && assets[idx].isSelected ? assets[idx] : nil
        }
    }
    private var isAllSelected: Bool {
        !filteredIndices.isEmpty && filteredIndices.allSatisfy { assets[$0].isSelected }
    }

    // Oldest age among currently visible photos (for banner)
    private var maxVisibleYears: Int {
        filteredIndices.compactMap { idx in
            Calendar.current.dateComponents([.year], from: assets[idx].creationDate, to: Date()).year
        }.max() ?? 0
    }

    private var bannerText: String {
        switch filterTier {
        case .frozen:
            let n = filteredIndices.count
            return maxVisibleYears > 0
                ? L10n.behaviorInsightBanner(n, maxVisibleYears)
                : L10n.coldTierFrozenDetail
        case .cold:
            return L10n.behaviorColdBanner
        case nil:
            let n = frozenCount
            return n > 0 && maxVisibleYears > 0
                ? L10n.behaviorInsightBanner(n, maxVisibleYears)
                : L10n.behaviorColdBanner
        }
    }
    private var bannerColor: Color {
        filterTier == .cold ? AppColors.blue : AppColors.amber
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: doneCount, label: L10n.photosDone(doneCount)) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.behaviorTitle,
                        subtitle: L10n.behaviorSubtitle(frozenCount, coldCount),
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                let next = !isAllSelected
                                for i in filteredIndices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )

                    if showBanner {
                        InfoBanner(text: bannerText, color: bannerColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Filter chips ──────────────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                label: L10n.all,
                                isActive: filterTier == nil
                            ) { filterTier = nil }

                            FilterChip(
                                label: "🥶 \(L10n.coldTierFrozen)  \(frozenCount)",
                                isActive: filterTier == .frozen
                            ) { filterTier = .frozen }

                            FilterChip(
                                label: "❄️ \(L10n.coldTierCold)  \(coldCount)",
                                isActive: filterTier == .cold
                            ) { filterTier = .cold }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // ── Photo grid ────────────────────────────────────────────
                    ScrollView {
                        Color.clear.frame(height: 0)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: BannerScrollOffsetKey.self,
                                    value: geo.frame(in: .named("behaviorScroll")).minY)
                            })
                        if filteredIndices.isEmpty {
                            Text("暂无冷照片")
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: gridCols, spacing: 3) {
                                ForEach(filteredIndices, id: \.self) { idx in
                                    LowQualityGridCell(
                                        asset: $assets[idx],
                                        onSingleTap: { assets[idx].isSelected.toggle() },
                                        onDoubleTap: { viewerRequest = BehaviorViewerRequest(startIndex: idx) }
                                    )
                                    .id(assets[idx].id)
                                }
                            }
                            .padding(3)
                        }
                        Spacer().frame(height: selectedInFilter.isEmpty ? 20 : 90)
                    }
                    .coordinateSpace(name: "behaviorScroll")
                    .onPreferenceChange(BannerScrollOffsetKey.self) { offset in
                        guard showBanner, offset < -10 else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showBanner = false
                        }
                    }
                    .simultaneousGesture(bannerHideGesture)
                }
                .background(AppColors.darkBG)

                if !selectedInFilter.isEmpty {
                    BottomDeleteBar(
                        count: selectedInFilter.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selectedInFilter.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            let targetIds = Set(selectedInFilter.map(\.id))
                            guard !targetIds.isEmpty else { return }
                            deleting = true
                            doneCount = targetIds.count
                            var scopedSelection = assets
                            for i in scopedSelection.indices {
                                scopedSelection[i].isSelected = targetIds.contains(scopedSelection[i].id)
                            }
                            do {
                                try await vm.deleteSelected(from: scopedSelection)
                                deleting = false
                                done = true
                            } catch {
                                deleting = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.setDetailInteraction(true) }
        .onDisappear { vm.setDetailInteraction(false) }
        .overlay(deleting ? ProgressView(L10n.processing).padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var bannerHideGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard showBanner, value.translation.height < -8 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBanner = false
                }
            }
    }
}

private struct BehaviorViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Helpers
struct InfoBanner: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.infoBannerBG)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.35), lineWidth: 0.8)
            )
            .cornerRadius(8)
            .padding(.horizontal).padding(.top, 6)
    }
}

private struct BannerScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.micro.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isActive ? AppColors.purple : AppColors.chipBG)
                .foregroundColor(isActive ? .white : AppColors.textSecondary)
                .cornerRadius(20)
        }
    }
}

private struct ScreenshotGridCell: View {
    @Binding var asset: PhotoAsset
    let category: ScreenshotCategory?
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 120)
                .frame(maxWidth: .infinity)
                .aspectRatio(9/16, contentMode: .fill)
                .clipped()
                .cornerRadius(10)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(category?.chipLabel ?? mediaTypeTag(asset.asset), fontSize: 8)
                    Spacer()
                    SelectionStatusBadge(isSelected: asset.isSelected, size: 20)
                }
            }
            .padding(4)

            if asset.isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onSingleTap() }
    }
}

private struct ScreenshotViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}
