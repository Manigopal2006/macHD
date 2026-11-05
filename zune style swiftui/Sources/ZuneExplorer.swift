import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing

@main
struct ZuneExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ExplorerView()
                .frame(minWidth: 930, minHeight: 620)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

enum MediaSection: String, CaseIterable, Identifiable {
    case all = "everything", music = "music", videos = "videos", pictures = "pictures", documents = "documents"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .all: "square.grid.2x2"; case .music: "waveform"; case .videos: "play.rectangle"; case .pictures: "photo"; case .documents: "doc.text" }
    }
    func contains(_ url: URL) -> Bool {
        if self == .all { return true }
        let ext = url.pathExtension.lowercased()
        switch self {
        case .all: return true
        case .music: return ["mp3", "m4a", "aac", "wav", "aiff", "flac", "alac", "ogg"].contains(ext)
        case .videos: return ["mp4", "mov", "m4v", "avi", "mkv", "mpg", "mpeg", "webm"].contains(ext)
        case .pictures: return ["jpg", "jpeg", "png", "heic", "tif", "tiff", "gif", "bmp", "webp", "svg"].contains(ext)
        case .documents: return ["pdf", "txt", "rtf", "doc", "docx", "pages", "md", "key", "ppt", "pptx", "numbers", "xls", "xlsx"].contains(ext)
        }
    }
}

struct MediaEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var ext: String { isDirectory ? "FOLDER" : url.pathExtension.uppercased() }
}

@MainActor
final class ExplorerModel: ObservableObject {
    @Published var root: URL?
    @Published var folder: URL?
    @Published var section: MediaSection = .all
    @Published var query = ""
    @Published var entries: [MediaEntry] = []
    @Published var selectedID: String?
    @Published var previewURL: URL?
    @Published var errorMessage: String?

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = "Open Library"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url; folder = url; refresh()
    }

    func refresh() {
        guard let folder else { entries = []; return }
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            entries = urls.compactMap { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir || section.contains(url) else { return nil }
                guard query.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(query) else { return nil }
                return MediaEntry(url: url, isDirectory: isDir)
            }.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            if !entries.contains(where: { $0.id == selectedID }) { selectedID = entries.first?.id }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription; entries = [] }
    }

    func open(_ entry: MediaEntry) {
        if entry.isDirectory { folder = entry.url; query = ""; refresh() }
        else { previewURL = entry.url }
    }
    func goBack() {
        guard let folder, let root, folder != root else { return }
        self.folder = folder.deletingLastPathComponent(); refresh()
    }
    func moveSelection(_ delta: Int) {
        guard !entries.isEmpty else { return }
        let current = entries.firstIndex(where: { $0.id == selectedID }) ?? 0
        let next = min(max(current + delta, 0), entries.count - 1)
        selectedID = entries[next].id
    }
    var selected: MediaEntry? { entries.first(where: { $0.id == selectedID }) }
}

