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
    func put(_ document: DocumentData) throws {
        if let json = document.data {
            guard let rawData = try? json.rawData(),
                  let data = try? JSONDecoder().decode(Entity.self, from: rawData) else {
                throw OperationalTransformError.invalidJSONData
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
    func sync(_ data: OperationData, version: UInt) throws {
        guard self.version == version else {
            throw OperationalTransformError.invalidVersion
        }
        switch data {
        case .create(_, let document):
            try put(document)
        case .update(let ops):
            try apply(operations: ops)
        case .delete:
            state = .deleted
        }
        self.version = version + 1
    }

    // Verify server ack for inflight message
    func ack(version: UInt, sequence: UInt) throws {
        self.version = version + 1
        guard inflightOperation != nil else {
            throw OperationalTransformError.invalidAck
        }
        inflightOperation = nil
        resume()
    }

    // Rejected message from server
    func rollback(_ data: OperationData?, version: UInt) throws {
        guard let data = data else { return }
        self.version = min(version, self.version)
        print("rollback \(data)")
//      ops.forEach(apply)
    }
}
