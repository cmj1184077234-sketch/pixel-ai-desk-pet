
namespace PixelDeskPet
{
    // ---------- 整体形象（皮肤）：整只桌宠的样子都由一张像素图决定 ----------
    public class Skin
    {
        public string Name = "";
        public string[] Rows = new string[0];
        public Dictionary<char, Color> Pal = new Dictionary<char, Color>();
        public string Outline = "", Feet = "";
        public string Eyes = "round", Hands = "round", Legs = "round";   // 眼睛 round/bar，手 round/square，脚 round/legs
        public bool NoOutline, Cheeks = true, Smile = true;
        public int HandRow = 19;
        public string Thin = "";                                          // 这些字母画出来的细线（比如胡须）不描边                                          // 小手长在第几行（按 28 行画布算，最下面一行贴地）
        public string EyeColor = "";                                      // 眼睛颜色，默认黑色；像素小人用深棕色更柔和
        public double CheekIn;
        public int FaceUp;
        public double EyeIn;
        public bool CheekUnder;                                           // 腮红放在眼睛正下方                                              // 两只眼睛往中间靠几格（0–2），靠近一点更可爱
        public string HandColor = "";                                     // 小手颜色：调色板里的字母或 #RRGGBB，默认和身体一样                                                // 脸往上挪几行（高个子的小人，身体才能长一点）                                            // 腮红往脸中间挪多少格（脸窄的形象用）                                          // 小手长在第几行（Q 版小人的手在身体上，要往下放）
        public string FilePath = "";
        public bool BuiltIn;
    }

    public partial class PetForm
    {
        // 画布：28×20 个字符，每个字符是半格。左上角在身体坐标 (0.5, 4)
        // 画布最多 28 行，最下面一行贴地；只画 20 行的形象会自动在上面补空行
        public const int SKIN_W = 28, SKIN_H = 28;
        const double SKIN_X0 = .5, SKIN_Y0 = 0;
        const int MAX_SKIN_COLORS = 10;
        // 程序会自己画眼睛、嘴巴、腮红，所以这块“脸”必须是身体
        const int FACE_R0 = SKIN_H - 12, FACE_R1 = SKIN_H - 8, FACE_C0 = 7, FACE_C1 = 20;   // 倒数第 12 到倒数第 8 行
        const string DEFAULT_SKIN = "叮叮";
        // 默认形象“叮叮”：一只小铃铛精（AI 干完活就是它在摇铃）
        const string DEFAULT_SKIN_JSON = "{\"name\": \"叮叮\", \"rows\": [\"............................\", \"............................\", \"............................\", \"........rrr......rrr........\", \".......rrrrrrrrrrrrrr.......\", \".......rrrrrrkkrrrrrr.......\", \"........rrrrrkkrrrrr........\", \".........rrrrrrrrrr.........\", \"...........bbbbbb...........\", \".........bbbbbbbbbb.........\", \".......bhbbbbbbbbbbbb.......\", \"......bhbbbbbbbbbbbbbb......\", \".....bbhbbbbbbbbbbbbbbb.....\", \".....bbhbbbbbbbbbbbbbbb.....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"...bbbbbbbbbbbbbbbbbbbbbb...\", \"...bbbbbbbbbbbbbbbbbbbbbb...\", \"..hhhhhhhhhhhhhhhhhhhhhhhh..\", \".dddddddddddddddddddddddddd.\", \".dddddddddddddddddddddddddd.\", \"............cccc............\", \".............cc.............\"], \"palette\": {\"b\": \"#F7CB4F\", \"d\": \"#DFA232\", \"h\": \"#FFF0B5\", \"r\": \"#E5574D\", \"k\": \"#B83B36\", \"c\": \"#C98A2A\"}, \"eyes\": \"short\", \"cheek_pos\": \"under\", \"smile\": \"false\", \"eye_in\": \"1\", \"outline\": \"#7A4A1E\", \"legs\": \"none\"}";

        static readonly string[] HAMSTER_ROWS = {
            "............................",
            "....bbbb............bbbb....",
            "...bbppbb..........bbppbb...",
            "...bbppbb..........bbppbb...",
            "...bbbbbbbbbbbbbbbbbbbbbb...",
            "...bbbbbbbbbbbbbbbbbbbbbb...",
            "....bbhhbbbbbbbbbbbbbbbb....",
            "...bbhbbbbbbbbbbbbbbbbbbb...",
            "...bbbbbbbbbbbbbbbbbbbbbb...",
            "..bbbbbbbbbbbbbbbbbbbbbbbb..",
            "..bbbbbbbbbbbbbbbbbbbbbbbb..",
            "..bbbbbbbbbbbbbbbbbbbbbbbb..",
            "..bbbbbbbbbbbbbbbbbbbbbbbb..",
            "..bbbbbbbbwwwwwwwwbbbbbbbb..",
            "..bbbbbbbwwwwwwwwwwbbbbbbb..",
            "...bbbbbwwwwwwwwwwwwbbbbb...",
            "...bbbbbwwwwwwwwwwwwbbbbb...",
            "....bbbbbwwwwwwwwwwbbbbb....",
            "......bbbbwwwwwwwwbbbb......",
            "........bbbbbbbbbbbb........" };

        List<Skin> skins = new List<Skin>();
        Skin skin;
        Brush SKIN_LINE = B("#5E3B2C"), SKIN_FEET = B("#E99A8A"), SKIN_EYE = B("#1A1A1A"), SKIN_HAND = B("#F2B880");
        Dictionary<char, Brush> skinBrushes = new Dictionary<char, Brush>();

        static Skin MakeHamster()
        {
            Skin s = new Skin();
            s.Name = DEFAULT_SKIN; s.BuiltIn = true;
            List<string> rows = new List<string>(HAMSTER_ROWS);
            while (rows.Count < SKIN_H) rows.Insert(0, new string('.', SKIN_W));   // 下面贴地，上面补空行
            s.Rows = rows.ToArray();
            s.Pal['b'] = ColorTranslator.FromHtml("#F2B880");
            s.Pal['w'] = ColorTranslator.FromHtml("#FFF1DE");
            s.Pal['p'] = ColorTranslator.FromHtml("#F7A6A8");
            s.Pal['h'] = ColorTranslator.FromHtml("#F9D7B0");
            s.Outline = "#5E3B2C"; s.Feet = "#E99A8A";
            return s;
        }

        // 默认形象：叮叮（画不出来时退回简单的仓鼠）
        Skin MakeDefault()
        {
            string problem;
            Skin s = null;
            try { s = ParseSkin(new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(DEFAULT_SKIN_JSON), out problem); } catch { }
            if (s == null) return MakeHamster();
            s.Name = DEFAULT_SKIN; s.BuiltIn = true;
            return s;
        }

        string SkinsDir() { string d = Path.Combine(cfgDir, "skins"); Directory.CreateDirectory(d); return d; }

        void LoadSkins()
        {
            skins.Clear();
            skins.Add(MakeDefault());
            List<string> files = new List<string>();
            try { string local = Path.Combine(dir, "skins"); if (Directory.Exists(local)) files.AddRange(Directory.GetFiles(local, "*.json")); } catch { }   // 程序文件夹里自带的形象
            try { files.AddRange(Directory.GetFiles(SkinsDir(), "*.json")); } catch { }                                                                 // 聊天 / 照片画出来的形象
            try
            {
                foreach (string f in files)
                {
                    try
                    {
                        Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(f, Encoding.UTF8));
                        string problem;
                        Skin s = ParseSkin(d, out problem);
                        if (s == null) continue;
                        s.FilePath = f;
                        skins.RemoveAll(delegate(Skin o) { return o.Name == s.Name; });
                        skins.Add(s);
                    }
                    catch { }
                }
            }
            catch { }
            string on = Names.Skin;   // config.txt 里的 skin=，第一次用哪个形象
            try { string f = Path.Combine(cfgDir, "skin_on.txt"); if (File.Exists(f)) on = File.ReadAllText(f, Encoding.UTF8).Trim(); } catch { }
            skin = skins[0];
            foreach (Skin s in skins) if (s.Name == on) skin = s;
            ApplySkinColors();
        }

