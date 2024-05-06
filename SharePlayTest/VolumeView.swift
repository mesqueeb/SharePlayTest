import RealityKit
import RealityKitContent
import SwiftUI

struct VolumeView: View {
  let saveId: UUID

  init(saveId: UUID) {
    self.saveId = saveId
  }

  @State private var welcomeMessage: String = ""
  @State private var enlarge = false

  @MainActor var sharePlayManager: SharePlayManager? {
    return WindowManager.register.sharePlayManagers[saveId] ?? nil
  }

  @MainActor func onRealityViewReady() {
    guard let sharePlayManager else {
      print("[onRealityViewReady] ❗️ no sharePlayManager found!")
      return
    }
    guard let groupSession = sharePlayManager.groupSession else {
      print("[onRealityViewReady] no groupSession found, SharePlay is not enabled")
      return
    }
    sharePlayManager.joinSharePlaySession(groupSession)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      RealityView { content in
        onRealityViewReady()
        // Add the initial RealityKit content
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
          content.add(scene)
        }
      } update: { content in
        // Update the RealityKit content when SwiftUI state changes
        if let scene = content.entities.first {
          let uniformScale: Float = enlarge ? 1.4 : 1.0
          scene.transform.scale = [uniformScale, uniformScale, uniformScale]
        }
      }
      .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
        enlarge.toggle()
      })
    }
    .toolbar {
      ToolbarItemGroup(placement: .bottomOrnament) {
        VStack {
          Text("SharePlay shared data").font(.title).padding(.bottom, 8)
          Text("Save ID: \(saveId.uuidString)")
          Text("File: \(WindowManager.register.sharePlaySharedData[saveId]?.file ?? "-")")
          TextField("Welcome Message", text: $welcomeMessage).padding().textFieldStyle(RoundedBorderTextFieldStyle())
        }
      }
    }
    .onChange(of: WindowManager.register.sharePlaySharedData[saveId]?.welcomeMessage ?? "...") { _, newMessage in
      welcomeMessage = newMessage
    }
    .onChange(of: welcomeMessage) { _, newMessage in
      if let data = WindowManager.register.sharePlaySharedData[saveId] {
        data.welcomeMessage = newMessage
      }
      sharePlayManager?.sendSaveDataMessage(.welcomeParticipant(welcomeMessage: welcomeMessage))
    }
  }
}

#Preview(windowStyle: .volumetric) {
  VolumeView(saveId: UUID())
}
