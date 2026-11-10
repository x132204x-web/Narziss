import AppKit
import SwiftUI
import EventKit
import NotchCore

private enum Ink {
    static let muted = Color(white: 0.65)
    static let surface = Color(white: 0.085)
    static let accent = Color(red: 0.75, green: 0.87, blue: 0.63)
}

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var clipboard: ClipboardStore
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var music: MusicStore
    @StateObject private var timer = CountdownStore()
    var body: some View {
        VStack(spacing: 0) {
            if state.expanded {
                compactHeader
                HStack(spacing: 4) {
                    ForEach(NotchTab.allCases) { tab in
                        Button { state.tab = tab } label: {
                            Text(tab.rawValue).lineLimit(1)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 7).frame(height: 28)
                                .background(state.tab == tab ? Color.white.opacity(0.12) : .clear, in: Capsule())
                        }
                        .foregroundStyle(state.tab == tab ? .white : Ink.muted)
                        .help(tab.rawValue).accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(state.tab == tab ? .isSelected : [])
                    }
                    Spacer(minLength: 4)
                    iconButton(state.pinned ? "pin.fill" : "pin", "Keep notch open") { state.pinned.toggle() }
                        .foregroundStyle(state.pinned ? Ink.accent : Ink.muted)
                    iconButton("chevron.up", "Fold notch") { state.close() }
                }
                .padding(.horizontal, 12).padding(.top, 8)
                Group {
                    switch state.tab {
                    case .clock: ClockPane(timer: timer)
                    case .calendar: CalendarPane(store: calendar)
                    case .clipboard: ClipboardPane(store: clipboard, onModal: { state.interacting = $0 })
                    case .music: MusicPane(store: music)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: state.width, height: state.height, alignment: .top)
        .background(state.expanded ? Color.black : Color.clear, in: UnevenRoundedRectangle(bottomLeadingRadius: state.expanded ? 30 : 16,
                                                        bottomTrailingRadius: state.expanded ? 30 : 16))
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .buttonStyle(.plain).tint(Ink.accent)
        .contentShape(Rectangle())
        .onHover { state.hover($0) }
        .onExitCommand { state.close() }
    }
    private var compactHeader: some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                    .frame(maxWidth: .infinity)
            }
            Color.clear.frame(width: state.cameraWidth, height: state.topHeight)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                Image(systemName: timer.countdown.isRunning || timer.countdown.isPaused || timer.countdown.isFinished ? "timer" : (music.track?.playing == true ? "waveform" : "circle.dotted"))
                    .foregroundStyle(Ink.accent)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(music.track?.playing == true ? "Playing" : "Narziss")
                        .monospacedDigit()
                }
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: state.topHeight)
        .contentShape(Rectangle())
        .onTapGesture { if state.expanded { state.close() } else { state.expanded = true } }
        .accessibilityLabel("Narziss Notch. Click to fold or expand.")
    }
}

private func iconButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol).font(.system(size: 12, weight: .medium)).frame(width: 24, height: 24)
            .contentShape(Rectangle())
    }.help(title).accessibilityLabel(title)
}

private struct ActionButton: View {
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(.black).background(Ink.accent, in: Capsule())
        }
    }
}

