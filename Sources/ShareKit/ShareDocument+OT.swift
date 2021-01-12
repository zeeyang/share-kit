import Foundation

protocol OperationalTransformDocument {
    func pause()
    func resume()
    func put(_ data: AnyCodable?, version: UInt, type: OperationalTransformType?) throws
    func sync(_ data: OperationData, version: UInt) throws
    func ack(version: UInt, sequence: UInt) throws
    func rollback(_ data: OperationData?, version: UInt) throws
}

extension ShareDocument: OperationalTransformDocument {
    // Shift inflightOps into queuedOps for re-send
    func pause() {
        try? trigger(event: .pause)
        if let inflight = inflightOperation {
            queuedOperations.append(inflight)
            inflightOperation = nil
        }
    }

    func resume() {
        try? trigger(event: .resume)
        guard let group = queuedOperations.popLast() else {
            return
        }
        send(group)
    }

    // Replace document data
    func put(_ data: AnyCodable?, version: UInt, type: OperationalTransformType?) throws {
        if let type = type {
            guard let transformer = OperationalTransformTypes[type] else {
                throw ShareDocumentError.operationalTransformType
            }
            documentTransformer = transformer
        }

        if let json = data {
            try trigger(event: .put)
            try update(json: json)
        } else {
            try trigger(event: .delete)
        }

        try update(version: version, validateSequence: false)
        resume()
    }

    // Sync with remote ops from server
    func sync(_ data: OperationData, version: UInt) throws {
        switch data {
        case .create(let type, let document):
            try put(document, version: version, type: type)
        case .update(let ops):
            try update(version: version + 1, validateSequence: true)
            try apply(operations: ops)
        case .delete:
            try trigger(event: .delete)
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
