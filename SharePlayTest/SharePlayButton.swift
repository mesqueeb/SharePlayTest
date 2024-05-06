import GroupActivities
import Observation
import SwiftData
import SwiftUI
import UIKit

public struct SharePlayButton: View {
  let saveId: UUID
  let file: String
  let sharePlayManager: SharePlayManager

  public init(saveId: UUID, file: String, sharePlayManager: SharePlayManager) {
    self.saveId = saveId
    self.file = file
    self.sharePlayManager = sharePlayManager
  }

  @StateObject var groupStateObserver = GroupStateObserver()
  @State private var isSharingControllerPresented: Bool = false

  /// Joins an active SharePlay session when FaceTime is active.
  /// Otherwise show a share sheet to start FaceTime and a SharePlay session.
  private func startSharePlaySession() {
    Task { @MainActor in
      if groupStateObserver.isEligibleForGroupSession {
        await sharePlayManager.startSharePlaySession(saveId: saveId, file: file)
      } else {
        isSharingControllerPresented = true
      }
    }
  }

  public var body: some View {
    Button(action: { startSharePlaySession() }) {
      HStack(spacing: 16) {
        Image(systemName: "person.line.dotted.person.fill")
          .font(.title)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
        Text("Start SharePlay")
          .font(.title)
      }
    }
    .sheet(isPresented: $isSharingControllerPresented) {
      ActivitySharingViewController(saveId: saveId, file: file)
    }
  }
}

struct ActivitySharingViewController: UIViewControllerRepresentable {
  typealias UIViewControllerType = GroupActivitySharingController

  var activity: SharePlayActivity

  init(saveId: UUID, file: String) {
    activity = SharePlayActivity(saveId: saveId, file: file)
  }

  func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivitySharingViewController>) -> GroupActivitySharingController {
    return try! GroupActivitySharingController(activity)
  }

  func updateUIViewController(_: GroupActivitySharingController, context _: UIViewControllerRepresentableContext<ActivitySharingViewController>) {
    // AFAIK we don't need to do anything here.
  }
}
