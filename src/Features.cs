namespace PixelDeskPet
{
    public class DayStats
    {
        public string Date;
        public int Work, WorkSec, Pat, Poke, Feed, Chat, ActiveSec, Pomo;
        public string Note = "";
    }


    // ---------- 名字：在 config.txt 里改 pet_name / my_name / pet_desc ----------
    public static class Names
    {
        public static string Pet = "叮叮";                       // 桌宠的名字
        public static string Nick = "你";                        // 桌宠怎么称呼你
        public static string Desc = "一只戴红蝴蝶结的像素小铃铛精，AI 干完活就摇响自己叫人";          // 一句话描述它自己（AI 聊天时会用）
        public static string DataFolder = "PixelDeskPet";        // 记忆、造型等数据放在 %APPDATA% 下的哪个文件夹
        public static string Skin = "";                          // 默认用哪个整体形象（skins 文件夹里的名字）
        public static void Load(string dir)
        {
            try
            {
                string f = System.IO.Path.Combine(dir, "config.txt");
                string ex = System.IO.Path.Combine(dir, "config.example.txt");
                if (!System.IO.File.Exists(f) && System.IO.File.Exists(ex)) System.IO.File.Copy(ex, f);   // 第一次运行：从模板生成自己的设置
                if (!System.IO.File.Exists(f)) return;
                foreach (string line in System.IO.File.ReadAllLines(f, System.Text.Encoding.UTF8))
                {
                    int i = line.IndexOf('=');
                    if (i <= 0 || line.TrimStart().StartsWith("#")) continue;
                    string k = line.Substring(0, i).Trim(), v = line.Substring(i + 1).Trim();
                    if (v == "") continue;
                    if (k == "pet_name") Pet = v;
                    else if (k == "my_name") Nick = v;
                    else if (k == "pet_desc") Desc = v;
                    else if (k == "skin") Skin = v;
                    else if (k == "data_folder" && v.IndexOfAny(System.IO.Path.GetInvalidFileNameChars()) < 0) DataFolder = v;
                }
            }
            catch { }
        }
    }

    public partial class PetForm
    {
        static string NAME { get { return Names.Pet; } }
        static string NICK { get { return Names.Nick; } }

        // ---------- 像素字体 ----------
        System.Drawing.Text.PrivateFontCollection pixelFonts;
        FontFamily pixelFamily;

        Font PixelFont(float px)
        {
            if (pixelFamily != null) return new Font(pixelFamily, px, FontStyle.Regular, GraphicsUnit.Pixel);
            return new Font("Microsoft YaHei UI", px * .75f, FontStyle.Regular, GraphicsUnit.Pixel);
        }

        void LoadPixelFont()
        {
            try
            {
                string f = Path.Combine(Path.Combine(dir, "assets"), "fusion-pixel.ttf");
                if (!File.Exists(f)) return;
                pixelFonts = new System.Drawing.Text.PrivateFontCollection();
                pixelFonts.AddFontFile(f);
                try { AddFontResourceEx(f, 0x10, IntPtr.Zero); } catch { }   // 让输入框这类控件也能用上像素字体
                if (pixelFonts.Families.Length > 0) pixelFamily = pixelFonts.Families[0];
            }
            catch { pixelFamily = null; }
        }

        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern int AddFontResourceEx(string name, uint fl, IntPtr res);

        public static void SafeFont(Control c, Font f)
        {
            try { c.Font = f; TextRenderer.MeasureText("测", c.Font); }
            catch { try { c.Font = new Font("Microsoft YaHei UI", 10f); } catch { } }
        }

        public PixelText ptext;
        public int TextScale() { return S >= 3 ? 2 : 1; }

        int TextPx() { return S >= 3 ? 24 : 12; }   // 像素字体是 12px 设计的，只用整数倍才清晰

        // ---------- 状态 ----------
        int hunger = 20;                 // 0..100
        double lastHungerTick, lastHungryAsk;
        string weatherKind = "";         // rain / snow / hot / cold / ""
        string weatherText = "";
        bool weatherOn = true;
        DateTime metDate = DateTime.Today;
        int unlockLevel;
        DayStats today;
        double lastStatsSave, lastQuietCheck, quietSince = -1;
        bool quiet, manualQuiet;
        double pomoEnd = -1, breakEnd = -1; int pomoMinutes;
        double awayStart;
        List<string[]> memos = new List<string[]>();          // 日期 | 关键词 | 原话
        List<KeyValuePair<DateTime, string>> reminders = new List<KeyValuePair<DateTime, string>>();
        string signText = "";
        List<string[]> chatLog = new List<string[]>();        // 谁 | 说了什么
        ChatWindow chatWin;

        void InitFeatures()
        {
            LoadPixelFont();
            bubbleFont = PixelFont(TextPx());
            ptext = new PixelText(Path.Combine(Path.Combine(dir, "assets"), "pixelfont.bin"));
            LoadExtra();
            LoadMemos();
            LoadReminders();
            NewDayIfNeeded();
            if (weatherOn)
            {
                Thread th = new Thread(WeatherLoop);
                th.IsBackground = true;
                th.Start();
            }
        }

        // ---------- 存档 ----------
        string ExtraFile() { return Path.Combine(cfgDir, "xiaoc.txt"); }

        void LoadExtra()
        {
            try
            {
                if (File.Exists(ExtraFile()))
                {
                    foreach (string line in File.ReadAllLines(ExtraFile(), Encoding.UTF8))
                    {
                        int i = line.IndexOf('='); if (i < 0) continue;
                        string k = line.Substring(0, i), v = line.Substring(i + 1);
                        if (k == "met") DateTime.TryParse(v, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out metDate);
                        if (k == "hunger") int.TryParse(v, out hunger);
                        if (k == "unlock") int.TryParse(v, out unlockLevel);
                        if (k == "walk" && (v == "none" || v == "small" || v == "medium")) walkRangeSetting = v;
                        if (k == "chatfreq" && (v == "often" || v == "normal" || v == "rarely" || v == "off")) chatFreq = v;
                    }
                }
                else SaveExtra();
            }
            catch { }
            string cfg = Path.Combine(dir, "config.txt");
            try
            {
                if (File.Exists(cfg))
                    foreach (string line in File.ReadAllLines(cfg, Encoding.UTF8))
                        if (line.Trim().ToLower().Replace(" ", "") == "weather=off") weatherOn = false;
            }
            catch { }
        }

        void SaveExtra()
        {
            try
            {
                File.WriteAllText(ExtraFile(), "met=" + metDate.ToString("yyyy-MM-dd") + "\r\nhunger=" + hunger + "\r\nunlock=" + unlockLevel + "\r\nwalk=" + walkRangeSetting + "\r\nchatfreq=" + chatFreq + "\r\n", Encoding.UTF8);
            }
            catch { }
        }

        int DaysTogether() { return (int)(DateTime.Today - metDate.Date).TotalDays + 1; }

        // ---------- 每帧的额外事情 ----------
        void FeaturesTick(double dt)
        {
            NewDayIfNeeded();
            double idle = Win.IdleSeconds();
            if (idle < 120) today.ActiveSec += 0; // 由下面每秒累加
            if (now - lastStatsSave > 1)
            {
                if (idle < 120 && !away) today.ActiveSec += (int)Math.Round(now - lastStatsSave);
                if (working) today.WorkSec += (int)Math.Round(now - lastStatsSave);
                if ((int)now % 60 == 0) SaveDiary();
                lastStatsSave = now;
            }

            // 饿：大约 3 分钟饿 1 点
            if (lastHungerTick == 0) lastHungerTick = now;
            if (now - lastHungerTick > 180) { lastHungerTick = now; hunger = Math.Min(100, hunger + 1); SaveExtra(); }

            // 免打扰：前台是全屏窗口（看视频、开会、放 PPT）
            if (now - lastQuietCheck > 2)
            {
                lastQuietCheck = now;
                bool q = manualQuiet || ForegroundFullscreen();
                if (q != quiet)
                {
                    quiet = q;
                    Opacity = quiet ? .3 : 1;
                    if (quiet) { quietSince = now; if (Calm() || state == "talk") Set("idle"); }
                    else
                    {
                        if (pendingDone && !away)
                        {
                            pendingDone = false;
                            string line = NICK + "，刚才你在忙的时候，Claude 已经做完啦！";
                            Say(line, 8); Announce(line);
                        }
                    }
                }
            }

            // 番茄钟
            if (pomoEnd > 0 && now >= pomoEnd)
            {
                pomoEnd = -1; today.Pomo++; breakEnd = now + 5 * 60;
                Set("party");
                Remind(NICK + "，专注时间到！你好棒，休息 5 分钟吧～", null);
            }
            if (breakEnd > 0 && now >= breakEnd)
            {
                breakEnd = -1;
                Set("wave");
                Remind("休息结束啦，要不要再来一个番茄钟？", null);
            }

            // 定时提醒
            for (int i = reminders.Count - 1; i >= 0; i--)
            {
                if (DateTime.Now >= reminders[i].Key)
                {
                    string what = reminders[i].Value;
                    reminders.RemoveAt(i); SaveReminders();
                    signText = what;
                    if (quiet) { quiet = false; Opacity = 1; lastQuietCheck = now + 60; }   // 提醒比免打扰重要，露面一分钟
                    Set("sign");
                    string line = NICK + "，到点啦：" + what + "！";
                    Say(line, 12);
                    PlaySfx("dingdong");
                }
            }

            // 亲密度解锁
            int lv = aff >= 80 ? 3 : aff >= 60 ? 2 : aff >= 40 ? 1 : 0;
            if (lv > unlockLevel)
            {
                unlockLevel = lv; SaveExtra();
                string[] what = { "", "抛球杂耍和小白花头饰", "跳舞和小嫩芽头饰", "小皇冠头饰，还有走路时冒小爱心" };
                Set("party");
                Say("亲密度升级！解锁了" + what[lv] + "！", 6);
            }
        }

        bool Unlocked(string thing)
        {
            switch (thing)
            {
                case "juggle": case "flower": return unlockLevel >= 1;
                case "dance": case "sprout": return unlockLevel >= 2;
                case "crown": case "trail": return unlockLevel >= 3;
            }
            return true;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);

        bool ForegroundFullscreen()
        {
            try
            {
                IntPtr h = Win.GetForegroundWindow();
                if (h == IntPtr.Zero || h == Handle) return false;
                string cls = Win.ClassOf(h);
                if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd") return false;
                // AI 自己的窗口（Claude、浏览器里的 AI 等）全屏时不算“在看视频”，提醒照常
                try
                {
                    uint pid; Win.GetWindowThreadProcessId(h, out pid);
                    string pname = Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant();
                    StringBuilder tb = new StringBuilder(512); GetWindowText(h, tb, 512);
                    if (AiLabel(pname, tb.ToString()) != null) return false;
                }
                catch { }
                Win.RECT r;
                if (!Win.GetWindowRect(h, out r)) return false;
                Rectangle b = Screen.FromHandle(h).Bounds;
                return r.Left <= b.Left && r.Top <= b.Top && r.Right >= b.Right && r.Bottom >= b.Bottom;
            }
            catch { return false; }
        }

        // ---------- 平时的小事（作息、饿、担心、回忆） 返回 true 表示已经安排了事情 ----------
        bool FeatureIdle()
        {
            if (ringing) return true;
            if (quiet || pomoEnd > 0) { nextIdleAct = 8; return true; }
            DateTime d = DateTime.Now;
            string day = d.ToString("yyyyMMdd");
            double hm = d.Hour + d.Minute / 60.0;
            if (!away && hm >= 7 && hm < 9.5 && Grounded() && Once(day + "brush")) { Set("brush"); Say("早上好 " + NICK + "！我先刷个牙～", 4); return true; }
            if (!away && hm >= 21 && hm < 22.5 && Grounded() && Once(day + "shower")) { Set("shower"); Say("洗香香时间～", 4); return true; }
            if (hm >= 12.5 && hm < 14 && Grounded() && Win.IdleSeconds() > 60 && Once(day + "nap")) { afterStretch = "sleep"; Set("stretch"); Say("呼啊……睡个午觉……", 3); return true; }

            if (hunger >= 70 && now - lastHungryAsk > 600 && !away)
            {
                lastHungryAsk = now; Set("hungry");
                Say(Pick(new string[] { NICK + "，我饿了……想吃橘子（右键可以喂我）", "咕噜噜……肚子在叫……", "有没有小橘子呀……" }), 5);
                return true;
            }

            // 熬夜或者连续工作太久：变得黏人，过来看看你
            bool late = d.Hour < 5 || d.Hour >= 24;
            if (!away && (late || now - activeSince > 3 * 3600) && rnd.NextDouble() < .35 && Grounded())
            {
                StartWalk(Cursor.Position.X > posX ? 1 : -1, 6, Cursor.Position.X);
                Say(late ? Pick(new string[] { NICK + "，好晚了，我有点担心你……", "再忙也要早点睡哦，我陪着你。" })
                         : Pick(new string[] { NICK + "，你已经忙了好久了，眼睛累不累？", "歇一下嘛，我在这里陪你。" }), 5);
                return true;
            }

            // 记得你说过的事
            if (!away && memos.Count > 0)
            {
                for (int i = 0; i < memos.Count; i++)
                {
                    DateTime md;
                    if (!DateTime.TryParse(memos[i][0], System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out md)) continue;
                    if (DateTime.Today > md.Date && (DateTime.Today - md.Date).TotalDays <= 7)
                    {
                        string kw = memos[i][1];
                        memos.RemoveAt(i); SaveMemos();
                        Set("talk");
                        Say(NICK + "，之前说的" + kw + "怎么样啦？", 7);
                        return true;
                    }
                }
                memos.RemoveAll(delegate(string[] m) { DateTime x; return DateTime.TryParse(m[0], out x) && (DateTime.Today - x.Date).TotalDays > 7; });
            }

            // 天气
            if (weatherKind != "" && rnd.NextDouble() < .08 && !away)
            {
                string line = weatherKind == "rain" ? "外面在下雨，出门记得带伞哦～" : weatherKind == "snow" ? "下雪啦！出门穿暖和点～" :
                    weatherKind == "hot" ? "今天好热，多喝水～" : "今天有点冷，别着凉啦～";
                Say(line, 5); Set("wave");
                return true;
            }
            return false;
        }

        // ---------- 离开与回来 ----------
        void ReturnFromAway(double awayFor)
        {
            if (pendingDone)
            {
                pendingDone = false;
                Set("happy");
                string line = "欢迎回来 " + NICK + "！你不在的时候，Claude 已经做完啦，快去看看吧！";
                Say(line, 10); Announce(line);
                return;
            }
            if (working) return;
            if (awayFor > 3600)
            {
                if (state == "sleep") Set("surprised");
                if (Grounded()) StartWalk(Cursor.Position.X > posX ? 1 : -1, 5, Cursor.Position.X);
                walkGear = false;
                string line = NICK + "！你终于回来了，我好想你～";
                Say(line, 6); Announce(line);
                AddAff(2);
            }
            else if (awayFor > 600)
            {
                if (state == "sleep") Set("surprised"); else Set("wave");
                Say(Pick(new string[] { "欢迎回来 " + NICK + "！", NICK + " 回来啦！我刚刚一直在等你。" }), 4);
            }
            else
            {
                if (state == "sleep") Set("surprised"); else Set("wave");
                Say("回来啦～", 3);
            }
        }

        // ---------- 天气（wttr.in，按网络位置大概判断） ----------
        void WeatherLoop()
        {
            while (true)
            {
                try
                {
                    ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
                    using (WebClient wc = new WebClient())
                    {
                        wc.Encoding = Encoding.UTF8;
                        wc.Headers.Add("User-Agent", "curl/8.0");
                        string s = wc.DownloadString("https://wttr.in/?format=%t|%C&lang=en").Trim();
                        string[] p = s.Split('|');
                        if (p.Length == 2)
                        {
                            Match m = Regex.Match(p[0], @"[-+]?\d+");
                            int temp = m.Success ? int.Parse(m.Value) : 20;
                            string c = p[1].ToLowerInvariant();
                            string kind = c.Contains("snow") || c.Contains("sleet") ? "snow" :
                                c.Contains("rain") || c.Contains("drizzle") || c.Contains("shower") || c.Contains("thunder") ? "rain" :
                                temp >= 30 ? "hot" : temp <= 8 ? "cold" : "";
                            weatherKind = kind;
                            weatherText = temp + "°C";
                        }
                    }
                }
                catch { }
                Thread.Sleep(30 * 60 * 1000);
            }
        }

        // ---------- 日记 ----------
        string DiaryFile() { return Path.Combine(dir, Names.Pet + "的日记.txt"); }
        string DiaryData() { return Path.Combine(cfgDir, "diary.txt"); }

        void NewDayIfNeeded()
        {
            string d = DateTime.Today.ToString("yyyy-MM-dd");
            if (today != null && today.Date == d) return;
            if (today != null) SaveDiary();
            today = null;
            foreach (DayStats s in ReadDiary()) if (s.Date == d) today = s;
            if (today == null) { today = new DayStats(); today.Date = d; }
            int days = DaysTogether();
            int[] marks = { 7, 30, 100, 200, 365, 500, 520, 1000 };
            if (Array.IndexOf(marks, days) >= 0 && Once(d + "anniv"))
            {
                Set("party");
                Say("今天是我们认识的第 " + days + " 天！" + NICK + "，谢谢你一直陪着我～", 8);
            }
        }

        List<DayStats> ReadDiary()
        {
            List<DayStats> list = new List<DayStats>();
            try
            {
                if (!File.Exists(DiaryData())) return list;
                foreach (string line in File.ReadAllLines(DiaryData(), Encoding.UTF8))
                {
                    string[] p = line.Split('|');
                    if (p.Length < 9) continue;
                    DayStats s = new DayStats();
                    s.Date = p[0];
                    int.TryParse(p[1], out s.Work); int.TryParse(p[2], out s.WorkSec); int.TryParse(p[3], out s.Pat);
                    int.TryParse(p[4], out s.Poke); int.TryParse(p[5], out s.Feed); int.TryParse(p[6], out s.Chat);
                    int.TryParse(p[7], out s.ActiveSec); int.TryParse(p[8], out s.Pomo);
                    if (p.Length > 9) s.Note = p[9];
                    list.Add(s);
                }
            }
            catch { }
            return list;
        }

        void SaveDiary()
        {
            if (today == null) return;
            try
            {
                List<DayStats> list = ReadDiary();
                list.RemoveAll(delegate(DayStats s) { return s.Date == today.Date; });
                list.Add(today);
                list.Sort(delegate(DayStats a, DayStats b) { return string.Compare(a.Date, b.Date); });
                StringBuilder sb = new StringBuilder();
                foreach (DayStats s in list)
                    sb.AppendLine(s.Date + "|" + s.Work + "|" + s.WorkSec + "|" + s.Pat + "|" + s.Poke + "|" + s.Feed + "|" + s.Chat + "|" + s.ActiveSec + "|" + s.Pomo + "|" + s.Note.Replace("|", " ").Replace("\n", " "));
                File.WriteAllText(DiaryData(), sb.ToString(), Encoding.UTF8);
                StringBuilder txt = new StringBuilder();
                for (int i = list.Count - 1; i >= 0; i--) txt.AppendLine(DiaryEntry(list[i])).AppendLine();
                File.WriteAllText(DiaryFile(), txt.ToString(), Encoding.UTF8);
            }
            catch { }
        }

        string DiaryEntry(DayStats s)
        {
            DateTime d; DateTime.TryParse(s.Date, out d);
            string[] wk = { "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" };
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("【" + d.ToString("M月d日") + " " + wk[(int)d.DayOfWeek] + "】");
            int h = s.ActiveSec / 3600, mi = (s.ActiveSec % 3600) / 60;
            if (s.ActiveSec > 60) sb.AppendLine("今天 " + NICK + " 在电脑前待了" + (h > 0 ? h + " 小时 " : "") + mi + " 分钟。");
            if (s.Work > 0) sb.AppendLine("Claude 工作了 " + s.Work + " 次，一共 " + Math.Max(1, s.WorkSec / 60) + " 分钟，我都在旁边帮忙盯着！");
            if (s.Pomo > 0) sb.AppendLine("我们一起完成了 " + s.Pomo + " 个番茄钟，" + NICK + " 好认真。");
            if (s.Pat > 0) sb.AppendLine(NICK + " 摸了我的头 " + s.Pat + " 下，好开心～");
            if (s.Poke > 0) sb.AppendLine("被戳了 " + s.Poke + " 下" + (s.Poke > 10 ? "，头都晕了！" : "。"));
            if (s.Feed > 0) sb.AppendLine("吃了 " + s.Feed + " 个小橘子，甜甜的。");
            if (s.Chat > 0) sb.AppendLine("和 " + NICK + " 聊了 " + s.Chat + " 句。");
            if (s.Note != "") sb.AppendLine(s.Note);
            if (sb.ToString().Split('\n').Length <= 2) sb.AppendLine("今天比较安静，我自己玩了一会儿。");
            return sb.ToString().TrimEnd();
        }

        void ShowDiary()
        {
            SaveDiary();
            List<DayStats> list = ReadDiary();
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("这是我认识 " + NICK + " 的第 " + DaysTogether() + " 天。").AppendLine();
            for (int i = list.Count - 1; i >= 0 && i >= list.Count - 30; i--) sb.AppendLine(DiaryEntry(list[i])).AppendLine();
            PixelWindow w = new PixelWindow(this, NAME + "的日记", sb.ToString(), PixelFont(TextPx() == 24 ? 24 : 12), false);
            w.Show(this);
        }

        // ---------- 记住你说过的事 ----------
        static readonly string[] EVENT_WORDS = { "考试", "截稿", "交稿", "交作业", "作业", "论文", "答辩", "开题", "中期", "面试", "展览", "布展", "汇报", "比赛", "ddl", "DDL", "deadline", "演出", "旅行", "搬家" };

        void LoadMemos()
        {
            try
            {
                string f = Path.Combine(cfgDir, "memos.txt");
                if (File.Exists(f))
                    foreach (string line in File.ReadAllLines(f, Encoding.UTF8))
                    {
                        string[] p = line.Split('|');
                        if (p.Length >= 3) memos.Add(p);
                    }
            }
            catch { }
        }

        void SaveMemos()
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                foreach (string[] m in memos) sb.AppendLine(m[0] + "|" + m[1] + "|" + m[2].Replace("|", " "));
                File.WriteAllText(Path.Combine(cfgDir, "memos.txt"), sb.ToString(), Encoding.UTF8);
            }
            catch { }
        }

        string NoteEvent(string msg)
        {
            foreach (string w in EVENT_WORDS)
            {
                if (msg.Contains(w))
                {
                    memos.RemoveAll(delegate(string[] m) { return m[1] == w; });
                    memos.Add(new string[] { DateTime.Today.ToString("yyyy-MM-dd"), w, msg });
                    SaveMemos();
                    if (today != null && today.Note.Length < 60) today.Note = (today.Note + " " + NICK + " 提到了" + w + "，我记下来了。").Trim();
                    return w;
                }
            }
            return null;
        }

        // ---------- 提醒 ----------
        void LoadReminders()
        {
            try
            {
                string f = Path.Combine(cfgDir, "reminders.txt");
                if (!File.Exists(f)) return;
                foreach (string line in File.ReadAllLines(f, Encoding.UTF8))
                {
                    string[] p = line.Split(new char[] { '|' }, 2);
                    DateTime d;
                    if (p.Length == 2 && DateTime.TryParse(p[0], System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out d))
                        reminders.Add(new KeyValuePair<DateTime, string>(d, p[1]));
                }
            }
            catch { }
        }

        void SaveReminders()
        {
            try
            {
                StringBuilder sb = new StringBuilder();
                foreach (KeyValuePair<DateTime, string> r in reminders) sb.AppendLine(r.Key.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture) + "|" + r.Value);
                File.WriteAllText(Path.Combine(cfgDir, "reminders.txt"), sb.ToString(), Encoding.UTF8);
            }
            catch { }
        }

        // 认得这些说法："10分钟后提醒我喝水"、"3点提醒我交作业"、"下午3点半提醒我开会"、"15:30 提醒我…"、"明天9点提醒我…"
        static bool ParseReminder(string msg, out DateTime when, out string what)
        {
            when = DateTime.MinValue; what = "";
            int k = msg.IndexOf("提醒我");
            if (k < 0) return false;
            what = msg.Substring(k + 3).Trim(new char[] { ' ', '，', ',', '。', '！', '!', '~', '～' });
            string head = msg.Substring(0, k);
            if (what == "") what = "该做事啦";
            Match m = Regex.Match(head, @"(\d+)\s*(分钟|分|min)");
            Match h = Regex.Match(head, @"(\d+)\s*(个)?小时");
            if (h.Success || (m.Success && head.Contains("后")))
            {
                when = DateTime.Now;
                if (h.Success) when = when.AddHours(int.Parse(h.Groups[1].Value));
                if (m.Success) when = when.AddMinutes(int.Parse(m.Groups[1].Value));
                return when > DateTime.Now;
            }
            Match t = Regex.Match(head, @"(\d{1,2})\s*[:：点]\s*(半|\d{1,2})?");
            if (t.Success)
            {
                int hh = int.Parse(t.Groups[1].Value), mm = 0;
                if (t.Groups[2].Success) mm = t.Groups[2].Value == "半" ? 30 : int.Parse(t.Groups[2].Value);
                if ((head.Contains("下午") || head.Contains("晚上") || head.Contains("傍晚")) && hh < 12) hh += 12;
                if (hh > 23 || mm > 59) return false;
                DateTime d = DateTime.Today.AddHours(hh).AddMinutes(mm);
                if (head.Contains("明天")) d = d.AddDays(1);
                else if (d <= DateTime.Now)
                {
                    if (hh < 12 && !head.Contains("上午") && !head.Contains("早") && d.AddHours(12) > DateTime.Now) d = d.AddHours(12);
                    else d = d.AddDays(1);
                }
                when = d;
                return true;
            }
            return false;
        }

        void AddReminder(DateTime when, string what)
        {
            reminders.Add(new KeyValuePair<DateTime, string>(when, what));
            SaveReminders();
        }

        void AskReminder()
        {
            ReminderWindow w = new ReminderWindow(this);
            w.Show(this);
        }

        public void ReminderFromWindow(string timeText, string what)
        {
            DateTime when; string w2;
            string msg = timeText.Trim();
            if (Regex.IsMatch(msg, @"^\d+$")) msg += "分钟后";
            if (!ParseReminder(msg + "提醒我" + what, out when, out w2))
            {
                Say("唔，我没看懂这个时间……试试「15:30」或「10分钟后」", 5); Set("confused");
                return;
            }
            AddReminder(when, w2);
            Set("wink");
            Say("记住啦！" + FormatWhen(when) + "提醒你：" + w2, 5);
        }

        static string FormatWhen(DateTime d)
        {
            string day = d.Date == DateTime.Today ? "" : d.Date == DateTime.Today.AddDays(1) ? "明天 " : d.ToString("M月d日 ");
            return day + d.ToString("HH:mm") + " ";
        }

        // ---------- 番茄钟 ----------
        void StartPomo(int minutes)
        {
            Interact();
            pomoMinutes = minutes; pomoEnd = now + minutes * 60; breakEnd = -1;
            Set("wave");
            Say("好！专注 " + minutes + " 分钟，我陪你一起～", 4);
        }

        void StopPomo()
        {
            pomoEnd = -1; breakEnd = -1;
            Say("番茄钟停下来啦。", 3);
        }

        // ---------- 聊天 ----------
        void OpenChatWindow()
        {
            Interact();
            if (state == "sulk") Forgive();
            if (chatWin == null || chatWin.IsDisposed)
            {
                chatWin = new ChatWindow(this, PixelFont(TextPx() == 24 ? 24 : 12));
                int st2 = Math.Max(0, chatLog.Count - 60);
                for (int i = st2; i < chatLog.Count; i++) chatWin.AddLine(chatLog[i][0], chatLog[i][1]);
                if (chatLog.Count == 0) chatWin.AddLine(NAME, HasAI() ? "嗨 " + Names.Nick + "！想聊什么都可以。我能帮你查资料，也能帮你在电脑上做事，还能给自己画新造型～" : "嗨 " + Names.Nick + "！想聊什么都可以～也可以说「10分钟后提醒我喝水」。");
            }
            chatWin.Show();
            chatWin.Activate();
            chatWin.FocusInput();
        }

        public void UserSays(string msg)
        {
            chatLog.Add(new string[] { NICK, msg });
            if (chatWin != null && !chatWin.IsDisposed) chatWin.AddLine(NICK, msg);
            if (today != null) today.Chat++;
            NoteEvent(msg);
            if (HasAI()) { AgentChat(msg, null); return; }
            if (!localHintShown)
            {
                localHintShown = true;
                ChatNote("（没接 AI 时，" + Names.Pet + " 靠自己的小脑袋聊天：会记住你说的事、读懂心情、接着话头问，知识类问题会去网上搜给你看。想让它真正理解你、帮你在电脑上做事，可以在右键「AI 设置…」接上 AI）");
            }

            DateTime when; string what;
            if (ParseReminder(msg, out when, out what))
            {
                AddReminder(when, what);
                PetSays("[眨眼] 记住啦！" + FormatWhen(when) + "我会提醒你" + what + "～");
                return;
            }
            Reply(msg);
        }

        public void UserSendsImage(string path, string caption)
        {
            if (caption == "") caption = "你看看这张图";
            chatLog.Add(new string[] { NICK, "[图片] " + caption });
            if (chatWin != null && !chatWin.IsDisposed) chatWin.AddLine(NICK, "[图片] " + caption);
            if (today != null) today.Chat++;
            if (HasAI()) { AgentChat(caption, path); return; }
            PetSays("[疑惑] 我现在还看不懂图片……右键「AI 设置…」填好 key，我就能看啦。");
        }

        static string PlainText(string t)
        {
            t = t.Replace("**", "").Replace("__", "").Replace("`", "");
            t = Regex.Replace(t, @"(?m)^\s*#{1,6}\s*", "");
            t = Regex.Replace(t, @"(?m)^\s*[-*]\s+", "· ");
            t = Regex.Replace(t, @"\[([^\]]+)\]\((https?://[^)]+)\)", "$1 $2");
            return t.Trim();
        }

        // 闲聊时像真人一样分几条发：用空行隔开、每段都短的回复，拆成几条消息，隔一小会儿一条
        List<string> pendingSays = new List<string>();
        System.Windows.Forms.Timer sayTimer;

        public void PetSays(string raw)
        {
            string mood0 = "talk";
            string all = PlainText(ParseMood(raw, ref mood0)).Replace("\r\n", "\n").Trim();
            string[] parts = System.Text.RegularExpressions.Regex.Split(all, @"\n\s*\n");
            bool split = parts.Length >= 2 && parts.Length <= 3 && !all.Contains("http") && !all.Contains("· ");
            if (split) foreach (string pp in parts) if (pp.Trim().Length == 0 || pp.Trim().Length > 70 || pp.Contains("\n")) split = false;
            if (sayTimer != null) { sayTimer.Stop(); foreach (string q in pendingSays) PetSaysOne(q); pendingSays.Clear(); }   // 上一轮还没发完的先发掉
            if (!split) { PetSaysOne(raw); return; }
            string head = raw.TrimStart().StartsWith("[") && raw.IndexOf(']') > 0 ? raw.Substring(0, raw.IndexOf(']') + 1) + " " : "";
            PetSaysOne(head + parts[0].Trim());
            for (int i = 1; i < parts.Length; i++) pendingSays.Add(parts[i].Trim());
            if (sayTimer == null) { sayTimer = new System.Windows.Forms.Timer(); sayTimer.Tick += delegate { NextSay(); }; }
            sayTimer.Interval = Math.Min(2200, 700 + pendingSays[0].Length * 45);
            sayTimer.Start();
        }

        void NextSay()
        {
            sayTimer.Stop();
            if (pendingSays.Count == 0) return;
            string q = pendingSays[0]; pendingSays.RemoveAt(0);
            PetSaysOne(q);
            if (pendingSays.Count > 0) { sayTimer.Interval = Math.Min(2200, 700 + pendingSays[0].Length * 45); sayTimer.Start(); }
        }

        void PetSaysOne(string raw)
        {
            string mood = "talk";
            string text = PlainText(ParseMood(raw, ref mood));
            chatLog.Add(new string[] { NAME, text });
            if (chatLog.Count > 200) chatLog.RemoveRange(0, chatLog.Count - 200);
            if (chatWin == null || chatWin.IsDisposed || !chatWin.ContainsFocus) PlaySfx("pop");
            if (chatWin != null && !chatWin.IsDisposed) chatWin.AddLine(NAME, text);
            if (!working && Grounded()) Set(mood);
            string bubble = text;
            int cut = bubble.IndexOf('\n');
            if (cut > 0 && cut < 60) bubble = bubble.Substring(0, cut);
            bool chatOpen = chatWin != null && !chatWin.IsDisposed && chatWin.Visible;
            if (bubble.Length > 54) bubble = bubble.Substring(0, 50) + "…" + (chatOpen ? "" : "（右键「和" + Names.Pet + "聊天」看全部）");
            else if (bubble != text) bubble += "…";
            Say(bubble, Math.Max(5, Math.Min(14, bubble.Length * 0.25)));
        }

        string ContextForModel()
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("现在是 " + DateTime.Now.ToString("M月d日 HH:mm") + "。");
            sb.Append("你认识 " + Names.Nick + " 第 " + DaysTogether() + " 天，亲密度 " + aff + "/100，饥饿 " + hunger + "/100。");
            if (weatherText != "") sb.Append("外面 " + weatherText + "。");
            if (today != null) sb.Append("今天 Claude 工作了 " + today.Work + " 次，" + Names.Nick + " 摸了你 " + today.Pat + " 下。");
            if (memos.Count > 0)
            {
                sb.Append(Names.Nick + " 最近提到过：");
                foreach (string[] m in memos) sb.Append(m[0] + " " + m[2] + "；");
            }
            return sb.ToString();
        }

        // ---------- 右键菜单里的新东西 ----------
        ToolStripMenuItem miDays, miQuiet, miPomo;
        void BuildFeatureMenu(ContextMenuStrip m, int insertAt)
        {
            miDays = new ToolStripMenuItem("认识 " + Names.Nick + " 的第 1 天");
            miDays.Enabled = false;
            m.Items.Insert(1, miDays);

            ToolStripMenuItem pomo = new ToolStripMenuItem("番茄钟");
            pomo.DropDownItems.Add("专注 25 分钟", null, delegate { StartPomo(25); });
            pomo.DropDownItems.Add("专注 50 分钟", null, delegate { StartPomo(50); });
            pomo.DropDownItems.Add("结束番茄钟", null, delegate { StopPomo(); });
            miPomo = pomo;
            ToolStripMenuItem rem = new ToolStripMenuItem("设个提醒…", null, delegate { AskReminder(); });
            ToolStripMenuItem dia = new ToolStripMenuItem("翻翻日记", null, delegate { ShowDiary(); });
            miQuiet = new ToolStripMenuItem("免打扰", null, delegate { manualQuiet = !manualQuiet; miQuiet.Checked = manualQuiet; lastQuietCheck = 0; });
            int at = Math.Min(insertAt, m.Items.Count);
            m.Items.Insert(at, new ToolStripSeparator());
            m.Items.Insert(at + 1, pomo);
            m.Items.Insert(at + 2, rem);
            m.Items.Insert(at + 3, dia);
            m.Items.Insert(at + 4, miQuiet);
            ToolStripMenuItem miNotBusy = new ToolStripMenuItem("它其实没在工作（别再认错了）", null, delegate { IgnoreCurrentButton(); });
            m.Items.Insert(2, miNotBusy);
            m.Opening += delegate
            {
                miNotBusy.Visible = detectedBusy && !manualWork;
                if (detectedBusy) miNotBusy.Text = "「" + busyApp + "」其实没在工作（别再认错了）";
                miDays.Text = "认识 " + NICK + " 的第 " + DaysTogether() + " 天" + (weatherText != "" ? "  ·  " + weatherText : "") + (hunger >= 70 ? "  ·  饿了" : "") +
                    (manualWork ? "  ·  手动工作模式开着" : detectedBusy ? "  ·  " + busyApp + " 正在工作" : "");
                miPomo.Text = pomoEnd > 0 ? "番茄钟（还剩 " + Math.Max(1, (int)Math.Ceiling((pomoEnd - now) / 60)) + " 分钟）" : breakEnd > 0 ? "番茄钟（休息中）" : "番茄钟";
            };
        }

        // ---------- 额外的画 ----------
        void DrawProp2(string prop, double t, double n, double fx, double fy, double dx, double dy)
        {
            switch (prop)
            {
                case "bell":
                    {
                        // 举着金色小铃铛左右摇
                        double sw = SeqD(n, .12, new double[] { -.4, .4 });
                        double hx = 14 + dx + sw * .3, hy = 4.5 + dy;
                        U(hx, hy, 2, 2, BODY);
                        U(hx + .75, hy + 2, .5, .5, HARDHAT_D);
                        U(hx + .25 + sw, hy + 2.5, 1.5, .5, GOLD);
                        U(hx + sw, hy + 3, 2, 1, GOLD);
                        U(hx - .25 + sw, hy + 4, 2.5, .5, GOLD);
                        U(hx + .5 + sw, hy + 3, .25, .75, PAPER);
                        U(hx + .75 + sw * 1.6, hy + 4.5, .5, .5, HARDHAT_D);
                        // 声音的小波纹
                        double wx = sw < 0 ? hx - 1.25 : hx + 3;
                        double dir = sw < 0 ? -1 : 1;
                        U(wx, hy + 2.75, .25, 1, EDGE);
                        U(wx + dir * .75, hy + 2.25, .25, 2, EDGE);
                        break;
                    }
                case "toothbrush":
                    {
                        double sc = SeqD(n, .15, new double[] { 0, .5 });
                        U(-1.5 + dx + sc, 10.25 + dy, 4.5, .5, BOOK); U(2.5 + dx + sc, 9.75 + dy, 1, .5, PAPER);
                        U(.25 + dx + sc, 10.5 + dy, 1.75, 1.5, BODY);
                        for (int i = 0; i < 3; i++) U(5.5 + i * 1.5 + ((n * 3 + i) % 1) * .5, 11 + Math.Sin(n * 5 + i) * .25, .75, .75, PAPER);
                        break;
                    }
                case "shower":
                    {
                        U(4, -3, 7, 1, NAIL); U(7, -4.5, 1, 1.5, NAIL); U(4.5, -2, 6, .5, NAIL);
                        for (int i = 0; i < 6; i++)
                        {
                            double a = ((n * 2.2) + i * .17) % 1.0;
                            U(4.75 + i * 1, -1.25 + a * 6.5, .25, .75, TEAR);
                        }
                        U(3 + Math.Sin(n * 2) * .5, 5, 1.25, 1.25, PAPER); U(10.5, 4.75 + Math.Sin(n * 3) * .25, 1, 1, PAPER); U(6, 4.5, .75, .75, PAPER);
                        break;
                    }
                case "belly":
                    U(5 + fx, 11 + fy, 1.75, 1.75, BODY_D); U(8.25 + fx, 11 + fy, 1.75, 1.75, BODY_D);
                    if (Seq(n, .5, new int[] { 0, 1 }) == 0) PixText("咕~", 12.5, 6.5, 2, EYE, true);
                    break;
                case "sign":
                    {
                        // 举着小牌子：上面写着要提醒的事
                        string s = signText.Length > 8 ? signText.Substring(0, 8) + "…" : signText;
                        double bob = SeqD(n, .4, new double[] { 0, -.25 });
                        U(1.25 + dx, -.5 + dy + bob, .5, 7.5, WOOD); U(13.25 + dx, -.5 + dy + bob, .5, 7.5, WOOD);
                        U(-.75 + dx, -4.75 + dy + bob, 16.5, 4.5, WOOD); U(-.5 + dx, -4.5 + dy + bob, 16, 4, PAPER);
                        PixText(s, 0, -4.25 + dy + bob, TextPx() == 24 ? 3 : 2.25, EYE, true);
                        break;
                    }
            }
        }

        // 天气的小物件、番茄钟计时牌、亲密度满的爱心尾巴
        void DrawExtras(double n, double fx, double fy, double dx, double dy, bool busyHands)
        {
            if (!busyHands && state != "sign" && state != "shower" && state != "sulk" && state != "dizzy")
            {
                if (weatherKind == "rain" && (state == "walk" || state == "idle" || state == "sit"))
                {
                    U(14.25 + dx, 0 + dy, .25, 9.5, WOOD);
                    U(9.5 + dx, -1 + dy, 9.5, 1, BOOK); U(10.5 + dx, -1.75 + dy, 7.5, .75, BOOK); U(12.5 + dx, -2.25 + dy, 3.5, .5, BOOK);
                    U(14 + dx, 9 + dy, .75, .5, WOOD);
                    for (int i = 0; i < 4; i++) { double a = ((n * 1.8) + i * .3) % 1.0; U(-1 + i * 5, -4 + a * 18, .25, .6, TEAR); }
                }
                else if (weatherKind == "hot" && (state == "idle" || state == "sit"))
                {
                    U(-.5 + dx, 6.5 + dy, 1.75, 3, POPSICLE); U(-.5 + dx, 6.5 + dy, 1.75, .75, POPSICLE_HI); U(.125 + dx, 9.5 + dy, .5, 1.5, WOOD);
                }
                if (weatherKind == "cold" || weatherKind == "snow")
                {
                    U(2 + fx, 11.5 + fy, 11, 1, SCARF); U(10 + fx, 12.5 + fy, 1.25, 2, SCARF); U(10 + fx, 13.25 + fy, 1.25, .25, PAPER);
                }
            }
            if (pomoEnd > 0)
            {
                int left = Math.Max(0, (int)(pomoEnd - now));
                string s = (left / 60).ToString("00") + ":" + (left % 60).ToString("00");
                U(-3.25, 1.5, 5.5, 2.5, WOOD); U(-3, 1.75, 5, 2, BOX); U(-1, 4, .5, 3, WOOD);
                PixText(s, -3, 1.75, TextPx() == 24 ? 2 : 1.6, EYE, false);
            }
            if (state == "walk" && Unlocked("trail") && aff >= 80 && Seq(n, .6, new int[] { 0, 1, 1 }) == 0) Bits(HEART, walkDir > 0 ? -1.5 : 15, 9, .3, PINK);
        }
    }

    // ---------- 聊天窗口 ----------
    public class ChatWindow : Form
    {
        PetForm pet; PixelView log; TextBox input; Font font;
        static readonly Color BG = Color.FromArgb(255, 248, 231), INK = Color.FromArgb(60, 50, 45), PETC = Color.FromArgb(200, 95, 70), ME = Color.FromArgb(70, 110, 170), NOTE = Color.FromArgb(150, 140, 130);

        public ChatWindow(PetForm p, Font f)
        {
            pet = p; font = new Font("Microsoft YaHei UI", 11f);   // 输入框和按钮用系统字体，聊天内容用像素字
            Text = "和" + Names.Pet + "聊天";
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.Manual;
            ClientSize = new Size(460, 440);
            TopMost = true;
            BackColor = BG;
            Rectangle wa = Screen.FromControl(p).WorkingArea;
            Location = new Point(Math.Max(wa.Left, Math.Min(wa.Right - Width, p.Left + p.Width / 2 - Width / 2)), Math.Max(wa.Top, p.Top - Height + 120));
            log = new PixelView(p.ptext, 2, true);
            log.BackColor = BG;
            log.SetBounds(12, 10, 436, 352);
            input = new TextBox();
            PetForm.SafeFont(input, font); input.BorderStyle = BorderStyle.FixedSingle; input.BackColor = Color.White;
            input.SetBounds(12, 376, 296, 36);
            Button img = new Button();
            img.Text = "图片"; PetForm.SafeFont(img, font); img.FlatStyle = FlatStyle.Flat; img.BackColor = Color.FromArgb(240, 226, 200); img.ForeColor = INK;
            img.FlatAppearance.BorderSize = 0;
            img.SetBounds(314, 374, 62, 40);
            Button send = new Button();
            send.Text = "发送"; PetForm.SafeFont(send, font); send.FlatStyle = FlatStyle.Flat; send.BackColor = Color.FromArgb(217, 128, 106); send.ForeColor = Color.White;
            send.FlatAppearance.BorderSize = 0;
            send.SetBounds(382, 374, 66, 40);
            Label tip = new Label();
            tip.Text = "Enter 发送 · 可以让" + Names.Pet + "查资料、帮你在电脑上做事、给自己画新造型";
            tip.Font = new Font("Microsoft YaHei UI", 8.5f); tip.ForeColor = NOTE; tip.SetBounds(12, 418, 436, 18);
            Controls.Add(log); Controls.Add(input); Controls.Add(img); Controls.Add(send); Controls.Add(tip);
            AcceptButton = send;
            send.Click += delegate
            {
                string msg = input.Text.Trim();
                if (msg == "") return;
                input.Text = "";
                pet.UserSays(msg);
            };
            img.Click += delegate
            {
                OpenFileDialog dlg = new OpenFileDialog();
                dlg.Title = "选一张图片给" + Names.Pet + "看";
                dlg.Filter = "图片|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.webp";
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                string cap = input.Text.Trim();
                input.Text = "";
                pet.UserSendsImage(dlg.FileName, cap);
            };
        }

        public void FocusInput() { input.Focus(); }

        public void SetStatus(string s) { if (!IsDisposed) Text = s == "" ? "和" + Names.Pet + "聊天" : "和" + Names.Pet + "聊天 · " + s; }

        public void AddLine(string who, string text)
        {
            if (IsDisposed) return;
            if (who == "") log.Add(NOTE, text);
            else log.Add(who == "m" ? ME : PETC, (who == "m" ? Names.Nick : who) + "：" + text);
        }
    }

    // ---------- 设提醒的小窗 ----------
    public class ReminderWindow : Form
    {
        public ReminderWindow(PetForm p)
        {
            Text = "让" + Names.Pet + "提醒你";
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(360, 150);
            TopMost = true;
            BackColor = Color.FromArgb(255, 248, 231);
            Font f = new Font("Microsoft YaHei UI", 10f);
            Label l1 = new Label(); l1.Text = "什么时候（15:30 / 10分钟后 / 明天9点）"; l1.Font = f; l1.SetBounds(12, 10, 336, 22);
            TextBox t1 = new TextBox(); t1.Font = f; t1.SetBounds(12, 34, 336, 26);
            Label l2 = new Label(); l2.Text = "提醒什么"; l2.Font = f; l2.SetBounds(12, 66, 336, 22);
            TextBox t2 = new TextBox(); t2.Font = f; t2.SetBounds(12, 88, 250, 26);
            Button ok = new Button(); ok.Text = "好的"; ok.Font = f; ok.SetBounds(270, 86, 78, 30);
            Controls.Add(l1); Controls.Add(t1); Controls.Add(l2); Controls.Add(t2); Controls.Add(ok);
            AcceptButton = ok;
            ok.Click += delegate
            {
                if (t1.Text.Trim() == "") return;
                p.ReminderFromWindow(t1.Text, t2.Text.Trim() == "" ? "该做事啦" : t2.Text.Trim());
                Close();
            };
        }
    }

    // ---------- 只读的像素风文字窗（日记） ----------
    public class PixelWindow : Form
    {
        public PixelWindow(PetForm owner, string title, string body, Font font, bool small)
        {
            Text = title;
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(480, 520);
            BackColor = Color.FromArgb(255, 248, 231);
            PixelView box = new PixelView(owner.ptext, 2, false);
            box.BackColor = BackColor;
            box.SetBounds(16, 14, 452, 496);
            box.SetText(Color.FromArgb(60, 50, 45), body);
            Controls.Add(box);
        }
    }
}