        Skin ParseSkin(Dictionary<string, object> d, out string problem)
        {
            problem = "";
            Skin s = new Skin();
            s.Name = Str(d, "name").Trim();
            if (s.Name == "") { problem = "没有名字"; return null; }
            object pal;
            if (d.TryGetValue("palette", out pal) && pal is Dictionary<string, object>)
                foreach (KeyValuePair<string, object> kv in (Dictionary<string, object>)pal)
                {
                    if (kv.Key.Length != 1 || kv.Key == ".") continue;
                    if (s.Pal.Count >= MAX_SKIN_COLORS) break;   // 颜色少才像像素画
                    try { s.Pal[kv.Key[0]] = ColorTranslator.FromHtml(Convert.ToString(kv.Value).Trim()); } catch { }
                }
            if (!s.Pal.ContainsKey('b')) { problem = "palette 里必须有 b（身体主色）"; return null; }
            object rs;
            List<string> rows = new List<string>();
            if (d.TryGetValue("rows", out rs) && rs is ArrayList)
                foreach (object r in (ArrayList)rs)
                {
                    string row = Convert.ToString(r);
                    if (row.Length > SKIN_W) row = row.Substring(0, SKIN_W);
                    row = row.PadRight(SKIN_W, '.');
                    if (rows.Count < SKIN_H) rows.Add(row);
                }
            if (rows.Count == 0) { problem = "没有画 rows"; return null; }
            // 行数不够的从上面补空行，让脚始终贴在最下面
            int pad = SKIN_H - rows.Count;
            while (rows.Count < SKIN_H) rows.Insert(0, new string('.', SKIN_W));
            int fup0; int.TryParse(Str(d, "face_up"), out fup0); fup0 = Math.Max(0, Math.Min(12, fup0));
            for (int r = FACE_R0 - fup0; r <= FACE_R1 - fup0; r++)
                for (int c = FACE_C0; c <= FACE_C1; c++)
                {
                    char ch = rows[r][c];
                    if (ch == '.' || ch == ' ' || !s.Pal.ContainsKey(ch))
                    { problem = "你画的第 " + (FACE_R0 - fup0 - pad) + "–" + (FACE_R1 - fup0 - pad) + " 行、第 " + FACE_C0 + "–" + FACE_C1 + " 列是脸（程序会在这里画眼睛和嘴），这块必须填满颜色，现在第 " + (r - pad) + " 行第 " + c + " 列是空的"; return null; }
                }
            s.Rows = rows.ToArray();
            s.Outline = Str(d, "outline");
            s.Feet = Str(d, "feet");
            if (s.Outline.ToLower() == "none") { s.NoOutline = true; s.Outline = ""; }
            if (Str(d, "eyes") == "bar") s.Eyes = "bar";
            if (Str(d, "eyes") == "short") s.Eyes = "short";
            if (Str(d, "hands") == "square") s.Hands = "square";
            if (Str(d, "hands") == "none") s.Hands = "none";     // 坐着的小动物：前爪画在图里，不另外加手
            if (Str(d, "legs") == "legs") s.Legs = "legs";
            if (Str(d, "legs") == "none") s.Legs = "none";       // 不另外加小脚
            if (Str(d, "cheeks").ToLower() == "false") s.Cheeks = false;
            int hr; if (int.TryParse(Str(d, "hand_row"), out hr) && hr + pad >= 6 && hr + pad <= SKIN_H - 2) s.HandRow = hr + pad;
            s.EyeColor = Str(d, "eye_color");
            int fu; if (int.TryParse(Str(d, "face_up"), out fu)) s.FaceUp = Math.Max(0, Math.Min(12, fu));
            s.HandColor = Str(d, "hand_color");
            s.Thin = Str(d, "thin");
            s.CheekUnder = Str(d, "cheek_pos") == "under";
            double ei; if (double.TryParse(Str(d, "eye_in"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out ei)) s.EyeIn = Math.Max(0, Math.Min(2, ei));
            double ci; if (double.TryParse(Str(d, "cheek_in"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out ci)) s.CheekIn = Math.Max(0, Math.Min(2, ci));
            if (Str(d, "smile").ToLower() == "false") s.Smile = false;
            return s;
        }

        string MakeSkin(Dictionary<string, object> input)
        {
            string problem;
            Skin s = ParseSkin(input, out problem);
            if (s == null) return "画不出来：" + problem;
            if (s.Name == DEFAULT_SKIN) s.Name += "（新）";
            s.FilePath = Path.Combine(SkinsDir(), SafeName(s.Name) + ".json");
            try { File.WriteAllText(s.FilePath, new JavaScriptSerializer().Serialize(input), Encoding.UTF8); } catch { }
            skins.RemoveAll(delegate(Skin o) { return o.Name == s.Name; });
            skins.Add(s);
            WearSkin(s);
            if (!working) Set("happy");
            return "已经变成新形象“" + s.Name + "”了（" + s.Pal.Count + " 种颜色）。";
        }

        string SetSkin(string name)
        {
            if (name == "" || name == "默认" || name == "default") name = DEFAULT_SKIN;
            foreach (Skin s in skins) if (s.Name == name) { WearSkin(s); return "换回了“" + s.Name + "”"; }
            return "没有叫“" + name + "”的形象";
        }

        void WearSkin(Skin s)
        {
            skin = s;
            try { File.WriteAllText(Path.Combine(cfgDir, "skin_on.txt"), s.Name, Encoding.UTF8); } catch { }
            ApplySkinColors();
            Invalidate();
        }

        static Color Darker(Color c, double k) { return Color.FromArgb((int)(c.R * k), (int)(c.G * k), (int)(c.B * k)); }

        // 身体主色可以被造型里的 body_color 覆盖
        void ApplySkinColors()
        {
            if (skin == null) skin = MakeHamster();
            string over = "";
            foreach (Look lk in looks) if (lk.Enabled && lk.BodyColor != "") over = lk.BodyColor;
            Color main = skin.Pal['b'];
            bool recolored = false;
            if (over != "") { try { main = ColorTranslator.FromHtml(over); recolored = true; } catch { } }
            BODY = new SolidBrush(main);
            BODY_D = new SolidBrush(Darker(main, .85));
            skinBrushes.Clear();
            foreach (KeyValuePair<char, Color> kv in skin.Pal) skinBrushes[kv.Key] = new SolidBrush(kv.Value);
            skinBrushes['b'] = BODY;
            thinBrushes.Clear();
            foreach (char tc in skin.Thin) { Brush tb; if (skinBrushes.TryGetValue(tc, out tb)) thinBrushes.Add(tb); }
            Color line = Darker(main, .38);
            if (!recolored && skin.Outline != "") { try { line = ColorTranslator.FromHtml(skin.Outline); } catch { } }
            SKIN_LINE = new SolidBrush(line);
            Color feet = Darker(main, .88);
            if (!recolored && skin.Feet != "") { try { feet = ColorTranslator.FromHtml(skin.Feet); } catch { } }
            SKIN_FEET = new SolidBrush(feet);
            SKIN_EYE = EYE;
            SKIN_HAND = BODY;
            if (skin.HandColor.Length == 1 && skin.Pal.ContainsKey(skin.HandColor[0])) SKIN_HAND = new SolidBrush(skin.Pal[skin.HandColor[0]]);
            else if (skin.HandColor != "") { try { SKIN_HAND = new SolidBrush(ColorTranslator.FromHtml(skin.HandColor)); } catch { } }
            if (skin.EyeColor != "") { try { SKIN_EYE = new SolidBrush(ColorTranslator.FromHtml(skin.EyeColor)); } catch { } }
        }

        // ---------- 画整只身体：身体 + 小手 + 小脚，再自动描一圈边 ----------
        const int PAD = 6;
        Brush[,] cells = new Brush[SKIN_H + PAD * 2 + 4, SKIN_W + PAD * 2];

        static int H2(double v) { return (int)Math.Round(v * 2); }

        void DrawSkin(double dx, double dy, double sq, bool flat, double armL, double armR, double armLX, double armRX,
                      bool hideArmL, bool hideArmR, double legLen, double legA, double legB, double wave)
        {
            if (skin == null) ApplySkinColors();
            int R = cells.GetLength(0), C = cells.GetLength(1);
            Array.Clear(cells, 0, cells.Length);
            string[] rows = skin.Rows;
            int sqr = H2(sq);
            // 找身体在“手”那一行的左右边缘
            int handRow = skin.HandRow, left = 2, right = SKIN_W - 3;
            for (int c = 0; c < SKIN_W; c++) if (rows[handRow][c] != '.') { left = c; break; }
            for (int c = SKIN_W - 1; c >= 0; c--) if (rows[handRow][c] != '.') { right = c; break; }
            int bottom = SKIN_H - 1;
            for (int r = SKIN_H - 1; r >= 0; r--) { bool any = false; foreach (char ch in rows[r]) if (ch != '.') { any = true; break; } if (any) { bottom = r; break; } }

            if (!flat)
            {
                // 脚（在身体后面，只露出下半截）
                if (skin.Legs == "legs" && legLen > 0)
                {
                    // 四条细腿，两两交替
                    int[] lc = { 5, 17, 9, 21 };
                    for (int k = 0; k < 4; k++)
                    {
                        int len = H2(legLen - (k < 2 ? legA : legB));
                        for (int r = 1; r <= len; r++) { Put(bottom + r, lc[k], SKIN_FEET); Put(bottom + r, lc[k] + 1, SKIN_FEET); }
                    }
                }
                else if (legLen >= 1 && skin.Legs != "none")
                {
                    int top = bottom - 1 + H2(legLen - 2);
                    // 脚跟着身体最下面一行的宽度走：胖的分得开，瘦的并在一起
                    int bl = 0, br = SKIN_W - 1;
                    for (int c = 0; c < SKIN_W; c++) if (rows[bottom][c] != '.') { bl = c; break; }
                    for (int c = SKIN_W - 1; c >= 0; c--) if (rows[bottom][c] != '.') { br = c; break; }
                    double mid = (bl + br) / 2.0, spread = Math.Min(5, (br - bl) / 2.0 - 1);
                    int[] fc = { (int)Math.Round(mid - spread - 2), (int)Math.Round(mid + spread - 1) }; double[] lift = { legA, legB };
                    for (int k = 0; k < 2; k++)
                    {
                        int t0 = top - H2(Math.Max(0, lift[k]));
                        for (int r = 0; r < 3; r++) for (int c = 0; c < 4; c++)
                            {
                                if ((r == 2) && (c == 0 || c == 3)) continue;
                                Put(t0 + r, fc[k] + c, SKIN_FEET);
                            }
                    }
                }
                // 身体
                for (int r = 0; r < SKIN_H; r++)
                    for (int c = 0; c < SKIN_W; c++)
                    {
                        char ch = rows[r][c];
                        Brush b;
                        if (ch == '.' || !skinBrushes.TryGetValue(ch, out b)) continue;
                        Put(r + sqr, c, b);
                    }
                // 小手
                if (skin.Hands == "none") { }
                else if (skin.Hands == "square")
                {
                    if (!hideArmL) Square(handRow - 1 + sqr - H2(armL), left - 4 + H2(armLX) - sqr);
                    if (!hideArmR) Square(handRow - 1 + sqr - H2(armR), right + 1 + H2(armRX) + sqr);
                }
                else
                {
                    if (!hideArmL) Hand(handRow + sqr - H2(armL), left - 2 + H2(armLX) - sqr);
                    if (!hideArmR) Hand(handRow + sqr - H2(armR), right + H2(armRX) + sqr);
                }
            }
            else
            {
                // 被戳晕：压成一半高，趴在地上，一只手无力地挥
                for (int r = 0; r < SKIN_H; r += 2)
                    for (int c = 0; c < SKIN_W; c++)
                    {
                        char ch = rows[r][c];
                        Brush b;
                        if (ch == '.' || !skinBrushes.TryGetValue(ch, out b)) continue;
                        Put(SKIN_H / 2 + 1 + r / 2, c, b);   // 压成一半高，贴在地上
                    }
                if (skin.Hands == "square") Square(SKIN_H - 9 - H2(wave), right + 1); else if (skin.Hands != "none") Hand(SKIN_H - 8 - H2(wave), right);
            }
            // 描边：空格子旁边有身体，就涂成边线色
            for (int r = 0; r < R && !skin.NoOutline; r++)
                for (int c = 0; c < C; c++)
                {
                    if (cells[r, c] != null) continue;
                    bool near = Solid(r - 1, c) || Solid(r + 1, c) || Solid(r, c - 1) || Solid(r, c + 1);
                    if (near) outlineMark[r * C + c] = true;
                }
            for (int i = 0; i < outlineMark.Length; i++) if (outlineMark[i]) { cells[i / C, i % C] = SKIN_LINE; outlineMark[i] = false; }
            double ox = SKIN_X0 - PAD * .5 + dx, oy = SKIN_Y0 - PAD * .5 + dy;
            for (int r = 0; r < R; r++)
                for (int c = 0; c < C; c++)
                    if (cells[r, c] != null) U(ox + c * .5, oy + r * .5, .5, .5, cells[r, c]);
        }
        bool[] outlineMark = new bool[(SKIN_H + PAD * 2 + 4) * (SKIN_W + PAD * 2)];

        HashSet<Brush> thinBrushes = new HashSet<Brush>();
        bool Solid(int r, int c)
        {
            if (r < 0 || c < 0 || r >= cells.GetLength(0) || c >= cells.GetLength(1)) return false;
            Brush b = cells[r, c];
            return b != null && b != SKIN_LINE && !thinBrushes.Contains(b);
        }

        void Put(int r, int c, Brush b)
        {
            r += PAD; c += PAD;
            if (r < 0 || c < 0 || r >= cells.GetLength(0) || c >= cells.GetLength(1)) return;
            cells[r, c] = b;
        }

        void Square(int r, int c)
        {
            for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) Put(r + i, c + j, SKIN_HAND);
        }

        void Hand(int r, int c)
        {
            // 3×3 的小圆手（四个角空着）
            for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++)
                {
                    if ((i == 0 || i == 2) && (j == 0 || j == 2)) continue;
                    Put(r + i, c + j, SKIN_HAND);
                }
        }

