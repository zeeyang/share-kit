import Foundation
import SwiftyJSON

protocol OperationalTransformDocument {
    func pause()
    func resume()
    func put(_ data: JSON?, version: UInt) throws
    func sync(_ data: OperationData, version: UInt) throws
    func ack(version: UInt, sequence: UInt) throws
    func rollback(_ data: OperationData?, version: UInt) throws
}

extension ShareDocument: OperationalTransformDocument {
    // Shift inflightOps into queuedOps for re-send
    func pause() {
        state = .paused
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
    func put(_ data: JSON?, version: UInt) throws {
        if let json = data {
            try update(json: json)
            state = .ready
        } else {
            state = .deleted
        }
        try update(version: version, validateSequence: false)
        resume()
    }

    // Sync with remote ops from server
    func sync(_ data: OperationData, version: UInt) throws {
        switch data {
        case .create(_, let document):
            try put(document, version: version)
        case .update(let ops):
            try apply(operations: ops)
        case .delete:
            state = .deleted
        }
    }

    // Verify server ack for inflight message
    func ack(version: UInt, sequence: UInt) throws {
        guard inflightOperation != nil else {
            throw ShareDocumentError.operationAck
        }
        try update(version: version + 1, validateSequence: true)
        inflightOperation = nil
        resume()
    }

    // Rejected message from server
    func rollback(_ data: OperationData?, version: UInt) throws {
        guard let data = data else { return }
//        self.version = min(version, self.version)
        print("rollback \(data)")
//      ops.forEach(apply)
    }
}