namespace PixelDeskPet
{
    // ---------- 像素字（Fusion Pixel 12px 预先栅格化成点阵，自己一格一格画，保证每个字都是清晰的像素） ----------
    public class PixelText
    {
        Dictionary<int, ushort[]> glyphs = new Dictionary<int, ushort[]>();
        Dictionary<int, int> advs = new Dictionary<int, int>();
        public bool Loaded;
        Font fallback = new Font("Microsoft YaHei UI", 12f, GraphicsUnit.Pixel);

        public PixelText(string path)
        {
            try
            {
                if (!File.Exists(path)) return;
                byte[] b = File.ReadAllBytes(path);
                int n = BitConverter.ToInt32(b, 0), p = 4;
                for (int i = 0; i < n; i++)
                {
                    int cp = BitConverter.ToUInt16(b, p); int adv = b[p + 2]; p += 3;
                    ushort[] rows = new ushort[12];
                    for (int r = 0; r < 12; r++) { rows[r] = BitConverter.ToUInt16(b, p); p += 2; }
                    glyphs[cp] = rows; advs[cp] = adv;
                }
                Loaded = n > 0;
            }
            catch { Loaded = false; }
        }

        public int Adv(char c)
        {
            int a;
            if (advs.TryGetValue(c, out a)) return a;
            return c < 128 ? 6 : 12;
        }

