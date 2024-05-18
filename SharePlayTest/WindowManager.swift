import AppIntents
import Foundation
import GroupActivities
import RealityKit
import SwiftData
import SwiftUI

@MainActor @Observable public final class SharePlaySharedData {
  public var welcomeMessage: String
  public var file: String
  public let saveId: UUID

  public init(saveId: UUID, file: String, welcomeMessage: String) {
    self.saveId = saveId
    self.file = file
    self.welcomeMessage = welcomeMessage
  }
}

@MainActor @Observable public final class WindowRegister {
  public var activeSaveId: UUID?
  public var openWindows: [ViewId: Bool] = [.MainWindow: true]
  public var sharePlayManagers: [UUID: SharePlayManager] = [:]
  public var sharePlaySharedData: [UUID: SharePlaySharedData] = [:]
}

@MainActor public enum WindowManager {
  public static let register = WindowRegister()

  private static var openWindow: OpenWindowAction!
  private static var openImmersiveSpace: OpenImmersiveSpaceAction!
  private static var dismissWindow: DismissWindowAction!
  private static var dismissImmersiveSpace: DismissImmersiveSpaceAction!

  public static func onFoundSession(_ session: GroupSession<SharePlayActivity>) throws {
    let saveId = session.activity.saveId
    let file = session.activity.file
    print("[onFoundSession] saveId: \(saveId.uuidString) file: \(file)")

    prepareSharePlay(saveId: saveId, file: file, session: session)

    register.openWindows[ViewId.Volume] = true
    register.activeSaveId = saveId
    openWindow(id: ViewId.Volume.rawValue)
  }

  /// Prepares the SharePlayManager and SharePlaySharedData
  public static func prepareSharePlay(saveId: UUID, file: String, session: GroupSession<SharePlayActivity>?) {
    // only prepare a new SharePlayManager if it doesn't exist yet
    if let existingSharePlayManager = register.sharePlayManagers[saveId] {
      if let session { existingSharePlayManager.groupSession = session }
      return
    }
    // prep the local state
    var sharedData = SharePlaySharedData(saveId: saveId, file: file, welcomeMessage: "")
    var handlers = SharePlayManagerHandlers(onReceiveSaveDataMessage: { message, _ in
      switch message {
      case .update(let file):
        sharedData.file = file
        return
      case .welcomeParticipant(let welcomeMessage):
        sharedData.welcomeMessage = welcomeMessage
        return
      }
    })
    let sharePlayManager = SharePlayManager(handlers: handlers)
    if let session { sharePlayManager.groupSession = session }

    // Set the local state
    register.sharePlaySharedData[saveId] = sharedData
    register.sharePlayManagers[saveId] = sharePlayManager
  }

  public static func toggleView(_ id: ViewId, saveId: UUID, file: String) async {
    prepareSharePlay(saveId: saveId, file: file, session: nil)
    if register.openWindows[id] ?? false {
      // closing...
      if id == .ImmersiveSpace {
        await dismissImmersiveSpace()
      } else {
        dismissWindow(id: id.rawValue)
      }
      register.openWindows[id] = false
    } else {
      // opening...
      register.openWindows[id] = true
      register.activeSaveId = saveId
      if id == .ImmersiveSpace {
        switch await openImmersiveSpace(id: id.rawValue) {
        case .opened:
          break
        case .error, .userCancelled:
          fallthrough
        @unknown default:
          register.openWindows[id] = false
          print("❗️ failed to open Immersive Space")
        }
      } else {
        openWindow(id: id.rawValue)
      }
    }
  }

  public static func startSharePlaySessionListener(
    openWindow: OpenWindowAction,
    openImmersiveSpace: OpenImmersiveSpaceAction,
    dismissWindow: DismissWindowAction,
    dismissImmersiveSpace: DismissImmersiveSpaceAction
  ) {
    self.openWindow = openWindow
    self.openImmersiveSpace = openImmersiveSpace
    self.dismissWindow = dismissWindow
    self.dismissImmersiveSpace = dismissImmersiveSpace

    Task { @MainActor in
      // Start SharePlay sessions
      for await session in SharePlayActivity.sessions() {
        guard let systemCoordinator = await session.systemCoordinator else { continue }
        var configuration = SystemCoordinator.Configuration()
        // For a Volume `.none` will default to "surround", meaning, the Volume is located in the middle and surrounded by all participants.
        configuration.spatialTemplatePreference = .none
        configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration = configuration

        do {
          try onFoundSession(session)
        } catch {
          print("❗️[SharePlayActivity.sessions()] error", error)
        }
      }
    }
  }
}