struct ExplorerView: View {
    @StateObject private var model = ExplorerModel()
    @FocusState private var keyboardFocus: Bool
    @State private var cursorMode = false
    private let orange = Color(red: 1, green: 0.38, blue: 0.08)
    private let canvas = Color(red: 0.055, green: 0.06, blue: 0.065)

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                HStack(spacing: 0) {
                    sidebar
                    Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                    mainPanel
                }
            }
        }
        .foregroundStyle(.white)
        .focusable()
        .focused($keyboardFocus)
        .onAppear { keyboardFocus = true }
        .onMoveCommand { direction in
            switch direction { case .up: model.moveSelection(-1); case .down: model.moveSelection(1); case .left: model.moveSelection(-1); case .right: model.moveSelection(1); default: break }
        }
        .onKeyPress(.return) { if let selected = model.selected { model.open(selected) }; return .handled }
        .onKeyPress(.space) { if let selected = model.selected, !selected.isDirectory { model.previewURL = selected.url }; return .handled }
        .onKeyPress(.delete, phases: .down) { model.goBack(); return .handled }
        .onKeyPress(.escape) { if model.previewURL != nil { model.previewURL = nil } else { model.goBack() }; return .handled }
        .onChange(of: model.section) { _, _ in model.refresh() }
        .onChange(of: model.query) { _, _ in model.refresh() }
        .quickLookPreview($model.previewURL)
        .alert("Can’t open this folder", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Text("ZUNE").font(.system(size: 16, weight: .black, design: .rounded)).tracking(2.5)
            Circle().fill(orange).frame(width: 6, height: 6)
            Text(model.root?.lastPathComponent.uppercased() ?? "MEDIA EXPLORER")
                .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.48)).lineLimit(1)
            Spacer()
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                TextField("Find media", text: $model.query).textFieldStyle(.plain).font(.system(size: 12)).frame(width: 150)
            }.padding(.horizontal, 11).padding(.vertical, 8).background(.white.opacity(0.06), in: Capsule())
            Button { cursorMode.toggle() } label: {
                Image(systemName: cursorMode ? "cursorarrow.rays" : "cursorarrow").font(.system(size: 13)).foregroundStyle(cursorMode ? orange : .white.opacity(0.55))
            }.buttonStyle(.plain).help("Cursor navigation")
            Button(action: model.chooseFolder) {
                HStack(spacing: 7) { Image(systemName: "folder"); Text("OPEN FOLDER") }
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.8)
                    .padding(.horizontal, 13).padding(.vertical, 9).background(orange, in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 24).frame(height: 58)
        .background(Color.black.opacity(0.2))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LIBRARY").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.32)).padding(.leading, 13).padding(.bottom, 12)
            ForEach(MediaSection.allCases) { section in
                Button { model.section = section } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.symbol).font(.system(size: 14, weight: .medium)).frame(width: 19)
                        Text(section.rawValue.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(0.7)
                        Spacer()
                        if model.section == section { Circle().fill(orange).frame(width: 5, height: 5) }
                    }
                    .foregroundStyle(model.section == section ? .white : .white.opacity(0.46))
                    .padding(.horizontal, 12).frame(height: 40)
                    .background(model.section == section ? .white.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(alignment: .leading) { if model.section == section { Capsule().fill(orange).frame(width: 2, height: 19) } }
                }.buttonStyle(.plain)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.bottom, 7)
                Text("NOW BROWSING").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.28))
                Text(model.folder?.lastPathComponent ?? "Choose a folder")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
                if model.folder != nil { Button("←  PARENT FOLDER") { model.goBack() }.font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(orange).buttonStyle(.plain).padding(.top, 5) }
            }.padding(.horizontal, 12).padding(.bottom, 8)
        }
        .padding(.horizontal, 14).padding(.top, 25).padding(.bottom, 19)
        .frame(width: 210).background(Color.white.opacity(0.018))
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.section.rawValue.uppercased()).font(.system(size: 37, weight: .light, design: .rounded)).tracking(-1.4)
                    HStack(spacing: 8) {
                        Text(model.folder?.path.replacingOccurrences(of: model.root?.path ?? "", with: "⌂") ?? "Select a folder to begin")
                            .lineLimit(1).truncationMode(.middle)
                        Text("·").foregroundStyle(orange)
                        Text("\(model.entries.count) ITEMS")
                    }.font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(0.7).foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
                Text("01  /  \(String(format: "%02d", model.entries.count))").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.35)).padding(.bottom, 4)
            }.padding(.horizontal, 32).padding(.top, 37).padding(.bottom, 23)

            if model.root == nil {
                emptyState
            } else if model.entries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: 15)], alignment: .leading, spacing: 19) {
                            ForEach(model.entries) { entry in
                                MediaTile(entry: entry, selected: model.selectedID == entry.id, accent: orange)
                                    .id(entry.id)
                                    .onTapGesture { model.selectedID = entry.id; if cursorMode { model.open(entry) } }
                                    .onHover { hovering in if hovering && cursorMode { model.selectedID = entry.id } }
                                    .onTapGesture(count: 2) { model.open(entry) }
                            }
                        }.padding(.horizontal, 32).padding(.bottom, 24)
                    }
                    .onChange(of: model.selectedID) { _, id in if let id { withAnimation(.easeOut(duration: 0.16)) { proxy.scrollTo(id, anchor: .center) } } }
                }
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: model.root == nil ? "externaldrive" : "sparkle.magnifyingglass").font(.system(size: 28, weight: .ultraLight)).foregroundStyle(orange.opacity(0.85))
            Text(model.root == nil ? "YOUR MEDIA, IN MOTION" : "NOTHING HERE YET")
                .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(1.6)
            Text(model.root == nil ? "Open a folder to browse audio, video, images and documents." : "Try another category or choose a different folder.")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.42))
            if model.root == nil { Button("CHOOSE A FOLDER") { model.chooseFolder() }.font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(orange).buttonStyle(.plain).padding(.top, 5) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text("↑ ↓  NAVIGATE"); Text("↵  OPEN"); Text("SPACE  PREVIEW"); Text("⌫  BACK")
            Spacer()
            Text("\(model.entries.count) ITEMS").foregroundStyle(.white.opacity(0.3))
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 32).frame(height: 38)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
}

struct MediaTile: View {
    let entry: MediaEntry
    let selected: Bool
    let accent: Color
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing))
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill).frame(maxWidth: .infinity).frame(height: 122).clipped().clipShape(RoundedRectangle(cornerRadius: 9))
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path)).resizable().interpolation(.high).scaledToFit().frame(width: 52, height: 52).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if entry.isDirectory {
                    Image(systemName: "folder.fill").font(.system(size: 13)).foregroundStyle(accent).padding(9)
                } else if ["mp4", "mov", "m4v", "avi", "mkv"].contains(entry.url.pathExtension.lowercased()) {
                    Image(systemName: "play.fill").font(.system(size: 11)).foregroundStyle(.white).padding(7).background(.black.opacity(0.55), in: Circle()).padding(9)
                }
                Text(entry.ext).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.5).foregroundStyle(.white.opacity(0.62)).padding(.horizontal, 7).padding(.vertical, 4).background(.black.opacity(0.5), in: Capsule()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
            }
            .frame(height: 122)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? accent : .white.opacity(0.055), lineWidth: selected ? 1.5 : 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name).font(.system(size: 11, weight: selected ? .semibold : .medium)).lineLimit(1).foregroundStyle(.white.opacity(selected ? 1 : 0.75))
                Text(entry.isDirectory ? "FOLDER" : entry.url.deletingLastPathComponent().lastPathComponent.uppercased()).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.7).lineLimit(1).foregroundStyle(.white.opacity(0.34))
            }
        }
        .padding(7).background(selected ? .white.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 11))
        .task(id: entry.id) { await loadThumbnail() }
        .accessibilityElement(children: .ignore).accessibilityLabel(entry.name).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func loadThumbnail() async {
        guard !entry.isDirectory else { return }
        let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: 500, height: 350), scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
        do {
            let result = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            await MainActor.run { thumbnail = result.nsImage }
        } catch { }
    }
}
