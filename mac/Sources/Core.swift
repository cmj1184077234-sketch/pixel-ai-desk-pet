import AppKit
import Foundation

// ---------- 通用小工具：尽量和 Windows 版的写法保持一致，方便两边对照 ----------

/// 和 C# 的 Math 一样的写法
enum Math {
    static let PI = Double.pi
    static func Min(_ a: Double, _ b: Double) -> Double { Swift.min(a, b) }
    static func Max(_ a: Double, _ b: Double) -> Double { Swift.max(a, b) }
    static func Min(_ a: Int, _ b: Int) -> Int { Swift.min(a, b) }
    static func Max(_ a: Int, _ b: Int) -> Int { Swift.max(a, b) }
    static func Abs(_ a: Double) -> Double { Swift.abs(a) }
    static func Abs(_ a: Int) -> Int { Swift.abs(a) }
    static func Sin(_ a: Double) -> Double { Foundation.sin(a) }
    static func Cos(_ a: Double) -> Double { Foundation.cos(a) }
    static func Asin(_ a: Double) -> Double { Foundation.asin(a) }
    static func Exp(_ a: Double) -> Double { Foundation.exp(a) }
    static func Sqrt(_ a: Double) -> Double { Foundation.sqrt(a) }
    static func Round(_ a: Double) -> Double { (a).rounded(.toNearestOrEven) }
    static func Floor(_ a: Double) -> Double { Foundation.floor(a) }
    static func Ceiling(_ a: Double) -> Double { Foundation.ceil(a) }
    static func Sign(_ a: Double) -> Int { a > 0 ? 1 : a < 0 ? -1 : 0 }
}

/// 小数取余（C# 的 % 对小数也能用）
func % (a: Double, b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }

/// C# 的 (int)x：向零取整
@inline(__always) func I(_ x: Double) -> Int {
    if x.isNaN || x.isInfinite { return 0 }
    if x > Double(Int.max / 2) { return Int.max / 2 }
    if x < Double(Int.min / 2) { return Int.min / 2 }
    return Int(x)
}
@inline(__always) func D(_ x: Int) -> Double { Double(x) }

/// 画笔：一种颜色（用对象身份区分，和 Windows 版的 Brush 一样能放进集合里比较）
final class Brush: Hashable {
    let color: CGColor
    let ns: NSColor
    init(_ c: NSColor) { ns = c.usingColorSpace(.sRGB) ?? c; color = ns.cgColor }
    static func == (a: Brush, b: Brush) -> Bool { a === b }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    var r: Int { Int(round(ns.redComponent * 255)) }
    var g: Int { Int(round(ns.greenComponent * 255)) }
    var b: Int { Int(round(ns.blueComponent * 255)) }
}

/// "#RRGGBB" → 颜色，看不懂返回 nil
func HexColor(_ s: String) -> NSColor? {
    var h = s.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    let named: [String: String] = ["white": "FFFFFF", "black": "000000", "red": "FF0000", "green": "008000", "blue": "0000FF",
                                   "yellow": "FFFF00", "orange": "FFA500", "pink": "FFC0CB", "gray": "808080", "grey": "808080",
                                   "purple": "800080", "brown": "A52A2A"]
    if let n = named[h.lowercased()] { h = n }
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}
func RGB(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(max(0, min(255, r))) / 255, green: CGFloat(max(0, min(255, g))) / 255, blue: CGFloat(max(0, min(255, b))) / 255, alpha: 1)
}
func B(_ hex: String) -> Brush { Brush(HexColor(hex) ?? .magenta) }
func BrushOf(_ hex: String) -> Brush? { HexColor(hex).map { Brush($0) } }
func ToHex(_ c: NSColor) -> String {
    let s = c.usingColorSpace(.sRGB) ?? c
    return String(format: "#%02X%02X%02X", Int(round(s.redComponent * 255)), Int(round(s.greenComponent * 255)), Int(round(s.blueComponent * 255)))
}

/// 随机数（和 C# 的 Random 用法一样）
final class Rnd {
    func NextDouble() -> Double { Double.random(in: 0..<1) }
    func Next(_ n: Int) -> Int { n <= 0 ? 0 : Int.random(in: 0..<n) }
    func Next(_ a: Int, _ b: Int) -> Int { b <= a ? a : Int.random(in: a..<b) }
}