        // 右键菜单「我的形象」
        ToolStripMenuItem BuildSkinMenu()
        {
            ToolStripMenuItem m = new ToolStripMenuItem("我的形象");
            m.DropDownItems.Add("…");
            m.DropDownOpening += delegate
            {
                m.DropDownItems.Clear();
                foreach (Skin s in skins)
                {
                    Skin s2 = s;
                    ToolStripMenuItem it = new ToolStripMenuItem(s.Name + (s.BuiltIn ? "（默认）" : ""), null, delegate { WearSkin(s2); Set("happy"); });
                    it.Checked = skin == s;
                    m.DropDownItems.Add(it);
                }
                m.DropDownItems.Add(new ToolStripSeparator());
                ToolStripMenuItem tip = new ToolStripMenuItem("想要新形象：在聊天里说，或者发照片给" + Names.Pet);
                tip.Enabled = false; m.DropDownItems.Add(tip);
                m.DropDownItems.Add("打开形象文件夹", null, delegate { try { Process.Start("explorer.exe", "\"" + SkinsDir() + "\""); } catch { } });
            };
            return m;
        }
    }
}

namespace PixelDeskPet
{
    // ---------- 像素小人生成器：照片里是人时，AI 只挑发型和颜色，程序按固定风格画出来 ----------
    public static class PersonGen
    {
        const int W = 28, HH = 23, OFF = 5;
        public static readonly string[] STYLES = { "messy", "short", "long", "bob", "buns", "curly" };

