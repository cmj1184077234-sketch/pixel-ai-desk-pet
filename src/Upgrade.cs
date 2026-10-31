
namespace PixelDeskPet
{
    // ---------- 看看别的 AI 在聊什么 + 自己给自己升级 ----------
    public partial class PetForm
    {
        // 和 desk-pet.ps1 里的顺序一致
        static readonly string[] SRC_FILES = { "Pet.cs", "Features.cs", "Agent.cs", "Brain.cs", "Sound.cs", "Skin.cs", "Upgrade.cs" };

        // ===== 读 AI 窗口里的文字 =====
        string ReadAiWindow(string want, int maxChars)
        {
            List<KeyValuePair<string, AutomationElement>> wins;
            try { wins = AiWindows(); } catch (Exception ex) { return "找 AI 窗口时出错：" + ex.Message; }
            if (wins.Count == 0) return "现在桌面上没有打开的 AI 窗口（支持 Claude、ChatGPT、DeepSeek、Kimi、豆包、WorkBuddy 等应用，以及浏览器里的 AI 网页）。";
            KeyValuePair<string, AutomationElement> pick = wins[0];
            bool found = false;
            if (want != "")
                foreach (KeyValuePair<string, AutomationElement> kv in wins)
                    if (kv.Key.IndexOf(want, StringComparison.OrdinalIgnoreCase) >= 0 || want.IndexOf(kv.Key, StringComparison.OrdinalIgnoreCase) >= 0) { pick = kv; found = true; break; }
            if (!found)
            {
                // 没指定就挑正在忙的，或者最近在用的那个
                foreach (KeyValuePair<string, AutomationElement> kv in wins) if (busyApp.Contains(kv.Key)) { pick = kv; found = true; break; }
                if (!found && lastBusyApp != "") foreach (KeyValuePair<string, AutomationElement> kv in wins) if (kv.Key == lastBusyApp) { pick = kv; break; }
            }
            StringBuilder sb = new StringBuilder();
            string last = "";
            int nodes = 0;
            DateTime until = DateTime.Now.AddSeconds(5);
            try
            {
                TreeWalker tw = TreeWalker.ControlViewWalker;
                Stack<AutomationElement> st = new Stack<AutomationElement>();
                st.Push(pick.Value);
                // 深度优先、从上到下收集文字
                List<AutomationElement> order = new List<AutomationElement>();
                Walk(tw, pick.Value, order, 0, ref nodes, until);
                foreach (AutomationElement e in order)
                {
                    string t = "";
                    try
                    {
                        ControlType ct = e.Current.ControlType;
                        if (ct == ControlType.Button || ct == ControlType.MenuItem || ct == ControlType.TabItem || ct == ControlType.Image || ct == ControlType.ScrollBar) continue;
                        t = e.Current.Name ?? "";
                        if (ct == ControlType.Edit)
                        {
                            object vp;
                            if (e.TryGetCurrentPattern(ValuePattern.Pattern, out vp)) t = ((ValuePattern)vp).Current.Value ?? t;
                        }
                    }
                    catch { continue; }
                    t = t.Trim();
                    if (t.Length < 2 || t == last || last.Contains(t)) continue;
                    sb.AppendLine(t);
                    last = t;
                }
            }
            catch (Exception ex) { if (sb.Length == 0) return "读不到这个窗口的文字：" + ex.Message; }
            string all = sb.ToString().Trim();
            if (all == "") return "「" + pick.Key + "」窗口里读不到文字（有的应用不对外提供文字）。可以让 " + Names.Nick + " 截个图发给你。";
            // 最新的对话一般在最下面，太长就保留后面的部分
            if (all.Length > maxChars) all = "……（前面省略）\n" + all.Substring(all.Length - maxChars);
            ChatNote("（" + Names.Pet + " 看了看「" + pick.Key + "」窗口）");
            return "「" + pick.Key + "」窗口（" + Safe(pick.Value) + "）里能看到的文字：\n" + all;
        }

        static string Safe(AutomationElement e) { try { return e.Current.Name; } catch { return ""; } }

        static void Walk(TreeWalker tw, AutomationElement e, List<AutomationElement> outList, int depth, ref int nodes, DateTime until)
        {
            if (depth > 40 || nodes > 6000 || DateTime.Now > until) return;
            AutomationElement c = null;
            try { c = tw.GetFirstChild(e); } catch { }
            while (c != null)
            {
                nodes++;
                outList.Add(c);
                Walk(tw, c, outList, depth + 1, ref nodes, until);
                if (nodes > 6000 || DateTime.Now > until) return;
                try { c = tw.GetNextSibling(c); } catch { c = null; }
            }
        }

