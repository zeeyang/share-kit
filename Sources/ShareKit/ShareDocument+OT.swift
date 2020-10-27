import Foundation
import SwiftyJSON

extension ShareDocument: OperationalTransformDocument {
    // Shift inflightOps into queuedOps for re-send
    func pause() {
        if let inflight = inflightOperation {
            queuedOperations.append(inflight)
            inflightOperation = nil
        }
    }

    // Drain ops queue after reconnect
    func resume() {
        guard let group = queuedOperations.popLast() else {
            return
        }
        send(group)
    }

    // Replace document data
    func put(_ document: DocumentData) {
        if let json = document.data {
            guard let rawData = try? json.rawData(),
                  let data = try? JSONDecoder().decode(Entity.self, from: rawData) else {
                return
            }
            self.json = json
            self.data = data
            state = .ready
        } else {
            state = .deleted
        }
        version = document.version
        resume()
    }

    // Sync with remote ops from server
    func sync(_ data: OperationData?, version: UInt) {
        guard self.version == version else {
            print("Drop version \(version) for current v\(self.version)")
            return
        }
        switch data {
        case .create(_, let document)?:
            put(document)
        case .update(let ops)?:
            try? apply(operations: ops)
        case .delete?:
            state = .deleted
        case nil:
            print("No data for sync \(version)")
        }
        self.version = version + 1
    }

    // Verify server ack for inflight message
    func ack(version: UInt, sequence: UInt) {
        self.version = version + 1
        guard inflightOperation != nil else {
            print("Unexpected ACK \(version) \(sequence)")
            return
        }
        inflightOperation = nil
        resume()
    }

    // Rejected message from server
    func rollback(_ data: OperationData?, version: UInt) {
        guard let data = data else { return }
        self.version = min(version, self.version)
        print("rollback \(data)")
//      ops.forEach(apply)
    }
}
