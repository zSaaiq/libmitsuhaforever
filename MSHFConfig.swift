import UIKit

private extension UIColor {
    class func hbcp_propertyList(value: String?) -> UIColor? {
        if var string = value {
            if string.count == 4 || string.count == 5 {
                let r = String(repeating: string[string.index(string.startIndex, offsetBy: 1)], count: 2)
                let g = String(repeating: string[string.index(string.startIndex, offsetBy: 2)], count: 2)
                let b = String(repeating: string[string.index(string.startIndex, offsetBy: 3)], count: 2)
                let a = string.count == 5 ? String(repeating: string[string.index(string.startIndex, offsetBy: 4)], count: 2) : "FF"
                string = String(format: "%@%@%@%@", r, g, b, a)
            }

            var hex: UInt64 = 0
            let scanner = Scanner(string: string)
            scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
            scanner.scanHexInt64(&hex)
            if string.count == 9 {
                return self.init(
                    red: CGFloat((hex & 0xFF000000) >> 24) / 255,
                    green: CGFloat((hex & 0x00FF0000) >> 16) / 255,
                    blue: CGFloat((hex & 0x0000FF00) >> 8) / 255,
                    alpha: CGFloat((hex & 0x000000FF) >> 0) / 255)
            } else {
                var alpha: Float = 1
                if scanner.scanString(":") != nil {
                alpha = scanner.scanFloat() ?? 1.0
                }


                return self.init(
                    red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                    green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                    blue: CGFloat((hex & 0x0000FF) >> 0) / 255,
                    alpha: CGFloat(alpha))
            }
        }
        return nil
    }
}

private func LCPParseColorString(_ hexString: String?, _ fallback: String) -> UIColor {
    if let result = UIColor.hbcp_propertyList(value:hexString) {
        return result
    }
    else {
        return UIColor.hbcp_propertyList(value:fallback) ?? UIColor.black
    }
}