        public List<string> Wrap(string text, int maxPx, int scale)
        {
            List<string> lines = new List<string>();
            foreach (string para in text.Replace("\r", "").Split('\n'))
            {
                StringBuilder cur = new StringBuilder(); int w = 0;
                foreach (char c in para)
                {
                    int a = Adv(c) * scale;
                    if (w + a > maxPx && cur.Length > 0)
                    {
                        // 标点不放在行首
                        if ("，。！？、：；）》」』～,.!?:;)".IndexOf(c) >= 0 && cur.Length > 1)
                        {
                            char last = cur[cur.Length - 1]; cur.Length--;
                            lines.Add(cur.ToString()); cur.Length = 0; cur.Append(last); w = Adv(last) * scale;
                        }
                        else { lines.Add(cur.ToString()); cur.Length = 0; w = 0; }
                    }
                    cur.Append(c); w += a;
                }
                lines.Add(cur.ToString());
            }
            return lines;
        }

        public int Width(string s, int scale) { int w = 0; foreach (char c in s) w += Adv(c) * scale; return w; }
        public int LineH(int scale) { return 14 * scale; }

        public Size Measure(string text, int maxPx, int scale)
        {
            List<string> lines = Wrap(text, maxPx, scale);
            int w = 0; foreach (string l in lines) w = Math.Max(w, Width(l, scale));
            return new Size(w, lines.Count * LineH(scale) - 2 * scale);
        }

