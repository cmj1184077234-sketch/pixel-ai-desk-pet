
namespace PixelDeskPet
{
    // ---------- 像素风小音效：全部现场合成，没有人声 ----------
    public static class Sfx
    {
        const int RATE = 22050;
        static Dictionary<string, byte[]> cache = new Dictionary<string, byte[]>();
        static Dictionary<string, double> lengths = new Dictionary<string, double>();
        static Random rnd = new Random(7);

        public static double Length(string name) { Get(name); double d; return lengths.TryGetValue(name, out d) ? d : 0; }

        public static byte[] Get(string name)
        {
            lock (cache)
            {
                byte[] b;
                if (cache.TryGetValue(name, out b)) return b;
                float[] s = Build(name);
                if (s == null) return null;
                b = Wav(s);
                cache[name] = b;
                lengths[name] = s.Length / (double)RATE;
                return b;
            }
        }

        static byte[] Wav(float[] s)
        {
            MemoryStream ms = new MemoryStream();
            BinaryWriter w = new BinaryWriter(ms);
            int n = s.Length;
            w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + n * 2); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(RATE); w.Write(RATE * 2); w.Write((short)2); w.Write((short)16);
            w.Write(Encoding.ASCII.GetBytes("data")); w.Write(n * 2);
            for (int i = 0; i < n; i++)
            {
                double v = Math.Max(-1, Math.Min(1, s[i]));
                w.Write((short)(v * 30000));
            }
            return ms.ToArray();
        }

        static float[] Buf(double sec) { return new float[(int)(RATE * sec)]; }

        // 铃铛一样的音色：基音 + 两个不协和泛音，指数衰减
        static void Bell(float[] b, double t0, double f, double amp, double decay)
        {
            int st = (int)(t0 * RATE);
            for (int i = Math.Max(0, st); i < b.Length; i++)
            {
                double t = (i - st) / (double)RATE;
                double e = Math.Exp(-t * decay) * amp;
                if (t < .002) e *= t / .002;
                if (e < .0005 && t > .05) break;
                b[i] += (float)(e * (Math.Sin(2 * Math.PI * f * t)
                    + .45 * Math.Sin(2 * Math.PI * f * 2.76 * t) * Math.Exp(-t * decay * 1.6)
                    + .2 * Math.Sin(2 * Math.PI * f * 5.4 * t) * Math.Exp(-t * decay * 2.8)));
            }
        }

        // 滑音：从 f0 滑到 f1，wave = sine / square / tri
        static void Tone(float[] b, double t0, double dur, double f0, double f1, double amp, string wave, double vib)
        {
            int st = (int)(t0 * RATE), n = (int)(dur * RATE);
            double ph = 0;
            for (int i = 0; i < n && st + i < b.Length; i++)
            {
                double t = i / (double)RATE, u = i / (double)n;
                double f = f0 + (f1 - f0) * u;
                if (vib > 0) f *= 1 + .04 * Math.Sin(2 * Math.PI * vib * t);
                ph += 2 * Math.PI * f / RATE;
                double v = wave == "square" ? (Math.Sin(ph) >= 0 ? 1 : -1) * .5 :
                           wave == "tri" ? 2 / Math.PI * Math.Asin(Math.Sin(ph)) : Math.Sin(ph);
                double env = Math.Min(1, t / .004) * Math.Min(1, (n - i) / (RATE * .02));
                b[st + i] += (float)(v * amp * env);
            }
        }

        static void Noise(float[] b, double t0, double dur, double amp, double smooth)
        {
            int st = (int)(t0 * RATE), n = (int)(dur * RATE);
            double y = 0;
            for (int i = 0; i < n && st + i < b.Length; i++)
            {
                double x = rnd.NextDouble() * 2 - 1;
                y += smooth * (x - y);
                double env = Math.Exp(-6.0 * i / n);
                b[st + i] += (float)(y * amp * env);
            }
        }