// ---------- 字符串：按“第几个字”取，和 C# 一样 ----------
extension String {
    var L: Int { count }
    func Sub(_ start: Int, _ len: Int? = nil) -> String {
        let a = Array(self)
        let s = Swift.max(0, Swift.min(start, a.count))
        let e = len == nil ? a.count : Swift.max(s, Swift.min(a.count, s + len!))
        return String(a[s..<e])
    }
    func At(_ i: Int) -> Character { let a = Array(self); return i >= 0 && i < a.count ? a[i] : " " }
    func IndexOf(_ s: String) -> Int {
        guard let r = range(of: s) else { return -1 }
        return distance(from: startIndex, to: r.lowerBound)
    }
    func IndexOf(_ c: Character) -> Int { if let i = firstIndex(of: c) { return distance(from: startIndex, to: i) }; return -1 }
    func LastIndexOf(_ s: String) -> Int {
        guard let r = range(of: s, options: .backwards) else { return -1 }
        return distance(from: startIndex, to: r.lowerBound)
    }
    var Trim: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    func Contains(_ s: String) -> Bool { s.isEmpty ? true : contains(s) }
    func Replace(_ a: String, _ b: String) -> String { a.isEmpty ? self : replacingOccurrences(of: a, with: b) }
    var Lower: String { lowercased() }
    func PadRight(_ n: Int, _ c: Character) -> String { count >= n ? self : self + String(repeating: c, count: n - count) }
    func Split(_ c: Character) -> [String] { split(separator: c, omittingEmptySubsequences: false).map(String.init) }
}
func Repeat(_ c: Character, _ n: Int) -> String { String(repeating: c, count: Swift.max(0, n)) }

// ---------- 文件 ----------
enum FileX {
    static let fm = FileManager.default
    static func Exists(_ p: String) -> Bool { var d: ObjCBool = false; return fm.fileExists(atPath: p, isDirectory: &d) && !d.boolValue }
    static func DirExists(_ p: String) -> Bool { var d: ObjCBool = false; return fm.fileExists(atPath: p, isDirectory: &d) && d.boolValue }
    static func Read(_ p: String) -> String? {
        guard let d = fm.contents(atPath: p) else { return nil }
        var s = String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        return s
    }
    static func Lines(_ p: String) -> [String] {
        guard let s = Read(p) else { return [] }
        var ls = s.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if ls.last == "" { ls.removeLast() }
        return ls
    }
    @discardableResult static func Write(_ p: String, _ s: String) -> Bool {
        do { try s.write(toFile: p, atomically: true, encoding: .utf8); return true } catch { return false }
    }
    static func WriteLines(_ p: String, _ ls: [String]) { Write(p, ls.map { $0 + "\n" }.joined()) }
    static func Append(_ p: String, _ s: String) {
        if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(s.data(using: .utf8)!); h.closeFile() } else { Write(p, s) }
    }
    static func Delete(_ p: String) { try? fm.removeItem(atPath: p) }
    static func MkDir(_ p: String) { try? fm.createDirectory(atPath: p, withIntermediateDirectories: true) }
    static func Files(_ dir: String, _ ext: String) -> [String] {
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        return items.filter { $0.lowercased().hasSuffix(ext) }.sorted().map { (dir as NSString).appendingPathComponent($0) }
    }
    static func Copy(_ a: String, _ b: String) { try? fm.copyItem(atPath: a, toPath: b) }
}
func PathJoin(_ a: String, _ b: String) -> String { (a as NSString).appendingPathComponent(b) }

// ---------- JSON（和 Windows 版的 JavaScriptSerializer 一样，用字典和数组） ----------
typealias Dict = [String: Any]
enum Json {
    static func Parse(_ s: String) -> Any? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
    }
    static func ParseDict(_ s: String) -> Dict? { Parse(s) as? Dict }
    static func Serialize(_ o: Any) -> String {
        guard JSONSerialization.isValidJSONObject(o), let d = try? JSONSerialization.data(withJSONObject: o, options: []) else { return "{}" }
        return String(data: d, encoding: .utf8) ?? "{}"
    }
}
/// 从字典里取一个字符串（数字、布尔也转成字符串）
func Str(_ d: Dict?, _ k: String) -> String {
    guard let d = d, let v = d[k] else { return "" }
    if v is NSNull { return "" }
    if let s = v as? String { return s }
    if let n = v as? NSNumber {
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
        return n.stringValue
    }
    return "\(v)"
}
func Items(_ o: Any?) -> [Any] { o as? [Any] ?? [] }

// ---------- 时间 ----------
func Fmt(_ d: Date, _ f: String) -> String {
    let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = f
    return df.string(from: d)
}
func ParseDate(_ s: String) -> Date? {
    for f in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/M/d", "yyyy/M/d H:mm:ss"] {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = f
        if let d = df.date(from: s.Trim) { return d }
    }
    return nil
}
var Cal: Calendar { Calendar.current }
func Today() -> Date { Cal.startOfDay(for: Date()) }
func Hour(_ d: Date = Date()) -> Int { Cal.component(.hour, from: d) }
func Minute(_ d: Date = Date()) -> Int { Cal.component(.minute, from: d) }
func Month(_ d: Date = Date()) -> Int { Cal.component(.month, from: d) }
func DayOf(_ d: Date = Date()) -> Int { Cal.component(.day, from: d) }
func AddDays(_ d: Date, _ n: Int) -> Date { Cal.date(byAdding: .day, value: n, to: d)! }
func AddMin(_ d: Date, _ n: Double) -> Date { d.addingTimeInterval(n * 60) }
func DaysBetween(_ a: Date, _ b: Date) -> Int { Cal.dateComponents([.day], from: Cal.startOfDay(for: a), to: Cal.startOfDay(for: b)).day ?? 0 }