        // ===== 自我升级 =====
        string SrcDir() { return Path.Combine(dir, "src"); }
        bool CanUpgrade() { return Directory.Exists(SrcDir()) && File.Exists(Path.Combine(SrcDir(), "Pet.cs")); }
        bool upgradePending;

        string ReadMyCode(string file, string query, int start, int count)
        {
            if (!CanUpgrade()) return "这个版本的代码不在 src 文件夹里，没法自我升级。";
            if (file == "" && query == "")
            {
                StringBuilder s = new StringBuilder("我的代码文件（C# 5 + WinForms，由启动脚本现场编译）：\n");
                foreach (string f in SRC_FILES)
                {
                    string p = Path.Combine(SrcDir(), f);
                    if (File.Exists(p)) s.AppendLine(f + "：" + File.ReadAllLines(p).Length + " 行");
                }
                s.AppendLine("Pet.cs=窗口/动作/绘制/AI 工作识别；Features.cs=提醒/番茄钟/聊天窗/字体；Agent.cs=AI 接口/工具/造型/性格；Brain.cs=离线聊天；Sound.cs=音效/摇铃；Skin.cs=整体形象；Upgrade.cs=读 AI 窗口/自我升级。");
                s.AppendLine("用 query 搜关键词，或者 file + start + count 看某一段。");
                return s.ToString();
            }
            List<string> files = new List<string>();
            if (file != "") files.Add(Path.GetFileName(file)); else files.AddRange(SRC_FILES);
            StringBuilder sb = new StringBuilder();
            foreach (string f in files)
            {
                string p = Path.Combine(SrcDir(), f);
                if (!File.Exists(p)) { sb.AppendLine("没有文件 " + f); continue; }
                string[] lines = File.ReadAllLines(p, Encoding.UTF8);
                if (query == "")
                {
                    int a = Math.Max(1, start), b = Math.Min(lines.Length, a + Math.Max(1, Math.Min(200, count <= 0 ? 120 : count)) - 1);
                    sb.AppendLine("== " + f + " 第 " + a + "–" + b + " 行（共 " + lines.Length + " 行）");
                    for (int i = a; i <= b; i++) sb.AppendLine(i + ": " + lines[i - 1]);
                }
                else
                {
                    int hits = 0;
                    for (int i = 0; i < lines.Length && hits < 40; i++)
                    {
                        if (lines[i].IndexOf(query, StringComparison.OrdinalIgnoreCase) < 0) continue;
                        hits++;
                        sb.AppendLine("== " + f + " 第 " + (i + 1) + " 行附近");
                        for (int j = Math.Max(0, i - 3); j <= Math.Min(lines.Length - 1, i + 3); j++) sb.AppendLine((j + 1) + ": " + lines[j]);
                    }
                }
            }
            string r = sb.ToString();
            if (r.Trim() == "") return "没搜到“" + query + "”。";
            return r.Length > 14000 ? r.Substring(0, 14000) + "\n……（太长了，缩小范围再看）" : r;
        }