        public void DrawLine(Graphics g, string s, int x, int y, int scale, Brush b)
        {
            foreach (char c in s)
            {
                ushort[] rows;
                if (glyphs.TryGetValue(c, out rows))
                {
                    for (int r = 0; r < 12; r++)
                    {
                        int v = rows[r]; int bit = 0;
                        while (v != 0 && bit < 16)
                        {
                            if ((v & 1) != 0)
                            {
                                int start = bit;
                                while ((v & 1) != 0) { v >>= 1; bit++; }
                                g.FillRectangle(b, x + start * scale, y + r * scale, (bit - start) * scale, scale);
                            }
                            else { v >>= 1; bit++; }
                        }
                    }
                }
                else if (c != ' ')
                {
                    using (Font f = new Font(fallback.FontFamily, 12f * scale, GraphicsUnit.Pixel)) g.DrawString(c.ToString(), f, b, x - scale * 2, y - scale);
                }
                x += Adv(c) * scale;
            }
        }

        public int Draw(Graphics g, string text, int x, int y, int scale, Brush b, int maxPx)
        {
            List<string> lines = Wrap(text, maxPx, scale);
            foreach (string l in lines) { DrawLine(g, l, x, y, scale, b); y += LineH(scale); }
            return lines.Count;
        }
    }

