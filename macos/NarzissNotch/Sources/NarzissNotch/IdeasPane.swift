import SwiftUI
import NotchCore

struct IdeasPane: View {
    @ObservedObject var store: IdeaStore
    var onModal: (Bool) -> Void
    @State private var draft = ""
    @State private var showDone = true
    @State private var editing: Idea?
    @State private var deleting: Idea?
    @FocusState private var composing: Bool
    private var visibleItems: [Idea] { store.orderedItems.filter { showDone || !$0.isDone } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ideas").notchFont(size: 15, weight: .medium)
                Spacer()
                Text(store.remainingCount == 0 && !store.items.isEmpty ? "All done" : "\(store.remainingCount) to do")
                    .notchFont(size: 11).foregroundStyle(Ink.muted)
            }
            HStack(spacing: 8) {
                TextField("Add an idea…", text: $draft)
                    .textFieldStyle(.plain).notchFont(size: 12)
                    .padding(.horizontal, 10).frame(height: 32)
                    .background(Ink.surface, in: RoundedRectangle(cornerRadius: 9))
                    .focused($composing).onSubmit(add)
                    .accessibilityLabel("New idea")
                ActionButton(title: "Add", symbol: "plus", action: add)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.disabled(store.isReadOnly)
            if visibleItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: store.items.isEmpty ? "lightbulb" : "checkmark.circle")
                        .notchFont(size: 26).foregroundStyle(Ink.accent)
                    Text(store.items.isEmpty ? "Keep an idea for later." : "Everything is ticked off.")
                        .notchFont(size: 13, weight: .medium)
                    Text(store.items.isEmpty ? "Add a reminder above. Flag what matters." : "Turn on Show done to see finished ideas.")
                        .notchFont(size: 11).foregroundStyle(Ink.muted)
                        .multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(visibleItems) { idea in
                            HStack(spacing: 6) {
                                Button { store.toggleDone(idea.id) } label: {
                                    Image(systemName: idea.isDone ? "checkmark.circle.fill" : "circle")
                                        .notchFont(size: 16).frame(width: 28, height: 28)
                                }
                                .foregroundStyle(idea.isDone ? Ink.accent : Ink.muted)
                                .help(idea.isDone ? "Mark as not done" : "Mark as done")
                                .accessibilityLabel("\(idea.isDone ? "Reopen" : "Complete") idea: \(idea.text)")
                                Text(idea.text).notchFont(size: 12)
                                    .strikethrough(idea.isDone).foregroundStyle(idea.isDone ? Ink.muted : .white)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading).help(idea.text)
                                iconButton(idea.isMarked ? "flag.fill" : "flag", idea.isMarked ? "Unmark important idea" : "Mark important idea") {
                                    store.toggleMarked(idea.id)
                                }.foregroundStyle(idea.isMarked ? Ink.accent : Ink.muted)
                                Menu {
                                    Button("Edit…") { editing = idea }
                                    Button("Delete…", role: .destructive) { deleting = idea }
                                } label: { Image(systemName: "ellipsis").frame(width: 20, height: 24) }
                                .menuStyle(.borderlessButton).fixedSize().help("Edit or delete idea")
                            }
                            .padding(8).background(Ink.surface, in: RoundedRectangle(cornerRadius: 10))
                            .disabled(store.isReadOnly)
                        }
                    }
                }
            }
            if let error = store.error {
                Text(error).notchFont(size: 10).foregroundStyle(.orange).lineLimit(3).help(error)
            }
            HStack {
                Text("\(store.items.count) ideas · Saved locally").notchFont(size: 10).foregroundStyle(Ink.muted)
                Spacer()
                Toggle("Show done", isOn: $showDone).toggleStyle(.checkbox).controlSize(.small)
                    .notchFont(size: 10).foregroundStyle(Ink.muted)
            }
        }
        .sheet(item: $editing) { idea in IdeaEditor(idea: idea, store: store) }
        .alert("Delete idea?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let idea = deleting { store.remove(idea.id) }; deleting = nil }
        } message: { Text("This removes the idea from your saved list.") }
        .onChange(of: composing || editing != nil || deleting != nil) { _, active in onModal(active) }
        .onDisappear { onModal(false) }
    }
    private func add() {
        if store.add(draft) { draft = ""; composing = true }
    }
}

private struct IdeaEditor: View {
    let idea: Idea
    @ObservedObject var store: IdeaStore
    @State private var draft: String
    @Environment(\.dismiss) private var dismiss
    init(idea: Idea, store: IdeaStore) {
        self.idea = idea; self.store = store; _draft = State(initialValue: idea.text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit idea").notchFont(size: 18, weight: .semibold)
            TextField("Idea", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(3...6).notchFont(size: 13)
                .accessibilityLabel("Idea text")
            if let error = store.error { Text(error).notchFont(size: 11).foregroundStyle(.orange) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                ActionButton(title: "Save", symbol: "checkmark") {
                    if store.edit(idea.id, text: draft) { dismiss() }
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(20).frame(width: 340).preferredColorScheme(.dark).buttonStyle(.plain)
    }
}