@objc (MSHFConfig) final public class MSHFConfig: NSObject {

    @objc private var enabled = false
    private var application: String?
    @objc private var style = 0
    @objc private var colorMode = 0
    private var enableAutoUIColor = false
    private var disableBatterySaver = false
    private var enableFFT = false
    private var enableAutoHide = false
    private var gain: Double = 50.0
    private var limiter: Double = 0.0
    private var waveColor: UIColor?
    private var subwaveColor: UIColor?
    private var subSubwaveColor: UIColor?
    private var calculatedColor: UIColor?
    private var numberOfPoints: Int = 0
    private var fps: Int = 24
    @objc private var waveOffset: CGFloat = 0.0
    @objc private var waveOffsetOffset: CGFloat = 0.0
    private var sensitivity: CGFloat = 0.0
    private var dynamicColorAlpha: CGFloat = 0.0
    private var barSpacing: CGFloat = 0.0
    private var barCornerRadius: CGFloat = 0.0
    private var lineThickness: CGFloat = 0.0
    @objc private var ignoreColorFlow = false
    @objc private var view: MSHFView?

    init(dictionary dict: Dictionary<String, Any>) {
        super.init()
        setDictionary(dict)

        // let MSHFPreferencesChanged =  "com.ryannair05.mitsuhaforever/ReloadPrefs"
    }

    @objc public func initializeView(withFrame frame: CGRect) {
        var superview: UIView?
        var index: Int?

        if let view = view {
            superview = view.superview
            index = superview?.subviews.firstIndex(of: view)

            view.stop()
            view.removeFromSuperview()
        }

        switch style {
            case 1:
                view = MSHFBarView(frame: frame)
                (view as! MSHFBarView).barSpacing = barSpacing
                (view as! MSHFBarView).barCornerRadius = barCornerRadius
            case 2:
                view = MSHFLineView(frame: frame)
                (view as! MSHFLineView).lineThickness = lineThickness
            case 3:
                view = MSHFDotView(frame: frame)
                (view as! MSHFDotView).barSpacing = barSpacing
            case 4:
                view = MSHFSiriView(frame: frame)
            default:
                view = MSHFJelloView(frame: frame)
        }

        if let superview = superview {
            if let index = index  {
                superview.insertSubview(view!, at: index)
            }
            else {
                superview.addSubview(view!)
            }
        }

        configureView()
    }

    private func configureView() {
        view!.autoHide = enableAutoHide
        view!.displayLink!.preferredFramesPerSecond = fps
        view!.numberOfPoints = numberOfPoints
        view!.waveOffset = waveOffset + waveOffsetOffset
        view!.gain = gain
        view!.limiter = limiter
        view!.sensitivity = sensitivity
        view!.audioProcessing?.fft = enableFFT
        view!.disableBatterySaver = disableBatterySaver
        view!.siriEnabled = colorMode == 1 || colorMode == 2

        if let waveColor = waveColor {
            if colorMode == 3 {
                view!.updateWave(waveColor, subwaveColor: waveColor)
            } else if let calculatedColor = calculatedColor, let subwaveColor = subwaveColor, let subSubwaveColor = subSubwaveColor, colorMode == 1 {
                view!.updateWave(calculatedColor,
                    subwaveColor: subwaveColor,
                    subSubwaveColor: subSubwaveColor)
            } else if let subwaveColor = subwaveColor, let subSubwaveColor = subSubwaveColor, colorMode == 2 {
                view!.updateWave(waveColor,
                    subwaveColor: subwaveColor,
                    subSubwaveColor: subSubwaveColor)
            }
        }
    }

    private func getAverageColor(from image: UIImage, withAlpha alpha: CGFloat) -> UIColor {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        let ctx = UIGraphicsGetCurrentContext()
        ctx!.interpolationQuality = .medium

        image.draw(in: CGRect(x: 0, y: 0, width: 1, height: 1), blendMode: .copy, alpha: 1)

        let data = Array(UnsafeBufferPointer(start: ctx?.data?.bindMemory(to: UInt8.self, capacity: 4), count: 4)).map{CGFloat($0)}

        let color = UIColor(
            red: data[2] / 255.0,
            green: data[1] / 255.0,
            blue: data[0] / 255.0,
            alpha: alpha)

        UIGraphicsEndImageContext()
        return color
    }

    @objc public func colorizeView(_ image: UIImage?) {
        guard let view = view else {
            return
        }

        if let image = image, colorMode == 1 {
            let color = getAverageColor(from: image, withAlpha: dynamicColorAlpha)
            calculatedColor = color
            let scolor = UIColor(red: 0.0,
                 green: 1.0,
                 blue: 0.0,
                 alpha: dynamicColorAlpha)
            let sscolor = UIColor(red: 0.0,
                 green: 0.0,
                 blue: 1.0,
                 alpha: dynamicColorAlpha)
            view.updateWave(color,
                 subwaveColor: scolor,
                 subSubwaveColor: sscolor)

        }
        else if let image = image, colorMode == 0 {
            let color = getAverageColor(from: image, withAlpha: dynamicColorAlpha)
            calculatedColor = color
            view.updateWave(color, subwaveColor: color)
        }
        else if colorMode == 2{
            let color = waveColor!
            let scolor = UIColor(red: 0.0,
                 green: 1.0,
                 blue: 0.0,
                 alpha: dynamicColorAlpha)
            let sscolor = UIColor(red: 0.0,
                 green: 0.0,
                 blue: 1.0,
                 alpha: dynamicColorAlpha)
            view.updateWave(color,
                 subwaveColor: scolor,
                 subSubwaveColor: sscolor)
        }
    }

    private func setDictionary(_ dict: Dictionary<String, Any>) {
        application = (dict["application"] as! String)
        enabled = dict["enabled"] as? Bool ?? true

        style = dict["style"] as? Int ?? 0
        colorMode = dict["colorMode"] as? Int ?? 0
        enableAutoUIColor = dict["enableAutoUIColor"] as? Bool ?? true
        ignoreColorFlow = dict["ignoreColorFlow"] as? Bool ?? false
        disableBatterySaver = dict["disableBatterySaver"] as? Bool ?? false
        enableFFT = dict["enableFFT"] as? Bool ?? false
        enableAutoHide = dict["enableAutoHide"] as? Bool ?? true

        if let value = dict["waveColor"] as? UIColor {
            waveColor = value
        }
        else if let value = dict["waveColor"] as? String {
            waveColor = LCPParseColorString(value, "#000000:0.5")
        }
        else {
            waveColor = UIColor.black.withAlphaComponent(0.5)
        }

        if let value = dict["subwaveColor"] as? UIColor {
            subwaveColor = value
        }
        else if let value = dict["subwaveColor"] as? String {
            subwaveColor = LCPParseColorString(value, "#000000:0.5")
        }
        else {
            subwaveColor = UIColor.black.withAlphaComponent(0.5)
        }

        if let value = dict["subSubwaveColor"] as? UIColor {
            subwaveColor = value
        }
        else if let value = dict["subSubwaveColor"] as? String {
            subwaveColor = LCPParseColorString(value, "#000000:0.5")
        }
        else {
            subwaveColor = UIColor.black.withAlphaComponent(0.5)
        }

      gain = dict["gain"] as? Double ?? 50
      limiter = dict["limiter"] as? Double ?? 0
      numberOfPoints = dict["numberOfPoints"] as? Int ?? 8
      sensitivity = dict["sensitivity"] as? CGFloat ?? 1
      dynamicColorAlpha = dict["dynamicColorAlpha"] as? CGFloat ?? 0.6

      barSpacing = dict["barSpacing"] as? CGFloat ?? 5
      barCornerRadius = dict["barCornerRadius"] as? CGFloat ?? 0
      lineThickness = dict["lineThickness"] as? CGFloat ?? 5

      waveOffset = dict["waveOffset"] as? CGFloat ?? 0

      fps = dict["fps"] as? Int ?? 24

    }

    private class func parseConfig(forApplication name: String) -> Dictionary<String, Any> {
        var prefs: [String : Any] = [:]
        prefs["application"] = name

        let MSHFPrefsFile = "/var/mobile/Library/Preferences/com.ryannair05.mitsuhaforever.plist"

        if let file = NSDictionary(contentsOfFile: MSHFPrefsFile) {
            for (key, value) in file {
                guard let key = key as? String else {
                    continue
                }

                let removedKey = key.replacingOccurrences(of: "MSHF\(name)", with: "")
                let lowerCaseKey = "\(removedKey.prefix(1).lowercased())\(removedKey.dropFirst(1))"

                prefs[lowerCaseKey] = value
            }
        }

        prefs["subwaveColor"] = prefs["waveColor"]
        prefs["subSubwaveColor"] = prefs["waveColor"]

        return prefs
    }

    @objc private func reload() {
        let oldStyle = style
        setDictionary(MSHFConfig.parseConfig(forApplication: application ?? ""))
        guard let view = view else {
            return
        }
        if style != oldStyle {
            initializeView(withFrame: view.frame)
            view.start()
        } else {
            configureView()
        }
    }

    @objc public class func loadConfig(forApplication name: String) -> MSHFConfig {
        return MSHFConfig(
            dictionary: MSHFConfig.parseConfig(forApplication: name))
    }
}
