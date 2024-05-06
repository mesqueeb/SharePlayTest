import SwiftUI

public enum ViewId: String {
  case Volume, ImmersiveSpace, MainWindow
}

@main
struct MainApp: App {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  @MainActor init() {
    WindowManager.startApp(
      openWindow: openWindow,
      openImmersiveSpace: openImmersiveSpace,
      dismissWindow: dismissWindow,
      dismissImmersiveSpace: dismissImmersiveSpace
    )
    print("UIApplication.shared.connectedScenes →", UIApplication.shared.connectedScenes)
  }

  var body: some Scene {
    WindowGroup(id: ViewId.Volume.rawValue) {
      ZStack {
        if let activeSaveId = WindowManager.register.activeSaveId {
          VolumeView(saveId: activeSaveId).id(activeSaveId)
        } else {
          Text("No open save")
        }
      }
      .handlesExternalEvents(preferring: [CONTENT_ID_VOLUME], allowing: [CONTENT_ID_VOLUME])
      .onDisappear { WindowManager.register.openWindows[ViewId.Volume] = false }
    }
    .handlesExternalEvents(matching: [CONTENT_ID_VOLUME])
    .windowStyle(.volumetric)

    WindowGroup(id: ViewId.MainWindow.rawValue) {
      MainWindowView()
        .task {
          print("UIApplication.shared.connectedScenes →", UIApplication.shared.connectedScenes)
        }
        .onDisappear { WindowManager.register.openWindows[ViewId.MainWindow] = false }
    }

    ImmersiveSpace(id: ViewId.ImmersiveSpace.rawValue) {
      ImmersiveView()
        .onDisappear { WindowManager.register.openWindows[ViewId.ImmersiveSpace] = false }
    }.immersionStyle(selection: .constant(.progressive), in: .progressive)
  }
}