    // 像素字的滚动文字面板：聊天记录和日记都用它
    public class PixelView : Panel
    {
        PixelText pt; int scale;
        List<KeyValuePair<Color, string>> items = new List<KeyValuePair<Color, string>>();
        int scroll; bool stickBottom;

        public PixelView(PixelText p, int sc, bool bottom)
        {
            pt = p; scale = sc; stickBottom = bottom;
            DoubleBuffered = true;
            SetStyle(ControlStyles.Selectable, true);
            MouseWheel += delegate(object o, MouseEventArgs e) { int step = Math.Sign(e.Delta) * pt.LineH(scale) * 2; scroll = Math.Max(0, stickBottom ? scroll + step : scroll - step); Invalidate(); };
            MouseEnter += delegate { Focus(); };
        }

        List<KeyValuePair<Rectangle, string>> links = new List<KeyValuePair<Rectangle, string>>();

        static string FirstUrl(string t)
        {
            Match m = Regex.Match(t, @"https?://[^\s，。）)""'<>]+");
            return m.Success ? m.Value.TrimEnd('.', ',', ';') : null;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            bool hit = false;
            foreach (KeyValuePair<Rectangle, string> l in links) if (l.Key.Contains(e.Location)) hit = true;
            Cursor = hit ? Cursors.Hand : Cursors.Default;
        }