        static bool InEll(int x, int y, double cx, double cy, double rx, double ry)
        {
            double a = (x + .5 - cx) / rx, b = (y + .5 - cy) / ry;
            return a * a + b * b <= 1;
        }

        class G
        {
            public char[,] c = new char[HH + OFF, W];
            public G() { for (int y = 0; y < HH + OFF; y++) for (int x = 0; x < W; x++) c[y, x] = '.'; }
            public char Get(int x, int y) { return (x < 0 || x >= W || y < -OFF || y >= HH) ? '.' : c[y + OFF, x]; }
            public void Set(int x, int y, char ch) { if (x >= 0 && x < W && y >= -OFF && y < HH) c[y + OFF, x] = ch; }
            public void HL(int x0, int x1, int y, char ch) { for (int x = x0; x <= x1; x++) Set(x, y, ch); }
            public void Ell(double cx, double cy, double rx, double ry, char ch, bool onlyEmpty)
            {
                for (int y = -OFF; y < HH; y++) for (int x = 0; x < W; x++)
                        if (InEll(x, y, cx, cy, rx, ry) && (!onlyEmpty || Get(x, y) == '.')) Set(x, y, ch);
            }
        }

        static void Head(G g, string style)
        {
            const double CX = 14.0;
            // 1 头发大轮廓（占头的三分之二）
            g.Ell(CX, 4.2, 12.4, 8.6, 'h', false);
            // 2 圆圆的小脸，两边脸蛋鼓一点
            for (int y = 5; y < 13; y++) for (int x = 0; x < W; x++)
                    if (InEll(x, y, CX, 8.9, 7.4, 4.0) || InEll(x, y, CX - 3, 10, 4, 2.6) || InEll(x, y, CX + 3, 10, 4, 2.6)) g.Set(x, y, 's');
            // 3 耳朵
            foreach (int[] e in new int[][] { new int[] { 4, 5 }, new int[] { 23, 22 } })
            {
                for (int y = 8; y <= 10; y++) { g.Set(e[0], y, 's'); g.Set(e[1], y, 's'); }
                g.Set(e[0], 9, 'q');
            }
            // 4 刘海：第 4 行整排，第 5 行几个发尖，眼睛上面留一行肤色
            g.HL(5, 22, 4, 'h');
            int[] tips = style == "curly" ? new int[] { 6, 8, 9, 12, 13, 15, 17, 18, 21 } :
                         style == "long" || style == "bob" ? new int[] { 6, 7, 8, 12, 13, 14, 18, 19, 21 } :
                         style == "buns" ? new int[] { 6, 7, 10, 11, 14, 15, 17, 18, 21 } :
                         style == "short" ? new int[] { 6, 7, 10, 13, 14, 17, 20, 21 } :
                         new int[] { 6, 7, 9, 10, 11, 13, 14, 16, 17, 19, 20, 21 };
            foreach (int x in tips) g.Set(x, 5, 'h');
            if (style == "long" || style == "bob")
            {
                int end = style == "long" ? 20 : 13;
                for (int y = 7; y < end; y++) foreach (int x in new int[] { 2, 3, 4, 23, 24, 25 })
                        if (!(y >= 8 && y <= 10 && (x == 4 || x == 23))) g.Set(x, y, 'h');
                if (style == "long") for (int y = 20; y <= 21; y++) foreach (int x in new int[] { 3, 4, 23, 24 }) g.Set(x, y, 'h');
            }
            if (style == "buns") { g.Ell(6.5, -3.6, 2.9, 2.5, 'h', false); g.Ell(21.5, -3.6, 2.9, 2.5, 'h', false); }
            // 5 阴影：下半圈和贴着脸侧的头发用暗色
            for (int y = -OFF; y < HH; y++) for (int x = 0; x < W; x++)
                {
                    if (g.Get(x, y) != 'h') continue;
                    if (y >= 8 && !InEll(x, y, CX, 4.0, 11.4, 7.4)) g.Set(x, y, 'k');
                    if (y >= 8 && (x < 7 || x > 20) && ("sq".IndexOf(g.Get(x + 1, y)) >= 0 || "sq".IndexOf(g.Get(x - 1, y)) >= 0)) g.Set(x, y, 'k');
                }
            // 6 发丝
            int[][] strands = { new int[] { 9, -1, 8, 0, 8, 1, 8, 2 }, new int[] { 14, -2, 14, -1, 13, 0, 13, 1 }, new int[] { 18, -1, 19, 0, 19, 1, 19, 2 },
                new int[] { 5, 1, 5, 2, 5, 3 }, new int[] { 22, 1, 22, 2, 22, 3 }, new int[] { 11, 2, 11, 3 }, new int[] { 16, 2, 16, 3 } };
            foreach (int[] s in strands) for (int i = 0; i < s.Length; i += 2) if (g.Get(s[i], s[i + 1]) == 'h') g.Set(s[i], s[i + 1], 'k');
            // 7 高光（天使环）
            int[] hi = { 6, -1, 7, -2, 8, -2, 10, -3, 11, -3, 16, -3, 17, -3, 19, -2, 20, -2, 21, -1 };
            for (int i = 0; i < hi.Length; i += 2) if (g.Get(hi[i], hi[i + 1]) == 'h') g.Set(hi[i], hi[i + 1], 'l');
            // 8 头顶
            if (style == "messy")
            {
                g.Set(14, -5, 'h'); g.Set(13, -5, 'h'); g.Set(13, -4, 'h');
                int[] sp = { 2, 0, 25, 0, 1, 4, 26, 4, 4, -3, 23, -3 };
                for (int i = 0; i < sp.Length; i += 2) g.Set(sp[i], sp[i + 1], 'h');
            }
            if (style == "curly")
            {
                double[] cc = { 4, -1, 8, -3, 14, -3.8, 20, -3, 24, -1, 1.8, 3.5, 26.2, 3.5 };
                for (int i = 0; i < cc.Length; i += 2) g.Ell(cc[i], cc[i + 1], 2.0, 1.7, 'h', true);
            }
            // 脸侧一点阴影
            for (int y = 7; y < 12; y++) for (int x = 0; x < W; x++)
                    if (g.Get(x, y) == 's' && (x < 8 || x > 19) && x != 4 && x != 5 && x != 22 && x != 23 &&
                        ("hk".IndexOf(g.Get(x - 1, y)) >= 0 || "hk".IndexOf(g.Get(x + 1, y)) >= 0)) g.Set(x, y, 'q');
        }

