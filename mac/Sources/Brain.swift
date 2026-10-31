import Foundation

// ---------- 不接 AI 时的“小脑袋”：记住你说的事、读懂情绪、接着话头问下去、不懂的就去网上帮你搜 ----------
struct BrainState {
    var lastFeeling = ""
    var lastFeelingAt = -999.0
    var askedFollowUp = false
    var followTopic = ""
    var usedLines: [String] = []
}

let STOP_CHARS: Swift.Set<Character> = ["，", "。", "！", "？", ",", ".", "!", "?", "~", "～", "；", ";", "\n", " "]

func Has(_ m: String, _ ks: String...) -> Bool { ks.contains { m.contains($0) } }

func FirstStop(_ s: String) -> Int { for (i, c) in s.enumerated() where STOP_CHARS.contains(c) { return i }; return -1 }

extension PetForm {
    func PickFresh(_ options: [String]) -> String {
        var fresh = options.filter { !brain.usedLines.contains($0) }
        if fresh.isEmpty { fresh = options }
        if fresh.isEmpty { return "" }
        let p = fresh[rnd.Next(fresh.count)]
        brain.usedLines.append(p)
        if brain.usedLines.count > 60 { brain.usedLines.removeFirst() }
        return p
    }

    static func Reflect(_ s: String) -> String {
        return s.Replace("我们", "\u{1}").Replace("我", "你").Replace("\u{1}", "我们").Replace("咱", "我们")
    }

    static func After(_ msg: String, _ keys: [String], _ key: inout String?) -> String? {
        key = nil
        for k in keys {
            let i = msg.IndexOf(k)
            if i < 0 { continue }
            var rest = msg.Sub(i + k.count)
            let e = FirstStop(rest)
            if e >= 0 { rest = rest.Sub(0, e) }
            rest = rest.Trim
            if rest.count > 14 { rest = rest.Sub(0, 14) }
            if rest.isEmpty { continue }
            key = k
            return rest
        }
        return nil
    }


    func Remember(_ fact: String) {
        for n in memoryNotes where n.hasSuffix(fact) { return }
        memoryNotes.append(Fmt(Date(), "M/d") + " " + fact)
        SaveMemory()
    }

    func Facts(_ prefix: String) -> [String] {
        var r: [String] = []
        for n in memoryNotes { let i = n.IndexOf(prefix); if i >= 0 { r.append(n.Sub(i + prefix.count).Trim) } }
        return r
    }

    // 按性格给句子加点味道
    func Flavor(_ line0: String) -> String {
        var line = line0
        if personality == "lively" { if rnd.NextDouble() < 0.6 { line = line.Replace("。", "！") } }
        else if personality == "lazy" {
            if rnd.NextDouble() < 0.5 { while line.hasSuffix("。") { line.removeLast() }; line += "～" }
            if rnd.NextDouble() < 0.15 { line += "（打了个哈欠）" }
        } else if personality == "tsundere" {
            let b = line.IndexOf("]")
            if rnd.NextDouble() < 0.35 && b > 0 { line = line.Sub(0, b + 1) + " 哼，" + line.Sub(b + 1).trimmingCharacters(in: .whitespaces) }
        } else if personality == "scholar" && rnd.NextDouble() < 0.2 { line += "（这个我得记进小本本。）" }
        return line
    }

