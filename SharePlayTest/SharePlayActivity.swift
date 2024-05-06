import GroupActivities
import SwiftUI

public let CONTENT_ID_VOLUME = "shareplay-test-volume"

public func defaultsGroupActivityMetadata() -> GroupActivityMetadata {
  var metadata = GroupActivityMetadata()
  metadata.title = "Let's Play Together"
  metadata.type = .generic
  metadata.sceneAssociationBehavior = .content(CONTENT_ID_VOLUME)
  return metadata
}

public struct SharePlayActivity: GroupActivity, Sendable {
  // App-specific data so your app can launch the activity on others' devices
  let saveId: UUID
  let file: String

  public var metadata: GroupActivityMetadata { return defaultsGroupActivityMetadata() }

  public init(saveId: UUID, file: String) {
    self.saveId = saveId
    self.file = file
  }
}
