import Combine
import Foundation
import GroupActivities
import Observation
import RealityKit
import SwiftData
import SwiftUI

public enum SaveDataMessage: Codable, Sendable {
  case update(file: String)
  case welcomeParticipant(welcomeMessage: String)
}

public enum MessengerKind: String, Codable, Sendable {
  /// A bit slower but relyable. Use this for messages that need to be synced at all costs. Like a sound on collision or at the end of a drag movement.
  case reliable
  /// Low Latency but unrelyable. Might skip a message here and there. Use for fast movements.
  case lowLatency
}

public typealias OnReceiveSaveDataMessage = (_ message: SaveDataMessage, _ messenger: MessengerKind) -> Void

public struct SharePlayManagerHandlers {
  let onReceiveSaveDataMessage: OnReceiveSaveDataMessage
}

/// This is the code required for SharePlay.
/// It handles `startSharePlaySession` and handles incoming messages.
public final class SharePlayManager {
  private let handlers: SharePlayManagerHandlers

  public init(handlers: SharePlayManagerHandlers) {
    self.handlers = handlers
  }

  private var subscriptions = Set<AnyCancellable>()
  private var tasks = Set<Task<Void, Never>>()
  public var groupSession: GroupSession<SharePlayActivity>?
  private var messenger: [MessengerKind: GroupSessionMessenger] = [:]

  /// Tears down the existing groupSession.
  @MainActor public func resetConnection(saveId: UUID, file: String) {
    print("[resetConnection] saveId:", saveId, ", file: ", file)
    self.messenger = [:]
    self.tasks.forEach { $0.cancel() }
    self.tasks = []
    self.subscriptions = []
    if self.groupSession != nil {
      self.groupSession?.leave()
      self.groupSession = nil
      self.startSharePlaySession(saveId: saveId, file: file)
    }
  }

  /// Sends a SaveDataMessage
  func sendSaveDataMessage(_ message: SaveDataMessage, to: Participants? = nil) {
    Task {
      if let to {
        try? await self.messenger[.reliable]?.send(message, to: to)
      } else {
        try? await self.messenger[.reliable]?.send(message)
      }
    }
  }

  /// Starts SharePlay via the SharePlayActivity
  @MainActor public func startSharePlaySession(saveId: UUID, file: String) {
    print("[startSharePlaySession] saveId:", saveId, "file: ", file)
    guard let data = WindowManager.register.sharePlaySharedData[saveId] else {
      print("❗️ Shared data not found")
      return
    }

    // Set an initial welcome message if it doesn't exist yet
    if data.welcomeMessage == "" {
      data.welcomeMessage = "Welcome to the Group Activity!"
    }

    Task {
      do {
        print("[startSharePlaySession] activate() saveId →", saveId)
        _ = try await SharePlayActivity(saveId: saveId, file: file).activate()
        print("[startSharePlaySession] activated! saveId →", saveId)
      } catch {
        print("❗️Failed to activate SharePlayActivity activity: \(error)")
      }
    }
  }

  /// Opens the stream that will listen for changes once a SharePlay session has started
  public func joinSharePlaySession(_ groupSession: GroupSession<SharePlayActivity>) {
    let saveId = groupSession.activity.saveId
    let file = groupSession.activity.file

    print("[joinSharePlaySession] prepping to join SharePlay (saveId: \(saveId.uuidString), file: \(file))")

    self.groupSession = groupSession

    let messengerLowLatency = GroupSessionMessenger(session: groupSession, deliveryMode: .unreliable)
    let messengerReliable = GroupSessionMessenger(session: groupSession)
    self.messenger = [
      MessengerKind.lowLatency: messengerReliable,
      MessengerKind.reliable: messengerLowLatency,
    ]

    groupSession.$state
      .sink { @MainActor state in
        if case .invalidated = state {
          self.groupSession = nil
          self.resetConnection(saveId: saveId, file: file)
        }
      }
      .store(in: &self.subscriptions)

    groupSession.$activeParticipants
      .sink { activeParticipants in
        let newParticipants = activeParticipants.subtracting(groupSession.activeParticipants)
        Task { @MainActor in
          // Warning here is the same warning as Apple's example code in `DrawingContentInAGroupSession`
          let data = WindowManager.register.sharePlaySharedData[saveId]!
          let message = SaveDataMessage.welcomeParticipant(welcomeMessage: data.welcomeMessage)
          print("[SharePlayManager] sending welcomeParticipant to new participants found:", newParticipants)
          self.sendSaveDataMessage(message, to: .only(newParticipants))
        }
      }
      .store(in: &self.subscriptions)

    self.tasks.insert(Task {
      // Warning here is the same warning as Apple's example code in `DrawingContentInAGroupSession`
      for await (message, _) in messengerLowLatency.messages(of: SaveDataMessage.self) {
        self.handlers.onReceiveSaveDataMessage(message, .lowLatency)
      }
    })
    self.tasks.insert(Task {
      // Warning here is the same warning as Apple's example code in `DrawingContentInAGroupSession`
      for await (message, _) in messengerReliable.messages(of: SaveDataMessage.self) {
        self.handlers.onReceiveSaveDataMessage(message, .reliable)
      }
    })

    print("[joinSharePlaySession] joining...")
    groupSession.join()
  }
}
