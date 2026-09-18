import AVFoundation
import Capacitor
import Foundation
import MobileVLCKit
import UIKit

@objc(VistaStreamHybridPlayerPlugin)
public final class VistaStreamHybridPlayerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "VistaStreamHybridPlayerPlugin"
    public let jsName = "VistaStreamHybridPlayer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "open", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pause", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "seek", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "selectAudioTrack", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "selectSubtitleTrack", returnType: CAPPluginReturnPromise)
    ]

    private weak var playerController: HybridPlayerViewController?

    @objc public func open(_ call: CAPPluginCall) {
        guard let rawURL = call.getString("url"), let url = URL(string: rawURL) else {
            call.reject("A valid playback URL is required.", "invalid_url")
            return
        }

        var headers: [String: String] = [:]
        for (name, value) in call.getObject("headers") ?? [:] {
            if let stringValue = value as? String, !stringValue.isEmpty {
                headers[name] = stringValue
            }
        }

        let requested = PlaybackEngine(rawValue: call.getString("engine") ?? "auto") ?? .auto
        let live = call.getBool("live") ?? false
        let defaultCache = live ? 2500 : 1500
        let options = HybridPlayerOptions(
            url: url,
            title: call.getString("title") ?? "",
            startAt: max(0, call.getDouble("startAt") ?? 0),
            requestedEngine: requested,
            backgroundEnabled: call.getBool("backgroundEnabled") ?? true,
            headers: headers,
            userAgent: call.getString("userAgent"),
            referrer: call.getString("referrer"),
            cookies: call.getString("cookies"),
            networkCachingMs: min(15000, max(250, call.getInt("networkCachingMs") ?? defaultCache)),
            connectionTimeoutSeconds: min(60, max(5, call.getDouble("connectionTimeoutSeconds") ?? 15)),
            live: live
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = self.bridge?.viewController else {
                call.reject("VistaStream could not present the native player.")
                return
            }
            self.playerController?.finish()
            let controller = HybridPlayerViewController(options: options)
            controller.modalPresentationStyle = .fullScreen
            controller.onEvent = { [weak self] name, payload in self?.notifyListeners(name, data: payload) }
            controller.onExit = { [weak self] payload in
                self?.notifyListeners("exit", data: payload)
                self?.playerController = nil
            }
            self.playerController = controller
            presenter.present(controller, animated: true) {
                call.resolve(["engine": controller.activeEngine.rawValue])
            }
        }
    }

    @objc public func play(_ call: CAPPluginCall) { perform(call) { $0.play() } }
    @objc public func pause(_ call: CAPPluginCall) { perform(call) { $0.pause() } }
    @objc public func stop(_ call: CAPPluginCall) { perform(call) { $0.finish() } }

    @objc public func seek(_ call: CAPPluginCall) {
        guard let seconds = call.getDouble("seconds"), seconds.isFinite, seconds >= 0 else {
            call.reject("seconds must be a non-negative number.")
            return
        }
        perform(call) { $0.seek(seconds: seconds) }
    }

    @objc public func getState(_ call: CAPPluginCall) {
        guard let controller = playerController else {
            call.resolve(["state": "idle", "seconds": 0, "duration": 0])
            return
        }
        call.resolve(controller.snapshot)
    }

    @objc public func selectAudioTrack(_ call: CAPPluginCall) {
        guard let id = call.getInt("id") else { call.reject("id is required."); return }
        perform(call) { $0.selectAudioTrack(id: id) }
    }

    @objc public func selectSubtitleTrack(_ call: CAPPluginCall) {
        guard let id = call.getInt("id") else { call.reject("id is required."); return }
        perform(call) { $0.selectSubtitleTrack(id: id) }
    }

    private func perform(_ call: CAPPluginCall, action: @escaping (HybridPlayerViewController) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let controller = self?.playerController else {
                call.reject("No native player is open.")
                return
            }
            action(controller)
            call.resolve()
        }
    }
}

enum PlaybackEngine: String {
    case auto
    case avplayer
    case vlc
}

struct HybridPlayerOptions {
    let url: URL
    let title: String
    let startAt: Double
    let requestedEngine: PlaybackEngine
    let backgroundEnabled: Bool
    let headers: [String: String]
    let userAgent: String?
    let referrer: String?
    let cookies: String?
    let networkCachingMs: Int
    let connectionTimeoutSeconds: Double
    let live: Bool

    func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    var requestHeaders: [String: String] {
        var result = headers
        func contains(_ name: String) -> Bool {
            result.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
        if let userAgent, !userAgent.isEmpty, !contains("User-Agent") { result["User-Agent"] = userAgent }
        if let referrer, !referrer.isEmpty, !contains("Referer") { result["Referer"] = referrer }
        if let cookies, !cookies.isEmpty, !contains("Cookie") { result["Cookie"] = cookies }
        return result
    }
}
