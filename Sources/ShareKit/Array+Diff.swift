extension Array where Element: Equatable {
    enum DiffResult {
        case equal
        case insert(start: Int, items: [Element])
        case delete(start: Int, items: [Element])
        case replace(start: Int, delete: [Element], insert: [Element])
    }

    /// Single pass array diff.
    /// - note: complex deltas are represented as a single .replace. e.g. ["a", "b", "c"]  -> ["a", "x", "b", "y", "c"] = .replace(start: 1, delete: ["b"], insert: ["x", "b", "y"])
    ///
    /// - Parameter target: target array for comparison
    /// - Returns: delta of transforming source to target as DiffResult enum
    func diff(_ target: [Element]) -> DiffResult {
        guard self != target else {
            return .equal
        }

        let sourceCount = self.count
        let targetCount = target.count

        var prefix = 0
        while prefix < sourceCount && prefix < targetCount && self[prefix] == target[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix + prefix < sourceCount && suffix + prefix < targetCount && self[sourceCount - 1 - suffix] == target[targetCount - 1 - suffix] {
            suffix += 1
        }

        let beforeRange = Array(self[prefix..<(sourceCount - suffix)])
        let afterRange = Array(target[prefix..<(targetCount - suffix)])
        switch (beforeRange.isEmpty, afterRange.isEmpty) {
        case (true, false):
            return .insert(start: prefix, items: afterRange)
        case (false, true):
            return .delete(start: prefix, items: beforeRange)
        case (false, false):
            return .replace(start: prefix, delete: beforeRange, insert: afterRange)
        case (true, true):
            return .equal
        }
    }
}