        static void Body(G g, bool strings, bool skirt)
        {
            g.HL(10, 17, 13, 'g'); g.HL(9, 18, 14, 'g');
            for (int y = 15; y < 19; y++) { g.HL(9, 18, y, 'b'); g.Set(18, y, 'c'); }
            g.HL(9, 18, 18, 'c');
            for (int y = 15; y < 18; y++) { g.Set(7, y, 'b'); g.Set(8, y, 'b'); g.Set(19, y, 'b'); g.Set(20, y, 'c'); }
            if (strings) { g.Set(12, 15, 'd'); g.Set(12, 16, 'd'); g.Set(15, 15, 'd'); g.Set(15, 16, 'd'); }
            if (skirt) { g.HL(9, 18, 19, 'p'); g.HL(8, 19, 20, 'p'); }
            else { g.HL(9, 18, 19, 'p'); g.HL(9, 18, 20, 'p'); g.Set(13, 20, '.'); g.Set(14, 20, '.'); }
            for (int y = 21; y <= 22; y++) foreach (int x in new int[] { 10, 11, 16, 17 }) g.Set(x, y, 's');
        }

        static Color Hex(string s, string fallback)
        {
            try { if (s != null && s.Trim() != "") return ColorTranslator.FromHtml(s.Trim()); } catch { }
            return ColorTranslator.FromHtml(fallback);
        }
        static string ToHex(Color c) { return "#" + c.R.ToString("X2") + c.G.ToString("X2") + c.B.ToString("X2"); }
        static Color Mul(Color c, double k) { return Color.FromArgb((int)Math.Min(255, c.R * k), (int)Math.Min(255, c.G * k), (int)Math.Min(255, c.B * k)); }
        static Color Mix(Color a, Color b, double t) { return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t)); }

        // 生成一张皮肤（和 make_skin 的格式一样）
        public static Dictionary<string, object> Build(string name, string style, string hair, string skin, string top, string collar,
                                                      string bottom, string bottomColor, string shoes, bool strings)
        {
            if (Array.IndexOf(STYLES, style) < 0) style = "messy";
            G g = new G();
            Head(g, style);
            Body(g, strings, bottom == "skirt");
            List<object> rows = new List<object>();
            for (int y = 0; y < HH + OFF; y++) { StringBuilder sb = new StringBuilder(); for (int x = 0; x < W; x++) sb.Append(g.c[y, x]); rows.Add(sb.ToString()); }
            Color h = Hex(hair, "#6A4636"), s = Hex(skin, "#FDE1CF"), b = Hex(top, "#EFE6D6");
            Color col = collar != null && collar.Trim() != "" ? Hex(collar, "#6E7D55") : Mul(b, .78);
            Color p = Hex(bottomColor, "#4E3E35");
            Dictionary<string, object> pal = new Dictionary<string, object>();
            pal["h"] = ToHex(h); pal["k"] = ToHex(Mul(h, .64)); pal["l"] = ToHex(Mix(h, Color.White, .32));
            pal["s"] = ToHex(s); pal["q"] = ToHex(Mul(s, .95));
            pal["b"] = ToHex(b); pal["c"] = ToHex(Mul(b, .88)); pal["g"] = ToHex(col);
            pal["d"] = ToHex(Mix(b, Color.Black, .3)); pal["p"] = ToHex(p);
            Dictionary<string, object> d = new Dictionary<string, object>();
            d["name"] = name; d["rows"] = new ArrayList(rows); d["palette"] = pal;
            d["outline"] = ToHex(Mix(Mul(h, .35), Color.FromArgb(43, 29, 24), .6));
            d["feet"] = ToHex(Hex(shoes, "#3B2E28"));
            d["eyes"] = "short"; d["eye_color"] = "#2E1E1A"; d["smile"] = "false"; d["cheek_pos"] = "under";
            d["eye_in"] = "1"; d["hand_row"] = "22"; d["face_up"] = "4"; d["hand_color"] = "s";
            return d;
        }
    }
}

namespace PixelDeskPet
{
    // ---------- 像素宠物生成器：坐着的小动物，正脸、身体是动物本来的样子，有胡须 ----------
    public static class PetGen
    {
        const int W = 28, H = 28;
        public static readonly string[] SPECIES = { "cat", "dog", "shiba", "rabbit", "hamster", "bear" };
        public static readonly string[] PATTERNS = { "none", "tabby", "spots", "calico", "tuxedo" };

