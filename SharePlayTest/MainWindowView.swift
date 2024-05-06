import RealityKit
import RealityKitContent
import SwiftUI

struct MainWindowView: View {
  @State var saveId: UUID?
  @State var file: String?

  @MainActor init() {
    let activeSaveId: UUID? = WindowManager.register.activeSaveId ?? nil
    _saveId = State(initialValue: activeSaveId)
    _file = State(initialValue: WindowManager.register.sharePlaySharedData[activeSaveId ?? UUID()]?.file ?? nil)
  }

  var body: some View {
    VStack {
      Model3D(named: "Scene", bundle: realityKitContentBundle)
        .padding(.bottom, 50)

      VStack(spacing: 16) {
        Text("SharePlay shared data").font(.title)
        Text("Save ID: \(saveId?.uuidString ?? "-")")
        Text("File: \(file ?? "-")")
      }.padding(16)

      VStack(spacing: 16) {
        if let saveId, let file, let sharePlayManager = WindowManager.register.sharePlayManagers[saveId] {
          SharePlayButton(saveId: saveId, file: file, sharePlayManager: sharePlayManager)
        } else {
          Text("Open volume to start SharePlay!")
        }
      }.padding(32)

      VStack(spacing: 16) {
        Button(WindowManager.register.openWindows[.Volume] ?? false ? "Close Volume" : "Open Volume") {
          let saveId = UUID()
          let file = "Test File \(Int.random(in: 0 ... 100))"
          Task { await WindowManager.toggleView(.Volume, saveId: saveId, file: file) }
        }
        .font(.title)
        .frame(width: 360)

        if let saveId, let file {
          Button(WindowManager.register.openWindows[.ImmersiveSpace] ?? false ? "Close Immersive Space" : "Open Immersive Space") {
            Task { await WindowManager.toggleView(.ImmersiveSpace, saveId: saveId, file: file) }
          }
          .font(.title)
          .frame(width: 360)
        }
      }.padding(16)
    }
    .padding()
    .onChange(of: WindowManager.register.activeSaveId ?? UUID()) { _, _ in
      if let newActiveSaveId = WindowManager.register.activeSaveId {
        saveId = newActiveSaveId
        file = WindowManager.register.sharePlaySharedData[newActiveSaveId]?.file
      }
    }
  }
}

#Preview(windowStyle: .automatic) {
  MainWindowView()
}