// ---------- 正则 ----------
func RxMatch(_ s: String, _ p: String) -> [String]? {
    guard let re = try? NSRegularExpression(pattern: p, options: []) else { return nil }
    let ns = s as NSString
    guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
    var g: [String] = []
    for i in 0..<m.numberOfRanges { let r = m.range(at: i); g.append(r.location == NSNotFound ? "" : ns.substring(with: r)) }
    return g
}
func RxIsMatch(_ s: String, _ p: String) -> Bool { RxMatch(s, p) != nil }
func RxReplace(_ s: String, _ p: String, _ t: String, multiline: Bool = false) -> String {
    guard let re = try? NSRegularExpression(pattern: p, options: multiline ? [.anchorsMatchLines] : []) else { return s }
    return re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: t)
}
func RxSplit(_ s: String, _ p: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: p, options: []) else { return [s] }
    let ns = s as NSString
    var out: [String] = []; var last = 0
    for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        out.append(ns.substring(with: NSRange(location: last, length: m.range.location - last))); last = m.range.location + m.range.length
    }
    out.append(ns.substring(from: last))
    return out
}
func RxAll(_ s: String, _ p: String, options: NSRegularExpression.Options = []) -> [[String]] {
    guard let re = try? NSRegularExpression(pattern: p, options: options) else { return [] }
    let ns = s as NSString
    return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
        (0..<m.numberOfRanges).map { i in let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r) }
    }
}

// ---------- 屏幕坐标：全部用“左上角为原点、往下为正”的坐标（和 Windows 一样），只在摆窗口时换算 ----------
struct RectI { var Left, Top, Right, Bottom: Double
    var Width: Double { Right - Left }; var Height: Double { Bottom - Top }
    func Contains(_ x: Double, _ y: Double) -> Bool { x >= Left && x < Right && y >= Top && y < Bottom }
}
enum Scr {
    static var primaryH: Double { Double(NSScreen.screens.first?.frame.height ?? 900) }
    static func flip(_ r: NSRect) -> RectI { RectI(Left: Double(r.minX), Top: primaryH - Double(r.maxY), Right: Double(r.maxX), Bottom: primaryH - Double(r.minY)) }
    static func toMac(_ x: Double, _ yTop: Double, _ h: Double) -> NSPoint { NSPoint(x: x, y: primaryH - yTop - h) }
    static var Cursor: (X: Double, Y: Double) { let p = NSEvent.mouseLocation; return (Double(p.x), primaryH - Double(p.y)) }
    static var All: [NSScreen] { NSScreen.screens }
    static func Bounds(_ s: NSScreen) -> RectI { flip(s.frame) }
    static func WorkingArea(_ s: NSScreen) -> RectI { flip(s.visibleFrame) }
    static var Primary: NSScreen { NSScreen.screens.first ?? NSScreen.main! }
    static func FromPoint(_ x: Double, _ y: Double) -> NSScreen {
        for s in All { if Bounds(s).Contains(x, y) { return s } }
        return Primary
    }
}

// ---------- 用户有多久没动键盘鼠标 ----------
enum Idle {
    static let anyInput = CGEventType(rawValue: ~0)!
    static func Seconds() -> Double { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput) }
    static func KeySeconds() -> Double { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) }
    static func LeftDown() -> Bool { CGEventSource.buttonState(.combinedSessionState, button: .left) }
    static func EscDown() -> Bool { CGEventSource.keyState(.combinedSessionState, key: 0x35) }
}

// ---------- 在主线程上执行（和 Windows 版的 Invoke / BeginInvoke 一样） ----------
func OnMain(_ f: @escaping () -> Void) { if Thread.isMainThread { f() } else { DispatchQueue.main.async(execute: f) } }
func OnMainSync<T>(_ f: () -> T) -> T { if Thread.isMainThread { return f() }; return DispatchQueue.main.sync(execute: f) }
func Background(_ f: @escaping () -> Void) { Thread.detachNewThread(f) }
func Later(_ sec: Double, _ f: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + sec, execute: f) }

/// 菜单项：用闭包处理点击
final class MenuAction: NSObject {
    let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func run(_ s: Any?) { f() }
}
var menuActions: [MenuAction] = []
extension NSMenu {
    @discardableResult
    func Add(_ title: String, checked: Bool = false, enabled: Bool = true, _ f: (() -> Void)? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let f = f { let a = MenuAction(f); menuActions.append(a); it.target = a; it.action = #selector(MenuAction.run(_:)) }
        it.state = checked ? .on : .off
        it.isEnabled = enabled && f != nil
        addItem(it)
        return it
    }
    func Sub(_ title: String) -> NSMenu {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let m = NSMenu(title: title); m.autoenablesItems = false
        it.submenu = m; addItem(it); return m
    }
    func Sep() { addItem(.separator()) }
}

/// 打开文件或网址
func OpenPath(_ p: String) { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
func OpenUrl(_ u: String) { if let url = URL(string: u) { NSWorkspace.shared.open(url) } }

/// 简单的弹窗
func Alert(_ title: String, _ text: String) {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
}