        string EditMyCode(string file, string find, string replace, string why, out bool isErr)
        {
            isErr = true;
            if (!CanUpgrade()) return "这个版本的代码不在 src 文件夹里，没法自我升级。";
            file = Path.GetFileName(file);
            if (Array.IndexOf(SRC_FILES, file) < 0) return "只能改这些文件：" + string.Join("、", SRC_FILES);
            if (find == "") return "find 不能是空的";
            // 安全底线：确认窗口相关的代码不能自己改
            foreach (string guard in new string[] { "ConfirmCommandWindow", "ConfirmCodeWindow", "ShowCodeConfirm", "RunPowerShell(" })
                if (find.Contains(guard) || replace.Contains(guard)) return "涉及运行命令或改代码前的确认窗口，这部分不能自己改。";
            string path = Path.Combine(SrcDir(), file);
            string text = File.ReadAllText(path, Encoding.UTF8);
            string tn = text.Replace("\r\n", "\n"), fn = find.Replace("\r\n", "\n"), rn = replace.Replace("\r\n", "\n");
            int at = tn.IndexOf(fn, StringComparison.Ordinal);
            if (at < 0) return "在 " + file + " 里找不到要替换的原文（要和代码一字不差，包括空格缩进）。先用 read_my_code 看准再改。";
            if (tn.IndexOf(fn, at + 1, StringComparison.Ordinal) >= 0) return "原文在 " + file + " 里出现了不止一次，多带几行上下文让它唯一。";
            string newText = tn.Substring(0, at) + rn + tn.Substring(at + fn.Length);
            // 先给 m 看
            bool ok = false;
            Invoke((MethodInvoker)delegate { ok = new ConfirmCodeWindow(file, why, find, replace).ShowDialog(this) == DialogResult.OK; });
            if (!ok) { ChatNote("（" + Names.Nick + " 没有同意这次改动）"); return Names.Nick + " 没有同意这次改动。问问 TA 想怎么改。"; }
            // 编译检查：所有文件拼起来，换上新内容，编译通过才写入
            Dictionary<string, string> all = new Dictionary<string, string>();
            foreach (string f in SRC_FILES)
            {
                string p = Path.Combine(SrcDir(), f);
                all[f] = f == file ? newText : (File.Exists(p) ? File.ReadAllText(p, Encoding.UTF8) : "");
            }
            ChatNote("（正在检查改完的代码能不能编译…）");
            string errs = CompileCheck(all);
            if (errs != "") return "编译没通过，没有保存，原来的代码没动：\n" + errs + "\n照着报错改一改再试。";
            try
            {
                string bdir = Path.Combine(dir, "src_backups", upgradeStamp);
                Directory.CreateDirectory(bdir);
                string bpath = Path.Combine(bdir, file);
                if (!File.Exists(bpath)) File.Copy(path, bpath);   // 这一轮升级里第一次改这个文件时才备份
                File.WriteAllText(path, newText.Replace("\n", "\r\n"), new UTF8Encoding(false));
            }
            catch (Exception ex) { return "保存失败：" + ex.Message; }
            upgradePending = true;
            isErr = false;
            LogEvent("自我升级：改了 " + file + "（" + why + "）");
            ChatNote("（" + Names.Pet + " 改好了 " + file + "，编译通过）");
            return "改好了，编译通过，旧版本已备份。改动要重启后才生效：所有要改的都改完后，调用 restart_self。";
        }

        string upgradeStamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");

        static string CompileCheck(Dictionary<string, string> files)
        {
            try
            {
                StringBuilder code = new StringBuilder();
                List<string> names = new List<string>(); List<int> starts = new List<int>();
                int lineNo = 1;
                foreach (string f in SRC_FILES)
                {
                    string c; if (!files.TryGetValue(f, out c)) continue;
                    c = c.Replace("\r\n", "\n");
                    names.Add(f); starts.Add(lineNo);
                    code.Append(c).Append("\n");
                    lineNo += c.Split('\n').Length;
                }
                Microsoft.CSharp.CSharpCodeProvider prov = new Microsoft.CSharp.CSharpCodeProvider(new Dictionary<string, string> { { "CompilerVersion", "v4.0" } });
                System.CodeDom.Compiler.CompilerParameters cp = new System.CodeDom.Compiler.CompilerParameters();
                cp.GenerateInMemory = false; cp.GenerateExecutable = false; cp.TreatWarningsAsErrors = false;
                cp.OutputAssembly = Path.Combine(Path.GetTempPath(), "pet_check_" + Guid.NewGuid().ToString("N") + ".dll");
                Type[] refTypes = { typeof(object), typeof(Uri), typeof(System.Linq.Enumerable), typeof(Form), typeof(Bitmap), typeof(AutomationElement),
                    typeof(ControlType), typeof(System.Windows.Rect), typeof(JavaScriptSerializer), typeof(System.Speech.Synthesis.SpeechSynthesizer) };
                foreach (Type t in refTypes) { string loc = t.Assembly.Location; if (loc != "" && !cp.ReferencedAssemblies.Contains(loc)) cp.ReferencedAssemblies.Add(loc); }
                System.CodeDom.Compiler.CompilerResults res = prov.CompileAssemblyFromSource(cp, code.ToString());
                try { File.Delete(cp.OutputAssembly); } catch { }
                StringBuilder sb = new StringBuilder();
                int n = 0;
                foreach (System.CodeDom.Compiler.CompilerError e in res.Errors)
                {
                    if (e.IsWarning) continue;
                    if (++n > 8) { sb.AppendLine("……还有更多错误"); break; }
                    string where = "第 " + e.Line + " 行";
                    for (int k = names.Count - 1; k >= 0; k--) if (e.Line >= starts[k]) { where = names[k] + " 第 " + (e.Line - starts[k] + 1) + " 行"; break; }
                    sb.AppendLine(where + "：" + e.ErrorText);
                }
                return sb.ToString().Trim();
            }
            catch (Exception ex) { return "编译检查本身出错了：" + ex.Message; }
        }

