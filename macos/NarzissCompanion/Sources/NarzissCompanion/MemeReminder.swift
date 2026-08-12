import AppKit
import Foundation

struct WorkMeme: Identifiable, Equatable, Sendable {
    let id: String
    let imageURL: URL
}

@MainActor
final class MemeReminderController: ObservableObject {
    @Published private(set) var currentMeme: WorkMeme?
    @Published private(set) var image: NSImage?

    var onVisibilityChange: ((Bool) -> Void)?
    var isPresentationAllowed: () -> Bool = { true }

    private static let enabledKey = "companion.workMemeRemindersEnabled"
    private let defaults: UserDefaults
    private let reminderInterval: TimeInterval
    private let displayDuration: Duration
    private let session: URLSession
    private var reminderTimer: Timer?
    private var dismissTask: Task<Void, Never>?
    private var imageTask: Task<Void, Never>?
    private var lastMemeID: String?

    init(
        defaults: UserDefaults = .standard,
        reminderInterval: TimeInterval = 20 * 60,
        displayDuration: Duration = .seconds(12)
    ) {
        self.defaults = defaults
        self.reminderInterval = reminderInterval
        self.displayDuration = displayDuration

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 12 * 1_024 * 1_024,
            diskCapacity: 60 * 1_024 * 1_024,
            diskPath: "NarzissWorkMemes"
        )
        session = URLSession(configuration: configuration)
    }

    var isEnabled: Bool {
        get {
            guard defaults.object(forKey: Self.enabledKey) != nil else { return true }
            return defaults.bool(forKey: Self.enabledKey)
        }
        set {
            defaults.set(newValue, forKey: Self.enabledKey)
            if newValue {
                scheduleNextReminder(after: reminderInterval)
            } else {
                reminderTimer?.invalidate()
                reminderTimer = nil
                dismiss()
            }
        }
    }

    func start() {
        guard isEnabled else { return }
        scheduleNextReminder(after: reminderInterval)
    }

    func stop() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        dismissTask?.cancel()
        imageTask?.cancel()
        dismiss()
    }

    @discardableResult
    func toggleEnabled() -> Bool {
        isEnabled.toggle()
        return isEnabled
    }

    func showNow(force: Bool = false) {
        guard isEnabled || force else { return }
        guard force || isPresentationAllowed() else {
            scheduleNextReminder(after: 2 * 60)
            return
        }

        let choices = Self.catalog.filter { $0.id != lastMemeID }
        guard let meme = choices.randomElement() ?? Self.catalog.first else { return }
        present(meme)
        if isEnabled { scheduleNextReminder(after: reminderInterval) }
    }

    func showPreview() {
        guard let meme = Self.catalog.first(where: { $0.id == "no-motivation" }) else { return }
        present(meme, visibleFor: .seconds(60))
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        imageTask?.cancel()
        imageTask = nil
        image = nil
        currentMeme = nil
        onVisibilityChange?(false)
    }

    private func scheduleNextReminder(after delay: TimeInterval) {
        reminderTimer?.invalidate()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showNow() }
        }
        RunLoop.main.add(timer, forMode: .common)
        reminderTimer = timer
    }

    private func present(_ meme: WorkMeme, visibleFor: Duration? = nil) {
        dismissTask?.cancel()
        imageTask?.cancel()
        lastMemeID = meme.id
        currentMeme = meme
        image = nil
        onVisibilityChange?(true)

        imageTask = Task { [weak self] in
            guard let self else { return }
            var request = URLRequest(url: meme.imageURL)
            request.timeoutInterval = 12
            request.cachePolicy = .returnCacheDataElseLoad
            guard
                let (data, response) = try? await session.data(for: request),
                (response as? HTTPURLResponse)?.statusCode == 200,
                !Task.isCancelled,
                currentMeme?.id == meme.id
            else { return }
            image = NSImage(data: data)
        }

        let duration = visibleFor ?? displayDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    // A deliberately small, office-safe allowlist. Images are fetched only when shown.
    private static let catalog: [WorkMeme] = [
        meme(
            "tired-cat",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00035-我累了猫.jpg"
        ),
        meme(
            "fishing",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00237-摸摸鱼.png"
        ),
        meme(
            "drink-water",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00248-再忙再累也要喝白开水.jpg"
        ),
        meme(
            "pressure",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00001-其实我觉得吧压力也没那么大.png"
        ),
        meme(
            "exception",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00010-对方不想和你说话并向你抛出了一个异常.jpg"
        ),
        meme(
            "wake-up",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00022-嗨嗨醒醒改该写代码了.jpg"
        ),
        meme(
            "serious-work",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/035TomAndJerry_猫和老鼠BQB/猫和老鼠00041-认真工作.jpg"
        ),
        meme(
            "go-rest",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/099p5r_女神异闻录_BQB/女神异闻录00005-今天很累了快去睡觉吧.png"
        ),
        meme(
            "no-motivation",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/093LiAn_李安_BQB/李安00006-一点工作的动力都没有.png"
        ),
        meme(
            "tomorrow-work",
            "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/107_FLittleBrother_葫芦兄弟_BQB/葫芦兄弟00012-怎么明天还要上班啊.png"
        )
    ]

    private static func meme(_ id: String, _ url: String) -> WorkMeme {
        WorkMeme(id: id, imageURL: URL(string: url)!)
    }
}
