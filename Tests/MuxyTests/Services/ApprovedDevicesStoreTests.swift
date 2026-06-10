import Foundation
import Testing

@testable import Muxy

@Suite("ApprovedDevicesStore", .serialized)
@MainActor
struct ApprovedDevicesStoreTests {
    private let store = ApprovedDevicesStore.shared

    private final class RevokedRecorder {
        private(set) var ids: [UUID] = []
        func record(_ id: UUID) { ids.append(id) }
    }

    private func withSeededDevices(
        _ count: Int,
        _ body: ([ApprovedDevice], RevokedRecorder) -> Void
    ) {
        let original = store.devices
        let onRevoke = store.onRevoke
        defer {
            store.replaceDevices(original)
            store.onRevoke = onRevoke
        }

        store.replaceDevices([])
        let ids = (0 ..< count).map { _ in UUID() }
        for (index, id) in ids.enumerated() {
            store.approve(deviceID: id, name: "Device \(index)", token: "token-\(index)")
        }

        let recorder = RevokedRecorder()
        store.onRevoke = { recorder.record($0) }
        body(store.devices, recorder)
    }

    @Test("batch revoke removes only the selected devices")
    func batchRevokeRemovesSelected() {
        withSeededDevices(3) { seeded, _ in
            let toRemove: Set<UUID> = [seeded[0].id, seeded[2].id]
            store.revoke(deviceIDs: toRemove)

            #expect(store.devices.map(\.id) == [seeded[1].id])
        }
    }

    @Test("batch revoke fires onRevoke once per removed device")
    func batchRevokeFiresCallbackPerDevice() {
        withSeededDevices(3) { seeded, recorder in
            let toRemove: Set<UUID> = [seeded[0].id, seeded[1].id]
            store.revoke(deviceIDs: toRemove)

            #expect(Set(recorder.ids) == toRemove)
            #expect(recorder.ids.count == 2)
        }
    }

    @Test("batch revoke with empty set is a no-op")
    func batchRevokeEmptySetNoOp() {
        withSeededDevices(2) { seeded, recorder in
            store.revoke(deviceIDs: [])

            #expect(store.devices.map(\.id) == seeded.map(\.id))
            #expect(recorder.ids.isEmpty)
        }
    }

    @Test("batch revoke ignores unknown ids")
    func batchRevokeUnknownIDsNoOp() {
        withSeededDevices(2) { seeded, recorder in
            store.revoke(deviceIDs: [UUID()])

            #expect(store.devices.map(\.id) == seeded.map(\.id))
            #expect(recorder.ids.isEmpty)
        }
    }

    @Test("single revoke removes exactly one device and fires once")
    func singleRevokeDelegates() {
        withSeededDevices(3) { seeded, recorder in
            store.revoke(deviceID: seeded[1].id)

            #expect(store.devices.map(\.id) == [seeded[0].id, seeded[2].id])
            #expect(recorder.ids == [seeded[1].id])
        }
    }
}