        static float[] Build(string name)
        {
            float[] b;
            switch (name)
            {
                case "ding":        // 叮～
                    b = Buf(1.1); Bell(b, 0, 1318.5, .42, 5.5); Bell(b, .08, 1975.5, .22, 6.5); return b;
                case "bell":        // 叮铃铃：摇铃铛
                    b = Buf(1.5);
                    for (int i = 0; i < 12; i++)
                    {
                        double t = i * .085;
                        Bell(b, t, i % 2 == 0 ? 2093 : 2489, .2, 13);
                        Noise(b, t, .03, .03, .9);
                    }
                    return b;
                case "dingdong":    // 叮——当
                    b = Buf(2.2); Bell(b, 0, 659.25, .4, 3.0); Bell(b, .55, 523.25, .42, 2.4); return b;
                case "step":        // 小脚步：嗒
                case "step2":
                    b = Buf(.045);
                    Tone(b, 0, .022, name == "step" ? 2500 : 2900, name == "step" ? 2100 : 2400, .1, "square", 0);
                    Noise(b, 0, .016, .05, .7);
                    return b;
                case "poke":        // 啾！
                    b = Buf(.12); Tone(b, 0, .1, 700, 1600, .28, "sine", 0); return b;
                case "purr":        // 被摸头：呼噜噜
                    b = Buf(.5);
                    for (int i = 0; i < 4; i++) Tone(b, i * .1, .09, 300 - i * 10, 280 - i * 10, .18, "tri", 0);
                    Tone(b, .38, .1, 880, 1175, .12, "sine", 0);
                    return b;
                case "boing":       // 跳：啵嘤
                    b = Buf(.26); Tone(b, 0, .24, 240, 680, .25, "sine", 14); return b;
                case "thud":        // 摔：噗通
                    b = Buf(.2); Noise(b, 0, .12, .5, .15); Tone(b, 0, .12, 150, 60, .45, "sine", 0); return b;
                case "crunch":      // 吃橘子：咔嚓咔嚓
                    b = Buf(.3); Noise(b, 0, .06, .35, .6); Noise(b, .12, .06, .3, .6); Tone(b, .2, .06, 1200, 1500, .08, "sine", 0); return b;
                case "happy":       // 开心：哆咪嗦
                    b = Buf(.32); Tone(b, 0, .07, 1046.5, 1046.5, .36, "square", 0); Tone(b, .08, .07, 1318.5, 1318.5, .36, "square", 0); Tone(b, .16, .14, 1568, 1568, .36, "square", 0); return b;
                case "sad":         // 委屈：呜呜
                    b = Buf(.55); Tone(b, 0, .2, 660, 600, .22, "tri", 6); Tone(b, .24, .3, 520, 440, .22, "tri", 6); return b;
                case "buzz":        // 生气：噗噗
                    b = Buf(.3); Tone(b, 0, .08, 160, 150, .3, "square", 0); Tone(b, .14, .1, 150, 130, .3, "square", 0); return b;
                case "wobble":      // 晕：咕噜咕噜
                    b = Buf(.6); Tone(b, 0, .55, 900, 300, .22, "sine", 11); return b;
                case "pop":         // 冒气泡：啵
                    b = Buf(.07); Tone(b, 0, .05, 1500, 900, .22, "sine", 0); return b;
            }
            return null;
        }
    }

    public partial class PetForm
    {
        SoundPlayer curPlayer;
        double bigSoundUntil, lastStepSfx;
        int stepParity;
        bool stepSfx = true;

        void PlaySfx(string name)
        {
            if (muted || quiet) return;
            bool big = name == "ding" || name == "bell" || name == "dingdong";
            if (!big && now < bigSoundUntil) return;   // 铃声响着的时候，小声音先让一让
            try
            {
                byte[] data = Sfx.Get(name);
                if (data == null) return;
                SoundPlayer p = new SoundPlayer(new MemoryStream(data));
                p.Play();
                curPlayer = p;
                if (big) bigSoundUntil = now + Sfx.Length(name);
            }
            catch { }
        }

        void StepSound()
        {
            if (!stepSfx || (state != "walk" && state != "pace")) return;
            if (now - lastStepSfx < .36) return;
            lastStepSfx = now;
            stepParity = 1 - stepParity;
            PlaySfx(stepParity == 0 ? "step" : "step2");
        }

        void StateSound(string s)
        {
            switch (s)
            {
                case "eat": PlaySfx("crunch"); break;
                case "jump": PlaySfx("boing"); break;
                case "angry": PlaySfx("buzz"); break;
                case "dizzy": PlaySfx("wobble"); break;
                case "sad": PlaySfx("sad"); break;
            }
        }

        // ---------- 工作做完：叮 → 摇铃铛 → 叮当 → 对话框，直到 m 摸摸它 ----------
        bool ringing, ringDeferred;
        double ringStart;
        int ringStage;
        string ringApp = "Claude";

        // 只要不是离开电脑（5 分钟没动）或在全屏看视频，就算在：盯着屏幕看 AI 回答时不动鼠标也算
        bool UserPresent() { return !away && !quiet; }

        void LogEvent(string text)
        {
            try
            {
                string f = Path.Combine(dir, Names.Pet + "的事件记录.txt");
                List<string> lines = new List<string>();
                if (File.Exists(f)) lines.AddRange(File.ReadAllLines(f, Encoding.UTF8));
                lines.Add(DateTime.Now.ToString("MM-dd HH:mm:ss") + "  " + text);
                if (lines.Count > 80) lines.RemoveRange(0, lines.Count - 80);
                File.WriteAllLines(f, lines.ToArray(), Encoding.UTF8);
            }
            catch { }
        }

        void StartRing(string app)
        {
            if (ringing)
            {
                if (!ringApp.Contains(app)) ringApp = ringApp + " 和 " + app;
                bubbleText = "叮！" + ringApp + " 的任务做完啦"; bubbleUntil = now + 1e7;
                LogEvent(app + " 也做完了 → 一起摇铃");
                return;
            }
            ringing = true; ringApp = app; ringStage = 0; ringStart = now;
            ringDeferred = !UserPresent();
            if (!ringDeferred) { Set("done"); PlaySfx("ding"); }
            else Set("bell");
            bubbleText = "叮！" + app + " 的任务做完啦"; bubbleUntil = now + 1e7;   // 一直写着是哪个 AI 做完了，直到 m 摸摸它
            LogEvent(app + " 工作结束 → " + (ringDeferred ? (away ? "你好像离开了，先不响，等你回来" : "你在全屏，先不响") : (muted ? "叮（声音是关着的，只有动作）" : "叮！开始摇铃铛")));
        }

        void RingTick()
        {
            if (!ringing) return;

            if (ringDeferred)
            {
                if (!UserPresent()) { if (state != "bell" && Grounded()) Set("bell"); return; }
                ringDeferred = false; ringStage = 0; ringStart = now;
                Set("done"); PlaySfx("ding");
                LogEvent("你回来了 → 叮！开始摇铃铛");
                return;
            }
            double t = now - ringStart;
            if (ringStage == 0 && t >= 1.3) { ringStage = 1; if (Grounded()) Set("bell"); PlaySfx("bell"); }
            else if (ringStage == 1 && t >= 20) { ringStage = 2; PlaySfx("dingdong"); }
            else if (ringStage == 2 && t >= 40)
            {
                ringStage = 3;
                string line = PickFresh(new string[] {
                    NICK + "，" + ringApp + " 做完啦～我铃铛都摇累了，快去看看吧！",
                    NICK + "！" + ringApp + " 那边好了，摸摸我告诉我你看到了～",
                    ringApp + " 早就做完啦，" + NICK + " 快来看看结果！" });
                bubbleText = line; bubbleUntil = now + 1e7;   // 一直显示，直到 m 摸摸它
                PlaySfx("pop");
            }
            if (ringStage >= 1 && state != "bell" && Grounded() && (state == "idle" || state == "land" || state == "party" || state == "happy")) Set("bell");
        }

        // m 看到了（摸摸或点它），铃铛就停下
        bool Acknowledge()
        {
            if (!ringing) return false;
            ringing = false; ringDeferred = false;
            bubbleUntil = 0;
            LogEvent("你摸了摸" + Names.Pet + "，铃铛停下（摇了 " + (int)(now - ringStart) + " 秒）");
            Interact();
            Set("love");
            PlaySfx("purr");
            Say(PickFresh(new string[] { "嘿嘿，你看到啦～", "收到摸摸！就知道你会来～", "好耶，提醒任务完成！", "终于等到你啦～" }), 3);
            return true;
        }
    }
}
