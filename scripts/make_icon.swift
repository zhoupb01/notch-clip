// 纯 CoreGraphics 绘制 NotchClip 应用图标（零第三方依赖）。
// 用法：swift make_icon.swift <输出PNG路径> [尺寸=1024]
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let px = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1024 : 1024

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("无法创建 CGContext")
}

// 以 1024 为设计基准，统一缩放到目标像素
let S = CGFloat(px) / 1024.0
ctx.scaleBy(x: S, y: S)
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

let W: CGFloat = 1024

// —— 圆角矩形主体（macOS Big Sur 图标网格：824 见方，居中，连续圆角）——
let margin: CGFloat = 100
let side = W - margin * 2                 // 824
let shape = CGRect(x: margin, y: margin, width: side, height: side)
let radius = side * 0.2237                // ≈184
let bg = CGPath(roundedRect: shape, cornerWidth: radius, cornerHeight: radius, transform: nil)

// 投影
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 34, color: rgb(0, 0, 0, 0.28))
ctx.addPath(bg); ctx.setFillColor(rgb(20, 20, 30)); ctx.fillPath()
ctx.restoreGState()

// 渐变底：紫 → 蓝（左上到右下）
ctx.saveGState()
ctx.addPath(bg); ctx.clip()
let grad = CGGradient(colorsSpace: cs,
                      colors: [rgb(139, 92, 246), rgb(56, 130, 246)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: shape.minX, y: shape.maxY),
                       end: CGPoint(x: shape.maxX, y: shape.minY), options: [])
// 顶部一层柔光，增加质感
let gloss = CGGradient(colorsSpace: cs,
                       colors: [rgb(255, 255, 255, 0.18), rgb(255, 255, 255, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(gloss,
                       start: CGPoint(x: shape.midX, y: shape.maxY),
                       end: CGPoint(x: shape.midX, y: shape.midY), options: [])
ctx.restoreGState()

// —— 顶部刘海（品牌记忆点）：黑色 pill，挂在主体顶边，只圆下方两角 ——
let nW = side * 0.40
let nH = side * 0.145
let nx0 = shape.midX - nW / 2
let nx1 = shape.midX + nW / 2
let top = shape.maxY                       // 与主体顶边齐平
let botY = top - nH
let r = nH * 0.48
let notch = CGMutablePath()
notch.move(to: CGPoint(x: nx0, y: top))
notch.addLine(to: CGPoint(x: nx1, y: top))
notch.addLine(to: CGPoint(x: nx1, y: botY + r))
notch.addArc(center: CGPoint(x: nx1 - r, y: botY + r), radius: r, startAngle: 0, endAngle: -.pi/2, clockwise: true)
notch.addLine(to: CGPoint(x: nx0 + r, y: botY))
notch.addArc(center: CGPoint(x: nx0 + r, y: botY + r), radius: r, startAngle: -.pi/2, endAngle: -.pi, clockwise: true)
notch.closeSubpath()
// 裁进主体圆角内，避免溢出
ctx.saveGState()
ctx.addPath(bg); ctx.clip()
ctx.addPath(notch); ctx.setFillColor(rgb(12, 12, 16)); ctx.fillPath()
// 摄像头小点
let camR = nH * 0.11
ctx.setFillColor(rgb(40, 42, 55))
ctx.fillEllipse(in: CGRect(x: shape.midX - camR, y: botY + nH*0.34 - camR, width: camR*2, height: camR*2))
ctx.setFillColor(rgb(70, 130, 246, 0.9))
let dotR = camR * 0.42
ctx.fillEllipse(in: CGRect(x: shape.midX - dotR, y: botY + nH*0.34 - dotR, width: dotR*2, height: dotR*2))
ctx.restoreGState()

// —— 中部：剪贴板卡片堆（复制历史）——
func roundedCard(center c: CGPoint, w: CGFloat, h: CGFloat, corner: CGFloat, rotate deg: CGFloat) -> CGPath {
    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: deg * .pi / 180)
    return CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: &t)
}

let cW = side * 0.46
let cH = side * 0.52
let cCenter = CGPoint(x: shape.midX, y: shape.midY - side * 0.055)
let cCorner = cW * 0.13

// 后卡（露出一角，暗示"多条历史"）
let back = roundedCard(center: CGPoint(x: cCenter.x + 46, y: cCenter.y + 54), w: cW, h: cH, corner: cCorner, rotate: 7)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(0, 0, 0, 0.22))
ctx.addPath(back); ctx.setFillColor(rgb(255, 255, 255, 0.5)); ctx.fillPath()
ctx.restoreGState()

// 前卡
let front = roundedCard(center: cCenter, w: cW, h: cH, corner: cCorner, rotate: 0)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: rgb(0, 0, 0, 0.28))
ctx.addPath(front); ctx.setFillColor(rgb(255, 255, 255)); ctx.fillPath()
ctx.restoreGState()

// 前卡上的文本行（首行高亮 = 刚复制的内容）
let padX = cW * 0.17
let lineX = cCenter.x - cW/2 + padX
let lineH = cH * 0.075
let usableW = cW - padX * 2
let widths: [CGFloat] = [1.0, 0.82, 0.66, 0.9, 0.5]
let colors: [CGColor] = [rgb(124, 92, 246), rgb(203, 208, 222), rgb(203, 208, 222), rgb(203, 208, 222), rgb(203, 208, 222)]
let firstY = cCenter.y + cH * 0.30
let gap = cH * 0.135
for i in 0..<widths.count {
    let y = firstY - CGFloat(i) * gap
    let w = usableW * widths[i]
    let barCorner = lineH * 0.5
    let bar = CGPath(roundedRect: CGRect(x: lineX, y: y - lineH/2, width: w, height: lineH),
                     cornerWidth: barCorner, cornerHeight: barCorner, transform: nil)
    ctx.addPath(bar); ctx.setFillColor(colors[i]); ctx.fillPath()
}

// —— 输出 PNG ——
guard let img = ctx.makeImage() else { fatalError("makeImage 失败") }
let rep = NSBitmapImageRep(cgImage: img)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG 编码失败") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("✓ 写出 \(outPath) (\(px)px)")
