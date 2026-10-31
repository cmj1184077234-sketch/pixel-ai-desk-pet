#pragma warning disable 0414, 0219, 0169, 0649, 0168, 0162, 0618
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using System.Speech.Synthesis;
using System.Media;

namespace PixelDeskPet
{
    public class Particle
    {
        public string Type;
        public double X, Y, VX, VY, Life;
    }

    static class Win
    {
        [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
        [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
        [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
        [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);

        public static double IdleSeconds()
        {
            try
            {
                LASTINPUTINFO l = new LASTINPUTINFO();
                l.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                if (!GetLastInputInfo(ref l)) return 0;
                return unchecked((uint)Environment.TickCount - l.dwTime) / 1000.0;
            }
            catch { return 0; }
        }
        public static uint LastInputTick()
        {
            try
            {
                LASTINPUTINFO l = new LASTINPUTINFO();
                l.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref l);
                return l.dwTime;
            }
            catch { return 0; }
        }
        public static string ClassOf(IntPtr h)
        {
            StringBuilder sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            return sb.ToString();
        }
    }

    public partial class PetForm : Form
    {
        // ---------- 尺寸 ----------
        // 画布：x 从 -3 到 18、y 从 -6 到 17（单位格），每个单位格再细分成 4×4 小格
        const int UX0 = 11, UY0 = 6;
        const int GW = 148, GH = 92;          // 小格数
        int S = 3;                           // 每个小格多少屏幕像素
        const int BUBBLE_H = 120;            // 头顶对话气泡的空间
        const int FORM_W_MIN = 360;
        const int FOOT = 84;                 // 脚底所在的小格行（y=15）

        // ---------- 颜色（纯平涂，没有描边） ----------
        static readonly Color KEY = Color.FromArgb(255, 0, 255);
        static Brush B(string hex) { return new SolidBrush(ColorTranslator.FromHtml(hex)); }
        static Brush GLINT = B("#FFFFFF");
        static Brush BODY = B("#A9BBCF"), BODY_D = B("#8C9FB4");   // 默认是灰蓝色的小方块，照片变装 / 造型可以换颜色
        static readonly Brush EYE = B("#1A1A1A"), MOUTH = B("#7A2230"),
            BLUSH = B("#F2A7A0"), SHADOW = B("#2E2E2E"), TEAR = B("#6EC6F5"), GOLD = B("#F5C842"), SPECK = B("#F0A030"),
            PINK = B("#E9768A"), CLOUD = B("#FFFFFF"), CLOUD_EDGE = B("#CFC8BC"), TERM = B("#1E1E22"), TERM_TXT = B("#7FB6FF"),
            CODE = B("#8BD17C"), LAPTOP = B("#3C3C40"), SCREEN_BG = B("#26262A"), SCREEN = B("#4A90E2"),
            HARDHAT = B("#E8B04A"), HARDHAT_D = B("#C98F2C"), NAIL = B("#6E7781"), WOOD = B("#8A5A3B"),
            PHONES = B("#2F4E8A"), PHONES_D = B("#263F70"), BOOK = B("#3F7FD0"), PAPER = B("#F7F7F2"),
            BALL_R = B("#E04848"), BALL_G = B("#4CAF50"), BALL_Y = B("#F2C230"), CHICK = B("#F6D04D"), CHICK_D = B("#E0B232"),
            BEAK = B("#F08A24"), PHONE = B("#2B2B2B"), CAP = B("#3F6FD0"), CAP_D = B("#2E55A8"), ORANGE = B("#FFA531"),
            LEAF = B("#5DBB6B"), LEAF_D = B("#3E8A5E"), BOX = B("#C9A26B"), BOX_D = B("#A9844F"), RAINCLOUD = B("#B8BEC8"),
            ANGER = B("#E04848"), STEAM = B("#C9D1DE"), EDGE = B("#7C8AA5"), DUST = B("#B9B2A8"), BOW = B("#FF8FB1"),
            BOW_D = B("#E8507A"), NIGHTCAP = B("#5B6CC9"), SANTA = B("#D63B3B"), CONF1 = B("#4FC3F7"), DARK = B("#2A3140"),
            MAGPIE = B("#2F5FA8"), MAGPIE_D = B("#1F3F70"), WITCH = B("#7A4FB0"), STRING = B("#9A9384"), LANTERN_HI = B("#FF8A65"),
            ZONGZI = B("#5E9E4A"), POPSICLE = B("#F48FB1"), POPSICLE_HI = B("#FFC1D9"), SCARF = B("#D9463E"), MOONCAKE = B("#D9A24A"), MOONCAKE_D = B("#B98232"), SNOW = B("#FFFFFF");
        static readonly Brush[] CONFS = { B("#E9768A"), B("#4FC3F7"), B("#F5C842"), B("#8BD17C"), B("#B39DDB") };

        static readonly string[] SPARK = { "010", "111", "010" };
        static readonly string[] HEART = { "01010", "11111", "01110", "00100" };
        static readonly string[] CROSS4 = { "1001", "0110", "0110", "1001" };
        static readonly string[] ZED = { "1111", "0010", "0100", "1111" };
        static readonly string[] NOTE_B = { "011", "010", "110", "110" };
        static readonly string[] PUFF = { "0110", "1111", "0110" };
        static readonly string[] QMARK = { "111", "001", "011", "000", "010" };
        static readonly string[] ORANGE_FULL = { "0110", "1111", "1111", "0110" };
        static readonly string[] ORANGE_BIT = { "0110", "1110", "1100", "0110" };
        static readonly string[] ORANGE_END = { "11", "11" };

        // ---------- 表情状态 ----------
        string state = "idle";
        double since, now, nextBlink = 2, blinkUntil, nextIdleAct = 9, lastSpawn;
        double lastInteract, lastChatAt, workStarted;
        int unanswered;
        string afterStretch = "idle";
        List<double> pokes = new List<double>();
        List<Particle> parts = new List<Particle>();
        Random rnd = new Random();
        Stopwatch clock = Stopwatch.StartNew();

        // ---------- 位置与物理（屏幕坐标：posX=身体中线，posY=脚底） ----------
        enum Mode { Ground, Perch, Fall, Held, Jump, Free }
        bool thrown;
        Mode mode = Mode.Fall;
        double posX, posY, vx, vy;
        IntPtr perchWnd = IntPtr.Zero;
        Win.RECT perchRect;
        double jumpT, jx0, jy0, jx1, jy1; IntPtr jumpWnd; bool jumpToFloor;
        bool walkGear;
        double lastFestSpawn;
        int walkDir = 1; double walkUntil, walkTarget = double.NaN; double paceCenter = 0;
        int squash; double lastFrame;
        Point heldOffset; Point lastCursor; double cursorVX, cursorVY;

        // ---------- 和人的互动 ----------
        volatile bool detectedBusy;
        bool working, manualWork, pendingDone, away;
        int notBusyCount;
        uint lastInputTick; Point lastInputCursor;
        List<double> keyEvents = new List<double>();
        double lastShakeReact, hoverSince = -1, lastHoverReact, lastClaudeClick = -99, lastEsc = -99;
        double activeSince, lastSitRemind, lastTimeCheck, lastDecay, lastSulkLine;
        HashSet<string> said = new HashSet<string>();
        int aff = 50; List<double> fed = new List<double>();
        Dictionary<uint, string> procNames = new Dictionary<uint, string>();

        bool muted;
        SpeechSynthesizer voice;
        string bubbleText = "";
        double bubbleUntil;
        bool chatting;

        System.Windows.Forms.Timer timer;
        Point downAt; bool mouseDown, dragged;
        string dir, cfgDir;
        string apiKey = "";
        List<string[]> history = new List<string[]>();
        int myPid = Process.GetCurrentProcess().Id;

        public PetForm(string folder)
        {
            dir = folder;
            cfgDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), Names.DataFolder);
            Directory.CreateDirectory(cfgDir);
            LoadConfig();
            muted = File.Exists(Path.Combine(cfgDir, "mute.txt"));
            InitVoice();

            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = KEY;
            TransparencyKey = KEY;
            DoubleBuffered = true;
            StartPosition = FormStartPosition.Manual;
            Text = Names.Pet;
            ResizeForm();
            LoadState();
            InitFeatures();
            InitAgent();

            BuildMenu();
            MouseDown += OnDown;
            MouseMove += OnMove;
            MouseUp += OnUp;
            MouseDoubleClick += delegate(object o, MouseEventArgs e) { if (e.Button == MouseButtons.Left && !dragged) Pat(); };
            FormClosing += delegate { SaveState(); SaveDiary(); };

            timer = new System.Windows.Forms.Timer();
            timer.Interval = 33;
            timer.Tick += delegate { Tick(); };
            timer.Start();

            Thread th = new Thread(DetectLoop);
            th.IsBackground = true;
            th.Start();

            lastInteract = lastChatAt = lastDecay = Now();
            activeSince = Now();
            lastInputTick = Win.LastInputTick();
            Greet();
        }

        protected override CreateParams CreateParams
        {
            get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x80; return cp; } // 不在 Alt+Tab 里出现
        }

        double Now() { return clock.Elapsed.TotalSeconds; }
        int FootOffset() { return BUBBLE_H + FOOT * S; }

        void ResizeForm()
        {
            int w = Math.Max(FORM_W_MIN, GW * S + 20);
            ClientSize = new Size(w, BUBBLE_H + GH * S);
        }

        void Place()
        {
            Location = new Point((int)Math.Round(posX - ClientSize.Width / 2.0), (int)Math.Round(posY - FootOffset()));
        }

        // ---------- 设置与存档 ----------
        void LoadConfig()
        {
            string f = Path.Combine(dir, "config.txt");
            if (!File.Exists(f)) return;
            foreach (string line in File.ReadAllLines(f, Encoding.UTF8))
            {
                string l = line.Trim();
                if (l.StartsWith("#") || l.IndexOf('=') < 0) continue;
                string k = l.Substring(0, l.IndexOf('=')).Trim().ToLower();
                string v = l.Substring(l.IndexOf('=') + 1).Trim();
                if (k == "api_key") apiKey = v;
                if (k == "api_base" && v != "") apiBase = v;
                if (k == "chat_model" && v != "") chatModel = v;
                if (k == "quick_model" && v != "") quickModel = v;
                if (k == "api_format") apiFormat = v.ToLower() == "openai" ? "openai" : "anthropic";
                if (k == "vision_base") visionBase = v;
                if (k == "vision_format") visionFormat = v.ToLower() == "openai" ? "openai" : v == "" ? "" : "anthropic";
                if (k == "vision_model") visionModel = v;
                if (k == "saver") saver = v.ToLower() != "off";
                if (k == "birthday") birthday = v.Replace("/", "-").Replace(".", "-");
                if (k == "pet_birthday") petBirthday = v.Replace("/", "-").Replace(".", "-");
                if (k == "size") { int s; if (int.TryParse(v, out s) && s >= 2 && s <= 6) S = s; }
            }
        }

