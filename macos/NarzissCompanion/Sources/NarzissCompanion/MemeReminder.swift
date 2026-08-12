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
    private var lowResolutionMemeIDs = Set<String>()

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

        let choices = Self.catalog
            .filter { $0.id != lastMemeID && !lowResolutionMemeIDs.contains($0.id) }
            .shuffled()
        presentFirstSuitable(from: choices)
        if isEnabled { scheduleNextReminder(after: reminderInterval) }
    }

    func showPreview() {
        let choices = Self.catalog.filter { !lowResolutionMemeIDs.contains($0.id) }
        presentFirstSuitable(from: choices, visibleFor: .seconds(60))
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

    private func presentFirstSuitable(from memes: [WorkMeme], visibleFor: Duration? = nil) {
        dismissTask?.cancel()
        imageTask?.cancel()
        image = nil
        currentMeme = nil
        onVisibilityChange?(false)

        imageTask = Task { [weak self] in
            guard let self else { return }
            for meme in memes {
                guard !Task.isCancelled else { return }
                var request = URLRequest(url: meme.imageURL)
                request.timeoutInterval = 12
                request.cachePolicy = .returnCacheDataElseLoad
                guard
                    let (data, response) = try? await session.data(for: request),
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    let candidateImage = NSImage(data: data)
                else { continue }

                guard Self.hasEnoughPixels(candidateImage) else {
                    lowResolutionMemeIDs.insert(meme.id)
                    continue
                }

                guard !Task.isCancelled else { return }
                lastMemeID = meme.id
                currentMeme = meme
                image = candidateImage
                onVisibilityChange?(true)
                scheduleDismiss(after: visibleFor ?? displayDuration)
                return
            }
        }
    }

    private func scheduleDismiss(after duration: Duration) {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private static func hasEnoughPixels(_ image: NSImage) -> Bool {
        let pixelWidth = image.representations.map(\.pixelsWide).max() ?? 0
        let pixelHeight = image.representations.map(\.pixelsHigh).max() ?? 0

        // The image is rendered inside a 220 x 170 point frame. Requiring roughly
        // double that resolution prevents visibly pixelated upscaling on Retina displays.
        return pixelWidth >= 440 || pixelHeight >= 340
    }

    // Exactly 100 office-safe, work-related images. Only the selected URL is fetched.
    private static let catalogURLs: [String] = [
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/001Funny_滑稽大佬😏BQB/滑稽大佬00015-喝咖啡-咖啡.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/001Funny_滑稽大佬😏BQB/滑稽大佬00051-稍加思索恍然大悟明白110.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/001Funny_滑稽大佬😏BQB/滑稽大佬00065-可以这很滑稽.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/001Funny_滑稽大佬😏BQB/滑稽大佬00085-滑稽震惊.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00021-给你吃.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00030-喝酸奶.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00039-啊哈.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00051-风吹脑门儿.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00063-哇超棒.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/003CuteBoy_可爱男孩纸👶BQB/可爱男孩纸00026-囧表情.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/003CuteBoy_可爱男孩纸👶BQB/可爱男孩纸00027-满脸单纯.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00006-不想说话想冷场.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00007-勉强假笑.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00008-瞪大眼睛-瞪眼.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00012-背光无奈假笑.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00015-假笑.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/004SmirkBoy_假笑男孩👦BQB/假笑男孩00026-假笑不说话.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00001-今天不想加油鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00008-哎鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00009-尼在干嘛鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00010-对不起鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00011-苍天鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/008HappyDuck_开心鸭🐥BQB/开心鸭00012-冲鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00014-猫问号-疑问猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00088-歪头笑眯眯猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00089-歪头不开心猫.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00118-我睡着惹-晚安-我睡着了猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/002CuteGirl_可爱的女孩纸👧BQB/可爱的女孩纸00189-ohmyGod我的天啊当公主真累.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/005ShowerheadBoy_莲蓬头男孩👲BQB/莲蓬头男孩00008-关机下班80到手.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00035-我累了猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00057-感到鸭力-感到压力猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00121-敲可爱猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00060-你打代码像蔡徐坤.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00237-摸摸鱼.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00246-提醒喝水小助手.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00248-再忙再累也要喝白开水.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/010Cat_是喵星人啦🐱BQB/是喵星人啦00141-疑问猫.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/021TongfuInn_同福客栈🏫BQB/同福客栈00087-我不困.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00001-其实我觉得吧压力也没那么大.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00002-反复滑稽.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00003-老夫写代码就用jQuery.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00005-妈妈说你什么都好就不该是个程序员.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00007-MyCodeCodeOnStackOverFlow.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00008-有rm-rf数据恢复经验.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/011Dog_狗🐶BQB/狗00018-微笑.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00010-对方不想和你说话并向你抛出了一个异常.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00011-等我写完了代码我也要和你们一起玩.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00012-Ping999.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/011Dog_狗🐶BQB/狗00021-强颜欢笑.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00014-深度学习.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00015-真的假的.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00016-抱歉我们想找的是22-26岁有30年工作经验的员工.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/014Pig_猪🐖BQB/猪00009-晚安睡了.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00019-你别急等我剪完这个头发再修BUG.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00020-对方不想和你说话并向你扔了一堆BUG.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00041-无语.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00022-嗨嗨醒醒改该写代码了.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00023-留下了没技术的泪水.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00026-我想做NLP找个好人家.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00027-Star皆空.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00033-摘要模型数据评估.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/015Golden_Curator_Panda金馆长熊猫🐼BQB/金馆长熊猫00050-震惊.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00035-myBeautifulCode.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00036-AiIfElse.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00038-向优秀程序员低头.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00041-C加加代码.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00042-我的内心非常Excited甚至还想再写两行代码.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00044-有时候我的代码会像这样不知道是干什么的但是有不敢删掉.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00046-呦写bug呢.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/021TongfuInn_同福客栈🏫BQB/同福客栈00028-老兄您真是厉害啊.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/021TongfuInn_同福客栈🏫BQB/同福客栈00036-问号疑问.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/023Emoji_表情符号BQB/Emoji00133-那我就鼓掌呗.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/024Programmer_程序员BQB/程序员00053-你竟然在代码里下毒.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/035TomAndJerry_猫和老鼠BQB/猫和老鼠00020-爱情工作生活我.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/035TomAndJerry_猫和老鼠BQB/猫和老鼠00041-认真工作.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/035TomAndJerry_猫和老鼠BQB/猫和老鼠00086-困迷茫对什么都提不起兴趣.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/043Altman_奥特曼BQB/奥特曼00239-我累了.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/051Call_打电话BQB/打电话00050-歪你的小宝贝困了.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/057HappyDuck_开心鸭BQB/开心鸭00020-刚下班鸭.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/061KeNan_柯南BQB/柯南00087-喝水.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/061KeNan_柯南BQB/柯南00108-好困.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/061KeNan_柯南BQB/柯南00172-困.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/078BeiFang_北方栖姬_BQB/北方栖姬00098-累成狗.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/078BeiFang_北方栖姬_BQB/北方栖姬00106-为什么不困.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/078BeiFang_北方栖姬_BQB/北方栖姬00150-对不起我是来摸鱼的.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/078BeiFang_北方栖姬_BQB/北方栖姬00267-心好累.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/078BeiFang_北方栖姬_BQB/北方栖姬00334-困了我去睡了晚安.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/023Emoji_表情符号BQB/Emoji00135-明白.JPG",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/093LiAn_李安_BQB/李安00006-一点工作的动力都没有.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/065TravelFrog_旅行青蛙🐸BQB/旅行青蛙00009-思考ing.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/095GenShin_原神_BQB/原神00076-摸鱼.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/096NationalDay_国庆节_BQB/国庆节00003-你国庆加班.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/096NationalDay_国庆节_BQB/国庆节00012-八号上班泡好茶听人诉苦讲故事.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/096NationalDay_国庆节_BQB/国庆节00028-你国庆加班还没有加班费伙食还要自费因为管伙食的不加班.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/098spyxfamily_间谍过家家_BQB/间谍过家家00013-摸鱼还得是我.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/099p5r_女神异闻录_BQB/女神异闻录00005-今天很累了快去睡觉吧.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/103EmpressesInThePalace_甄嬛传💃_BQB/甄嬛传00028-还有五分钟就下班了.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/105_BlackMythWuKong_黑神话悟空🐒_BQB/黑神话悟空00012-嗯你8月20号必须休息.jpg",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/107_FLittleBrother_葫芦兄弟_BQB/葫芦兄弟00012-怎么明天还要上班啊.png",
        "https://raw.githubusercontent.com/zhaoolee/ChineseBQB/master/107_FLittleBrother_葫芦兄弟_BQB/葫芦兄弟00014-下班勿cue.png",
    ]

    private static let catalog: [WorkMeme] = catalogURLs.enumerated().map { index, url in
        WorkMeme(id: String(index), imageURL: URL(string: url)!)
    }
}