    // 返回 nil 表示要去网上查，查完再回答
    func LocalThink(_ msg: String) -> String? {
        let m = msg.Trim
        let h = Hour()
        var k: String? = nil
        let N = Names.Nick

        // ---- 打招呼、道别、感谢 ----
        if Has(m, "晚安") { return PickFresh(["[困] 晚安 " + N + "，今天辛苦啦，做个软软的梦。", "[爱心] 晚安～明天醒来我还在这儿。", "[困] 去睡吧，我帮你守着桌面。"]) }
        if Has(m, "早安", "早上好", "早啊") { return PickFresh(["[开心] 早安 " + N + "！今天第一件事打算做什么？", "[眨眼] 早～睡得好吗？", "[开心] 早上好！我已经在程序坞上晒了一会儿太阳了。"]) }
        if Has(m, "你好", "嗨", "哈喽", "在吗", "在不在") || m.lowercased() == "hi" || m.lowercased() == "hello" {
            return PickFresh(["[开心] 在的在的！" + N + " 找我呀？", "[眨眼] 嗨～我一直都在。", "[开心] 来啦！今天过得怎么样？", h >= 23 || h < 5 ? "[困] 这么晚还找我，是睡不着吗？" : "[眨眼] 嗨 " + N + "，正想你呢。"])
        }
        if Has(m, "谢谢", "感谢", "多谢") { return PickFresh(["[害羞] 不客气嘛～", "[开心] 能帮上忙我就很开心了。", "[害羞] 嘿……被谢谢了，有点不好意思。"]) }
        if Has(m, "拜拜", "再见", "走了", "下线") { return PickFresh(["[想你] 拜拜～早点回来哦。", "[开心] 去吧去吧，我在这儿等你。", "[难过] 这就走啦……那下次见！"]) }

        // ---- 关于桌宠自己 ----
        if Has(m, "你的生日", "你生日", "你几岁", "你多大") {
            if Festival() == "petbday" { return "[跳舞] 就是今天！今天是我的生日！可以给我唱首歌吗？" }
            var md = PetBday().Replace("-", " 月 ")
            while md.hasPrefix("0") { md.removeFirst() }
            return "[开心] 我的生日是 " + md + " 日，那天我来到了你的桌面。到时候要记得哦～"
        }
        if Has(m, "生日快乐") && Festival() == "petbday" { AddAff(5); return "[爱心] 谢谢 " + N + "！这是我第一次……不对，是最开心的一次生日！" }
        if Has(m, "你是谁", "你叫什么", "你的名字") { return "[眨眼] 我是" + Names.Pet + "，住在 " + N + " 桌面上的像素小伙伴。今天是我们认识的第 \(DaysTogether()) 天。" }
        if Has(m, "你喜欢什么", "你爱吃", "你喜欢吃") { return PickFresh(["[开心] 我最喜欢小橘子！还有被摸头。", "[眨眼] 喜欢晒太阳、听你说话，还有橘子。你呢？"]) }
        if Has(m, "你在干嘛", "你在做什么", "你干嘛呢") { return PickFresh(["[发呆] 在看你的桌面发呆，图标排得挺好看的。", "[眨眼] 在想你什么时候会来找我说话，然后你就来了。", "[开心] 在练习走路不摔跤。"]) }
        if Has(m, "你开心吗", "你还好吗", "你怎么样") { return aff >= 70 ? "[爱心] 有你陪着就很开心！" : hunger > 60 ? "[难过] 有点饿……其他都挺好的。" : "[开心] 挺好的！你呢？" }
        if Has(m, "可爱", "喜欢你", "爱你", "真棒", "好乖") { AddAff(2); return PickFresh(["[害羞] 唔……突然这么说，我整个都要红了。", "[爱心] 我也最喜欢 " + N + " 了！", "[害羞] 再、再说一遍？我没听清。"]) }
        if Has(m, "笨", "丑", "讨厌你", "傻") { return PickFresh(["[生气] 哼！我可是很可爱的！", "[难过] 呜……那我努力变聪明一点。", "[生气] 你再说我就躲进纸箱里了！"]) }

        // ---- 记住 m 告诉我的事 ----
        if let like = PetForm.After(m, ["我最喜欢", "我喜欢", "我爱", "我超爱"], &k), !Has(m, "不喜欢") {
            Remember(N + " 喜欢" + like)
            return Flavor(PickFresh([
                "[开心] 你喜欢" + like + "呀！我记住了。是从什么时候开始喜欢的？",
                "[眨眼] " + like + "！记下来了。它哪里最打动你？",
                "[开心] 原来 " + N + " 喜欢" + like + "，以后我看到相关的就想到你。"]))
        }
        if let dislike = PetForm.After(m, ["我不喜欢", "我讨厌", "我受不了"], &k) {
            Remember(N + " 不喜欢" + dislike)
            return Flavor(PickFresh(["[疑惑] 不喜欢" + dislike + "啊……是发生过什么吗？", "[眨眼] 好，记住了，以后不提" + dislike + "。"]))
        }
        if let plan = PetForm.After(m, ["明天要", "明天得", "下周要", "我打算", "我准备", "我要去", "我得去"], &k) {
            Remember(N + " " + k!.Replace("我", "") + plan)
            brain.followTopic = plan
            return Flavor(PickFresh(["[开心] " + PetForm.Reflect(k!) + plan + "！需要我到时候提醒你吗？可以说“几点提醒我……”。", "[眨眼] 记下了，" + plan + "加油！准备得怎么样了？"]))
        }
        if let doing = PetForm.After(m, ["我正在", "我在做", "我在写", "我在画", "我在弄", "我在学"], &k) {
            brain.followTopic = doing
            let verb = k! == "我正在" ? "" : k!.Sub(2)
            return Flavor(PickFresh(["[疑惑] " + verb + doing + "呀，顺利吗？", "[开心] 在" + verb + doing + "！听起来很认真，要不要我安静陪着你？", "[眨眼] " + doing + "进行到哪一步啦？"]))
        }

        // ---- 情绪 ----
        var feel = ""
        if Has(m, "累", "困", "疲惫", "没精神", "好困", "熬夜") { feel = "tired" }
        else if Has(m, "难过", "伤心", "想哭", "哭了", "委屈", "失落", "不开心", "郁闷", "emo", "心情不好") { feel = "sad" }
        else if Has(m, "焦虑", "压力", "紧张", "担心", "崩溃", "来不及", "做不完", "ddl", "DDL", "截止") { feel = "anxious" }
        else if Has(m, "生气", "气死", "烦死", "无语", "火大", "烦") { feel = "angry" }
        else if Has(m, "开心", "高兴", "太好了", "成功了", "搞定", "哈哈", "耶", "爽", "好棒") { feel = "happy" }
        else if Has(m, "无聊", "没意思", "好闲") { feel = "bored" }
        else if Has(m, "饿", "想吃", "没吃饭") { feel = "hungry" }
        if feel != "" {
            brain.lastFeeling = feel; brain.lastFeelingAt = now; brain.askedFollowUp = true
            switch feel {
            case "tired":
                return Flavor(PickFresh([
                    h >= 23 || h < 5 ? "[困] 都这么晚了，累是正常的……今天就到这儿好不好？" : "[困] 辛苦了。是昨晚没睡好，还是今天事情太多？",
                    "[爱心] 累了就靠在椅背上闭眼一分钟，我帮你数着。",
                    "[困] 我也有点困……要不我们一起伸个懒腰？"]))
            case "sad":
                return PickFresh(["[难过] 抱抱 " + N + "。想说说发生了什么吗？不想说也没关系，我就在这儿。", "[爱心] 难过的时候不用硬撑，我陪着你。", "[难过] 嗯……我在听。是今天发生的事吗？"])
            case "anxious":
                return Flavor(PickFresh(["[爱心] 先深呼吸一下。最着急的是哪一件？我们一件一件来。", "[疑惑] 压力好大的样子……要不要我帮你开个番茄钟，先专心做 25 分钟？", "[爱心] 你已经在很努力了。离截止还有多久呀？"]))
            case "angry":
                return Flavor(PickFresh(["[生气] 谁惹你了？我帮你瞪它！", "[疑惑] 怎么啦？说出来会舒服一点。", "[生气] 哼，先别气坏自己，喝口水再跟我说。"]))
            case "happy":
                return Flavor(PickFresh(["[跳舞] 太好啦！快告诉我是什么好事！", "[开心] 看你开心我也开心，转个圈庆祝一下～", "[跳舞] 耶！今天值得多吃一个橘子！"]))
            case "bored":
                return Flavor(PickFresh(["[眨眼] 无聊的话，要不要看我跳舞？右键「跳个舞」。", "[疑惑] 那我们来聊点奇怪的：你觉得云摸起来是什么感觉？", "[开心] 喂我个橘子吧，我可以表演吃橘子。"]))
            case "hungry":
                return Flavor(PickFresh(["[想你] 我也饿了……你想吃什么？", "[开心] 快去吃点好吃的！回来告诉我吃了什么。", "[眨眼] 饿着肚子可干不好活，先去吃饭！"]))
            default: break
            }
        }

        // ---- 问题 ----
        let question = m.hasSuffix("？") || m.hasSuffix("?") || Has(m, "什么是", "是什么", "为什么", "怎么", "如何", "多少", "哪里", "哪个", "是谁", "什么时候", "几号", "吗", "呢")
        if question {
            brain.askedFollowUp = false
            let hm = Fmt(Date(), "HH:mm")
            if Has(m, "睡") { return h >= 23 || h < 5 ? "[困] 该睡啦！现在已经 " + hm + " 了，剩下的明天再说。" : h >= 21 ? "[眨眼] 还不算太晚，不过可以开始收尾了，别熬太久。" : "[疑惑] 现在才 " + hm + "，是太累了吗？困了就小睡一会儿。" }
            if Has(m, "吃什么", "吃啥") { return PickFresh(["[开心] 我投一票热乎乎的汤面！", "[眨眼] 吃点有蔬菜的吧，然后饭后来点水果，比如……橘子。", "[疑惑] 想吃清淡的还是想吃重口的？"]) }
            if Has(m, "几点", "现在时间") { return "[眨眼] 现在 " + hm + " 啦。" }
            if Has(m, "天气", "下雨", "冷不冷", "热不热") { return weatherText != "" ? "[眨眼] 外面现在大概 " + weatherText + (weatherKind == "rain" ? "，在下雨，出门带伞！" : weatherKind == "cold" ? "，有点冷，多穿点。" : weatherKind == "hot" ? "，挺热的，多喝水。" : "，还挺舒服的。") : "[疑惑] 我还没查到天气，可能是网络不通。" }
            if Has(m, "第几天", "认识多久") { return "[爱心] 今天是我们认识的第 \(DaysTogether()) 天！" }
            if !m.contains("你") && m.count >= 4 { return nil }   // 知识类问题去网上搜
            return Flavor(PickFresh(["[疑惑] 唔，这个问题让我想想……你自己是怎么想的？", "[眨眼] 我的小脑袋还在转，先听听你的想法？", "[发呆] 好难的问题。我猜……一半一半？", "[开心] 这个嘛，我觉得跟着你的心意来就好。"]))
        }

        // ---- 回答我刚才问的问题：接着话头 ----
        if brain.askedFollowUp && m.count >= 4 && now - brain.lastFeelingAt < 600 {
            brain.askedFollowUp = false
            var echo = m; let cut = FirstStop(echo); if cut > 2 { echo = echo.Sub(0, cut) }; if echo.count > 16 { echo = echo.Sub(0, 16) + "…" }
            echo = PetForm.Reflect(echo)
            switch brain.lastFeeling {
            case "sad": return PickFresh(["[难过] 原来是" + echo + "……换作是我也会难受的。你现在好一点了吗？", "[爱心] 嗯，" + echo + "，这确实不好受。谢谢你愿意告诉我。"])
            case "anxious": return PickFresh(["[爱心] " + echo + "……那我们先把最小的一步做掉，好不好？", "[疑惑] 明白了。需要我定个提醒，帮你盯着时间吗？"])
            case "angry": return PickFresh(["[生气] " + echo + "？那确实很让人生气！", "[爱心] 换我也会气的。说出来是不是舒服点了？"])
            case "tired": return PickFresh(["[困] " + echo + "，难怪会累。今天早点休息吧。", "[爱心] 那你真的辛苦了，等下记得喝点热水。"])
            case "happy": return PickFresh(["[跳舞] " + echo + "！太厉害了吧！", "[开心] 哇，" + echo + "，我要把这件事写进今天的日记！"])
            default: break
            }
        }

        // ---- 想聊天 ----
        if Has(m, "聊聊", "聊天", "陪我", "说说话") {
            return Flavor(PickFresh(["[开心] 好呀！那我先问：你今天最开心的一个瞬间是什么？", "[眨眼] 来！你最近有没有特别想吃、想去、或者想做的事？", "[疑惑] 好啊～如果可以变成任何一种动物待一天，你想变成什么？", "[开心] 聊什么都行！要不你讲讲今天都做了什么？"]))
        }

        // ---- 闲聊的小感叹 ----
        if Has(m, "天气") && Has(m, "好", "不错", "晴") { return PickFresh(["[开心] 是吧！这种天气最适合晒太阳了，你要不要出去走走？", "[眨眼] 天气好的时候，连像素都亮一点。"]) }
        if Has(m, "下雨", "下雪", "好冷", "好热") { return PickFresh(["[发呆] 这种天气就适合待在屋里，听雨声做事。", "[困] 天气这样，记得照顾好自己哦。"]) }
        if Has(m, "真不错", "真好", "好美", "好看", "好好吃", "好喜欢") { return Flavor(PickFresh(["[开心] 听起来就让人心情变好！", "[眨眼] 能让你这么说，一定很棒。给我也讲讲？"])) }

        // ---- 其他：认真听，接着聊，偶尔提起以前说过的事 ----
        let likes = Facts(N + " 喜欢")
        var snippet = m; let c2 = FirstStop(snippet); if c2 > 2 { snippet = snippet.Sub(0, c2) }; if snippet.count > 12 { snippet = snippet.Sub(0, 12) + "…" }
        var pool: [String] = []
        pool.append("[眨眼] “" + PetForm.Reflect(snippet) + "”……嗯嗯，然后呢？")
        pool.append("[开心] 我在听！再多说一点嘛。")
        pool.append("[疑惑] 嗯？你是怎么想到这个的？")
        pool.append("[发呆] 嗯……我把这句话在脑袋里转了一圈，觉得挺有意思的。")
        pool.append("[眨眼] 原来如此。那你现在心情怎么样？")
        if brain.followTopic != "" { pool.append("[疑惑] 对了，你之前说的" + brain.followTopic + "，现在怎么样啦？") }
        if !likes.isEmpty { pool.append("[开心] 说起来，你之前说喜欢" + likes[rnd.Next(likes.count)] + "，最近还有在玩吗？") }
        if h >= 23 || h < 5 { pool.append("[困] 嗯嗯……不过已经很晚了，聊完这句就去睡吧？") }
        return Flavor(PickFresh(pool))
    }

    // 不接 AI 也能查：把网上搜到的第一条结果念给 m 听，并给出来源
    func LocalSearchReply(_ q: String) {
        Say("我去网上帮你搜搜……", 20)
        if !working && Grounded() { Set("read") }
        chatting = true
        Background { [weak self] in
            let r = PetForm.SearchWeb(q)
            var reply: String
            if let m1 = RxAll(r, "^1\\. (.+)\\n\\s+(\\S+)\\n\\s+(.*)$", options: [.anchorsMatchLines]).first {
                let title = m1[1].Trim, url = m1[2].Trim
                var snip = m1[3].Trim
                if snip.count > 80 { snip = snip.Sub(0, 80) + "…" }
                reply = "[眨眼] 我在网上搜到这个：" + title + (snip != "" ? "——" + snip : "") + "\n来源：" + url + "\n我自己读不太懂原文，你点开核对一下哦。"
            } else { reply = "[难过] 我搜了一下，没找到靠谱的结果……可能是网络不通，换个说法再问我试试？" }
            OnMain { self?.chatting = false; self?.PetSays(reply) }
        }
    }
}