        void LoadState()
        {
            Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            posX = wa.Right - 140; posY = wa.Bottom - 200;
            try
            {
                string f = Path.Combine(cfgDir, "state.txt");
                if (File.Exists(f))
                {
                    foreach (string line in File.ReadAllLines(f))
                    {
                        string[] kv = line.Split('=');
                        if (kv.Length != 2) continue;
                        if (kv[0] == "hat") { hatChoice = kv[1].Trim(); continue; }
                        if (kv[0] == "fest") { festMode = kv[1].Trim() == "off" ? "off" : ""; continue; }
                        double d;
                        if (!double.TryParse(kv[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out d)) continue;
                        if (kv[0] == "x") posX = d;
                        if (kv[0] == "y") posY = d;
                        if (kv[0] == "size" && d >= 2 && d <= 6) { S = (int)d; ResizeForm(); }
                        if (kv[0] == "aff") aff = Math.Max(0, Math.Min(100, (int)d));
                    }
                }
            }
            catch { }
            bool onScreen = false;
            foreach (Screen sc in Screen.AllScreens) if (sc.Bounds.Contains(new Point((int)posX, (int)posY - 10))) onScreen = true;
            if (!onScreen) { posX = wa.Right - 140; posY = wa.Bottom - 200; }
            Rectangle wa2 = ScreenArea(posX);
            if (posY > wa2.Bottom) posY = wa2.Bottom;
            mode = Math.Abs(posY - wa2.Bottom) < 3 ? Mode.Ground : Mode.Free;   // 上次放在哪里，就出现在哪里
            vx = 0; vy = 0; homeX = posX;
            Place();
        }

        void SaveState()
        {
            try
            {
                System.Globalization.CultureInfo ci = System.Globalization.CultureInfo.InvariantCulture;
                File.WriteAllText(Path.Combine(cfgDir, "state.txt"),
                    "x=" + posX.ToString(ci) + "\r\ny=" + posY.ToString(ci) + "\r\nsize=" + S + "\r\naff=" + aff + "\r\nhat=" + hatChoice + "\r\nfest=" + (festMode == "off" ? "off" : "auto") + "\r\n");
            }
            catch { }
        }

        void AddAff(int d)
        {
            aff = Math.Max(0, Math.Min(100, aff + d));
            SaveState();
        }

        // ---------- 右键菜单 ----------
        ToolStripMenuItem miSleep, miWork, miAuto, miSound, miAff;
        void BuildMenu()
        {
            ContextMenuStrip m = new ContextMenuStrip();
            m.Font = new Font("Microsoft YaHei UI", 9f);
            miAff = new ToolStripMenuItem("亲密度");
            miAff.Enabled = false;
            m.Items.Add(miAff);
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add("和" + Names.Pet + "聊天…", null, delegate { OpenChatWindow(); });
            m.Items.Add("喂一个小橘子", null, delegate { Feed(); });
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add("戳一下", null, delegate { Poke(); });
            m.Items.Add("摸摸头", null, delegate { Pat(); });
            m.Items.Add("跳个舞", null, delegate { Act("dance"); });
            m.Items.Add("去散个步", null, delegate { Interact(); if (Grounded()) { StartWalk(rnd.Next(2) == 0 ? -1 : 1, 6, double.NaN); UserAct(6.2); } });
            m.Items.Add("跳到当前窗口上", null, delegate { Interact(); UserAct(2); TryJumpToWindow(true); });
            miSleep = new ToolStripMenuItem("睡觉", null, delegate
            {
                if (state == "sleep") Act("surprised");
                else { afterStretch = "sleep"; Act("stretch"); }
            });
            m.Items.Add(miSleep);
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem size = new ToolStripMenuItem("大小");
            string[] names = { "小", "中", "大", "特大" };
            for (int i = 0; i < 4; i++)
            {
                int s = i + 2;
                size.DropDownItems.Add(names[i], null, delegate { S = s; ResizeForm(); Place(); SaveState(); });
            }
            m.Items.Add(size);
            ToolStripMenuItem hat = new ToolStripMenuItem("头饰");
            string[] hatNames = { "粉色蝴蝶结", "小白花", "小嫩芽", "小皇冠", "不戴" };
            string[] hatIds = { "bow", "flower", "sprout", "crown", "" };
            for (int i = 0; i < hatIds.Length; i++)
            {
                string id = hatIds[i];
                ToolStripMenuItem it = new ToolStripMenuItem(hatNames[i], null, delegate { hatChoice = id; SaveState(); Act("happy"); });
                it.Tag = id;
                hat.DropDownItems.Add(it);
            }
            hat.DropDownOpening += delegate
            {
                int k2 = 0;
                foreach (ToolStripMenuItem it in hat.DropDownItems)
                {
                    string id2 = (string)it.Tag;
                    it.Checked = id2 == hatChoice;
                    it.Enabled = Unlocked(id2);
                    string need = id2 == "flower" ? "亲密度 40 解锁" : id2 == "sprout" ? "亲密度 60 解锁" : id2 == "crown" ? "亲密度 80 解锁" : "";
                    it.Text = hatNames[k2] + (it.Enabled || need == "" ? "" : "（" + need + "）");
                    k2++;
                }
            };
            m.Items.Add(hat);
            m.Items.Add(Names.Pet + " 的生日…", null, delegate { SetPetBirthday(); });
            ToolStripMenuItem fm = new ToolStripMenuItem("节日装扮");
            ToolStripMenuItem fAuto = new ToolStripMenuItem("跟着日历自动换", null, delegate { festMode = ""; SaveState(); Act("happy"); });
            ToolStripMenuItem fOff = new ToolStripMenuItem("不换节日装扮", null, delegate { festMode = "off"; SaveState(); });
            fm.DropDownItems.Add(fAuto); fm.DropDownItems.Add(fOff); fm.DropDownItems.Add(new ToolStripSeparator());
            ToolStripMenuItem pv = new ToolStripMenuItem("预览");
            foreach (string[] f in FESTS)
            {
                string key = f[0], line = f[2];
                pv.DropDownItems.Add(f[1], null, delegate { festMode = key; Act("happy"); Say("（预览）" + line, 5); });
            }
            fm.DropDownItems.Add(pv);
            fm.DropDownOpening += delegate { fAuto.Checked = festMode == ""; fOff.Checked = festMode == "off"; };
            m.Items.Add(fm);
            miSound = new ToolStripMenuItem("声音", null, delegate { ToggleSound(); });
            miSound.Checked = !muted;
            m.Items.Add(miSound);
            stepSfx = !File.Exists(Path.Combine(cfgDir, "nostep.txt"));
            ToolStripMenuItem miStep = new ToolStripMenuItem("走路的嗒嗒声");
            miStep.Checked = stepSfx;
            miStep.Click += delegate
            {
                stepSfx = !stepSfx; miStep.Checked = stepSfx;
                try { string nf = Path.Combine(cfgDir, "nostep.txt"); if (stepSfx) File.Delete(nf); else File.WriteAllText(nf, "1"); } catch { }
            };
            m.Items.Add(miStep);
            miWork = new ToolStripMenuItem("手动：假装 Claude 在工作", null, delegate
            {
                manualWork = !manualWork;
                miWork.Checked = manualWork;
            });
            m.Items.Add(miWork);
            miAuto = new ToolStripMenuItem("开机自动启动", null, delegate { ToggleAutostart(); });
            miAuto.Checked = File.Exists(StartupFile());
            m.Items.Add(miAuto);
            m.Items.Add("检测诊断（识别不到时用）", null, delegate { Diagnose(); });
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add("退出", null, delegate { SaveState(); SaveDiary(); Application.Exit(); });
            m.Opening += delegate
            {
                miSleep.Text = state == "sleep" ? "叫醒" : "睡觉";
                int h = (aff + 10) / 20;
                miAff.Text = "亲密度  " + new string('♥', h) + new string('♡', 5 - h) + "  (" + aff + ")";
            };
            BuildFeatureMenu(m, 6);
            BuildAgentMenu(m);
            ContextMenuStrip = m;
        }

        string StartupFile()
        {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), Names.Pet + "桌宠.vbs");
        }

        void ToggleAutostart()
        {
            string f = StartupFile();
            try
            {
                if (File.Exists(f)) { File.Delete(f); miAuto.Checked = false; Say("好，开机就不自动出来啦。", 4); return; }
                string ps1 = Program.Script != "" ? Program.Script : Path.Combine(dir, "desk-pet.ps1");
                string vbs = "Set sh = CreateObject(\"WScript.Shell\")\r\n" +
                    "sh.Run \"powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File \"\"" + ps1 + "\"\"\", 0, False\r\n";
                File.WriteAllText(f, vbs, Encoding.Default);
                miAuto.Checked = true;
                Say("以后开机我就自己跑出来陪你！", 4);
            }
            catch (Exception ex) { Say("设置失败了：" + ex.Message, 6); }
        }

        // ---------- 鼠标 ----------
        void OnDown(object o, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            mouseDown = true; dragged = false;
            downAt = Cursor.Position;
            heldOffset = new Point((int)(posX - downAt.X), (int)(posY - downAt.Y));
        }
        void OnMove(object o, MouseEventArgs e)
        {
            if (!mouseDown) return;
            Point p = Cursor.Position;
            if (!dragged && Math.Abs(p.X - downAt.X) + Math.Abs(p.Y - downAt.Y) > 5)
            {
                dragged = true;
                mode = Mode.Held; perchWnd = IntPtr.Zero;
                Interact();
                Set("held");
            }
        }
        void OnUp(object o, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            mouseDown = false;
            if (dragged)
            {
                // 往下甩（带一点弧线）才会掉下去摔倒；其他时候松手就停在原地
                if (cursorVY > 650 && cursorVY > Math.Abs(cursorVX) * .35)
                {
                    mode = Mode.Fall; thrown = true;
                    vx = Math.Max(-1400, Math.Min(1400, cursorVX * .8));
                    vy = Math.Max(300, Math.Min(1500, cursorVY * .6));
                    Set("fall");
                }
                else
                {
                    Rectangle wa = ScreenArea(posX);
                    if (posY > wa.Bottom) posY = wa.Bottom;
                    mode = Math.Abs(posY - wa.Bottom) < 4 ? Mode.Ground : Mode.Free;
                    if (mode == Mode.Ground) posY = wa.Bottom;
                    homeX = posX; vx = 0; vy = 0;
                    squash = 1; Set(working ? "think" : "land");
                    SaveState();
                }
                return;
            }
            if (e.Location.Y > BUBBLE_H) Poke();
        }

        // ---------- 状态切换 ----------
        void Set(string s)
        {
            state = s; since = now;
            parts.RemoveAll(delegate(Particle p) { return p.Type == "z"; });
            if (s == "done") Spawn("spark", 9);
            if (s == "party") Spawn("conf", 14);
            StateSound(s);
        }

        bool Grounded() { return mode == Mode.Ground || mode == Mode.Perch || mode == Mode.Free; }
        bool Calm()
        {
            return state == "idle" || state == "walk" || state == "sit" || state == "daydream" || state == "lookaround";
        }

        void Interact()
        {
            lastInteract = now; unanswered = 0;
        }

        void Poke()
        {
            if (Acknowledge()) return;
            Interact();
            PlaySfx("poke");
            if (working) UserAct(2);
            if (state == "sulk") { Forgive(); return; }
            pokes.RemoveAll(delegate(double t) { return now - t > 4; });
            pokes.Add(now);
            if (pokes.Count >= 8) { pokes.Clear(); Set("angry"); Say("哼！别戳啦！", 3); AddAff(-4); return; }
            if (pokes.Count >= 5) { Set("dizzy"); Say("晕……晕了……", 3); return; }
            AddAff(1); if (today != null) today.Poke++;
            Set(Pick(new string[] { "surprised", "surprised", "wink", "shy", "happy" }));
        }

        void Pat()
        {
            if (Acknowledge()) return;
            Interact();
            PlaySfx("purr");
            if (working) UserAct(3.4);
            if (state == "sulk") { Forgive(); return; }
            AddAff(3); if (today != null) today.Pat++;
            Set(rnd.NextDouble() < .5 ? "love" : "shy");
            if (Festival() == "petbday" && Once(DateTime.Now.ToString("yyyyMMdd") + "bdaypat"))
            { Set("party"); Say("生日摸头！这是我今天收到的最好的礼物～", 4); return; }
            if (aff >= 80) Say(Pick(new string[] { "最喜欢你啦！", "嘿嘿，再摸一下嘛～", "被你摸头是今天最开心的事！" }), 3);
            else Say(Pick(new string[] { "嘿嘿，好舒服～", "再摸摸嘛～", "唔……有点不好意思。" }), 3);
        }

        void Forgive()
        {
            AddAff(5);
            Set("shy");
            Say("哼……好吧，原谅你了。下次不许不理我。", 4);
        }

        double userActUntil;
        // m 主动叫它做的动作，就算 AI 在工作也先做完，再回去陪 AI
        void UserAct(double seconds) { userActUntil = now + seconds; }
        void Act(string s)
        {
            Interact();
            Set(s);
            double h;
            UserAct(HOLD_T.TryGetValue(s, out h) ? h + .2 : 4);
        }

        string Pick(string[] a) { return a[rnd.Next(a.Length)]; }

        static readonly Dictionary<string, double> HOLD_T = new Dictionary<string, double> {
            {"done",1.6},{"brush",7},{"shower",8},{"hungry",5},{"sign",12},{"party",2.6},{"confused",1.8},{"miss",5},{"music",8},{"read",8},{"juggle",6},{"bird",6.5},{"wave",2.2},{"surprised",1.0},{"happy",3},{"lookaround",2.6},{"daydream",7},{"talk",4},{"wink",1.6},
            {"shy",3.2},{"love",3.2},{"dizzy",3},{"angry",3.2},{"sad",4},{"dance",5},{"land",.35},
            {"sit",7},{"eat",3.6},{"jumpy",.6}};
        static readonly Dictionary<string, string> HOLD_N = new Dictionary<string, string> {
            {"done","party"},{"brush","idle"},{"shower","happy"},{"hungry","idle"},{"sign","idle"},{"party","idle"},{"confused","idle"},{"miss","idle"},{"music","idle"},{"read","idle"},{"juggle","idle"},{"bird","idle"},{"wave","idle"},{"surprised","happy"},{"happy","idle"},{"lookaround","idle"},{"daydream","idle"},{"talk","idle"},
            {"wink","idle"},{"shy","idle"},{"love","idle"},{"dizzy","idle"},{"angry","idle"},{"sad","idle"},{"dance","idle"},
            {"land","idle"},{"sit","idle"},{"eat","yum"},{"jumpy","idle"}};

        static readonly string[] DONE_LINES = {
            "Claude 做完啦！快去看看吧～", "完成！我一直在旁边帮你盯着呢。", "好啦好啦，Claude 回答出来了！",
            "叮～ Claude 交作业了！", "Claude 做完了！要不要顺便歇一会儿？", Names.Nick + "，Claude 那边好了，去看看结果？",
            "搞定！Claude 今天也很努力呢。", "Claude 停下来啦，看看是不是你想要的？" };
        static readonly string[] BORED_LINES = {
            "好安静呀……你在忙什么呢？", "我刚刚数了自己的像素，一共 750 个！", "要不要喝口水，伸个懒腰？",
            "唔，有点无聊，陪我说两句嘛。（右键可以和我聊天）", "你今天过得怎么样？", "我在想……云会不会也想下来走走。" };

        // ---------- 每帧 ----------
        bool tickErrorLogged;
        void Tick()
        {
            try { TickInner(); }
            catch (Exception ex)
            {
                if (!tickErrorLogged)
                {
                    tickErrorLogged = true;
                    try { File.WriteAllText(Path.Combine(dir, "运行日志.txt"), DateTime.Now + "\r\n" + ex.ToString(), Encoding.UTF8); } catch { }
                }
                Invalidate();
            }
        }

        void TickInner()
        {
            now = Now();
            double dt = lastFrame > 0 ? Math.Min(.1, now - lastFrame) : .033;
            lastFrame = now;
            double t = now - since;

            SenseUser(dt);
            CheckWork();
            FeaturesTick(dt);
            RingTick();
            StepSound();
            ProactiveTick();

            // 自动转换
            double hold;
            if (state == "eat" || state == "yum" || HOLD_T.TryGetValue(state, out hold))
            {
                if (state == "yum") { Set("happy"); Say(Pick(new string[] { "好吃！橘子最棒了！", "嗷呜～甜甜的！", "吃饱饱，有力气陪你了！" }), 4); }
                else if (HOLD_T.TryGetValue(state, out hold) && t > hold) Set(HOLD_N[state]);
            }
            else if (state == "stretch" && t > 2.8) { string n = afterStretch; afterStretch = "idle"; Set(n); }
            else if (state == "walk" && !double.IsNaN(walkUntil) && now > walkUntil) Set(rnd.NextDouble() < .3 ? "sit" : "idle");
            else if (state == "type" && (keyEvents.Count == 0 || now - keyEvents[keyEvents.Count - 1] > 2.5)) Set("idle");
            else if (state == "sulk" && now - lastSulkLine > 60) { lastSulkLine = now; Say(Pick(new string[] { "哼。", "……", "哼，不理你。" }), 3); }
            else if (state == "idle" && !working && !chatting && t > nextIdleAct) IdleAction();

            if (now > nextBlink) { blinkUntil = now + .13; nextBlink = now + 2 + rnd.NextDouble() * 3.5; }

            Physics(dt);
            UpdateParticles(dt);
            if (now - lastTimeCheck > 20) { lastTimeCheck = now; TimeEvents(); }
            Invalidate();
        }

        // ---------- 感知你在做什么 ----------
        void SenseUser(double dt)
        {
            Point c = Cursor.Position;
            cursorVX = cursorVX * .6 + (c.X - lastCursor.X) / Math.Max(dt, .001) * .4;
            cursorVY = cursorVY * .6 + (c.Y - lastCursor.Y) / Math.Max(dt, .001) * .4;
            double speed = Math.Sqrt(cursorVX * cursorVX + cursorVY * cursorVY);
            bool cursorMoved = c != lastCursor;
            lastCursor = c;

            // 键盘：输入时间变了而鼠标没动，就算敲了一下键
            uint tick = Win.LastInputTick();
            if (tick != lastInputTick)
            {
                if (!cursorMoved && c == lastInputCursor) keyEvents.Add(now);
                lastInputTick = tick; lastInputCursor = c;
            }
            keyEvents.RemoveAll(delegate(double k) { return now - k > 3; });
            bool typing = keyEvents.Count >= 4;
            if (typing && !working && Grounded() && Calm()) { Set("type"); }

            // 点"停止"或按 Esc：记下来，用来判断是不是被打断
            try
            {
                if ((Win.GetAsyncKeyState(0x01) & 0x8000) != 0)
                {
                    lock (stopRects) foreach (KeyValuePair<string, Rectangle> sr in stopRects) if (sr.Value.Contains(c)) { lastStopClick = now; lastStopApp = sr.Key; }
                    if (OverClaude(c)) lastClaudeClick = now;
                }
                if ((Win.GetAsyncKeyState(0x1B) & 0x8000) != 0) lastEsc = now;
            }
            catch { }

            // 鼠标快速晃过 → 吓一跳；鼠标停在身上 → 害羞/开心
            double dx = c.X - posX, dy = c.Y - (posY - 22 * S);
            double dist = Math.Sqrt(dx * dx + dy * dy);
            if (speed > 4500 && dist < 260 && now - lastShakeReact > 6 && !working && Grounded() && Calm())
            {
                lastShakeReact = now; Set("surprised"); Say(Pick(new string[] { "哇！吓我一跳！", "什么东西飞过去了？！" }), 2.5);
            }
            if (dist < 22 * S && !mouseDown)
            {
                if (hoverSince < 0) hoverSince = now;
                if (now - hoverSince > 1.6 && now - lastHoverReact > 25 && !working && state == "idle")
                {
                    lastHoverReact = now; Set(aff >= 60 ? "love" : "shy");
                    Say(aff >= 60 ? "你在看我吗？嘿嘿～" : "唔……干嘛一直盯着我。", 3);
                }
            }
            else hoverSince = -1;

            // 离开与回来
            double idle = Win.IdleSeconds();
            if (!away && idle > 300) { away = true; awayStart = now - idle; }
            else if (away && idle < 2)
            {
                away = false; activeSince = now;
                ReturnFromAway(now - awayStart);
            }
            else if (!away && pendingDone && idle < 2)
            {
                pendingDone = false;
                string line = NICK + "，你刚才不在，Claude 已经做完啦！";
                Say(line, 8); Announce(line);
            }

            // 久坐提醒：连续在电脑前 45 分钟
            if (!away && now - activeSince > 45 * 60 && now - lastSitRemind > 45 * 60 && !working)
            {
                lastSitRemind = now; activeSince = now;
                afterStretch = "idle"; Set("stretch");
                string line = NICK + "，已经坐了四十五分钟啦，起来走走、喝口水吧！";
                Say(line, 8); Announce(line);
            }

            // 亲密度慢慢下降
            if (now - lastInteract > 20 * 60 && now - lastDecay > 20 * 60 && !away) { lastDecay = now; AddAff(-2); }
        }

        bool OverClaude(Point c)
        {
            try
            {
                Win.POINT p; p.X = c.X; p.Y = c.Y;
                IntPtr h = Win.GetAncestor(Win.WindowFromPoint(p), 2);
                uint pid; Win.GetWindowThreadProcessId(h, out pid);
                string name;
                if (!procNames.TryGetValue(pid, out name))
                {
                    try { name = Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant(); } catch { name = ""; }
                    procNames[pid] = name;
                }
                return name == "claude" || Array.IndexOf(BROWSERS, name) >= 0;
            }
            catch { return false; }
        }

        // ---------- Claude 的工作状态 ----------
        void CheckWork()
        {
            KeepAwake(detectedBusy || agentBusy);
            List<string> cur;
            lock (busyNow) cur = new List<string>(busyNow);
            if (manualWork && !cur.Contains("Claude")) cur.Add("Claude");
            // 每个 AI 分开算：谁开始、谁结束
            lock (cpuDetected) foreach (string a in cpuDetected) cpuWas.Add(a);
            foreach (string app in cur)
            {
                appLastSeen[app] = now;
                if (!appActive.Contains(app))
                {
                    appActive.Add(app);
                    appStarted[app] = now;
                    if (appActive.Count == 1) workStarted = now;
                    if (today != null) today.Work++;
                    lastBusyApp = app;
                    if (ringing && ringApp.Contains(app)) { ringing = false; bubbleUntil = 0; }
                }
            }
            List<string> finished = new List<string>();
            foreach (string app in appActive)
            {
                double seen; appLastSeen.TryGetValue(app, out seen);
                double st; appStarted.TryGetValue(app, out st);
                // 停止按钮消失一会儿才算做完：AI 分好几步干活时，步骤之间按钮会短暂消失，要等它真的停下来
                bool viaCpu; lock (cpuDetected) viaCpu = cpuDetected.Contains(app) || cpuWas.Contains(app);
                double grace = viaCpu ? 3 : (now - st > 30 ? 25 : 15);
                if (!cur.Contains(app) && now - seen > grace) finished.Add(app);
            }
            foreach (string app in finished)
            {
                appActive.Remove(app);
                double st0; appStarted.TryGetValue(app, out st0);
                double seen0; appLastSeen.TryGetValue(app, out seen0);
                bool cpuTask = cpuWas.Remove(app);
                double dur = seen0 - st0;
                // 太短的不算一个“任务”：一闪而过的按钮、后台随手占了一下 CPU
                if (dur < (cpuTask ? 40 : 6))
                {
                    LogEvent(app + " 只忙了 " + (int)dur + " 秒，不算完成任务，不摇铃");
                    continue;
                }
                lastInteract = lastChatAt = now; unanswered = 0;
                bool interrupted = (now - lastStopClick < 4 && (lastStopApp == app || lastStopApp == "")) || (now - lastEsc < 3 && now - lastClaudeClick < 60);
                if (interrupted)
                {
                    LogEvent(app + " 被中途停下 → 委屈，不摇铃");
                    if (!ringing) { Set("sad"); Say(Pick(new string[] { "唔……刚才那次被打断了。", "诶，停下来了吗？没关系，我等你。" }), 5); }
                }
                else if (WatchingApp(app))
                {
                    // m 正盯着这个 AI 的窗口：不用摇铃吵 TA，轻轻说一声就好
                    LogEvent(app + " 做完了（忙了 " + (int)dur + " 秒），你正看着它 → 只说一声，不摇铃");
                    if (!ringing && Grounded()) { Set("happy"); Say(app + " 做完啦～", 4); }
                }
                else { LogEvent(app + " 做完了（忙了 " + (int)dur + " 秒）"); StartRing(app); }
            }

            bool busy = appActive.Count > 0;
            if (busy)
            {
                notBusyCount = 0;
                if (!working)
                {
                    working = true;
                    if (mode == Mode.Held || mode == Mode.Fall || mode == Mode.Jump) return;
                    if (!ringing) Set("think");
                }
                if (ringing) return;   // 正在为做完的 AI 摇铃，就先不陪还在忙的那个思考
                bool busyState = state == "think" || state == "work" || state == "work2" || state == "build";
                if (now < userActUntil || state == "eat" || state == "catch" || state == "yum") busyState = true;
                else if (Grounded() && !busyState && state != "done" && now - since > 1) Set("think");
                double wt = now - workStarted;
                if (Grounded() && busyState && now >= userActUntil && state != "eat" && state != "catch" && state != "yum")
                {
                    // 想一会儿 → 在终端里敲命令 → 抱着电脑写代码，轮流来；超过两分钟戴上安全帽开始敲锤子
                    string want = wt > 120 ? "build" : new string[] { "think", "work", "work2" }[((int)(wt / 8)) % 3];
                    if (want != state) Set(want);
                }
            }
            else if (working)
            {
                working = false; notBusyCount = 0;
                if (!ringing && (state == "think" || state == "work" || state == "work2" || state == "build")) Set("idle");
            }
        }

        // ---------- 平时自己找事做 ----------
        void IdleAction()
        {
            nextIdleAct = 6 + rnd.NextDouble() * 7;
            if (FeatureIdle()) return;
            double idle = Win.IdleSeconds();

            if (!away && now - lastInteract > 40 * 60 && aff < 45)
            {
                Set("sulk"); lastSulkLine = now; Say("哼，你都不理我……", 4); return;
            }
            if (away && idle > 600) { afterStretch = "sleep"; Set("stretch"); return; }
            if (!away && now - lastInteract > 15 * 60 && idle > 180) { afterStretch = "sleep"; Set("stretch"); return; }

            if (!Grounded()) return;
            if (WalkPalDone()) return;
            List<KeyValuePair<string, int>> w = new List<KeyValuePair<string, int>>();
            w.Add(new KeyValuePair<string, int>("daydream", 14));
            w.Add(new KeyValuePair<string, int>("lookaround", 12));
            w.Add(new KeyValuePair<string, int>("happy", 8));
            w.Add(new KeyValuePair<string, int>("stretch", 7));
            if (Unlocked("dance")) w.Add(new KeyValuePair<string, int>("dance", 6));
            w.Add(new KeyValuePair<string, int>("wink", 6));
            w.Add(new KeyValuePair<string, int>("love", aff >= 70 ? 10 : 3));
            w.Add(new KeyValuePair<string, int>("shy", 4));
            w.Add(new KeyValuePair<string, int>("music", 8));
            w.Add(new KeyValuePair<string, int>("read", 7));
            if (Unlocked("juggle")) w.Add(new KeyValuePair<string, int>("juggle", 6));
            w.Add(new KeyValuePair<string, int>("bird", 5));
            bool walkPal = false; foreach (Look lk in looks) if (lk.Enabled && lk.When == "walk") walkPal = true;
            if (WalkRangePx() > 0) w.Add(new KeyValuePair<string, int>("walk", walkPal ? 20 : away ? 18 : 14));   // 遛着猫稍微多走一点
            w.Add(new KeyValuePair<string, int>("sit", 10));
            if (aff >= 70 && !away && WalkRangePx() > 0 && Math.Abs(Cursor.Position.X - posX) < WalkRangePx() * 2) w.Add(new KeyValuePair<string, int>("chase", 6));
            for (int wi = 0; wi < w.Count; wi++) w[wi] = new KeyValuePair<string, int>(w[wi].Key, Math.Max(0, (int)Math.Round(w[wi].Value * PersonaMult(w[wi].Key))));
            int sum = 0; foreach (KeyValuePair<string, int> kv in w) sum += kv.Value;
            if (sum <= 0) { Set("daydream"); return; }
            int x = rnd.Next(sum); string pick = "daydream";
            foreach (KeyValuePair<string, int> kv in w) { if ((x -= kv.Value) < 0) { pick = kv.Key; break; } }

            bool walkLook = false; foreach (Look lk in looks) if (lk.Enabled && lk.When == "walk") walkLook = true;
            if (pick == "walk") StartWalk(rnd.Next(2) == 0 ? -1 : 1, 2 + rnd.NextDouble() * (walkLook ? 4 : 2.5), double.NaN);
            else if (pick == "chase") { StartWalk(Cursor.Position.X > posX ? 1 : -1, 3, Cursor.Position.X); }
            else if (pick == "perch") { if (!TryJumpToWindow(false)) Set("daydream"); }
            else if (pick == "hopdown") HopDown();
            else Set(pick);
        }

        void StartWalk(int d, double seconds, double target)
        {
            walkDir = d; walkUntil = now + seconds; walkTarget = target; walkGear = seconds > 4 && rnd.NextDouble() < .45;
            Set("walk");
        }

        // ---------- 窗口 ----------
        bool GoodPerch(IntPtr h, out Win.RECT r)
        {
            r = new Win.RECT();
            if (h == IntPtr.Zero || h == Handle || !Win.IsWindow(h) || !Win.IsWindowVisible(h) || Win.IsIconic(h) || Win.IsZoomed(h)) return false;
            string cls = Win.ClassOf(h);
            if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd" ||
                cls == "Windows.UI.Core.CoreWindow" || cls == "#32768") return false;
            uint pid; Win.GetWindowThreadProcessId(h, out pid);
            if (pid == myPid) return false;
            int cloaked = 0;
            try { Win.DwmGetWindowAttribute(h, 14, out cloaked, 4); } catch { }
            if (cloaked != 0) return false;
            if (!Win.GetWindowRect(h, out r)) return false;
            if (r.Right - r.Left < 50 * S || r.Bottom - r.Top < 120) return false;
            Screen sc = Screen.FromPoint(new Point((r.Left + r.Right) / 2, Math.Max(r.Top, 0)));
            Rectangle wa = sc.WorkingArea;
            if (r.Top < wa.Top + 70 * S || r.Top > wa.Bottom - 60) return false;
            return true;
        }

        bool TryJumpToWindow(bool asked)
        {
            if (mode != Mode.Ground && mode != Mode.Perch) return false;
            IntPtr h = Win.GetForegroundWindow();
            Win.RECT r;
            if (!GoodPerch(h, out r))
            {
                if (asked) Say("这个窗口我跳不上去……（最大化或太靠上的窗口不行）", 4);
                return false;
            }
            double margin = 24 * S;
            double tx = Math.Max(r.Left + margin, Math.Min(r.Right - margin, posX + (rnd.NextDouble() - .5) * 200));
            StartJump(tx, r.Top, h, false);
            return true;
        }

        void HopDown()
        {
            Rectangle wa = Screen.FromPoint(new Point((int)posX, (int)posY)).WorkingArea;
            double tx = posX + (posX - perchRect.Left < perchRect.Right - posX ? -1 : 1) * (Math.Min(posX - perchRect.Left, perchRect.Right - posX) + 30 * S);
            tx = Math.Max(wa.Left + 24 * S, Math.Min(wa.Right - 24 * S, tx));
            StartJump(tx, wa.Bottom, IntPtr.Zero, true);
        }

        void StartJump(double tx, double ty, IntPtr wnd, bool floor)
        {
            mode = Mode.Jump; jumpT = 0; jx0 = posX; jy0 = posY; jx1 = tx; jy1 = ty; jumpWnd = wnd; jumpToFloor = floor;
            perchWnd = IntPtr.Zero;
            Set("jump");
        }

        // ---------- 物理 ----------
        void Physics(double dt)
        {
            Point c = Cursor.Position;
            switch (mode)
            {
                case Mode.Held:
                    posX = c.X + heldOffset.X; posY = c.Y + heldOffset.Y;
                    break;

                case Mode.Jump:
                    {
                        jumpT += dt / .75;
                        double u = Math.Min(1, jumpT);
                        double h = 60 + Math.Abs(jy1 - jy0) * .3;
                        posX = jx0 + (jx1 - jx0) * u;
                        posY = jy0 + (jy1 - jy0) * u - Math.Sin(u * Math.PI) * h;
                        if (u >= 1)
                        {
                            Win.RECT r;
                            if (!jumpToFloor && GoodPerch(jumpWnd, out r)) { perchWnd = jumpWnd; perchRect = r; posY = r.Top; mode = Mode.Perch; }
                            else if (jumpToFloor) { mode = Mode.Ground; }
                            else { mode = Mode.Fall; vx = 0; vy = 0; break; }
                            Land(500);
                            if (walkAfterLand && mode == Mode.Ground) { walkAfterLand = false; homeX = posX; UserAct(8); StartWalk(rnd.Next(2) == 0 ? -1 : 1, 6, double.NaN); }
                        }
                        break;
                    }

                case Mode.Fall:
                    {
                        double oldY = posY;
                        vy += 2600 * dt;
                        posX += vx * dt; posY += vy * dt;
                        Rectangle wa = ScreenArea(posX);
                        if (posX < wa.Left + 22 * S) { posX = wa.Left + 22 * S; vx = -vx * .5; }
                        if (posX > wa.Right - 22 * S) { posX = wa.Right - 22 * S; vx = -vx * .5; }
                        if (posY < wa.Top + 60 * S && vy < 0) { vy = 0; }
                        // 落到当前窗口顶上
                        IntPtr fg = Win.GetForegroundWindow();
                        Win.RECT r;
                        if (vy > 0 && GoodPerch(fg, out r) && oldY <= r.Top && posY >= r.Top && posX > r.Left + 18 * S && posX < r.Right - 18 * S)
                        {
                            posY = r.Top; perchWnd = fg; perchRect = r; mode = Mode.Perch; Land(vy); homeX = posX; break;
                        }
                        if (posY >= wa.Bottom)
                        {
                            posY = wa.Bottom; mode = Mode.Ground; Land(vy); homeX = posX; SaveState();
                            if (walkAfterLand && state != "dizzy") { walkAfterLand = false; UserAct(8); StartWalk(rnd.Next(2) == 0 ? -1 : 1, 6, double.NaN); }
                        }
                        break;
                    }

                case Mode.Perch:
                    {
                        Win.RECT r;
                        if (!GoodPerch(perchWnd, out r)) { mode = Mode.Fall; vx = 0; vy = 0; if (state != "held") Set("fall"); break; }
                        posX += r.Left - perchRect.Left;          // 窗口被拖动，跟着走
                        posY = r.Top;
                        perchRect = r;
                        if (posX < r.Left + 14 * S || posX > r.Right - 14 * S)
                        {
                            if (state == "walk" || state == "pace") { walkDir = -walkDir; posX = Math.Max(r.Left + 14 * S, Math.Min(r.Right - 14 * S, posX)); }
                            else { mode = Mode.Fall; vx = 0; vy = 0; Set("fall"); break; }
                        }
                        if (double.IsNaN(homeX)) homeX = posX;
                        Walk(dt, Math.Max(r.Left + 20 * S, homeX - WalkRangePx()), Math.Min(r.Right - 20 * S, homeX + WalkRangePx()));
                        break;
                    }

                case Mode.Ground:
                    {
                        Rectangle wa = ScreenArea(posX);
                        if (Math.Abs(posY - wa.Bottom) > 2) { mode = Mode.Free; break; }  // 任务栏位置变了，就待在原地
                        if (double.IsNaN(homeX)) homeX = posX;
                        Walk(dt, Math.Max(wa.Left + 24 * S, homeX - WalkRangePx()), Math.Min(wa.Right - 24 * S, homeX + WalkRangePx()));
                        break;
                    }

                case Mode.Free:
                    {
                        Rectangle wa = ScreenArea(posX);
                        if (double.IsNaN(homeX)) homeX = posX;
                        Walk(dt, Math.Max(wa.Left + 24 * S, homeX - WalkRangePx()), Math.Min(wa.Right - 24 * S, homeX + WalkRangePx()));
                        break;
                    }
            }
            Place();
        }

        Rectangle ScreenArea(double x)
        {
            Screen best = Screen.PrimaryScreen;
            foreach (Screen sc in Screen.AllScreens) if (x >= sc.Bounds.Left && x < sc.Bounds.Right) best = sc;
            return best.WorkingArea;
        }

        void Walk(double dt, double minX, double maxX)
        {
            if (state != "walk" && state != "pace") return;
            if (maxX - minX < 4) { Set("idle"); return; }
            double speed = (state == "pace" ? 8 : 10) * S;
            posX += walkDir * speed * dt;
            if (state == "pace")
            {
                if (posX > paceCenter + 30 * S) walkDir = -1;
                if (posX < paceCenter - 30 * S) walkDir = 1;
            }
            if (!double.IsNaN(walkTarget) && state == "walk" && Math.Abs(posX - walkTarget) < 6)
            {
                walkTarget = double.NaN; Set(aff >= 70 ? "love" : "idle"); return;
            }
            if (posX < minX) { posX = minX; walkDir = 1; walkTarget = double.NaN; }
            if (posX > maxX) { posX = maxX; walkDir = -1; walkTarget = double.NaN; }
        }

        void Land(double speed)
        {
            squash = speed > 1500 ? 3 : speed > 700 ? 2 : 1;
            vx = 0; vy = 0;
            Spawn("dust", 4);
            bool wasThrown = thrown; thrown = false;
            if (wasThrown)
            {
                squash = 3;
                Set("dizzy");
                PlaySfx("thud");
                Say(Pick(new string[] { "哎哟！摔倒了……", "呜……屁股好痛……", "眼前全是小星星……", Names.Nick + " 好坏，把我摔下来了！" }), 3);
                if (today != null) today.Poke++;
                return;
            }
            if (working) { Set("think"); return; }
            Set("land");
        }

        // ---------- 粒子 ----------
        void UpdateParticles(double dt)
        {
            for (int i = parts.Count - 1; i >= 0; i--)
            {
                Particle p = parts[i];
                p.Life -= dt; p.X += p.VX * dt; p.Y += p.VY * dt;
                if (p.Type == "spark" || p.Type == "speck" || p.Type == "crumb") p.VY += 4 * dt;
                if (p.Type == "orange") { p.VY += 18 * dt; if (p.Y >= 10.25) { p.Life = 0; Set("eat"); } }
                if (p.Life <= 0) parts.RemoveAt(i);
            }
            if (state == "sleep" && now - lastSpawn > 1.4) { Spawn("z", 1); lastSpawn = now; }
            if ((state == "love" || state == "miss") && now - lastSpawn > .6) { Spawn("heart", 1); lastSpawn = now; }
            if (state == "music" && now - lastSpawn > .7) { Spawn("note", 1); lastSpawn = now; }
            if (state == "bell" && now - lastSpawn > .8) { Spawn("note", 1); lastSpawn = now; }
            if (state == "dance" && now - lastSpawn > .5) { Spawn("note", 1); lastSpawn = now; }
            if (state == "angry" && now - lastSpawn > .45) { Spawn("puff", 1); lastSpawn = now; }
            if (state == "eat" && now - lastSpawn > .4) { Spawn("crumb", 1); lastSpawn = now; }
            string fest = Festival();
            if (now - lastFestSpawn > 1.1)
            {
                lastFestSpawn = now;
                if (fest == "christmas") Spawn("snow", 2);
                else if ((fest == "newyear" || fest == "birthday") && rnd.NextDouble() < .35) Spawn("conf", 3);
                else if ((fest == "valentine" || fest == "qixi") && rnd.NextDouble() < .4) Spawn("heart", 1);
            }
            if ((state == "work2" || state == "type") && now - lastSpawn > .35) { Spawn("code", 1); lastSpawn = now; }
        }

        void Spawn(string type, int n)
        {
            for (int i = 0; i < n; i++)
            {
                Particle p = new Particle(); p.Type = type; p.Life = 1.2 + rnd.NextDouble() * .6;
                double r1 = rnd.NextDouble(), r2 = rnd.NextDouble();
                if (type == "spark") { bool left = i % 2 == 0; p.X = left ? -2 + r1 * 3 : 14 + r1 * 2; p.Y = 2 + r2 * 5; p.VX = (left ? -1 : 1) * (.5 + r1); p.VY = -2 - r2 * 2; if (i % 3 == 2) p.Type = "speck"; }
                else if (type == "heart") { p.X = 12 + r1 * 2; p.Y = 4; p.VX = .6; p.VY = -2; }
                else if (type == "z") { p.X = 12.5; p.Y = 4; p.VX = .8; p.VY = -1.2; p.Life = 2.2; }
                else if (type == "note") { p.X = rnd.Next(2) == 0 ? -1 : 14.5; p.Y = 5; p.VX = 0; p.VY = -2; }
                else if (type == "puff") { p.X = rnd.Next(2) == 0 ? 1.5 : 12; p.Y = 4.5; p.VX = 0; p.VY = -1.8; p.Life = .9; }
                else if (type == "q") { p.X = 13; p.Y = 3; p.VX = 0; p.VY = -.8; p.Life = 1.4; }
                else if (type == "dust") { bool left = i % 2 == 0; p.X = left ? 1.5 : 12.5; p.Y = 14.5; p.VX = left ? -3.5 : 3.5; p.VY = -.6; p.Life = .45; }
                else if (type == "crumb") { p.X = 7 + r1; p.Y = 12; p.VX = (r2 - .5) * 3; p.VY = -1; p.Life = .7; }
                else if (type == "code") { p.X = 8 + r1 * 5; p.Y = 9; p.VX = 0; p.VY = -2.2; p.Life = .7; }
                else if (type == "snow") { p.X = -2 + r1 * 19; p.Y = -5; p.VX = (r2 - .5) * .6; p.VY = 1.2 + r2 * .6; p.Life = 9; }
                else if (type == "conf") { p.X = 1 + r1 * 13; p.Y = -3 + r2 * 4; p.VX = (rnd.Next(5) - 2) * .01 + .001; p.VY = 1.5 + r2; p.Life = 2.2; }
                else if (type == "orange") { p.X = 6.5; p.Y = -5; p.VX = 0; p.VY = 3; p.Life = 5; }
                parts.Add(p);
            }
        }

        // ---------- 喂食 ----------
        void Feed()
        {
            Interact();
            if (!Grounded()) return;
            if (working) UserAct(6);
            fed.RemoveAll(delegate(double f) { return now - f > 1800; });
            if (fed.Count >= 4) { Set("dizzy"); Say("吃不下啦……肚子圆滚滚的～", 3); return; }
            fed.Add(now);
            AddAff(6); hunger = Math.Max(0, hunger - 40); SaveExtra(); if (today != null) today.Feed++;
            Set("catch");
            Spawn("orange", 1);
        }

        // ---------- 时间感知 ----------
        void Greet()
        {
            int h = DateTime.Now.Hour;
            string g = h < 5 ? Names.Nick + "，这么晚还没睡呀？我陪你。" : h < 11 ? "早上好 " + Names.Nick + "！今天也一起加油～" :
                h < 14 ? "中午好 " + Names.Nick + "！吃饭了吗？" : h < 18 ? "下午好 " + Names.Nick + "！Claude 工作的时候我会陪你等着。" :
                h < 23 ? "晚上好 " + Names.Nick + "！今天辛苦啦。" : Names.Nick + "，这么晚还在忙呀？我陪你。";
            Say(g, 6); Set("wave");
            said.Add(DateTime.Now.ToString("yyyyMMdd") + "greet");
        }

        void TimeEvents()
        {
            if (away || working || Win.IdleSeconds() > 120) return;
            DateTime d = DateTime.Now;
            string day = d.ToString("yyyyMMdd");
            int h = d.Hour, m = d.Minute;
            double hm = h + m / 60.0;
            if (hm >= 6 && hm < 10.5 && Once(day + "morning")) { Remind("早上好！新的一天开始啦～", "happy"); return; }
            if (hm >= 11.75 && hm < 13 && Once(day + "lunch")) { Remind("中午啦，记得去吃饭哦！", "happy"); return; }
            if (hm >= 17.75 && hm < 19 && Once(day + "dinner")) { Remind("该吃晚饭啦～别饿着肚子工作。", "happy"); return; }
            if ((h >= 23 || h < 2) && Once(day + "late" + h + (m / 30)))
            {
                afterStretch = "idle"; Set("stretch");
                Remind(Pick(new string[] { "已经很晚啦，早点睡吧……", "呼啊……我都困了，你也去休息吧？", "熬夜对身体不好哦，明天再继续吧。" }), null);
                return;
            }
            string fest = festMode == "" ? Festival() : "";
            if (fest != "" && Once(day + "fest"))
            {
                if (fest == "petbday") { Remind(PetBdayLine(), "party"); return; }
                foreach (string[] f in FESTS) if (f[0] == fest) { Remind(f[2], fest == "christmas" || fest == "newyear" || fest == "birthday" ? "party" : "happy"); return; }
            }
            if (m == 0 && Once(day + "hour" + h) && Calm()) { Say(h + " 点啦！", 4); Set("wink"); }
        }

        bool Once(string key) { if (said.Contains(key)) return false; said.Add(key); return true; }

        void Remind(string line, string mood)
        {
            if (mood != null) Set(mood);
            Say(line, 8); Announce(line);
        }

        string hatChoice = "bow";
        string festMode = "";        // "" = 跟着日历走，"off" = 不换装，其他 = 预览某个节日
        string birthday = "";        // config.txt 里的 birthday=MM-DD

        // 农历节日在公历上的日期（2026–2031）
        static readonly string[] CNY = { "2026-02-17", "2027-02-06", "2028-01-26", "2029-02-13", "2030-02-03", "2031-01-23" };
        static readonly string[] DUANWU = { "2026-06-19", "2027-06-09", "2028-05-28", "2029-06-16", "2030-06-05", "2031-06-24" };
        static readonly string[] QIXI = { "2026-08-19", "2027-08-08", "2028-08-26", "2029-08-16", "2030-08-05", "2031-08-24" };
        static readonly string[] ZHONGQIU = { "2026-09-25", "2027-09-15", "2028-10-03", "2029-09-22", "2030-09-12", "2031-10-01" };

        static bool Near(DateTime d, string[] dates, int before, int after)
        {
            foreach (string s in dates)
            {
                DateTime c = DateTime.Parse(s, System.Globalization.CultureInfo.InvariantCulture);
                double diff = (d.Date - c).TotalDays;
                if (diff >= -before && diff <= after) return true;
            }
            return false;
        }

        static readonly string[][] FESTS = {
            new string[] { "newyear", "元旦", "新年快乐！今年也请多多指教～" },
            new string[] { "cny", "春节", "过年好！新年快乐，红包拿来～" },
            new string[] { "lantern", "元宵节", "元宵节快乐！今天要吃汤圆哦～" },
            new string[] { "valentine", "情人节", "情人节快乐！我最喜欢你啦～" },
            new string[] { "children", "儿童节", "儿童节快乐！今天大家都是小朋友！" },
            new string[] { "dragonboat", "端午节", "端午安康！我想吃粽子～" },
            new string[] { "qixi", "七夕", "七夕快乐！喜鹊都来陪我啦～" },
            new string[] { "midautumn", "中秋节", "中秋快乐！月亮好圆，月饼好甜～" },
            new string[] { "national", "国庆节", "国庆快乐！放假啦，出去玩吧～" },
            new string[] { "halloween", "万圣节", "不给糖就捣蛋！嘿嘿～" },
            new string[] { "christmas", "圣诞节", "圣诞快乐！下雪啦～" },
            new string[] { "birthday", "生日", "生日快乐！今天你最大！" },
            new string[] { "petbday", Names.Pet + "的生日", "今天是我的生日！谢谢 " + Names.Nick + " 把我带到桌面上～" },
        };

        string Festival()
        {
            if (festMode == "off") return "";
            if (festMode != "") return festMode;
            DateTime d = DateTime.Now;
            if (birthday.Length == 5 && d.ToString("MM-dd") == birthday) return "birthday";
            if (d.ToString("MM-dd") == PetBday()) return "petbday";
            if (Near(d, CNY, 7, 0)) return "cny";                 // 除夕前一周到初一
            if (Near(d, CNY, -1, 6)) return "cny";                // 初二到初七
            if (Near(d, CNY, -14, 14)) return "lantern";          // 正月十五
            if ((d.Month == 12 && d.Day == 31) || (d.Month == 1 && d.Day <= 2)) return "newyear";
            if (d.Month == 2 && d.Day == 14) return "valentine";
            if (d.Month == 6 && d.Day == 1) return "children";
            if (Near(d, DUANWU, 1, 1)) return "dragonboat";
            if (Near(d, QIXI, 0, 0)) return "qixi";
            if (Near(d, ZHONGQIU, 2, 1)) return "midautumn";
            if (d.Month == 10 && d.Day <= 7) return "national";
            if ((d.Month == 10 && d.Day >= 29) || (d.Month == 11 && d.Day <= 1)) return "halloween";
            if (d.Month == 12 && d.Day >= 20 && d.Day <= 26) return "christmas";
            return "";
        }

        string Hat()
        {
            string f = Festival();
            switch (f)
            {
                case "newyear": case "birthday": case "petbday": return "party";
                case "cny": case "lantern": return "cny";
                case "valentine": return "heartband";
                case "qixi": return "magpie";
                case "midautumn": return "bunny";
                case "halloween": return "witch";
                case "christmas": return "santa";
                case "dragonboat": return "band";
            }
            DateTime d = DateTime.Now;
            if (d.Hour >= 23 || d.Hour < 6) return "night";
            return hatChoice;
        }

        // 节日手里拿的东西（儿童节气球、元宵灯笼、端午粽子、中秋月饼、国庆小红旗、春节红包、生日蛋糕）
        string HeldItem()
        {
            switch (Festival())
            {
                case "cny": return "hongbao";
                case "lantern": return "lantern";
                case "children": return "balloon";
                case "dragonboat": return "zongzi";
                case "midautumn": return "mooncake";
                case "national": return "flag";
                case "birthday": case "petbday": return "cake";
                case "halloween": return "candy";
            }
            return "";
        }

        // ---------- 绘制（坐标单位 = 参考图里的一个"像素格"，可以用 0.25 的小数） ----------
        // 身体 2..13 × 6..13，眼睛 1×2，手 2×2，四只脚 1×2，脚底在 y=15
        Graphics G; int OX, OY;
        int PX(double x) { return OX + (int)Math.Round((x + UX0) * 4) * S; }
        int PY(double y) { return OY + (int)Math.Round((y + UY0) * 4) * S; }
        void U(double x, double y, double w, double h, Brush b)
        {
            int cx = (int)Math.Round((x + UX0) * 4), cy = (int)Math.Round((y + UY0) * 4);
            int cw = (int)Math.Round(w * 4), ch = (int)Math.Round(h * 4);
            if (cw <= 0 || ch <= 0) return;
            G.FillRectangle(b, OX + cx * S, OY + cy * S, cw * S, ch * S);
        }
        void Bits(string[] rows, double x, double y, double px, Brush b)
        {
            for (int j = 0; j < rows.Length; j++)
                for (int i = 0; i < rows[j].Length; i++)
                    if (rows[j][i] == '1') U(x + i * px, y + j * px, px, px, b);
        }
        int PixScale(double sizeUnits) { return Math.Max(1, (int)Math.Round(sizeUnits * 4 * S / 12.0)); }
        void PixText(string s, double x, double y, double sizeUnits, Brush b, bool cjk)
        {
            if (ptext != null && ptext.Loaded) { ptext.DrawLine(G, s, PX(x), PY(y) + S, PixScale(sizeUnits), b); return; }
            using (Font f = new Font(cjk ? "Microsoft YaHei UI" : "Consolas", (float)(sizeUnits * 4 * S), FontStyle.Bold, GraphicsUnit.Pixel))
            {
                G.TextRenderingHint = TextRenderingHint.SingleBitPerPixelGridFit;
                G.DrawString(s, f, b, PX(x), PY(y));
            }
        }
        static int Seq(double t, double step, int[] v) { return v[(int)(t / step) % v.Length]; }
        static double SeqD(double t, double step, double[] v) { return v[(int)(t / step) % v.Length]; }

        static readonly string[] CMDS = { "git", "npm test", "ls", "build", "edit", "grep" };

        protected override void OnPaint(PaintEventArgs e)
        {
            G = e.Graphics;
            G.SmoothingMode = SmoothingMode.None;
            OX = (ClientSize.Width - GW * S) / 2; OY = BUBBLE_H;
            double t = now - since, n = now;
            bool blink = now < blinkUntil;

            double dx = 0, dy = 0, lx = 0, ly = 0, armL = 0, armR = 0, armLX = 0, armRX = 0, legA = 0, legB = 0, legLen = 2, sq = 0;
            string eye = blink ? "blink" : "open", mouth = "", prop = "", over = "";
            bool blush = false, shadow = Grounded(), ownHat = false, flat = false, hideArmL = false, hideArmR = false, sweat = false;

            switch (state)
            {
                case "idle":
                    {
                        double c = n % 2.6; dy = (c > 1.6 && c < 2.3) ? -.25 : 0;
                        Point cp = Cursor.Position;
                        lx = Clamp((cp.X - posX) / 250.0) * .5; ly = Clamp((cp.Y - (posY - 22 * S)) / 200.0) * .5;
                        break;
                    }
                case "think":
                    lx = .5; ly = -.5; armR = 1 + SeqD(n, .5, new double[] { 0, .25 }); over = "dots";
                    sweat = now - workStarted > 30 && working;
                    break;
                case "work":
                    ly = -.5; dy = -SeqD(n, .2, new double[] { 0, .25 }); over = "term";
                    armL = SeqD(n, .15, new double[] { .5, 0 }); armR = .5 - armL;
                    break;
                case "work2":
                case "type":
                    prop = "laptop"; lx = .5; ly = .5; hideArmR = true;
                    armL = SeqD(n, .15, new double[] { .5, 0 });
                    break;
                case "build":
                    prop = "hammer"; ownHat = true; sweat = true; hideArmR = true;
                    dy = Seq(n, .35, new int[] { 0, 1 }) == 1 ? .25 : 0;
                    break;
                case "done":
                    dy = -SeqD(Math.Min(t, 1.39), .14, new double[] { 0, 1.5, 3, 1.5, 0, 1.5, 3, 1.5, 0, 0 });
                    eye = "happy"; armL = armR = 2; over = "ok"; break;
                case "party":
                    eye = "happy"; ownHat = true; prop = "partyhat"; armL = SeqD(n, .3, new double[] { 2.5, 1 }); armR = 3.5 - armL;
                    dy = -SeqD(n, .3, new double[] { 0, .5 }); break;
                case "happy":
                    dy = -SeqD(n, .3, new double[] { 0, .5 }); eye = "happy";
                    armL = SeqD(n, .25, new double[] { 1.5, 0 }); armR = 1.5 - armL; over = "sparkle"; break;
                case "daydream":
                    eye = blink ? "blink" : "dot"; lx = .5; ly = -.5; over = "cloud";
                    dy = (n % 3) > 1.8 ? -.25 : 0; break;
                case "surprised":
                    dy = t < .45 ? -Math.Round(Math.Sin(t / .45 * Math.PI) * 8) / 4 : 0;
                    eye = "big"; armL = armR = 2; over = "bang"; break;
                case "confused":
                    eye = "line"; over = "question"; dx = t < .3 ? .25 : 0; break;
                case "lookaround":
                    lx = t < 1 ? -.5 : t < 2 ? .5 : 0; ly = t < 2 ? -.25 : 0; break;
                case "sleep":
                    eye = "line"; dy = (n % 2.4) > 1.2 ? .25 : 0; break;
                case "talk":
                    mouth = Seq(n, .25, new int[] { 0, 1 }) == 0 ? "o" : "";
                    dy = -SeqD(n, .5, new double[] { 0, .25 }); break;
                case "wink":
                    eye = "wink"; armR = 2; over = "twinkle";
                    dy = t < .4 ? -SeqD(t, .13, new double[] { 0, .5, .5, 0 }) : 0; break;
                case "shy":
                    eye = "squeeze"; blush = true; over = "heart1";
                    dx = -SeqD(n, .6, new double[] { 0, .25 }); armL = armR = .5; break;
                case "love":
                    eye = "happy"; over = "hearts"; armL = armR = 1.5; dy = -SeqD(n, .4, new double[] { 0, .25 }); break;
                case "miss":
                    eye = "happy"; prop = "phone"; over = "you"; hideArmL = true; dy = -SeqD(n, .5, new double[] { 0, .25 }); break;
                case "dizzy":
                    flat = true; eye = "cross"; over = "stars"; shadow = Grounded(); break;
                case "angry":
                    eye = "squeeze"; over = "anger";
                    dx = SeqD(n, .08, new double[] { -.25, .25 }); armL = SeqD(n, .15, new double[] { 1.5, .5 }); armR = 2 - armL; break;
                case "sad":
                    eye = "open"; over = "rain"; dy = .25; armL = armR = -.5; prop = "tears"; break;
                case "dance":
                    {
                        int k = (int)(n / .25) % 4;
                        double[] ddx = { -1, -.5, 1, .5 }, ddy = { 0, -1, 0, -1 };
                        dx = ddx[k]; dy = ddy[k]; eye = "happy"; over = "notes";
                        armL = SeqD(n, .25, new double[] { 2.5, 0 }); armR = 2.5 - armL;
                        legA = SeqD(n, .25, new double[] { .5, 0 }); legB = .5 - legA;
                        break;
                    }
                case "music":
                    prop = "headphones"; ownHat = true; eye = "chill"; over = "notes";
                    dx = SeqD(n, .5, new double[] { -.25, .25 }); dy = -SeqD(n, .25, new double[] { 0, .25 }); break;
                case "read":
                    prop = "book"; eye = blink ? "blink" : "open"; ly = .5; lx = -.5; hideArmL = true; break;
                case "juggle":
                    prop = "balls"; ly = -.5; armL = SeqD(n, .3, new double[] { 1.5, .5 }); armR = 2 - armL; break;
                case "bird":
                    prop = "bird"; ly = -.5; eye = t > 3 ? "happy" : (blink ? "blink" : "open"); break;
                case "wave":
                    armR = SeqD(n, .2, new double[] { 3, 2 }); armRX = SeqD(n, .2, new double[] { 0, .5 }); eye = "happy"; break;
                case "stretch":
                    if (t < .35) armL = armR = 2;
                    else if (t < 2.0) { armL = armR = 4.5; armLX = .5; armRX = -.5; dy = -.5; eye = "line"; mouth = "yawn"; }
                    else if (t < 2.3) armL = armR = 2;
                    break;
                case "walk":
                    lx = walkDir * .5; legA = SeqD(n, .18, new double[] { .5, 0 }); legB = .5 - legA;
                    dy = -SeqD(n, .18, new double[] { 0, .25 }); armL = SeqD(n, .18, new double[] { .5, 0 }); armR = .5 - armL;
                    if (walkGear) { prop = "gear"; ownHat = true; }
                    break;
                case "sit":
                    dy = 1.5; legLen = .5; eye = blink ? "blink" : (t > 3 ? "line" : "open"); lx = Math.Round(Math.Sin(n * .6)) * .5;
                    break;
                case "held":
                    eye = "squeeze";
                    legA = SeqD(n, .12, new double[] { -.5, 0 }); legB = -.5 - legA; legLen = 2.5;
                    armL = SeqD(n, .1, new double[] { 2, .5 }); armR = 2.5 - armL; shadow = false;
                    break;
                case "fall":
                    eye = "big"; armL = armR = 3; legLen = 2.5; shadow = false; break;
                case "jump":
                    eye = "happy"; armL = armR = 2.5; legLen = 1.5; shadow = false; break;
                case "land":
                    sq = Math.Max(0, squash - (int)(t / .12)) * .5; eye = sq > .5 ? "line" : "open"; break;
                case "catch":
                    eye = "big"; ly = -.5; armL = armR = 3; break;
                case "eat":
                    prop = "orange"; eye = "happy";
                    mouth = Seq(n, .2, new int[] { 0, 1 }) == 0 ? "o" : "";
                    break;
                case "brush":
                    prop = "toothbrush"; eye = "happy"; hideArmL = true; dy = -SeqD(n, .3, new double[] { 0, .25 }); break;
                case "shower":
                    prop = "shower"; eye = "line"; ownHat = true; dx = SeqD(n, .5, new double[] { -.25, .25 }); break;
                case "hungry":
                    prop = "belly"; eye = blink ? "blink" : "dot"; hideArmL = hideArmR = true; dy = (n % 2) > 1 ? .25 : 0; break;
                case "sign":
                    prop = "sign"; armL = armR = 3; ownHat = true; eye = Seq(n, .6, new int[] { 0, 1 }) == 0 ? "open" : "big"; break;
                case "bell":
                    prop = "bell"; hideArmR = true;
                    eye = Seq(n, .6, new int[] { 0, 1 }) == 0 ? "happy" : "open";
                    mouth = Seq(n, .24, new int[] { 0, 1 }) == 0 ? "o" : "";
                    armL = SeqD(n, .24, new double[] { .5, 0 });
                    dy = -SeqD(n, .24, new double[] { 0, .25 });
                    break;
                case "sulk":
                    prop = "box"; eye = blink ? "blink" : "dot"; lx = Math.Round(Math.Sin(n * .7)) * .5; dy = 1.5; legLen = 0; shadow = false; break;
            }

            // 地上的影子：一条深色细线，跳起来也留在地上
            if (shadow && !flat)
            {
                double sw = Math.Max(5, 10 - Math.Abs(Math.Min(0, dy)) * .9);
                U(7.5 - sw / 2, 15, sw, .5, SHADOW);
            }
            if (!flat) DrawLooks("back", dx, dy, dx, dy, n, ownHat);

            if (flat)
            {
                // 被戳晕：整只扁扁地趴在地上，翻着小脚，一只手无力地挥
                U(1.5, 14.5, 12, .5, SHADOW);
                DrawSkin(0, 0, 0, true, 0, 0, 0, 0, false, false, 0, 0, 0, SeqD(n, .3, new double[] { 0, .5 }));
                Bits(CROSS4, 3.75, 12.25, .25, EYE); Bits(CROSS4, 9.75, 12.25, .25, EYE);
                DrawOver(over, t, n, 0, 0);
                DrawParticles(n);
                DrawBubble(e.Graphics);
                return;
            }

            // 整只身体：皮肤像素图 + 小手 + 小脚 + 自动描边
            DrawSkin(dx, dy, sq, false, armL, armR, armLX, armRX, hideArmL, hideArmR, legLen, legA, legB, 0);

            double fx = dx, fy0 = dy + sq;
            double fy = fy0 - (skin != null ? skin.FaceUp * .5 : 0);   // 高个子的形象，脸和头顶整体往上挪
            if (!ownHat && !HeadLookVisible()) DrawHat(Hat(), fx, fy);

            double ci = skin != null ? skin.CheekIn : 0;
            if (blush || (CHEEKS && (skin == null || skin.Cheeks)))
            {
                if (skin != null && skin.CheekUnder)
                {
                    // 腮红正好在两只眼睛下面
                    double ei = skin.EyeIn;
                    double cy = skin.Eyes == "short" ? 9.75 : 10.25;   // 紧挨着眼睛下面，落在脸蛋上
                    U(4 + ei + fx + lx, cy + fy + ly, 1, 1, BLUSH); U(10 - ei + fx + lx, cy + fy + ly, 1, 1, BLUSH);   // 小方块腮红，和眼睛对齐，眼睛看哪边就跟着挪
                }
                else { U(2.75 + ci + fx, 10.25 + fy, 1, .5, BLUSH); U(11.25 - ci + fx, 10.25 + fy, 1, .5, BLUSH); }
            }

            // 眼睛：都很简单，靠形状表达情绪
            double[] EX = { 4, 10 };
            for (int i = 0; i < 2; i++)
            {
                double ex = EX[i] + (skin != null ? (i == 0 ? skin.EyeIn : -skin.EyeIn) : 0) + fx + lx, ey = 8 + fy + ly;
                string k = eye;
                if (k == "wink") k = i == 0 ? "open" : "happy";
                switch (k)
                {
                    case "open":
                        if (skin != null && skin.Eyes == "short") U(ex, ey, 1, 1.5, SKIN_EYE);                              // 短一点的竖眼睛
                        else if (skin != null && skin.Eyes == "bar") U(ex, ey, 1, 2, SKIN_EYE);                                   // 竖条眼睛
                        else { U(ex - .125, ey + .5, 1.25, 1.25, SKIN_EYE); U(ex + .5, ey + .5, .5, .5, GLINT); }         // 圆圆的眼睛 + 小高光
                        break;
                    case "blink": U(ex, ey + 1.5, 1, .5, SKIN_EYE); break;
                    case "line": U(ex - .25, ey + 1, 1.5, .5, SKIN_EYE); break;                    // - -
                    case "dot": U(ex, ey + .75, 1, 1, SKIN_EYE); break;                           // . .
                    case "big":
                        if (skin != null && skin.Eyes == "short") U(ex - .25, ey - .25, 1.5, 2, SKIN_EYE);
                        else if (skin != null && skin.Eyes == "bar") U(ex - .25, ey - .5, 1.5, 2.5, SKIN_EYE);
                        else { U(ex - .25, ey, 1.75, 1.75, SKIN_EYE); U(ex + .5, ey, .5, .5, GLINT); }
                        break;
                    case "happy":                                                             // ^ ^
                        U(ex - .25, ey + 1, .5, .5, SKIN_EYE); U(ex + .25, ey + .5, .5, .5, SKIN_EYE); U(ex + .75, ey + 1, .5, .5, SKIN_EYE); break;
                    case "chill":                                                             // v v
                        U(ex - .25, ey + .5, .5, .5, SKIN_EYE); U(ex + .25, ey + 1, .5, .5, SKIN_EYE); U(ex + .75, ey + .5, .5, .5, SKIN_EYE); break;
                    case "squeeze":                                                           // > <
                        if (i == 0) { U(ex - .25, ey + .25, .5, .5, SKIN_EYE); U(ex + .25, ey + .75, .5, .5, SKIN_EYE); U(ex - .25, ey + 1.25, .5, .5, SKIN_EYE); }
                        else { U(ex + .75, ey + .25, .5, .5, SKIN_EYE); U(ex + .25, ey + .75, .5, .5, SKIN_EYE); U(ex + .75, ey + 1.25, .5, .5, SKIN_EYE); }
                        break;
                    case "cross": Bits(CROSS4, ex, ey + .25, .25, SKIN_EYE); break;
                }
            }

            if (mouth == "" && SMILE && (skin == null || skin.Smile) && eye != "cross" && eye != "line")
            {
                // 小小的微笑 ᴗ
                U(6.75 + fx, 10.5 + fy, .25, .25, SKIN_EYE); U(7 + fx, 10.75 + fy, .5, .25, SKIN_EYE); U(7.5 + fx, 10.5 + fy, .25, .25, SKIN_EYE);
            }
            switch (mouth)
            {
                case "o": U(7 + fx, 11 + fy, 1, .75, MOUTH); break;
                case "yawn": U(7 + fx, 10.5 + fy, 1, 1.75, MOUTH); break;
            }

            if (sweat)
            {
                double a = (n % 1.4) / 1.4 * 3;
                if (a < 2.5) { U(13.25 + dx, 4.5 + a + dy, .5, .5, TEAR); U(13 + dx, 5 + a + dy, 1, .75, TEAR); }
            }

            DrawLooks("front", fx, fy, dx, dy, n, ownHat);
            DrawProp(prop, t, n, fx, fy0, dx, dy);
            DrawExtras(n, fx, fy0, dx, dy, prop != "" || hideArmL);
            if (prop == "" && !hideArmL && state != "dizzy" && state != "sulk" && !HandLookVisible("left_hand")) DrawHeld(HeldItem(), n, dx + armLX, dy - armL);
            DrawOver(over, t, n, dx, dy);
            DrawParticles(n);
            DrawBubble(e.Graphics);
        }


        // ---------- 脸上的小细节 ----------
        public static bool CHEEKS = true, SMILE = true;

        // ---------- 道具 ----------
        void DrawProp(string prop, double t, double n, double fx, double fy, double dx, double dy)
        {
            switch (prop)
            {
                case "laptop":
                    // 深色笔记本挡在右前方，屏幕上是绿色的 </>
                    U(7 + dx, 9 + dy, 7, 4.5, LAPTOP); U(7.5 + dx, 9.5 + dy, 6, 3.5, SCREEN_BG);
                    U(6 + dx, 13.25 + dy, 8.5, .75, LAPTOP);
                    Bits(new string[] { "01000010010", "10000100001", "01001000010" }, 8.25 + dx, 10.5 + dy, .4, CODE);
                    if (Seq(n, .5, new int[] { 0, 1 }) == 0) Bits(SPARK, 13.5 + dx, 5, .5, GOLD);
                    break;
                case "hammer":
                    {
                        // 黄色安全帽 + 一下一下敲锤子
                        U(3.5 + fx, 3.75 + fy, 8, 2.25, HARDHAT); U(2.5 + fx, 5.5 + fy, 10, .75, HARDHAT_D);
                        U(7 + fx, 3.75 + fy, 1, 2, HARDHAT_D); U(6.5 + fx, 4.5 + fy, 2, .5, HARDHAT_D);
                        bool down = Seq(n, .35, new int[] { 0, 1 }) == 1;
                        U(15.5, 13.75, 2.5, 1.25, NAIL); U(16.25, 13.25, 1, .5, GOLD);
                        if (!down) { U(13 + dx, 6.5 + dy, 2, 2, BODY); U(14.25 + dx, 3.5 + dy, .5, 4, WOOD); U(13.5 + dx, 2.75 + dy, 2, 1, NAIL); }
                        else
                        {
                            U(13 + dx, 9 + dy, 2, 2, BODY); U(14.5 + dx, 9.75 + dy, 3, .5, WOOD); U(16.75 + dx, 9.25 + dy, 1, 2.5, NAIL);
                            Bits(SPARK, 17.5, 11.5, .4, GOLD);
                        }
                        break;
                    }
                case "partyhat":
                    U(6.75 + fx, 1.5 + fy, 1.5, .75, GOLD); U(6.25 + fx, 2.25 + fy, 2.5, 1.25, PINK);
                    U(5.75 + fx, 3.5 + fy, 3.5, 1.25, GOLD); U(5.25 + fx, 4.75 + fy, 4.5, 1.25, PINK);
                    U(7.25 + fx, .75 + fy, .5, .75, CONF1);
                    break;
                case "headphones":
                    U(2.5 + fx, 3.75 + fy, 10, .75, PHONES); U(1.75 + fx, 4.25 + fy, .75, 2.5, PHONES); U(12.5 + fx, 4.25 + fy, .75, 2.5, PHONES);
                    U(1.25 + fx, 6.5 + fy, 1.5, 2.75, PHONES_D); U(12.25 + fx, 6.5 + fy, 1.5, 2.75, PHONES_D);
                    break;
                case "book":
                    // 圆眼镜 + 一本蓝色的书
                    U(3.25 + fx - .5, 7.5 + fy, 2.5, .25, WOOD); U(3.25 + fx - .5, 10.5 + fy, 2.5, .25, WOOD);
                    U(2.75 + fx - .5, 7.75 + fy, .25, 2.75, WOOD); U(5 + fx, 7.75 + fy, .25, 2.75, WOOD);
                    U(9.25 + fx - .5, 7.5 + fy, 2.5, .25, WOOD); U(9.25 + fx - .5, 10.5 + fy, 2.5, .25, WOOD);
                    U(8.75 + fx - .5, 7.75 + fy, .25, 2.75, WOOD); U(11 + fx, 7.75 + fy, .25, 2.75, WOOD);
                    U(5.25 + fx, 8.5 + fy, 3.5, .25, WOOD);
                    U(-.5 + dx, 9 + dy, 3.25, 3.75, BOOK); U(-.25 + dx, 9.5 + dy, 2.5, .25, PAPER); U(-.25 + dx, 10.25 + dy, 2.5, .25, PAPER); U(-.25 + dx, 11 + dy, 1.75, .25, PAPER);
                    U(1.5 + dx, 11.25 + dy, 1.5, 1.5, BODY);
                    if ((n % 5) > 4.6) U(1 + dx, 8.5 + dy, 2, 4.5, PAPER);   // 翻页
                    break;
                case "balls":
                    {
                        Brush[] cols = { BALL_R, BALL_G, BALL_Y };
                        for (int i = 0; i < 3; i++)
                        {
                            double u = ((n / 1.2) + i / 3.0) % 1.0;
                            double bx = 1.5 + u * 12, by = 5 - Math.Sin(u * Math.PI) * 5;
                            U(bx, by, 1.25, 1.25, cols[i]);
                        }
                        break;
                    }
                case "bird":
                    {
                        double hop = t < .6 ? -(1 - t / .6) * 3 : (Seq(n, .7, new int[] { 0, 0, 0, 1 }) == 1 ? -.5 : 0);
                        double bx = 6.5 + fx, by = 3.5 + fy + hop;
                        U(bx, by + .5, 2.25, 2, CHICK); U(bx + .5, by, 1.5, 1, CHICK);
                        U(bx + 1.5, by + .25, .25, .25, EYE); U(bx + 2, by + .5, .75, .5, BEAK);
                        U(bx - .25, by + 1, .5, .75, CHICK_D);
                        if (t > 3) Bits(SPARK, 10.5, 2, .4, GOLD);
                        break;
                    }
                case "phone":
                    U(-.5 + dx, 7.75 + dy, 1.75, 3, PHONE); U(-.25 + dx, 8.25 + dy, 1.25, 2, SCREEN);
                    U(.75 + dx, 9.25 + dy, 1.5, 1.5, BODY);
                    break;
                case "gear":
                    {
                        // 出门散步：蓝色鸭舌帽 + 小背包
                        double brim = walkDir > 0 ? 9.5 : 1.5;
                        U(3.5 + fx, 4.25 + fy, 8, 1.75, CAP); U(brim + fx, 5.25 + fy, 4, .75, CAP); U(7 + fx, 4.75 + fy, 1, .5, GOLD);
                        double bp = walkDir > 0 ? .25 : 12.5;
                        U(bp + dx, 7 + dy, 2.25, 4.5, CAP_D); U(bp + .5 + dx, 8 + dy, 1, .75, GOLD);
                        break;
                    }
                case "tears":
                    {
                        double a = (n % 1.0) * 2.5, b = ((n + .5) % 1.0) * 2.5;
                        if (a < 2) U(4.25 + fx, 10 + fy + a, .5, .75, TEAR);
                        if (b < 2) U(10.25 + fx, 10 + fy + b, .5, .75, TEAR);
                        break;
                    }
                case "orange":
                    {
                        string[] o = t < 1.2 ? ORANGE_FULL : t < 2.4 ? ORANGE_BIT : ORANGE_END;
                        double ox = t < 2.4 ? 6.5 : 7, oy = 10.5 + fy + (t < 2.4 ? 0 : .5);
                        Bits(o, ox + fx, oy, .5, ORANGE);
                        if (t < 1.2) U(7.25 + fx, 10 + fy, .5, .5, LEAF);
                        U(4.5 + fx, 11 + fy, 1.75, 1.75, BODY_D); U(8.75 + fx, 11 + fy, 1.75, 1.75, BODY_D);
                        break;
                    }
                default:
                    DrawProp2(prop, t, n, fx, fy, dx, dy);
                    break;
                case "box":
                    // 躲进纸箱生闷气，只露出眼睛偷偷看你
                    U(1, 10.25, 13, 4.75, BOX); U(1, 10.25, 13, .5, BOX_D); U(6.75, 10.75, 1.5, 1, BOX_D);
                    U(.25, 9.75, 1.5, .75, BOX_D); U(13.25, 9.75, 1.5, .75, BOX_D);
                    break;
            }
        }

        void DrawHeld(string item, double n, double dx, double dy)
        {
            switch (item)
            {
                case "hongbao":
                    U(-.75 + dx, 8 + dy, 2, 2.75, BALL_R); U(-.25 + dx, 8.75 + dy, 1, .75, GOLD);
                    break;
                case "lantern":
                    {
                        double sw = SeqD(n, .6, new double[] { 0, .25, 0, -.25 });
                        U(.75 + dx, 3.5 + dy, .25, 6, WOOD);
                        U(-1 + dx + sw, 5 + dy, .25, .75, WOOD);
                        U(-1.75 + dx + sw, 5.75 + dy, 1.75, .5, GOLD); U(-2 + dx + sw, 6.25 + dy, 2.25, 2.25, BALL_R);
                        U(-1.75 + dx + sw, 8.5 + dy, 1.75, .5, GOLD); U(-1.125 + dx + sw, 9 + dy, .5, 1, GOLD);
                        if (Seq(n, .4, new int[] { 0, 1 }) == 0) U(-1.25 + dx + sw, 6.75 + dy, .75, 1.25, LANTERN_HI);
                        break;
                    }
                case "balloon":
                    {
                        double bob = SeqD(n, .8, new double[] { 0, -.25 });
                        U(14.25 + dx, 3 + dy + bob, .25, 6, STRING);
                        U(13.25 + dx, -.75 + dy + bob, 2.25, 3, BALL_R); U(13.5 + dx, -1.25 + dy + bob, 1.75, .5, BALL_R);
                        U(13.75 + dx, -.5 + dy + bob, .5, .75, LANTERN_HI); U(14.125 + dx, 2.25 + dy + bob, .5, .5, BALL_R);
                        break;
                    }
                case "zongzi":
                    Bits(new string[] { "00100", "01110", "11111" }, -1 + dx, 8.25 + dy, .6, ZONGZI);
                    U(-1 + dx, 9.25 + dy, 3, .25, PAPER);
                    break;
                case "mooncake":
                    U(-1 + dx, 8.25 + dy, 2.75, 2.75, MOONCAKE); U(-.5 + dx, 8.75 + dy, 1.75, 1.75, MOONCAKE_D); U(0 + dx, 9.25 + dy, .75, .75, MOONCAKE);
                    break;
                case "flag":
                    {
                        double wave = SeqD(n, .3, new double[] { 0, .25 });
                        U(.75 + dx, 3.5 + dy, .25, 6, WOOD);
                        U(-2.75 + dx, 3.5 + dy + wave, 3.5, 2.25, BALL_R); U(-2.25 + dx, 4 + dy + wave, .5, .5, GOLD);
                        break;
                    }
                case "cake":
                    U(-1.5 + dx, 8.5 + dy, 3.25, 2.25, PAPER); U(-1.5 + dx, 8.5 + dy, 3.25, .5, PINK); U(-1.5 + dx, 9.75 + dy, 3.25, .25, PINK);
                    U(.0 + dx, 7.25 + dy, .25, 1.25, CONF1);
                    if (Seq(n, .2, new int[] { 0, 1 }) == 0) U(-.125 + dx, 6.5 + dy, .5, .75, GOLD); else U(0 + dx, 6.75 + dy, .25, .5, SPECK);
                    break;
                case "candy":
                    U(-.5 + dx, 8.75 + dy, 1.5, 1.5, BALL_R); U(-.25 + dx, 9 + dy, .5, .5, PAPER);
                    U(-1.25 + dx, 9.25 + dy, .75, .5, BALL_R); U(1 + dx, 9.25 + dy, .75, .5, BALL_R);
                    break;
            }
        }

        // ---------- 头顶的符号 ----------
        void DrawOver(string over, double t, double n, double dx, double dy)
        {
            switch (over)
            {
                case "dots":    // 思考：小点一个一个冒出来
                    {
                        int c = (int)(n * 2.5) % 4;
                        for (int i = 0; i < c; i++) U(12 + i * 1.25 + dx, 2 - i * .5, .75, .75, EYE);
                        break;
                    }
                case "term":    // Claude Code 的终端气泡，一个字一个字敲命令
                case "ok":
                    {
                        U(1, -4.25, 13, 3.25, TERM); U(7, -1, 1, .75, TERM);
                        string text;
                        Brush color = TERM_TXT;
                        if (over == "ok") { text = "> ok"; color = CODE; }
                        else
                        {
                            string cmd = CMDS[((int)(n / 2.4)) % CMDS.Length];
                            int shown = Math.Min(cmd.Length, (int)((n % 2.4) / .16));
                            text = "> " + cmd.Substring(0, shown);
                        }
                        PixText(text, 1.5, -4.25, 2.25, color, false);
                        if (over != "ok" && Seq(n, .3, new int[] { 0, 1 }) == 0)
                        {
                            float w = ptext != null && ptext.Loaded ? ptext.Width(text, PixScale(2.25)) : text.Length * 5 * S;
                            G.FillRectangle(GOLD, PX(1.5) + w + S, PY(-3.75), S * 4, S * 9);
                        }
                        break;
                    }
                case "bang": U(7.25 + dx, .5 + dy, .75, 2.5, GOLD); U(7.25 + dx, 3.5 + dy, .75, .75, GOLD); break;
                case "question": Bits(QMARK, 12, .5 + SeqD(n, .4, new double[] { 0, -.25 }), .5, GOLD); break;
                case "sparkle":
                    if (Seq(n, .3, new int[] { 0, 1 }) == 0) Bits(SPARK, 13.5, 3, .5, GOLD); else Bits(SPARK, -.5, 4, .4, GOLD);
                    break;
                case "twinkle": if (Seq(n, .15, new int[] { 0, 1 }) == 0) Bits(SPARK, 12 + dx, 6.5 + dy, .4, GOLD); break;
                case "heart1": Bits(HEART, 12.5, 3 + SeqD(n, .4, new double[] { 0, -.25 }), .35, PINK); break;
                case "cloud":
                    {
                        double cx = 12 + SeqD(n, 1, new double[] { 0, .25, .5, .75, .5, .25 }), cy = 1.5 - SeqD(n, 1.5, new double[] { 0, .25 });
                        U(cx + .5, cy, 2, .5, CLOUD); U(cx, cy + .5, 3.25, 1, CLOUD);
                        break;
                    }
                case "anger":
                    Bits(new string[] { "01010", "11011", "00000", "11011", "01010" }, 12.5, 2.5, .35, ANGER);
                    if (Seq(n, .5, new int[] { 0, 1 }) == 0) U(.5, 3.5, 1, 1, STEAM); else U(.25, 2.5, .75, .75, STEAM);
                    break;
                case "rain":
                    {
                        U(4.5, -1.5, 6, 1.5, RAINCLOUD); U(5.5, -2, 3.5, .5, RAINCLOUD);
                        for (int i = 0; i < 3; i++)
                        {
                            double a = ((n * 1.6) + i * .37) % 1.0;
                            U(5.25 + i * 1.75, .25 + a * 4.5, .35, .6, TEAR);
                        }
                        break;
                    }
                case "stars":
                    {
                        double[][] path = { new double[] { -4, .5 }, new double[] { -2.5, -.5 }, new double[] { 0, -1 }, new double[] { 2.5, -.5 }, new double[] { 4, .5 }, new double[] { 0, 1 } };
                        for (int i = 0; i < 3; i++)
                        {
                            double[] q = path[((int)(n / .2) + i * 2) % 6];
                            Bits(SPARK, 6.9 + q[0] + dx, 8.5 + q[1] + dy, .4, GOLD);
                        }
                        break;
                    }
                case "you":
                    {
                        // 想你了：头顶的小云里写着"你"
                        U(10.25, 3.75, .5, .5, CLOUD_EDGE); U(11, 2.75, .75, .75, CLOUD_EDGE);
                        U(11.5, -2.75, 6, 4.75, CLOUD_EDGE); U(11.75, -2.5, 5.5, 4.25, CLOUD);
                        PixText("你", 12.85, -2.6, 3, EYE, true);
                        break;
                    }
            }
        }

        void DrawParticles(double n)
        {
            foreach (Particle p in parts)
            {
                if (p.Life < .3 && ((int)(n * 12)) % 2 == 1 && p.Type != "dust") continue;
                switch (p.Type)
                {
                    case "spark": Bits(SPARK, p.X, p.Y, .5, GOLD); break;
                    case "speck": U(p.X, p.Y, 1, 1, SPECK); break;
                    case "heart": Bits(HEART, p.X, p.Y, .35, PINK); break;
                    case "z": Bits(ZED, p.X, p.Y, .35, EDGE); break;
                    case "note": Bits(NOTE_B, p.X, p.Y, .4, GOLD); break;
                    case "puff": Bits(PUFF, p.X, p.Y, .35, STEAM); break;
                    case "q": Bits(QMARK, p.X, p.Y, .35, GOLD); break;
                    case "dust": U(p.X, p.Y, .75, .25, DUST); break;
                    case "snow": if (p.Y < 15) U(p.X, p.Y, .5, .5, SNOW); else p.Life = 0; break;
                    case "crumb": U(p.X, p.Y, .25, .25, ORANGE); break;
                    case "code": U(p.X, p.Y, .5, .25, CODE); break;
                    case "conf": U(p.X, p.Y, .5, .5, CONFS[(int)(p.VX * 100 + 300) % CONFS.Length]); break;
                    case "orange": Bits(ORANGE_FULL, p.X, p.Y, .5, ORANGE); U(p.X + 1, p.Y - .5, .5, .5, LEAF); break;
                }
            }
        }

        void DrawHat(string hat, double fx, double fy)
        {
            switch (hat)
            {
                case "night":   // 睡帽：帽檐贴着头顶 y=6
                    U(4.5 + fx, 4 + fy, 6, 1, NIGHTCAP); U(5.5 + fx, 3.25 + fy, 4.5, .75, NIGHTCAP); U(7 + fx, 2.5 + fy, 3.5, .75, NIGHTCAP);
                    U(10 + fx, 2.75 + fy, .75, 1, NIGHTCAP); U(10.25 + fx, 3.5 + fy, 1.25, 1.25, PAPER);
                    U(4 + fx, 5 + fy, 7, 1, PAPER);
                    break;
                case "santa":
                    U(4.5 + fx, 4 + fy, 6, 1, SANTA); U(5.5 + fx, 3.25 + fy, 4.5, .75, SANTA); U(7 + fx, 2.5 + fy, 3.5, .75, SANTA);
                    U(10 + fx, 2.75 + fy, .75, 1, SANTA); U(10.25 + fx, 3.5 + fy, 1.25, 1.25, PAPER);
                    U(4 + fx, 5 + fy, 7, 1, PAPER);
                    break;
                case "cny":
                    U(3.5 + fx, 3 + fy, 8, 2, SANTA); U(5 + fx, 1.75 + fy, 5, 1.25, SANTA);
                    U(2.5 + fx, 5 + fy, 10, 1, GOLD); U(7 + fx, .75 + fy, 1, 1, GOLD); U(7.25 + fx, 2.5 + fy, .5, 2, GOLD);
                    break;
                case "party":
                    U(6.75 + fx, 1.5 + fy, 1.5, .75, GOLD); U(6.25 + fx, 2.25 + fy, 2.5, 1.25, PINK);
                    U(5.75 + fx, 3.5 + fy, 3.5, 1.25, GOLD); U(5.25 + fx, 4.75 + fy, 4.5, 1.25, PINK);
                    U(7.25 + fx, .75 + fy, .5, .75, CONF1);
                    break;
                case "heartband":   // 情人节：头顶一颗爱心发箍
                    U(2.5 + fx, 5.5 + fy, 10, .5, PINK);
                    U(7.5 + fx, 3.75 + fy, .25, 1.75, PINK);
                    Bits(HEART, 6.5 + fx, 2.25 + fy, .45, PINK);
                    break;
                case "magpie":      // 七夕：一只蓝色小喜鹊 + 小爱心
                    U(6 + fx, 4.25 + fy, 3, 1.75, MAGPIE); U(8.5 + fx, 3.75 + fy, 1.25, 1.25, MAGPIE); U(5 + fx, 4.5 + fy, 1.25, .75, MAGPIE_D);
                    U(9.25 + fx, 4 + fy, .25, .25, PAPER); U(9.75 + fx, 4.25 + fy, .5, .25, EYE); U(6.5 + fx, 5 + fy, 1.5, .5, PAPER);
                    Bits(HEART, 10.75 + fx, 2.25 + fy - SeqD(now, .5, new double[] { 0, .25 }), .3, PINK);
                    break;
                case "bunny":       // 中秋：玉兔耳朵
                    U(4.5 + fx, 1.5 + fy, 1.25, 4.5, PAPER); U(9.25 + fx, 1.5 + fy, 1.25, 4.5, PAPER);
                    U(4.75 + fx, 2.25 + fy, .75, 3, BLUSH); U(9.5 + fx, 2.25 + fy, .75, 3, BLUSH);
                    break;
                case "witch":       // 万圣节：紫色小巫师帽
                    U(2.5 + fx, 5.25 + fy, 10, .75, WITCH); U(4.5 + fx, 3.75 + fy, 6, 1.5, WITCH);
                    U(5.5 + fx, 2.5 + fy, 4, 1.25, WITCH); U(6.75 + fx, 1.5 + fy, 2.5, 1, WITCH); U(8.75 + fx, 1.25 + fy, 1.5, .75, WITCH);
                    U(4.5 + fx, 4.5 + fy, 6, .5, GOLD); U(6.25 + fx, 2.75 + fy, .5, .5, GOLD);
                    break;
                case "band":        // 端午：五彩绳头带
                    U(2 + fx, 6.5 + fy, 11, .5, BALL_R); U(2 + fx, 7 + fy, 11, .25, GOLD);
                    U(12.5 + fx, 6.75 + fy, .5, 1.5, BALL_G); U(13 + fx, 7 + fy, .5, 1.25, CONF1);
                    break;
                case "bow":     // 粉色蝴蝶结，歪戴在右上角
                    U(8.75 + fx, 4.25 + fy, 1.5, 1.75, BOW); U(8.5 + fx, 4.75 + fy, .5, .75, BOW);
                    U(11.25 + fx, 4.25 + fy, 1.5, 1.75, BOW); U(12.5 + fx, 4.75 + fy, .5, .75, BOW);
                    U(10.25 + fx, 4.75 + fy, 1, 1.25, BOW_D);
                    break;
                case "crown":
                    U(4.5 + fx, 4.25 + fy, 6, 1.75, GOLD); U(4.5 + fx, 3 + fy, 1, 1.25, GOLD); U(7 + fx, 2.5 + fy, 1, 1.75, GOLD); U(9.5 + fx, 3 + fy, 1, 1.25, GOLD);
                    U(5.5 + fx, 4.75 + fy, .75, .75, PINK); U(7.125 + fx, 4.75 + fy, .75, .75, CONF1); U(8.75 + fx, 4.75 + fy, .75, .75, PINK);
                    break;
                case "flower":
                    U(10.5 + fx, 3.25 + fy, 1, 1, PAPER); U(9.5 + fx, 4.25 + fy, 1, 1, PAPER); U(11.5 + fx, 4.25 + fy, 1, 1, PAPER);
                    U(10.5 + fx, 5.25 + fy, 1, .75, PAPER); U(10.5 + fx, 4.25 + fy, 1, 1, GOLD);
                    break;
                case "sprout":
                    {
                        double sw = SeqD(now, .9, new double[] { 0, .25 });
                        U(7.25 + fx, 3.75 + fy, .5, 2.25, LEAF_D);
                        U(5.75 + fx + sw, 3 + fy, 1.5, .75, LEAF); U(6.25 + fx + sw, 2.5 + fy, .75, .5, LEAF);
                        U(7.75 + fx + sw, 2.5 + fy, 1.5, .75, LEAF); U(8.25 + fx + sw, 2 + fy, .75, .5, LEAF);
                        break;
                    }
            }
        }

        static int Clamp(double v) { return v > .5 ? 1 : v < -.5 ? -1 : 0; }

        Font bubbleFont = new Font("Microsoft YaHei UI", 9.5f);
        void DrawBubble(Graphics g)
        {
            if (bubbleText == "" || now > bubbleUntil) return;
            int maxW = ClientSize.Width - 40;
            int sc = TextScale(), w, h;
            bool pix = ptext != null && ptext.Loaded;
            if (pix) { Size sz = ptext.Measure(bubbleText, maxW, sc); w = sz.Width + 8 * sc + 8; h = sz.Height + 8 * sc + 4; }
            else
            {
                g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
                SizeF sz = g.MeasureString(bubbleText, bubbleFont, maxW);
                w = (int)Math.Ceiling(sz.Width) + 22; h = (int)Math.Ceiling(sz.Height) + 14;
            }
            h = Math.Min(h, BUBBLE_H - 10);
            int x = (ClientSize.Width - w) / 2, y = BUBBLE_H - h - 8;
            int k = Math.Max(2, sc * 2);
            Brush edge = EDGE, paper = Brushes.White;
            // 像素风气泡：切掉四个角
            g.FillRectangle(edge, x + k, y, w - 2 * k, h);
            g.FillRectangle(edge, x, y + k, w, h - 2 * k);
            g.FillRectangle(paper, x + k, y + k, w - 2 * k, h - 2 * k);
            g.FillRectangle(paper, x + k / 2 + 1, y + k, k / 2, h - 2 * k);
            g.FillRectangle(paper, x + w - k, y + k, k / 2, h - 2 * k);
            g.FillRectangle(edge, x + w / 2 - k, y + h, k * 2, k);
            g.FillRectangle(paper, x + w / 2 - k / 2, y + h - k, k, k);
            g.FillRectangle(edge, x + w / 2 - k / 2, y + h + k, k, k);
            if (pix) ptext.Draw(g, bubbleText, x + 4 * sc + 4, y + 4 * sc + 2, sc, DARK, maxW);
            else g.DrawString(bubbleText, bubbleFont, DARK, new RectangleF(x + 11, y + 7, w - 20, h - 10));
        }

        void Say(string text, double seconds)
        {
            if (quiet) return;
            bubbleText = text; bubbleUntil = Now() + seconds;
        }

        // ---------- 声音 ----------
        void InitVoice()
        {
            return;
            try
            {
                voice = new SpeechSynthesizer();
                foreach (InstalledVoice v in voice.GetInstalledVoices())
                {
                    if (v.Enabled && v.VoiceInfo.Culture.Name.StartsWith("zh")) { voice.SelectVoice(v.VoiceInfo.Name); break; }
                }
                voice.Rate = 1;
                voice.Volume = 85;
            }
            catch { voice = null; }
        }

        void ToggleSound()
        {
            muted = !muted;
            miSound.Checked = !muted;
            string f = Path.Combine(cfgDir, "mute.txt");
            try { if (muted) File.WriteAllText(f, "1"); else File.Delete(f); } catch { }
            if (!muted) { PlaySfx("happy"); Say("声音打开啦～", 3); }
            else Say("好，我安安静静地陪着你。", 3);
        }

        // 像素风的"叮～"声，在内存里合成
        static byte[] chime;
        static byte[] Chime()
        {
            if (chime != null) return chime;
            int rate = 22050;
            double[][] notes = { new double[] { 988, .09 }, new double[] { 1319, .16 } };
            List<byte> pcm = new List<byte>();
            foreach (double[] nt in notes)
            {
                int len = (int)(rate * nt[1]);
                for (int i = 0; i < len; i++)
                {
                    double env = 1 - (double)i / len;
                    double sqw = Math.Sin(2 * Math.PI * nt[0] * i / rate) > 0 ? 1 : -1;
                    pcm.Add((byte)(128 + sqw * 38 * env));
                }
            }
            MemoryStream ms = new MemoryStream();
            BinaryWriter w = new BinaryWriter(ms);
            w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + pcm.Count); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate); w.Write((short)1); w.Write((short)8);
            w.Write(Encoding.ASCII.GetBytes("data")); w.Write(pcm.Count); w.Write(pcm.ToArray());
            chime = ms.ToArray();
            return chime;
        }

        void Announce(string text)
        {
            // 不用人声，只“叮”一声，话写在气泡里
            PlaySfx("ding");
        }

        // ---------- 检测有没有 AI 在工作（看窗口里有没有“停止”按钮） ----------
        static readonly string[] BROWSERS = { "chrome", "msedge", "firefox", "brave", "opera", "vivaldi", "360chrome", "360se", "qqbrowser", "sogouexplorer", "2345explorer", "liebao", "quark", "arc" };
        static readonly string[][] AI_APPS = {
            new string[] { "claude", "Claude" }, new string[] { "chatgpt", "ChatGPT" }, new string[] { "codex", "Codex" },
            new string[] { "cursor", "Cursor" }, new string[] { "windsurf", "Windsurf" }, new string[] { "trae", "Trae" },
            new string[] { "doubao", "豆包" }, new string[] { "kimi", "Kimi" }, new string[] { "deepseek", "DeepSeek" },
            new string[] { "copilot", "Copilot" }, new string[] { "yuanbao", "元宝" }, new string[] { "qwen", "通义" },
            new string[] { "tongyi", "通义" }, new string[] { "codebuddy", "CodeBuddy" }, new string[] { "workbuddy", "WorkBuddy" },
            new string[] { "code", "VS Code" }, new string[] { "jimeng", "即梦" }, new string[] { "lingma", "通义灵码" } };
        static readonly string[][] AI_SITES = {
            new string[] { "claude", "Claude" }, new string[] { "chatgpt", "ChatGPT" }, new string[] { "gemini", "Gemini" },
            new string[] { "deepseek", "DeepSeek" }, new string[] { "豆包", "豆包" }, new string[] { "kimi", "Kimi" },
            new string[] { "copilot", "Copilot" }, new string[] { "通义", "通义" }, new string[] { "千问", "通义千问" },
            new string[] { "文心", "文心一言" }, new string[] { "元宝", "元宝" }, new string[] { "perplexity", "Perplexity" },
            new string[] { "grok", "Grok" }, new string[] { "智谱", "智谱清言" }, new string[] { "chatglm", "智谱清言" },
            new string[] { "poe", "Poe" }, new string[] { "秘塔", "秘塔" }, new string[] { "纳米ai", "纳米AI" }, new string[] { "即梦", "即梦" },
            new string[] { "mistral", "Mistral" }, new string[] { "minimax", "MiniMax" }, new string[] { "海螺", "海螺AI" } };

        static bool IsStopName(string name)
        {
            if (string.IsNullOrEmpty(name)) return false;
            string l = name.ToLowerInvariant();
            if (l.Contains("debug") || l.Contains("shift+f5") || name.Contains("调试") || l.Contains("loading") || name.Contains("加载") ||
                l.Contains("record") || name.Contains("录制") || name.Contains("录音") || l.Contains("dictation") || name.Contains("听写")) return false;
            return l.Contains("stop") || l.Contains("interrupt") || l.Contains("cancel generat") || name.Contains("停止") || name.Contains("中断") ||
                name.Contains("中止") || name.Contains("取消生成") || name.Contains("暂停生成");
        }

        static string AiLabel(string pname, string title)
        {
            foreach (string[] a in AI_APPS) if (pname == a[0]) return a[1];
            if (Array.IndexOf(BROWSERS, pname) >= 0)
            {
                string t = title.ToLowerInvariant();
                foreach (string[] a in AI_SITES) if (t.Contains(a[0])) return a[1];
            }
            return null;
        }

        static List<KeyValuePair<string, AutomationElement>> AiWindows()
        {
            List<KeyValuePair<string, AutomationElement>> list = new List<KeyValuePair<string, AutomationElement>>();
            AutomationElementCollection wins = AutomationElement.RootElement.FindAll(TreeScope.Children,
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window));
            foreach (AutomationElement w in wins)
            {
                try
                {
                    string pname = Process.GetProcessById(w.Current.ProcessId).ProcessName.ToLowerInvariant();
                    string label = AiLabel(pname, w.Current.Name ?? "");
                    if (label != null) list.Add(new KeyValuePair<string, AutomationElement>(label, w));
                }
                catch { }
            }
            return list;
        }

        static List<AutomationElement> ClaudeWindows()
        {
            List<AutomationElement> l = new List<AutomationElement>();
            foreach (KeyValuePair<string, AutomationElement> kv in AiWindows()) l.Add(kv.Value);
            return l;
        }

        static string stopName = "";
        static bool detectedByButton;
        static List<string> ignoreButtons = new List<string>();
        static bool Ignored(string app, string name) { lock (ignoreButtons) return ignoreButtons.Contains(app + "|" + name); }

        void LoadIgnore()
        {
            try
            {
                string f = Path.Combine(cfgDir, "ignore_buttons.txt");
                if (File.Exists(f)) lock (ignoreButtons) ignoreButtons.AddRange(File.ReadAllLines(f, Encoding.UTF8));
            }
            catch { }
        }

        // m 说“它其实没在工作”：把现在认错的那个按钮记下来，以后不再当成“停止”
        void IgnoreCurrentButton()
        {
            string app = busyApp, name = stopName;
            bool viaCpu; lock (cpuDetected) viaCpu = cpuDetected.Contains(app);
            if (app != "" && app.IndexOf('、') < 0 && viaCpu) name = "CPU";
            if (app == "" || name == "") { Say("现在没有在等的 AI 呀～", 3); return; }
            lock (ignoreButtons) { ignoreButtons.Add(app + "|" + name); }
            try { File.AppendAllText(Path.Combine(cfgDir, "ignore_buttons.txt"), app + "|" + name + "\r\n", Encoding.UTF8); } catch { }
            LogEvent(Names.Nick + " 说 " + app + " 没在工作 → 以后忽略按钮「" + name + "」");
            busyApp = ""; detectedBusy = false; appActive.Clear(); lock (busyNow) busyNow.Clear(); manualWork = false;
            if (miWork != null) miWork.Checked = false;
            Set("shy");
            Say(name == "CPU" ? "对不起，我认错啦！以后不再靠「" + app + "」忙不忙来判断它在不在工作了。" : "对不起，我认错啦！以后不会再把「" + name + "」当成停止按钮了。", 5);
        }

        static Dictionary<string, Rectangle> stopRects = new Dictionary<string, Rectangle>();
        static List<string> busyNow = new List<string>();
        static int detectFails;
        static bool detectFrozen;   // 只给测试用   // “停止”按钮在屏幕上的位置，用来判断 m 是不是点了停止
        double lastStopClick = -99;
        string lastStopApp = "";
        HashSet<string> appActive = new HashSet<string>();
        HashSet<string> cpuWas = new HashSet<string>();   // 这一轮是靠 CPU 认出来在忙的 AI

        // m 现在是不是正看着这个 AI 的窗口（它在最前面，而且 m 刚刚还在动鼠标键盘）
        bool WatchingApp(string app)
        {
            try
            {
                if (Win.IdleSeconds() > 20) return false;
                IntPtr h = Win.GetForegroundWindow();
                uint pid; Win.GetWindowThreadProcessId(h, out pid);
                string pname = Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant();
                StringBuilder t = new StringBuilder(512); Win.GetWindowText(h, t, 512);
                return AiLabel(pname, t.ToString()) == app;
            }
            catch { return false; }
        }
        Dictionary<string, double> appLastSeen = new Dictionary<string, double>();
        Dictionary<string, double> appStarted = new Dictionary<string, double>();

        static List<string> Detect()
        {
            List<string> found = new List<string>();
            detectedByButton = false;
            Condition btn = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
            foreach (KeyValuePair<string, AutomationElement> kv in AiWindows())
            {
                if (found.Contains(kv.Key)) continue;
                try
                {
                    foreach (AutomationElement b in kv.Value.FindAll(TreeScope.Descendants, btn))
                        if (IsStopName(b.Current.Name) && !Ignored(kv.Key, b.Current.Name))
                        {
                            stopName = b.Current.Name;
                            try
                            {
                                System.Windows.Rect r = b.Current.BoundingRectangle;
                                lock (stopRects) stopRects[kv.Key] = new Rectangle((int)r.X - 8, (int)r.Y - 8, (int)r.Width + 16, (int)r.Height + 16);
                            }
                            catch { }
                            found.Add(kv.Key);
                            detectedByButton = true;
                            break;
                        }
                }
                catch { }
            }
            return found;
        }


        // ---------- 没有“停止”按钮的 AI（比如 WorkBuddy 这类智能体）：看它是不是在持续占用 CPU ----------
        static Dictionary<string, TimeSpan> cpuLast = new Dictionary<string, TimeSpan>();
        static Dictionary<string, List<bool>> cpuHist = new Dictionary<string, List<bool>>();
        static DateTime cpuLastAt = DateTime.MinValue;
        // 只有这几个没有“停止”按钮的智能体才看 CPU；豆包、ChatGPT、Codex 这些有停止按钮，只认按钮，后台随便占点 CPU 不算在干活
        static readonly string[] CPU_APPS = { "workbuddy", "codebuddy" };
        static HashSet<string> cpuOn = new HashSet<string>();      // 现在按 CPU 判断“在干活”的
        static HashSet<string> cpuDetected = new HashSet<string>(); // 这次是靠 CPU 认出来的（不是靠按钮）

        static List<string> CpuBusyApps()
        {
            List<string> busy = new List<string>();
            DateTime t = DateTime.Now;
            double dt = cpuLastAt == DateTime.MinValue ? 0 : (t - cpuLastAt).TotalSeconds;
            cpuLastAt = t;
            // 前台窗口是哪个程序：用户正在操作它时（刚有键盘鼠标输入），它忙不算 AI 在工作
            string fg = "";
            try { uint pid; Win.GetWindowThreadProcessId(Win.GetForegroundWindow(), out pid); fg = Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant(); } catch { }
            bool userTyping = Win.IdleSeconds() < 3;
            foreach (string[] a in AI_APPS)
            {
                string name = a[0];
                if (Array.IndexOf(CPU_APPS, name) < 0) continue;
                Process[] ps;
                try { ps = Process.GetProcessesByName(name); } catch { continue; }
                if (ps.Length == 0) { cpuLast.Remove(name); cpuHist.Remove(name); cpuOn.Remove(name); continue; }
                TimeSpan total = TimeSpan.Zero;
                foreach (Process pr in ps) { try { total += pr.TotalProcessorTime; } catch { } finally { pr.Dispose(); } }
                TimeSpan prev;
                bool active = false;
                if (cpuLast.TryGetValue(name, out prev) && dt > .5)
                {
                    double load = (total - prev).TotalSeconds / dt;      // 相当于占用了几个核
                    active = load > .25 && !(userTyping && fg == name);
                }
                cpuLast[name] = total;
                List<bool> h;
                if (!cpuHist.TryGetValue(name, out h)) { h = new List<bool>(); cpuHist[name] = h; }
                h.Add(active); if (h.Count > 12) h.RemoveAt(0);
                int n = 0; foreach (bool b in h) if (b) n++;
                int recent = 0; for (int k = Math.Max(0, h.Count - 8); k < h.Count; k++) if (h[k]) recent++;
                // 开始：最近约 18 秒里至少 10 次都在忙（持续在跑，不是偶尔动一下）
                // 结束：最近约 12 秒里最多 1 次在忙
                if (!cpuOn.Contains(name) && h.Count >= 12 && n >= 10) cpuOn.Add(name);
                else if (cpuOn.Contains(name) && h.Count >= 8 && recent <= 1) cpuOn.Remove(name);
                if (cpuOn.Contains(name) && !Ignored(a[1], "CPU")) busy.Add(a[1]);
            }
            return busy;
        }

        void DetectLoop()
        {
            while (true)
            {
                List<string> f = null;
                try { f = Detect(); detectFails = 0; } catch { detectFails++; }
                if (f != null) try
                    {
                        List<string> cpu = CpuBusyApps();
                        lock (cpuDetected) { cpuDetected.Clear(); foreach (string a in cpu) if (!f.Contains(a)) { f.Add(a); cpuDetected.Add(a); } }
                    }
                    catch { }
                if (f == null) { if (detectFails < 3) { Thread.Sleep(1500); continue; } f = new List<string>(); }   // 偶尔出错不算结束
                if (detectFrozen) { Thread.Sleep(1500); continue; }
                lock (busyNow) { busyNow.Clear(); busyNow.AddRange(f); }
                busyApp = string.Join("、", f.ToArray());
                detectedBusy = f.Count > 0;
                Thread.Sleep(1500);
            }
        }

        void Diagnose()
        {
            Say("我在检查 Claude 的窗口，稍等一下…", 4);
            Thread th = new Thread(delegate()
            {
                StringBuilder sb = new StringBuilder();
                try
                {
                    List<AutomationElement> wins = ClaudeWindows();
                    sb.AppendLine("找到 Claude 窗口数量：" + wins.Count);
                    foreach (AutomationElement w in wins)
                    {
                        sb.AppendLine();
                        sb.AppendLine("窗口：" + w.Current.Name + "  (进程 " + Process.GetProcessById(w.Current.ProcessId).ProcessName + ")");
                        foreach (AutomationElement b in w.FindAll(TreeScope.Descendants,
                            new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button)))
                        {
                            string name = b.Current.Name;
                            sb.AppendLine((IsStopName(name) ? (Ignored(AiLabel(Process.GetProcessById(w.Current.ProcessId).ProcessName.ToLowerInvariant(), w.Current.Name ?? "") ?? "", name) ? "  ☆(已忽略) " : "  ★ ") : "    ") + "按钮：" + name);
                        }
                    }
                    sb.AppendLine();
                    sb.AppendLine("说明：带 ★ 的按钮被当作“停止”按钮。Claude 正在工作时运行一次诊断，把这个文件发给 Claude，它就能帮你调整。");
                }
                catch (Exception ex) { sb.AppendLine("出错：" + ex.Message); }
                string f = Path.Combine(dir, "诊断结果.txt");
                try { File.WriteAllText(f, sb.ToString(), Encoding.UTF8); Process.Start("notepad.exe", "\"" + f + "\""); } catch { }
            });
            th.IsBackground = true;
            th.Start();
        }

        // ---------- 聊天 ----------
        void OpenChat()
        {
            Interact();
            if (state == "sulk") Forgive();
            Form f = new Form();
            f.Text = "和" + Names.Pet + "聊天";
            f.FormBorderStyle = FormBorderStyle.FixedToolWindow;
            f.StartPosition = FormStartPosition.Manual;
            f.ClientSize = new Size(300, 38);
            f.TopMost = true;
            f.Location = new Point(Math.Max(0, Left + Width / 2 - 150), Top + Height + 4);
            if (f.Bottom > Screen.FromControl(this).WorkingArea.Bottom) f.Top = Top - 70;
            TextBox tb = new TextBox();
            tb.Font = new Font("Microsoft YaHei UI", 10f);
            tb.SetBounds(6, 6, 228, 26);
            Button send = new Button();
            send.Text = "发送"; send.SetBounds(240, 5, 54, 28);
            send.Font = new Font("Microsoft YaHei UI", 9f);
            f.Controls.Add(tb); f.Controls.Add(send);
            f.AcceptButton = send;
            send.Click += delegate
            {
                string msg = tb.Text.Trim();
                if (msg == "") return;
                tb.Text = "";
                Reply(msg);
            };
            f.Show(this);
            tb.Focus();
        }

        void Reply(string msg)
        {
            Interact(); lastChatAt = now; AddAff(2);
            string text = LocalThink(msg);
            if (text == null) { LocalSearchReply(msg); return; }
            if (!working && Grounded()) Set("think");
            Say("唔……", 3);
            chatting = true;
            System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
            t.Interval = 500 + rnd.Next(700) + Math.Min(1200, msg.Length * 30);
            t.Tick += delegate { t.Stop(); t.Dispose(); chatting = false; PetSays(text); };
            t.Start();
        }

        static readonly Dictionary<string, string> MOODS = new Dictionary<string, string> {
            {"开心","happy"},{"害羞","shy"},{"爱心","love"},{"生气","angry"},{"难过","sad"},{"惊讶","surprised"},
            {"跳舞","dance"},{"眨眼","wink"},{"发呆","daydream"},{"晕","dizzy"},{"困","stretch"},{"疑惑","confused"},{"想你","miss"}};

        static string ParseMood(string text, ref string mood)
        {
            text = text.Trim();
            if (text.StartsWith(Names.Pet + "：") || text.StartsWith(Names.Pet + ":")) text = text.Substring(Names.Pet.Length + 1).Trim();
            if (text.Length > 2 && (text[0] == '[' || text[0] == '【'))
            {
                int end = text.IndexOfAny(new char[] { ']', '】' });
                if (end > 0 && end < 6)
                {
                    string tag = text.Substring(1, end - 1);
                    string st;
                    if (MOODS.TryGetValue(tag, out st)) mood = st;
                    text = text.Substring(end + 1).Trim();
                }
            }
            return text;
        }

        static string PERSONA { get { return PERSONA0; } }
        static string PERSONA0 = "你是\"" + Names.Pet + "\"，一只" + Names.Desc + "桌宠，住在主人的电脑桌面上，陪主人工作。主人叫 " + Names.Nick + "，你一直叫TA " + Names.Nick + "。" +
            "说中文，语气可爱、轻松、真诚，每次只说 1-2 句，不超过 40 个字。可以用\"嘿嘿\"\"唔\"这样的语气词，不用表情符号。" +
            "你知道自己是个小桌宠，不假装是人类。" + Names.Nick + " 难过时温柔一点；不懂的事就老实说不知道；" + Names.Nick + " 熬夜或太累时关心TA。" +
            "每次回答都以一个方括号表情开头，从这些里选最合适的一个：[开心][害羞][爱心][生气][难过][惊讶][跳舞][眨眼][发呆][晕][困][疑惑][想你]。例如：[开心] 嘿嘿，" + Names.Nick + " 今天也一起加油！";

        string AskModel(string msg)
        {
            try
            {
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
                JavaScriptSerializer js = new JavaScriptSerializer();
                List<object> msgs = new List<object>();
                foreach (string[] h in history) msgs.Add(new Dictionary<string, object> { { "role", h[0] }, { "content", h[1] } });
                msgs.Add(new Dictionary<string, object> { { "role", "user" }, { "content", msg } });
                Dictionary<string, object> body = new Dictionary<string, object> {
                    { "model", "claude-haiku-5-5" }, { "max_tokens", 200 }, { "system", PERSONA + "\n\n" + ContextForModel() }, { "messages", msgs } };
                byte[] data = Encoding.UTF8.GetBytes(js.Serialize(body));
                HttpWebRequest req = (HttpWebRequest)WebRequest.Create("https://api.anthropic.com/v1/messages");
                req.Method = "POST";
                req.ContentType = "application/json";
                req.Headers.Add("x-api-key", apiKey);
                req.Headers.Add("anthropic-version", "2023-06-01");
                req.Timeout = 30000;
                using (Stream s = req.GetRequestStream()) s.Write(data, 0, data.Length);
                using (HttpWebResponse res = (HttpWebResponse)req.GetResponse())
                using (StreamReader rd = new StreamReader(res.GetResponseStream(), Encoding.UTF8))
                {
                    Dictionary<string, object> j = js.Deserialize<Dictionary<string, object>>(rd.ReadToEnd());
                    StringBuilder sb = new StringBuilder();
                    foreach (object o in (System.Collections.ArrayList)j["content"])
                    {
                        Dictionary<string, object> blk = (Dictionary<string, object>)o;
                        if ((string)blk["type"] == "text") sb.Append((string)blk["text"]);
                    }
                    return sb.Length > 0 ? sb.ToString() : null;
                }
            }
            catch { return null; }
        }

        string LocalReply(string m)
        {
            string l = m.ToLowerInvariant();
            int h = DateTime.Now.Hour;
            if (l.Contains("你好") || l.Contains("嗨") || l.Contains("hi") || l.Contains("hello") || m.Contains("在吗")) return Pick(new string[] { "[开心] 嗨嗨 " + Names.Nick + "！我一直在～", "[眨眼] 在的在的！" + Names.Nick + " 找我什么事？" });
            if (m.Contains("早安") || m.Contains("早上好")) return "[开心] 早安 " + Names.Nick + "！今天也一起加油～";
            if (m.Contains("晚安")) return "[困] 晚安 " + Names.Nick + "，做个好梦，明天见～";
            if (m.Contains("喜欢") || m.Contains("爱你") || m.Contains("可爱")) return Pick(new string[] { "[害羞] 唔……被 " + Names.Nick + " 这么说，我脸都红了。", "[爱心] 我也最喜欢 " + Names.Nick + " 啦！" });
            if (m.Contains("累") || m.Contains("困") || m.Contains("睡")) return h >= 23 || h < 5 ? "[困] 好晚了，" + Names.Nick + " 快去睡吧，我帮你看着。" : "[困] 那就歇一会儿吧，我帮你盯着 Claude。";
            if (m.Contains("难过") || m.Contains("伤心") || m.Contains("烦") || m.Contains("哭") || m.Contains("焦虑") || m.Contains("压力")) return Pick(new string[] { "[难过] 抱抱 " + Names.Nick + "。不开心的话，可以多跟我说说。", "[爱心] " + Names.Nick + " 已经很努力了，我一直在这儿陪你。" });
            if (m.Contains("开心") || m.Contains("高兴") || m.Contains("成功") || m.Contains("好了") || m.Contains("搞定")) return Pick(new string[] { "[跳舞] 太好啦！我也跟着开心！", "[开心] 嘿嘿，" + Names.Nick + " 好厉害！" });
            if (m.Contains("笨") || m.Contains("丑") || m.Contains("讨厌")) return "[生气] 哼！我可是很可爱的！";
            if (m.Contains("跳舞") || m.Contains("唱歌")) return "[跳舞] 来啦来啦，动次打次～";
            if (m.Contains("名字") || m.Contains("你是谁")) return "[眨眼] 我是" + Names.Pet + "，住在 " + Names.Nick + " 桌面上的像素小家伙！";
            if (m.Contains("饿") || m.Contains("吃")) return hunger >= 50 ? "[想你] 我也饿了……右键喂我一个小橘子嘛～" : "[开心] " + Names.Nick + " 也去吃点好吃的吧！";
            if (m.Contains("天气") || m.Contains("下雨") || m.Contains("冷") || m.Contains("热")) return weatherText != "" ? "[眨眼] 外面现在 " + weatherText + (weatherKind == "rain" ? "，在下雨，记得带伞！" : weatherKind == "cold" ? "，有点冷，多穿点～" : weatherKind == "hot" ? "，好热，多喝水～" : "，还不错！") : "[疑惑] 我还没查到天气……";
            if (m.Contains("几点") || m.Contains("时间")) return "[眨眼] 现在 " + DateTime.Now.ToString("HH:mm") + " 啦～";
            if (m.Contains("几天") || m.Contains("认识")) return "[爱心] 今天是我认识 " + Names.Nick + " 的第 " + DaysTogether() + " 天！";
            if (m.Contains("谢谢")) return "[害羞] 嘿嘿，不客气～";
            if (m.Contains("生日")) return birthday.Length == 5 ? "[开心] 我记得 " + Names.Nick + " 的生日是 " + int.Parse(birthday.Substring(0, 2)) + " 月 " + int.Parse(birthday.Substring(3)) + " 日！那天我要给你唱歌～" : "[疑惑] 我还不知道你的生日呢～在 config.txt 里写上 birthday=月-日 告诉我吧！";
            foreach (string w in EVENT_WORDS) if (m.Contains(w)) return "[开心] " + w + "加油！我记下来了，过两天来问你怎么样～";
            return Pick(new string[] {
                "[发呆] 唔，这个我还不太懂……不过我在认真听哦。",
                "[眨眼] 嘿嘿，然后呢然后呢？",
                "[开心] " + Names.Nick + " 说的我都记在小脑袋里啦。",
                "[疑惑] 嗯……可以再跟我多说一点吗？",
                "[晕] 这个问题有点难，我脑袋转不过来了。" });
        }
    }

    public static class Program
    {
        public static string Script = "";   // 启动脚本的位置：开机自启、自我升级后重启都用它

        public static void Run(string folder) { Run(folder, Path.Combine(folder, "desk-pet.ps1")); }

        public static void Run(string folder, string script)
        {
            Script = script;
            Names.Load(folder);   // 先读名字，再创建桌宠
            bool created = false;
            Mutex m = null;
            // 刚重启时，旧的那只可能还没完全退出，多等几秒
            for (int i = 0; i < 10 && !created; i++)
            {
                m = new Mutex(true, "PixelDeskPet_" + Names.DataFolder, out created);
                if (!created) { m.Dispose(); Thread.Sleep(600); }
            }
            if (!created) { MessageBox.Show(Names.Pet + "已经在桌面上啦～", Names.Pet); return; }
            Application.EnableVisualStyles();
            Application.Run(new PetForm(folder));
            GC.KeepAlive(m);
        }
    }
}
