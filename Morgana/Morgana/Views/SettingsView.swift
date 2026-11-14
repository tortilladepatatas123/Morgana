import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var userData: PlaylistStore
    @State private var showingImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.folders) { folder in
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.name).lineLimit(1)
                                Text("\(store.tracks.filter { $0.folderID == folder.id }.count) canciones")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.removeFolders(at: $0) }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Añadir carpeta", systemImage: "folder.badge.plus")
                    }
                } header: {
                    Text("Carpetas de música")
                } footer: {
                    Text("Los archivos no se copian ni se envían a ningún sitio: la app los lee directamente desde la carpeta que elijas. Si están en iCloud Drive, mantenlos descargados.")
                }

                Section {
                    Button {
                        store.rescan()
                    } label: {
                        Label("Volver a escanear", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isScanning || store.folders.isEmpty)

                    if store.isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(store.scanStatus)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Biblioteca") {
                    LabeledContent("Canciones", value: "\(store.tracks.count)")
                    LabeledContent("Álbumes", value: "\(store.albums.count)")
                    LabeledContent("Artistas", value: "\(store.artists.count)")
                    LabeledContent("Géneros", value: "\(store.genres.count)")
                    LabeledContent("Favoritos", value: "\(store.tracks(for: userData.favorites).count)")
                    LabeledContent("Listas", value: "\(userData.playlists.count)")
                }
            }
            .miniPlayerBottomSpacing()
            .navigationTitle("Configuración")
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    store.addFolder(url)
                case .failure(let error):
                    store.errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .miniPlayerInset()
    }
}