        class G
        {
            public char[,] c = new char[H, W];
            public G() { for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) c[y, x] = '.'; }
            public char Get(int x, int y) { return (x < 0 || x >= W || y < 0 || y >= H) ? '.' : c[y, x]; }
            public void Set(int x, int y, char ch) { if (x >= 0 && x < W && y >= 0 && y < H) c[y, x] = ch; }
            public void Rect(int x0, int y0, int x1, int y1, char ch) { for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) Set(x, y, ch); }
            public void RectOn(int x0, int y0, int x1, int y1, char ch, string only) { for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) if (only.IndexOf(Get(x, y)) >= 0) Set(x, y, ch); }
            public void Ell(double cx, double cy, double rx, double ry, char ch, string only)
            {
                for (int y = 0; y < H; y++) for (int x = 0; x < W; x++)
                    {
                        double a = (x + .5 - cx) / rx, b = (y + .5 - cy) / ry;
                        if (a * a + b * b <= 1 && (only == null || only.IndexOf(Get(x, y)) >= 0)) Set(x, y, ch);
                    }
            }
            public void Pts(int[] p, char ch) { for (int i = 0; i + 1 < p.Length; i += 2) Set(p[i], p[i + 1], ch); }
        }

        static Color Hex(string s, Color fallback) { try { if (s != null && s.Trim() != "") return ColorTranslator.FromHtml(s.Trim()); } catch { } return fallback; }
        static string ToHex(Color c) { return "#" + c.R.ToString("X2") + c.G.ToString("X2") + c.B.ToString("X2"); }
        static Color Mul(Color c, double k) { return Color.FromArgb((int)Math.Min(255, c.R * k), (int)Math.Min(255, c.G * k), (int)Math.Min(255, c.B * k)); }
        static Color Mix(Color a, Color b, double t) { return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t)); }

        public static Dictionary<string, object> Build(string name, string species, string main, string light, string pattern, string patternColor,
                                                      string pattern2, string earColor, string nose)
        {
            if (Array.IndexOf(SPECIES, species) < 0) species = "cat";
            if (Array.IndexOf(PATTERNS, pattern) < 0) pattern = "none";
            G g = new G();
            // ---- 头：上面小圆、下面大圆，叠成一个饭团脸 ----
            int[] hw = { 0, 4, 6, 7, 8, 9, 9, 10, 10, 11, 11, 11, 10, 8 };          // 每一行的半宽：上窄下宽，顺滑过渡
            for (int y = 1; y < hw.Length; y++) g.Rect(14 - hw[y], y, 13 + hw[y], y, 'b');
            if (species == "cat" || species == "shiba")
            {
                char inner = species == "shiba" ? 'w' : 'p';
                g.Rect(6, 0, 7, 0, 'b'); g.Rect(6, 1, 8, 1, 'b'); g.Rect(6, 2, 9, 2, 'b'); g.Rect(6, 3, 10, 3, 'b');
                g.Rect(20, 0, 21, 0, 'b'); g.Rect(19, 1, 21, 1, 'b'); g.Rect(18, 2, 21, 2, 'b'); g.Rect(17, 3, 21, 3, 'b');
                g.Set(7, 1, inner); g.Rect(7, 2, 8, 2, inner); g.Set(20, 1, inner); g.Rect(19, 2, 20, 2, inner);
            }
            else if (species == "rabbit") { g.Rect(8, 0, 11, 3, 'b'); g.Rect(16, 0, 19, 3, 'b'); g.Rect(9, 0, 10, 3, 'p'); g.Rect(17, 0, 18, 3, 'p'); }
            else if (species == "hamster" || species == "bear")
            { g.Rect(5, 1, 9, 3, 'b'); g.Rect(18, 1, 22, 3, 'b'); g.Set(5, 1, '.'); g.Set(9, 1, '.'); g.Set(18, 1, '.'); g.Set(22, 1, '.'); g.Rect(6, 2, 8, 3, 'p'); g.Rect(19, 2, 21, 3, 'p'); }
            if (species == "dog")
            {
                // 头顶一顶有颜色的"帽子"，中间留一道白，垂耳从头顶两侧挂下来
                g.RectOn(0, 1, 27, 5, 'e', "b"); g.Rect(13, 2, 14, 5, 'b'); g.RectOn(12, 5, 15, 5, 'b', "e");
                g.Rect(4, 4, 7, 11, 'e'); g.Rect(20, 4, 23, 11, 'e'); g.Rect(3, 5, 3, 10, 'e'); g.Rect(24, 5, 24, 10, 'e');
                g.Rect(5, 12, 6, 12, 'e'); g.Rect(21, 12, 22, 12, 'e');
            }
            // ---- 身体：小小圆圆的一团，比头窄，短短的 ----
            int[] bw = { 5, 6, 7, 7, 8, 8, 8, 8, 7, 6 };                                // 第 14~23 行的半宽
            for (int k = 0; k < bw.Length; k++) g.Rect(14 - bw[k], 14 + k, 13 + bw[k], 14 + k, 'b');
            g.RectOn(9, 14, 18, 14, 'm', "b");                                         // 下巴底下一道阴影
            for (int y = 20; y < 24; y++) { g.Set(13, y, 'm'); g.Set(14, y, 'm'); }       // 两只小前脚
            g.Set(10, 23, 'm'); g.Set(17, 23, 'm');
            // ---- 脸 ----
            if (species == "dog" || species == "shiba" || species == "bear") { g.Rect(11, 10, 16, 12, 'w'); g.Set(11, 10, 'b'); g.Set(16, 10, 'b'); }
            g.Rect(13, 10, 14, 10, 'n');                                                 // 小鼻子
            // 胡须（细线）
            if (species == "cat" || species == "rabbit" || species == "hamster") g.Pts(new int[] { 0, 9, 1, 9, 0, 11, 1, 11, 26, 9, 27, 9, 26, 11, 27, 11 }, 'k');
            // 胸口浅色
            bool white = pattern == "tuxedo";
            if (white || (light != null && light.Trim() != "")) g.Ell(14, 16.6, 3.0, 2.3, 'w', "bm");
            if (white) { g.RectOn(9, 22, 12, 23, 'w', "b"); g.RectOn(15, 22, 18, 23, 'w', "b"); g.Rect(13, 5, 14, 9, 'w'); g.Rect(12, 8, 15, 9, 'w'); }
            // ---- 花纹 ----
            if (pattern == "tabby")
            {
                g.Pts(new int[] { 10, 2, 10, 3, 13, 2, 13, 3, 14, 2, 14, 3, 17, 2, 17, 3, 3, 9, 4, 9, 23, 9, 24, 9 }, 'd');
                g.Pts(new int[] { 7, 17, 8, 17, 19, 17, 20, 17, 6, 20, 7, 20, 20, 20, 21, 20 }, 'd');
            }
            else if (pattern == "spots") { if (species != "dog") { g.Ell(8, 2.6, 3.4, 2.4, 'd', "bp"); } g.Ell(18.5, 19, 1.6, 1.5, 'd', "b"); g.Ell(9, 21, 1.4, 1.3, 'd', "b"); }
            else if (pattern == "calico") { g.Ell(7.5, 4.5, 3.6, 3.0, 'o', "bp"); g.Ell(20.5, 5, 3.2, 2.8, 'd', "bp"); g.Ell(8, 20, 2.2, 2.2, 'o', "b"); g.Ell(19.5, 17, 1.8, 1.7, 'd', "b"); }
            // ---- 颜色：描边用柔和的深灰/深色，不用纯黑 ----
            const int SHIFT = 4;                                                          // 整体往下挪，身子短了下面不留空
            for (int y = H - 1; y >= 0; y--) for (int x = 0; x < W; x++) g.c[y, x] = y >= SHIFT ? g.c[y - SHIFT, x] : '.';
            List<object> rows = new List<object>();
            for (int y = 0; y < H; y++) { StringBuilder sb = new StringBuilder(); for (int x = 0; x < W; x++) sb.Append(g.c[y, x]); rows.Add(sb.ToString()); }
            Color b = Hex(main, ColorTranslator.FromHtml("#F7F5F2"));
            double lum = .3 * b.R + .59 * b.G + .11 * b.B;
            Color w = Hex(light, lum > 215 ? Color.White : ColorTranslator.FromHtml("#F6F1EA"));
            Color line = lum > 200 ? ColorTranslator.FromHtml("#8C8486") : Mix(Mul(b, .45), ColorTranslator.FromHtml("#3A3236"), .5);
            Dictionary<string, object> pal = new Dictionary<string, object>();
            pal["b"] = ToHex(b); pal["m"] = ToHex(lum > 200 ? ColorTranslator.FromHtml("#D9D4D2") : Mul(b, .8)); pal["w"] = ToHex(w); pal["k"] = ToHex(line);
            pal["d"] = ToHex(Hex(patternColor, Mul(b, .66))); pal["o"] = ToHex(Hex(pattern2, ColorTranslator.FromHtml("#E9A05A")));
            pal["e"] = ToHex(Hex(earColor, Mul(b, .7))); pal["p"] = "#F7C6CC";
            pal["n"] = ToHex(Hex(nose, ColorTranslator.FromHtml("#2E2A2C")));
            Dictionary<string, object> dd = new Dictionary<string, object>();
            dd["name"] = name; dd["rows"] = new ArrayList(rows); dd["palette"] = pal; dd["outline"] = ToHex(line);
            dd["eyes"] = "short"; dd["eye_color"] = lum < 90 ? "#E8B83A" : "#2E2A2C"; dd["smile"] = "false"; dd["cheek_pos"] = "under";
            dd["eye_in"] = "1"; dd["face_up"] = "4"; dd["hands"] = "none"; dd["legs"] = "none"; dd["thin"] = "k";
            return dd;
        }
    }
    // 万物生成器：照片里不是人也不是常见宠物时用（食物、植物、物件、小怪兽、玩偶……）
    // 和小人 / 宠物一样由程序来画：从一套可爱的“底座轮廓”里挑一个，配上颜色、头顶的标志物和身上的花纹，保证每次都圆润统一
    public static class ThingGen
    {
        const int W = 28, H = 28;
        public static readonly string[] BASES = { "blob", "bean", "square", "triangle", "drop", "cloud", "bell", "pudding", "cup", "octopus" };
        public static readonly string[] TOPS = { "none", "sprout", "bow", "cherry", "antenna", "cat_ears", "round_ears", "horns", "flower", "straw", "curl", "frog_eyes", "crown" };
        public static readonly string[] MARKS = { "none", "band", "top_layer", "bottom_layer", "stripes", "vstripes", "spots", "belly", "pearls" };

        class G
        {
            public char[,] c = new char[H, W];
            public G() { for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) c[y, x] = '.'; }
            public char Get(int x, int y) { return (x < 0 || x >= W || y < 0 || y >= H) ? '.' : c[y, x]; }
            public void Set(int x, int y, char ch) { if (x >= 0 && x < W && y >= 0 && y < H) c[y, x] = ch; }
            public void SetOn(int x, int y, char ch, string only) { if (only.IndexOf(Get(x, y)) >= 0) Set(x, y, ch); }
            public void Rect(int x0, int y0, int x1, int y1, char ch) { for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) Set(x, y, ch); }
            public void RectOn(int x0, int y0, int x1, int y1, char ch, string only) { for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) SetOn(x, y, ch, only); }
            public void Row(int y, int hw, char ch) { Rect(14 - hw, y, 13 + hw, y, ch); }
            public void Ell(double cx, double cy, double rx, double ry, char ch, string only)
            {
                for (int y = 0; y < H; y++) for (int x = 0; x < W; x++)
                    {
                        double a = (x + .5 - cx) / rx, b = (y + .5 - cy) / ry;
                        if (a * a + b * b <= 1 && (only == null || only.IndexOf(Get(x, y)) >= 0)) Set(x, y, ch);
                    }
            }
            // 左右对称地画（x 是左半边的坐标）
            public void Sym(int x, int y, char ch) { Set(x, y, ch); Set(27 - x, y, ch); }
            public void Pts(int[] p, char ch) { for (int i = 0; i + 1 < p.Length; i += 2) Set(p[i], p[i + 1], ch); }
            public int Left(int y) { for (int x = 0; x < W; x++) if (Get(x, y) != '.') return x; return 14; }
            public int Top() { for (int y = 0; y < H; y++) if (Get(13, y) != '.' || Get(14, y) != '.') return y; return 10; }
        }

        static Color Hex(string s, Color fallback) { try { if (s != null && s.Trim() != "") return ColorTranslator.FromHtml(s.Trim()); } catch { } return fallback; }
        static string ToHex(Color c) { return "#" + c.R.ToString("X2") + c.G.ToString("X2") + c.B.ToString("X2"); }
        static Color Mul(Color c, double k) { return Color.FromArgb((int)Math.Min(255, c.R * k), (int)Math.Min(255, c.G * k), (int)Math.Min(255, c.B * k)); }
        static Color Mix(Color a, Color b, double t) { return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t)); }

        public static Dictionary<string, object> Build(string name, string bas, string main, string top, string topColor, string mark, string markColor)
        {
            if (Array.IndexOf(BASES, bas) < 0) bas = "blob";
            if (Array.IndexOf(TOPS, top) < 0) top = "none";
            if (Array.IndexOf(MARKS, mark) < 0) mark = "none";
            G g = new G();
            bool noFeet = false;
            // ---- 底座轮廓 ----
            switch (bas)
            {
                case "bean": g.Ell(14, 18.6, 10.6, 9.2, 'b', null); break;
                case "square":
                    g.Rect(3, 10, 24, 26, 'b'); g.Row(9, 9, 'b');
                    g.Set(3, 10, '.'); g.Set(24, 10, '.'); g.Set(3, 26, '.'); g.Set(24, 26, '.'); break;
                case "triangle":
                    for (int y = 7; y < 27; y++) { int hw = Math.Min(13, 1 + (int)((y - 7) * 0.78)); if (y >= 25) hw -= y - 24; g.Row(y, hw, 'b'); }
                    break;
                case "drop":
                    g.Ell(14, 19.2, 11, 7.8, 'b', null);
                    for (int y = 7; y < 15; y++) g.Row(y, 1 + (y - 7) * 6 / 5, 'b');
                    break;
                case "cloud":
                    g.Ell(6.5, 14.5, 4.5, 4.5, 'b', null); g.Ell(14, 11.5, 6.2, 6.2, 'b', null); g.Ell(21.5, 14.5, 4.5, 4.5, 'b', null);
                    g.Rect(2, 16, 25, 24, 'b'); g.Rect(1, 18, 26, 23, 'b'); g.Row(25, 11, 'b'); break;
                case "bell":
                    {
                        int[] hw = { 3, 5, 7, 8, 9, 9, 10, 10, 10, 10, 10, 10, 10, 11, 11, 12, 13, 13 };
                        for (int i = 0; i < hw.Length; i++) g.Row(8 + i, hw[i], 'b');
                        g.Rect(1, 24, 26, 25, 'd'); g.Rect(12, 26, 15, 26, 'u'); g.Rect(13, 27, 14, 27, 'u'); noFeet = true;
                    }
                    break;
                case "pudding":
                    for (int y = 10; y < 27; y++) g.Row(y, 8 + (y - 10) * 5 / 16, 'b');
                    g.Rect(1, 27, 26, 27, 'q'); noFeet = true; break;
                case "cup":
                    g.Row(9, 11, 'b'); g.Row(10, 11, 'b');
                    for (int y = 11; y < 27; y++) g.Row(y, 10 - (y - 11) / 8, 'b');
                    g.Rect(3, 9, 24, 10, 'd'); break;
                case "octopus":
                    g.Ell(14, 15, 11, 9.2, 'b', null);
                    for (int x0 = 3; x0 <= 21; x0 += 6) { g.Rect(x0, 22, x0 + 3, 25, 'b'); g.Rect(x0 + 1, 26, x0 + 3, 26, 'b'); }
                    g.Set(3, 26, 'b'); g.Set(2, 27, 'b'); g.Set(24, 26, 'b'); g.Set(25, 27, 'b');
                    foreach (int x in new int[] { 7, 8, 13, 14, 19, 20 }) { g.Set(x, 24, '.'); g.Set(x, 25, '.'); }
                    noFeet = true; break;
                default: g.Ell(14, 18.8, 12.4, 8.2, 'b', null); break;
            }
            int T = g.Top(), L = g.Left(T + 3);
            string body = "bdm";
            // ---- 身上的花纹（不碰脸那一块）----
            switch (mark)
            {
                case "band": g.RectOn(9, 21, 18, 27, 'm', "b"); break;
                case "top_layer":
                    g.RectOn(0, T, 27, T + 3, 'm', "b");
                    foreach (int x in new int[] { 6, 7, 11, 16, 17, 21 }) g.RectOn(x, T + 4, x, T + 4 + (x % 3), 'm', "b");
                    break;
                case "bottom_layer": g.RectOn(0, 23, 27, 26, 'm', "b"); break;
                case "stripes": foreach (int y in new int[] { T + 2, T + 5, 22, 25 }) if (y < 15 || y > 21) g.RectOn(0, y, 27, y, 'm', "b"); break;
                case "vstripes": for (int x = 4; x < 27; x += 5) { g.RectOn(x, 0, x, 15, 'm', "b"); g.RectOn(x, 21, x, 27, 'm', "b"); } break;
                case "spots": g.Ell(L + 3, T + 4, 2, 1.6, 'm', "b"); g.Ell(27 - L - 3.5, T + 3, 1.5, 1.3, 'm', "b"); g.Ell(6.5, 23, 1.6, 1.5, 'm', "b"); g.Ell(21, 24, 2, 1.7, 'm', "b"); break;
                case "belly": g.Ell(14, 24, 6.4, 3.6, 'm', "b"); break;
                case "pearls": foreach (int[] p in new int[][] { new[] { 7, 24 }, new[] { 10, 22 }, new[] { 12, 25 }, new[] { 16, 23 }, new[] { 19, 25 }, new[] { 21, 22 }, new[] { 8, 21 } }) g.RectOn(p[0], p[1], p[0] + 1, p[1] + 1, 'm', "b"); break;
            }
            // 左上角一小块高光，看起来圆润有光泽
            g.RectOn(L + 2, T + 3, L + 2, T + 5, 'h', "b"); g.RectOn(L + 3, T + 2, L + 3, T + 2, 'h', "b");
            // ---- 头顶的标志物 ----
            switch (top)
            {
                case "sprout":
                    g.Rect(13, T - 4, 14, T - 1, 'g');
                    g.Ell(9.5, T - 5.2, 3.6, 2.0, 't', "."); g.Ell(19, T - 6.2, 3.8, 2.1, 't', ".");
                    for (int x = 7; x < 12; x++) g.Set(x, x < 10 ? T - 5 : T - 4, 'g');
                    for (int x = 17; x < 22; x++) g.Set(x, x < 19 ? T - 6 : T - 7, 'g');
                    break;
                case "bow":
                    {
                        int[][] bw = { new[] { 8, 10 }, new[] { 7, 11 }, new[] { 7, 12 }, new[] { 8, 12 }, new[] { 9, 11 } };
                        for (int i = 0; i < 5; i++) for (int x = bw[i][0]; x <= bw[i][1]; x++) g.Sym(x, T - 5 + i, 't');
                        g.Rect(12, T - 4, 15, T - 1, 't'); g.Rect(13, T - 3, 14, T - 2, 'u');
                    }
                    break;
                case "cherry": g.Ell(14, T - 2.4, 2.3, 2.3, 't', null); g.Set(13, T - 3, 'h'); g.Rect(15, T - 7, 15, T - 4, 'g'); g.Set(16, T - 8, 'g'); break;
                case "antenna": g.Rect(13, T - 4, 14, T - 1, 'u'); g.Rect(12, T - 7, 15, T - 5, 't'); g.Set(12, T - 7, '.'); g.Set(15, T - 7, '.'); g.Set(12, T - 6, 'h'); break;
                case "cat_ears":
                    for (int k = 0; k < 4; k++) for (int x = L + 1 + k / 2; x <= L + 5 - (k + 1) / 2; x++) g.Sym(x, T + 1 - k, 'b');
                    g.Sym(L + 3, T, 'p'); g.Sym(L + 3, T - 1, 'p'); break;
                case "round_ears": g.Ell(L + 3.5, T + 0.5, 2.7, 2.5, 'b', "."); g.Ell(27 - L - 2.5, T + 0.5, 2.7, 2.5, 'b', "."); g.RectOn(L + 3, T, L + 3, T, 'p', "b"); g.RectOn(24 - L, T, 24 - L, T, 'p', "b"); break;
                case "horns":
                    for (int k = 0; k < 4; k++) { g.Sym(L + 4 - k / 2, T + 1 - k, 't'); g.Sym(L + 5 - k / 2, T + 1 - k, 't'); }
                    break;
                case "flower":
                    g.Rect(13, T - 2, 14, T - 1, 'g');
                    g.Ell(14, T - 6.5, 1.8, 1.6, 't', null); g.Ell(14, T - 2.6, 1.8, 1.6, 't', null); g.Ell(12, T - 4.6, 1.8, 1.6, 't', null); g.Ell(16, T - 4.6, 1.8, 1.6, 't', null);
                    g.Rect(13, T - 5, 14, T - 4, 'u'); break;
                case "straw": for (int k = 0; k < 7; k++) { g.Set(16 + k / 2, T - k, 't'); g.Set(17 + k / 2, T - k, 't'); } g.SetOn(17, T, 'u', "t"); break;
                case "curl": g.Pts(new int[] { 14, T - 1, 14, T - 2, 15, T - 3, 16, T - 3, 17, T - 2, 13, T - 1 }, 'u'); break;
                case "frog_eyes": g.Ell(L + 4, T + 1, 3.4, 3.0, 'b', "."); g.Ell(27 - L - 3, T + 1, 3.4, 3.0, 'b', "."); break;
                case "crown":
                    g.Rect(9, T - 2, 18, T - 1, 't');
                    foreach (int x in new int[] { 9, 13, 14, 18 }) g.Set(x, T - 3, 't');
                    g.Set(9, T - 4, 't'); g.Set(18, T - 4, 't'); g.Rect(13, T - 5, 14, T - 4, 't'); g.Set(11, T - 2, 'u'); g.Set(16, T - 2, 'u');
                    break;
            }
            g.Rect(7, 16, 20, 20, 'b');                                                    // 脸这一块留给程序画眼睛和嘴
            g.Pts(new int[] { 7, 16, 20, 16 }, 'b');
            // ---- 颜色 ----
            Color b = Hex(main, ColorTranslator.FromHtml("#F2C46B"));
            double lum = .3 * b.R + .59 * b.G + .11 * b.B;
            string defTop = top == "sprout" ? "#86C96F" : top == "bow" || top == "cherry" ? "#E5574D" : top == "antenna" || top == "crown" ? "#F6C744"
                : top == "horns" ? "#F4E6C8" : top == "flower" ? "#F59AB5" : top == "straw" ? "#F29BB0" : "";
            Color t = Hex(topColor, defTop == "" ? Mul(b, .7) : ColorTranslator.FromHtml(defTop));
            Color line = lum > 215 ? ColorTranslator.FromHtml("#7D8796") : Mix(Mul(b, .42), ColorTranslator.FromHtml("#3A2E2A"), .45);
            Dictionary<string, object> pal = new Dictionary<string, object>();
            pal["b"] = ToHex(b); pal["d"] = ToHex(Mul(b, .86)); pal["h"] = ToHex(Mix(b, Color.White, .6));
            pal["m"] = ToHex(Hex(markColor, mark == "belly" || mark == "bottom_layer" ? Mix(b, Color.White, .55) : Mul(b, .72)));
            pal["t"] = ToHex(t); pal["u"] = ToHex(top == "curl" ? Mul(b, .6) : top == "flower" ? ColorTranslator.FromHtml("#F6C744") : Mul(t, .72));
            pal["g"] = "#4F9A45"; pal["p"] = "#F7C6CC"; pal["q"] = "#DCE6EF";
            List<object> rows = new List<object>();
            Dictionary<string, object> used = new Dictionary<string, object>();
            for (int y = 0; y < H; y++)
            {
                StringBuilder sb = new StringBuilder();
                for (int x = 0; x < W; x++) { char ch = g.c[y, x]; sb.Append(ch); if (ch != '.') used[ch.ToString()] = true; }
                rows.Add(sb.ToString());
            }
            foreach (string k in new List<string>(pal.Keys)) if (!used.ContainsKey(k)) pal.Remove(k);
            Dictionary<string, object> dd = new Dictionary<string, object>();
            dd["name"] = name; dd["rows"] = new ArrayList(rows); dd["palette"] = pal; dd["outline"] = ToHex(line);
            dd["eyes"] = "short"; dd["eye_color"] = lum < 90 ? "#F4E3B0" : "#2E2A2C"; dd["smile"] = "false"; dd["cheek_pos"] = "under"; dd["eye_in"] = "1";
            if (noFeet) dd["legs"] = "none";
            if (bas == "octopus") dd["hands"] = "none";
            return dd;
        }
    }

}
