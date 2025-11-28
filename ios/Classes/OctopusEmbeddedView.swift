import Foundation
import Flutter
import SwiftUI
import Octopus
import OctopusUI
import Combine

// Custom view that wraps OctopusHomeScreen and handles navigation events
struct OctopusHomeScreenWithCallback: View {
  let octopus: OctopusSDK
  let navBarLeadingItem: OctopusHomeScreen.NavBarLeadingItemKind
  let navBarPrimaryColor: Bool
  let onNavigateToLogin: () -> Void
  let inset: CGFloat = 10

  var body: some View {
    OctopusHomeScreen(
      octopus: octopus,
      bottomSafeAreaInset: inset,
      navBarLeadingItem: navBarLeadingItem,
      navBarPrimaryColor: navBarPrimaryColor
    )
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OctopusNavigateToLogin"))) { _ in
      onNavigateToLogin()
    }
  }
}

final class OctopusViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return OctopusPlatformView(frame: frame, viewId: viewId, args: args)
  }
}

final class OctopusPlatformView: NSObject, FlutterPlatformView {
  private let container: SafeHostingContainerView

  init(frame: CGRect, viewId: Int64, args: Any?) {
    self.container = SafeHostingContainerView(args: args)
    self.container.frame = frame
    super.init()
  }

  func view() -> UIView { container }
}

private final class SafeHostingContainerView: UIView {

  private var hostingController: UIHostingController<AnyView>?
  private let args: Any?

  init(args: Any?) {
    self.args = args
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }

    // Avoid double initialization
    guard hostingController == nil else { return }

    initializeSwiftUIView()
  }

  private func initializeSwiftUIView() {
    guard let octopus = OctopusSdkFlutterPlugin.sharedOctopus else {
      addErrorLabel()
      return
    }

    var theme: OctopusTheme? = nil
    var navBarTitle: String? = nil
    var navBarPrimaryColor = false
    var themeMode: String? = nil

    if let dict = args as? [String: Any] {
      let main = (dict["primaryMain"] as? NSNumber).map { OctopusSdkFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let low = (dict["primaryLowContrast"] as? NSNumber).map { OctopusSdkFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let high = (dict["primaryHighContrast"] as? NSNumber).map { OctopusSdkFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let onPrimary = (dict["onPrimary"] as? NSNumber).map { OctopusSdkFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let logoBase64 = dict["logoBase64"] as? String
      navBarTitle = dict["navBarTitle"] as? String
      navBarPrimaryColor = (dict["navBarPrimaryColor"] as? Bool) ?? false

      // Font sizes
      let fontSizeTitle1 = (dict["fontSizeTitle1"] as? NSNumber)?.intValue ?? 26
      let fontSizeTitle2 = (dict["fontSizeTitle2"] as? NSNumber)?.intValue ?? 20
      let fontSizeBody1 = (dict["fontSizeBody1"] as? NSNumber)?.intValue ?? 17
      let fontSizeBody2 = (dict["fontSizeBody2"] as? NSNumber)?.intValue ?? 14
      let fontSizeCaption1 = (dict["fontSizeCaption1"] as? NSNumber)?.intValue ?? 12
      let fontSizeCaption2 = (dict["fontSizeCaption2"] as? NSNumber)?.intValue ?? 10
      themeMode = dict["themeMode"] as? String
      print("iOS: themeMode received: \(themeMode ?? "nil")")

      if main != nil || low != nil || high != nil || onPrimary != nil || logoBase64 != nil ||
         fontSizeTitle1 != 26 || fontSizeTitle2 != 20 || fontSizeBody1 != 17 ||
         fontSizeBody2 != 14 || fontSizeCaption1 != 12 || fontSizeCaption2 != 10 ||
         themeMode != nil {
        theme = OctopusSdkFlutterPlugin.buildTheme(
          main: main ?? .systemBlue,
          low: low ?? UIColor.systemBlue.withAlphaComponent(0.2),
          high: high ?? .white,
          onPrimary: onPrimary ?? .white,
          logoBase64: logoBase64,
          fontSizeTitle1: fontSizeTitle1,
          fontSizeTitle2: fontSizeTitle2,
          fontSizeBody1: fontSizeBody1,
          fontSizeBody2: fontSizeBody2,
          fontSizeCaption1: fontSizeCaption1,
          fontSizeCaption2: fontSizeCaption2,
          themeMode: themeMode
        )
      }
    }

    // Prepare leading item based on navBarTitle
    let leadingItem: OctopusHomeScreen.NavBarLeadingItemKind = {
      if let title = navBarTitle {
        return .text(.init(text: title))
      }
      return .logo
    }()

    let root: AnyView
    if let theme {
      root = AnyView(OctopusHomeScreenWithCallback(
        octopus: octopus,
        navBarLeadingItem: leadingItem,
        navBarPrimaryColor: navBarPrimaryColor,
        onNavigateToLogin: triggerOnNavigateToLoginCallback
      ).environment(\.octopusTheme, theme)
      .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    } else {
      root = AnyView(OctopusHomeScreenWithCallback(
        octopus: octopus,
        navBarLeadingItem: leadingItem,
        navBarPrimaryColor: navBarPrimaryColor,
        onNavigateToLogin: triggerOnNavigateToLoginCallback
      ).preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    }
    let controller = UIHostingController(rootView: root)
    let parentViewController = self.findViewController()
    parentViewController?.addChild(controller)
    controller.view.backgroundColor = .clear

    // Force the interface style based on themeMode
    if let themeMode = themeMode {
      switch themeMode {
      case "light": window?.overrideUserInterfaceStyle = .light
      case "dark":  window?.overrideUserInterfaceStyle = .dark
      default:      window?.overrideUserInterfaceStyle = .unspecified
      }
    }

    addSubview(controller.view)
    controller.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        controller.view.topAnchor.constraint(equalTo: topAnchor),
        controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
        controller.view.trailingAnchor.constraint(equalTo: trailingAnchor)
      ])

    controller.didMove(toParent: parentViewController)

    hostingController = controller
  }

  private func addErrorLabel() {
    let label = UILabel(frame: bounds)
    label.text = "SDK not initialized.\nCall initializeOctopusSDK() first."
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .systemGray
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(label)
  }

  private func triggerOnNavigateToLoginCallback() {
    print("iOS: triggerOnNavigateToLoginCallback called")
    OctopusEventEmitter.shared?.emitNavigateToLogin()
  }
}

// Helper extension to find the parent UIViewController
extension UIView {
  func findViewController() -> UIViewController? {
    if let nextResponder = self.next as? UIViewController {
      return nextResponder
    } else if let nextResponder = self.next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
}
