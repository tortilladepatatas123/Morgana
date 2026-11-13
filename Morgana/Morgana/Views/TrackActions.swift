import SwiftUI

/// Menú contextual (mantener pulsado) y gesto de deslizar para favoritos y listas.
struct TrackActionsModifier: ViewModifier {
    let track: Track
    let swipe: Bool

    @EnvironmentObject var userData: PlaylistStore
    @State private var showAddToPlaylist = false

    private var isFavorite: Bool { userData.isFavorite(track.id) }

    func body(content: Content) -> some View {
        let base = content
            .contextMenu {
                Button {
                    userData.toggleFavorite(track.id)
                } label: {
                    Label(
                        isFavorite ? "Quitar de favoritos" : "Añadir a favoritos",
                        systemImage: isFavorite ? "star.slash" : "star"
                    )
                }
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Añadir a una lista…", systemImage: "text.badge.plus")
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                AddToPlaylistSheet(trackIDs: [track.id])
            }

        if swipe {
            base.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    userData.toggleFavorite(track.id)
                } label: {
                    Label(isFavorite ? "Quitar" : "Favorita", systemImage: isFavorite ? "star.slash" : "star.fill")
                }
                .tint(.yellow)
            }
        } else {
            base
        }
    }
}

extension View {
    /// - Parameter swipe: `false` en pantallas con su propio gesto de deslizar (p. ej. editar una lista).
    func trackActions(_ track: Track, swipe: Bool = true) -> some View {
        modifier(TrackActionsModifier(track: track, swipe: swipe))
    }
}

/// Hoja para escribir un nombre (crear o renombrar una lista).
struct PlaylistNameSheet: View {
    let title: String
    let confirmTitle: String
    var initialName = ""
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre de la lista", text: $name)
                    .submitLabel(.done)
                    .onSubmit(submit)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: submit)
                        .disabled(!isValid)
                }
            }
            .onAppear { name = initialName }
        }
        .presentationDetents([.height(220)])
    }

    private func submit() {
        guard isValid else { return }
        onSubmit(name)
        dismiss()
    }
}

/// Hoja para elegir a qué lista se añaden una o varias pistas, o crear una nueva.
struct AddToPlaylistSheet: View {
    let trackIDs: [UUID]

    @EnvironmentObject var userData: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showNew = true
                } label: {
                    Label("Nueva lista", systemImage: "plus")
                }

                ForEach(userData.playlists) { playlist in
                    Button {
                        userData.add(trackIDs, to: playlist.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundStyle(.secondary)
                            Text(playlist.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            if trackIDs.allSatisfy({ playlist.trackIDs.contains($0) }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Añadir a una lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showNew) {
                PlaylistNameSheet(title: "Nueva lista", confirmTitle: "Crear") { name in
                    userData.createPlaylist(name: name, trackIDs: trackIDs)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