        protected override void OnMouseClick(MouseEventArgs e)
        {
            base.OnMouseClick(e);
            foreach (KeyValuePair<Rectangle, string> l in links)
                if (l.Key.Contains(e.Location)) { try { Process.Start(l.Value); } catch { } return; }
        }

        public void Add(Color c, string text) { items.Add(new KeyValuePair<Color, string>(c, text)); if (stickBottom) scroll = 0; Invalidate(); }
        public void SetText(Color c, string text) { items.Clear(); items.Add(new KeyValuePair<Color, string>(c, text)); scroll = 0; Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(BackColor);
            int lh = pt.LineH(scale), maxW = Width - 8;
            List<KeyValuePair<Color, string>> lines = new List<KeyValuePair<Color, string>>();
            List<string> lineUrl = new List<string>();
            foreach (KeyValuePair<Color, string> it in items)
            {
                string url = FirstUrl(it.Value);
                foreach (string l in pt.Wrap(it.Value, maxW, scale)) { lines.Add(new KeyValuePair<Color, string>(it.Key, l)); lineUrl.Add(url); }
                lines.Add(new KeyValuePair<Color, string>(it.Key, "")); lineUrl.Add(null);
            }
            links.Clear();
            int total = lines.Count * lh;
            int maxScroll = Math.Max(0, total - Height + 8);
            if (scroll > maxScroll) scroll = maxScroll;
            int y0 = stickBottom ? Math.Min(4, Height - 4 - total) + scroll : 4 - scroll;
            for (int i = 0; i < lines.Count; i++)
            {
                int y = y0 + i * lh;
                if (y + lh < 0 || y > Height) continue;
                Color col = lineUrl[i] != null ? Color.FromArgb(60, 110, 190) : lines[i].Key;
                using (SolidBrush b = new SolidBrush(col)) pt.DrawLine(g, lines[i].Value, 4, y, scale, b);
                if (lineUrl[i] != null && lines[i].Value != "")
                    links.Add(new KeyValuePair<Rectangle, string>(new Rectangle(4, y, pt.Width(lines[i].Value, scale), lh), lineUrl[i]));
            }
        }
    }
}
