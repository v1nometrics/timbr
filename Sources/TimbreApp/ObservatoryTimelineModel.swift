// SPDX-License-Identifier: MPL-2.0
// State of the Observatory timeline (ADR-0018). Every query runs off the main actor on its own
// read-only connection (EventLogReader); the UI only ever receives a finished page.
import Foundation
import AppKit
import TimbreCore

@MainActor
public final class ObservatoryTimelineModel: ObservableObject {
    nonisolated public static let pageSize = 100

    @Published public private(set) var rows: [EventRow] = []
    @Published public private(set) var total: Int?            // nil while the count is being computed
    @Published public private(set) var hasMore = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var categories: [String] = []
    @Published public private(set) var isExporting = false
    @Published public var text = "" { didSet { if text != oldValue { scheduleReload(after: .milliseconds(250)) } } }
    @Published public var selectedCategories: Set<String> = [] { didSet { if selectedCategories != oldValue { scheduleReload(after: .zero) } } }

    private let reader: EventLogReader?
    private let databasePath: String?
    private var generation = 0
    private var reloadTask: Task<Void, Never>?
    private var headTask: Task<Void, Never>?
    private var loadingMore = false

    public init(databasePath: String?) {
        self.databasePath = databasePath
        self.reader = databasePath.flatMap { try? EventLogReader(path: $0) }
    }

    public var filter: EventFilter { EventFilter(text: text, categories: selectedCategories) }
    public var searchTooShort: Bool { filter.searchTooShort }
    public var isFiltering: Bool { !filter.isEmpty }

    // MARK: Loading

    public func start() {
        guard let reader else { return }
        Task { [weak self] in
            let cats = await Task.detached(priority: .utility) { reader.categories() }.value
            self?.categories = cats
        }
        reload()
    }

    private func scheduleReload(after delay: Duration) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    /// First page for the current filter. Stale answers (the filter moved on) are dropped.
    public func reload() {
        guard let reader else { return }
        generation += 1
        let gen = generation
        let f = filter
        isLoading = true
        total = nil
        loadingMore = false
        Task { [weak self] in
            let page = await Task.detached(priority: .userInitiated) { reader.page(filter: f, limit: Self.pageSize) }.value
            guard let self, gen == self.generation else { return }
            self.rows = page.rows
            self.hasMore = page.hasMore
            self.isLoading = false
            let n = await Task.detached(priority: .utility) { reader.count(filter: f) }.value
            if gen == self.generation { self.total = n }
        }
    }

    /// Called when the user scrolls near the end. One page at a time.
    public func loadMoreIfNeeded(currentIndex: Int) {
        guard let reader, hasMore, !loadingMore, !isLoading, currentIndex >= rows.count - 15, let cursor = rows.last?.cursor else { return }
        loadingMore = true
        let gen = generation
        let f = filter
        Task { [weak self] in
            let page = await Task.detached(priority: .userInitiated) { reader.page(filter: f, after: cursor, limit: Self.pageSize) }.value
            guard let self, gen == self.generation else { return }
            self.rows.append(contentsOf: page.rows)
            self.hasMore = page.hasMore
            self.loadingMore = false
        }
    }

    public var isLoadingMore: Bool { loadingMore }

    /// A new event was persisted: pull in whatever is newer than the top row (cheap, one index seek).
    public func refreshHead() {
        guard let reader else { return }
        headTask?.cancel()
        headTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))   // coalesce bursts
            guard !Task.isCancelled, let self else { return }
            guard let top = self.rows.first?.cursor else { if !self.isLoading { self.reload() }; return }
            let gen = self.generation
            let f = self.filter
            let fresh = await Task.detached(priority: .utility) { reader.newer(filter: f, than: top) }.value
            guard !Task.isCancelled, gen == self.generation, !fresh.isEmpty else { return }
            let known = Set(self.rows.prefix(fresh.count + 5).map(\.id))
            let add = fresh.filter { !known.contains($0.id) }
            self.rows.insert(contentsOf: add, at: 0)
            if let t = self.total { self.total = t + add.count }
            let unseen = Set(add.map(\.event.category)).subtracting(self.categories)
            if !unseen.isEmpty { self.categories = (self.categories + unseen).sorted() }
        }
    }

    // MARK: Export

    /// Exports every event matching the current filter, not just the ones loaded on screen.
    /// Returns the number written, or nil if the user cancelled the save panel.
    public func export(_ format: EventExportFormat, suggestedName: String, message: String) async throws -> Int? {
        guard let databasePath, !isExporting else { return nil }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName + "." + format.fileExtension
        panel.message = message
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        isExporting = true
        defer { isExporting = false }
        let f = filter
        return try await Task.detached(priority: .utility) {
            try EventLogReader.export(databasePath: databasePath, filter: f, format: format, to: url) { Task.isCancelled }
        }.value
    }
}
