#!/usr/bin/env swift
import AppKit
import Foundation

// ============================================================
// 1. 画图标并输出各尺寸 PNG
// ============================================================
func drawIconC(size px: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: px, height: px), flipped: false) { rect in
        // 蓝色渐变背景
        let colors = [NSColor(red: 0.15, green: 0.45, blue: 0.98, alpha: 1.0),
                      NSColor(red: 0.25, green: 0.20, blue: 0.95, alpha: 1.0)]
        let gradient = NSGradient(colors: colors)
        let rpath = NSBezierPath(roundedRect: rect, xRadius: CGFloat(px) * 0.22, yRadius: CGFloat(px) * 0.22)
        gradient?.draw(in: rpath, angle: 135)

        // 白色粗体 C
        let fontSize = CGFloat(px) * 0.68
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
        let C = "C"
        C.draw(in: rect.insetBy(dx: CGFloat(px) * 0.06, dy: CGFloat(px) * 0.10), withAttributes: attrs)
        return true
    }
    return img
}

func savePNG(_ img: NSImage, to url: URL) -> Bool {
    guard let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try png.write(to: url)
        return true
    } catch {
        return false
    }
}

// iconutil 要求 Imageset 格式目录结构
let tmpBase = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudeSwitchIconset")
let imageset = tmpBase.appendingPathComponent("ClaudeSwitch.iconset")
try? FileManager.default.removeItem(at: tmpBase)
try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)

// 需要的尺寸 (iconutil 命名规则)
let requiredSizes: [(String, Int)] = [
    ("icon_16x16.png",              16),
    ("icon_16x16@2x.png",           32),
    ("icon_32x32.png",              32),
    ("icon_32x32@2x.png",           64),
    ("icon_128x128.png",            128),
    ("icon_128x128@2x.png",         256),
    ("icon_256x256.png",            256),
    ("icon_256x256@2x.png",         512),
    ("icon_512x512.png",            512),
    ("icon_512x512@2x.png",         1024),
]

for (filename, px) in requiredSizes {
    let img = drawIconC(size: px)
    let url = imageset.appendingPathComponent(filename)
    if !savePNG(img, to: url) {
        print("❌ 失败: \(filename)")
        exit(1)
    }
}

print("✅ PNG 生成完成: \(imageset.path)")

// ============================================================
// 2. 调用 iconutil 生成 .icns
// ============================================================
let icnsPath = tmpBase.appendingPathComponent("ClaudeSwitch.icns")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", icnsPath.path, imageset.path]
iconutil.currentDirectoryURL = tmpBase

do {
    try iconutil.run()
    iconutil.waitUntilExit()
} catch {
    print("❌ iconutil 运行失败: \(error)")
    exit(1)
}

guard FileManager.default.fileExists(atPath: icnsPath.path) else {
    print("❌ iconutil 未生成 icns 文件")
    exit(1)
}

print("✅ icns 生成成功: \(icnsPath.path)")

// ============================================================
// 3. 写入 App bundle
// ============================================================
let appPath = "/Users/zhangxuehua/Projects/ClaudeSwitch/ClaudeSwitch.app"
let resourcesDir = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources")
try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let destIcn = resourcesDir.appendingPathComponent("ClaudeSwitch.icns")
try? FileManager.default.removeItem(at: destIcn)
try FileManager.default.copyItem(at: icnsPath, to: destIcn)

// 确认 Info.plist 有 CFBundleIconFile
let infoPath = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist")
var plist = (try? String(contentsOf: infoPath, encoding: .utf8)) ?? ""
if !plist.contains("CFBundleIconFile") {
    if let range = plist.range(of: "</dict>") {
        plist.insert(contentsOf: "\n\t<key>CFBundleIconFile</key>\n\t<string>ClaudeSwitch.icns</string>\n", at: range.lowerBound)
        try? plist.write(to: infoPath, atomically: true, encoding: .utf8)
    }
}

// touch app bundle 强制 Finder 刷新
try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: appPath)

print("✅ 图标已写入 App bundle")
let sz = try! FileManager.default.attributesOfItem(atPath: destIcn.path)[.size] as! Int
print("icns 大小: \(sz / 1024) KB")