        void RestartSelf()
        {
            try
            {
                string script = Program.Script;
                if (script == "" || !File.Exists(script)) { Say("找不到启动脚本，麻烦你手动重启我一下～", 6); return; }
                ProcessStartInfo psi = new ProcessStartInfo("powershell.exe",
                    "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -Command \"Start-Sleep 2; & '" + script.Replace("'", "''") + "'\"");
                psi.WindowStyle = ProcessWindowStyle.Hidden; psi.CreateNoWindow = true; psi.UseShellExecute = false;
                Process.Start(psi);
                LogEvent("自我升级后重启");
                SaveState();
                Application.Exit();
            }
            catch (Exception ex) { Say("重启失败了：" + ex.Message, 6); }
        }

        // 右键菜单：撤销最近一次升级
        void UndoUpgrade()
        {
            try
            {
                string root = Path.Combine(dir, "src_backups");
                if (!Directory.Exists(root)) { Say("还没有升级过，没有可以撤销的～", 4); return; }
                string[] ds = Directory.GetDirectories(root);
                if (ds.Length == 0) { Say("还没有升级过，没有可以撤销的～", 4); return; }
                Array.Sort(ds);
                string last = ds[ds.Length - 1];
                if (MessageBox.Show("把代码恢复到 " + Path.GetFileName(last) + " 这次升级之前的样子，然后重启？", Names.Pet, MessageBoxButtons.OKCancel) != DialogResult.OK) return;
                foreach (string f in Directory.GetFiles(last)) File.Copy(f, Path.Combine(SrcDir(), Path.GetFileName(f)), true);
                Directory.Move(last, last + "_已撤销");
                LogEvent("撤销了自我升级 " + Path.GetFileName(last));
                RestartSelf();
            }
            catch (Exception ex) { Say("撤销失败了：" + ex.Message, 6); }
        }
    }

    // 改自己代码前，给 m 看清楚改什么
    public class ConfirmCodeWindow : Form
    {
        public ConfirmCodeWindow(string file, string why, string find, string replace)
        {
            Text = Names.Pet + " 想给自己升级一下";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false; MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(640, 520);
            TopMost = true;
            BackColor = Color.FromArgb(255, 248, 231);
            Font f = new Font("Microsoft YaHei UI", 10f);
            Label l = new Label(); l.Font = f; l.SetBounds(16, 10, 608, 48);
            l.Text = Names.Pet + " 说：" + (why == "" ? "（没有说明）" : why) + "\n要改的文件：src\\" + file + "（改之前会自动备份，右键可以撤销）";
            Label a = new Label(); a.Text = "原来的代码："; a.Font = f; a.SetBounds(16, 62, 300, 22);
            TextBox ta = Box(find); ta.SetBounds(16, 86, 608, 160);
            Label b = new Label(); b.Text = "改成："; b.Font = f; b.SetBounds(16, 254, 300, 22);
            TextBox tb = Box(replace); tb.SetBounds(16, 278, 608, 180);
            Button no = new Button(); no.Text = "不要"; no.Font = f; no.SetBounds(440, 472, 86, 34); no.DialogResult = DialogResult.Cancel;
            Button yes = new Button(); yes.Text = "同意修改"; yes.Font = f; yes.SetBounds(534, 472, 90, 34); yes.DialogResult = DialogResult.OK;
            Controls.Add(l); Controls.Add(a); Controls.Add(ta); Controls.Add(b); Controls.Add(tb); Controls.Add(no); Controls.Add(yes);
            AcceptButton = no; CancelButton = no;
        }

        static TextBox Box(string s)
        {
            TextBox t = new TextBox();
            t.Multiline = true; t.ReadOnly = true; t.ScrollBars = ScrollBars.Both; t.WordWrap = false;
            t.Font = new Font("Consolas", 9.5f); t.Text = s.Replace("\r\n", "\n").Replace("\n", "\r\n");
            return t;
        }
    }
}