@MainActor
private final class CountdownStore: ObservableObject {
    @Published var countdown = Countdown()
    @Published var minutes = 25
    private var ticker: Timer?
    init() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.countdown.isRunning else { return }
                if self.countdown.finishIfNeeded() { NSSound.beep() }
            }
        }
    }
    func start() { countdown.start(seconds: Double(minutes) * 60) }
    func label(at date: Date) -> String {
        let seconds = Int(ceil(countdown.remaining(at: date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    func compactLabel(at date: Date) -> String? {
        if countdown.isFinished { return "Done" }
        return countdown.isRunning || countdown.isPaused ? label(at: date) : nil
    }
    deinit { ticker?.invalidate() }
}

private struct ClockPane: View {
    @ObservedObject var timer: CountdownStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Countdown").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(timer.countdown.isFinished ? "Time’s up" : (timer.countdown.isPaused ? "Paused" : (timer.countdown.isRunning ? "Counting down" : "Ready")))
                        .font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
                HStack(spacing: 12) {
                    Text(timer.countdown.isRunning || timer.countdown.isPaused || timer.countdown.isFinished
                         ? timer.label(at: context.date) : String(format: "%02d:00", timer.minutes))
                        .font(.system(size: 44, weight: .light, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText()).foregroundStyle(timer.countdown.isFinished ? Ink.accent : .white)
                    Spacer(minLength: 0)
                    if timer.countdown.isRunning || timer.countdown.isPaused || timer.countdown.isFinished {
                        iconButton("arrow.counterclockwise", "Reset timer") { timer.countdown.reset() }
                    }
                    ActionButton(title: timer.countdown.isRunning ? "Pause" : (timer.countdown.isPaused ? "Resume" : "Start"),
                                 symbol: timer.countdown.isRunning ? "pause.fill" : "play.fill") {
                        if timer.countdown.isRunning { timer.countdown.pause() }
                        else if timer.countdown.isPaused { timer.countdown.resume() }
                        else { timer.start() }
                    }
                }
                HStack(spacing: 8) {
                    ForEach([5, 15, 25], id: \.self) { minutes in
                        Button { timer.minutes = minutes } label: {
                            Text("\(minutes) min").font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(timer.minutes == minutes ? .white.opacity(0.16) : Ink.surface, in: Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                    Stepper(value: $timer.minutes, in: 1...180) {
                        Text("\(timer.minutes) min").font(.system(size: 12)).monospacedDigit()
                    }.fixedSize().help("Custom duration, 1–180 minutes")
                }
                .disabled(timer.countdown.isRunning || timer.countdown.isPaused)
            }
        }
    }
}

private struct CalendarPane: View {
    @ObservedObject var store: CalendarStore
    private let cal = Calendar.current
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text(store.month, format: .dateTime.month(.wide).year()).font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                    iconButton("chevron.left", "Previous month") { store.moveMonth(-1) }
                    iconButton("chevron.right", "Next month") { store.moveMonth(1) }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(cal.veryShortStandaloneWeekdaySymbols[(cal.firstWeekday - 1 + index) % 7])
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.muted).frame(height: 14)
                    }
                    ForEach(CalendarMonth.days(containing: store.month, calendar: cal), id: \.self) { day in
                        let selected = cal.isDate(day, inSameDayAs: store.selectedDate)
                        Button { store.select(day) } label: {
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 11, weight: cal.isDateInToday(day) ? .bold : .regular))
                                .frame(maxWidth: .infinity).frame(height: 20)
                                .foregroundStyle(selected ? .black : (cal.isDate(day, equalTo: store.month, toGranularity: .month) ? .white : Ink.muted.opacity(0.55)))
                                .background(selected ? Ink.accent : .clear, in: Circle())
                                .overlay(Circle().strokeBorder(cal.isDateInToday(day) && !selected ? Ink.accent : .clear))
                        }
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                Button("Back to today") { store.today() }.font(.system(size: 11)).foregroundStyle(Ink.accent)
            }.frame(width: 174)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
            VStack(alignment: .leading, spacing: 10) {
                Text(store.selectedDate, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 16, weight: .medium))
                if store.hasAccess {
                    if store.events.isEmpty {
                        Text("Room to breathe.").font(.system(size: 13, weight: .medium))
                        Text("No events for this day.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(Array(store.events.enumerated()), id: \.offset) { _, event in
                                    HStack(alignment: .top, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 2).fill(Color(cgColor: event.calendar.cgColor)).frame(width: 3)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.title ?? "Untitled event").font(.system(size: 12, weight: .medium)).lineLimit(2)
                                            Text(event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened))
                                                .font(.system(size: 11)).foregroundStyle(Ink.muted)
                                        }
                                    }.fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                } else {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 26)).foregroundStyle(Ink.accent)
                    Text(store.message ?? (store.isDenied ? "Allow calendar access in System Settings to see your events." : "Your schedule, a glance away."))
                        .font(.system(size: 12)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                    ActionButton(title: store.isDenied ? "Settings" : "Connect", symbol: "calendar") {
                        if store.isDenied { openPrivacy("Calendars") } else { store.connect() }
                    }
                }
                Spacer(minLength: 0)
                Button("Open Calendar ↗") { NSWorkspace.shared.open(URL(string: "ical://")!) }
                    .font(.system(size: 11)).foregroundStyle(Ink.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ClipboardPane: View {
    @ObservedObject var store: ClipboardStore
    var onModal: (Bool) -> Void
    @State private var confirmClear = false
    @State private var editing = false
    @State private var editingID: UUID?
    @State private var draftTitle = ""
    @State private var draftText = ""
    @State private var deleting: SavedSnippet?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clipboard history").font(.system(size: 15, weight: .medium))
                Spacer()
                Toggle("Capture", isOn: $store.isEnabled).toggleStyle(.switch).controlSize(.mini)
                    .font(.system(size: 11)).help("Capture new text copies while enabled")
                Menu {
                    Button("Clear recent clips") { store.clearRecents() }
                    Button("Clear all recent clips…", role: .destructive) { confirmClear = true }
                } label: { Image(systemName: "ellipsis").frame(width: 26, height: 26) }
                .menuStyle(.borderlessButton).fixedSize().help("Manage history")
            }
            HStack(spacing: 12) {
                Button("Recent") { store.showingSaved = false }
                    .foregroundStyle(store.showingSaved ? Ink.muted : Ink.accent)
                Button("Starred (\(store.saved.count))") { store.showingSaved = true }
                    .foregroundStyle(store.showingSaved ? Ink.accent : Ink.muted)
                Spacer()
                if store.showingSaved {
                    iconButton("plus", "Add a clip") {
                        editingID = nil; draftTitle = ""; draftText = ""; editing = true
                    }
                }
            }.font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Ink.muted)
                TextField("Search your clips", text: $store.query).textFieldStyle(.plain)
                if !store.query.isEmpty { iconButton("xmark.circle.fill", "Clear search") { store.query = "" } }
            }
            .font(.system(size: 12)).padding(.horizontal, 12).frame(height: 28).background(Ink.surface, in: RoundedRectangle(cornerRadius: 9))
            if store.showingSaved {
                if store.filteredSaved.isEmpty {
                    VStack(spacing: 8) {
                        Text(store.query.isEmpty ? "Keep useful information close." : "No matching starred clips.").font(.system(size: 13, weight: .medium))
                        Text("Star a recent clip to keep it here.").font(.system(size: 11)).foregroundStyle(Ink.muted)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(store.filteredSaved) { snippet in
                                HStack(spacing: 4) {
                                    Button { store.copySaved(snippet) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(snippet.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                            Text(store.copiedID == snippet.id ? "Copied" : snippet.text).font(.system(size: 11))
                                                .foregroundStyle(Ink.muted).lineLimit(2)
                                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                    }.help("Copy starred clip")
                                    iconButton("pencil", "Edit starred clip") {
                                        editingID = snippet.id; draftTitle = snippet.title; draftText = snippet.text; editing = true
                                    }
                                    iconButton("trash", "Delete starred clip") { deleting = snippet }
                                }.padding(8).background(Ink.surface, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            } else if store.filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 28)).foregroundStyle(Ink.accent)
                    Text(store.query.isEmpty ? (store.isEnabled ? "Copy something. Find it here." : "Keep useful things close.") : "No matching clips.")
                        .font(.system(size: 14, weight: .medium))
                    Text(store.query.isEmpty ? (store.isEnabled ? "New text copies appear here automatically." : "Turn on Capture to save new text copies.") : "Try a different search.")
                        .font(.system(size: 12)).foregroundStyle(Ink.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.filtered) { clip in
                            HStack(spacing: 8) {
                                Button { store.copy(clip) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.text).font(.system(size: 12)).lineLimit(2).multilineTextAlignment(.leading)
                                        Text(store.copiedID == clip.id ? "Copied to clipboard" : "\(clip.text.count) characters · Click to copy")
                                            .font(.system(size: 10)).foregroundStyle(store.copiedID == clip.id ? Ink.accent : Ink.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.help("Copy this item")
                                iconButton(store.isStarred(clip) ? "star.fill" : "star", store.isStarred(clip) ? "Unstar clip" : "Star clip permanently") {
                                    store.toggleStar(clip)
                                }.foregroundStyle(store.isStarred(clip) ? Ink.accent : Ink.muted)
                                iconButton("xmark", "Delete item") { store.remove(clip) }.foregroundStyle(Ink.muted)
                            }.padding(8).background(Ink.surface, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            HStack {
                Text(store.showingSaved ? "Starred clips stay after quitting" : "\(store.history.items.count)/\(store.history.limit) recent clips · Memory only").font(.system(size: 10))
                Spacer()
                Text(store.isEnabled ? "Capturing text" : "Capture paused").font(.system(size: 10))
            }.foregroundStyle(Ink.muted)
        }
        .onChange(of: editing) { _, open in onModal(open) }
        .sheet(isPresented: $editing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(editingID == nil ? "Add a clip" : "Edit clip").font(.system(size: 18, weight: .semibold))
                TextField("Title (optional)", text: $draftTitle).textFieldStyle(.roundedBorder)
                TextEditor(text: $draftText).font(.system(size: 13)).frame(minHeight: 160)
                HStack {
                    Button("Cancel") { editing = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    ActionButton(title: "Save", symbol: "square.and.arrow.down") {
                        if store.save(title: draftTitle, text: draftText, id: editingID) { editing = false; store.showingSaved = true }
                    }.disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(20).frame(width: 340).preferredColorScheme(.dark).buttonStyle(.plain)
        }
        .alert("Starred clips", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("OK") { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
        .alert("Delete starred clip?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let snippet = deleting { store.deleteSaved(snippet) }; deleting = nil }
        } message: { Text("This removes the starred clip from this Mac.") }
        .alert("Clear all clipboard history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear all", role: .destructive) { store.clearAll() }
        } message: { Text("Recent clips will be removed. Starred clips and your current system clipboard stay as they are.") }
    }
}

private struct MusicPane: View {
    @ObservedObject var store: MusicStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOW PLAYING").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(Ink.muted)
                Spacer()
                Toggle("Connect media", isOn: $store.isEnabled).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
            }
            if let track = store.track {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(Ink.surface)
                        Circle().stroke(Ink.accent.opacity(0.35), lineWidth: 1).padding(12)
                        Circle().stroke(Ink.accent.opacity(0.2), lineWidth: 1).padding(22)
                        Image(systemName: "music.note").font(.system(size: 34, weight: .light)).foregroundStyle(Ink.accent)
                    }.frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(track.title).font(.system(size: 18, weight: .medium)).lineLimit(2)
                        Text(track.artist).font(.system(size: 13)).foregroundStyle(Ink.muted).lineLimit(1)
                        Text(track.appName).font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.accent)
                    }
                    Spacer(minLength: 0)
                }
                VStack(spacing: 6) {
                    ProgressView(value: min(max(track.position, 0), max(track.duration, 1)), total: max(track.duration, 1)).tint(Ink.accent)
                    HStack {
                        Text(timestamp(track.position)); Spacer(); Text(timestamp(track.duration))
                    }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Ink.muted)
                }
                HStack(spacing: 30) {
                    Spacer()
                    iconButton("backward.end.fill", "Previous track") { store.send("previous track") }
                    Button { store.send("playpause") } label: {
                        Image(systemName: track.playing ? "pause.fill" : "play.fill").font(.system(size: 22))
                            .frame(width: 42, height: 42).foregroundStyle(.black).background(Ink.accent, in: Circle())
                    }.accessibilityLabel(track.playing ? "Pause" : "Play")
                    iconButton("forward.end.fill", "Next track") { store.send("next track") }
                    Spacer()
                }
                if let message = store.message { Text(message).font(.system(size: 11)).foregroundStyle(Ink.muted).lineLimit(2) }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "hifispeaker.fill").font(.system(size: 42, weight: .light)).foregroundStyle(Ink.accent)
                    Text(store.isEnabled ? "Give your day a soundtrack." : "Your music, within reach.")
                        .font(.system(size: 18, weight: .medium))
                    Text(store.message ?? (store.isEnabled ? "Play a video, podcast, or track in any app that supports macOS Now Playing." : "Connect to show the Mac’s active media and control playback."))
                        .font(.system(size: 12)).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
                    HStack(spacing: 14) {
                        Button("Open Music ↗") { openPlayer("com.apple.Music") }
                        Button("Open Spotify ↗") { openPlayer("com.spotify.client") }
                    }.font(.system(size: 12)).foregroundStyle(Ink.accent)
                    if store.message != nil {
                        Button("Try again") { Task { await store.refresh() } }.font(.system(size: 11)).foregroundStyle(Ink.muted)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private func timestamp(_ value: Double) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private func openPlayer(_ id: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

private func openPrivacy(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") {
        NSWorkspace.shared.open(url)
    }
}
