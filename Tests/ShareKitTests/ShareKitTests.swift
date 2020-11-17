import XCTest
import SwiftyJSON
@testable import ShareKit

final class ShareKitTests: XCTestCase {
    func testJSON0ObjectInsert() throws {
        let original: JSON = ["x": 100, "nested": ["y": 200]]

        let insertSimple: JSON = ["p": ["name"], "oi": "outter"]
        let result1 = try JSON0Transformer.apply([insertSimple], to: original)
        XCTAssertEqual(result1, JSON(["name": "outter", "x": 100, "nested": ["y": 200]]))

        let insertSimpleNonEmpty: JSON = ["p": ["x"], "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertSimpleNonEmpty], to: original))

        let insertNestedInner: JSON = ["p": ["nested", "name"], "oi": "inner"]
        let result2 = try JSON0Transformer.apply([insertNestedInner], to: original)
        XCTAssertEqual(result2, JSON(["x": 100, "nested": ["name": "inner", "y": 200]]))

        let insertNestedNonEmpty: JSON = ["p": ["nested", "y"], "oi": 200]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedNonEmpty], to: original))

        let insertNestedBranch: JSON = ["p": ["newbranch"], "oi": ["name": "inner"]]
        let result3 = try JSON0Transformer.apply([insertNestedBranch], to: original)
        XCTAssertEqual(result3, JSON(["x": 100, "nested": ["y": 200], "newbranch": ["name": "inner"]]))

        let insertNestedBranchNonEmpty: JSON = ["p": ["nested"], "oi": []]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedBranchNonEmpty], to: original))
    }

    func testJSON0ObjectDelete() throws {
        let original: JSON = ["name": "outter", "nested": ["name": "inner"]]

        let deleteSimple: JSON = ["p": ["name"], "od": "outter"]
        let result1 = try JSON0Transformer.apply([deleteSimple], to: original)
        XCTAssertEqual(result1, JSON(["nested": ["name": "inner"]]))

        let deleteSimpleMismatch: JSON = ["p": ["name"], "od": "not-outter"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteSimpleMismatch], to: original))

        let deleteNestedInner: JSON = ["p": ["nested", "name"], "od": "inner"]
        let result2 = try JSON0Transformer.apply([deleteNestedInner], to: original)
        XCTAssertEqual(result2, JSON(["name": "outter", "nested": JSON()]))

        let deleteNestedMismatch: JSON = ["p": ["nested", "name"], "od": "not-inner"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedMismatch], to: original))

        let deleteNestedBranch: JSON = ["p": ["nested"], "od": ["name": "inner"]]
        let result3 = try JSON0Transformer.apply([deleteNestedBranch], to: original)
        XCTAssertEqual(result3, JSON(["name": "outter"]))

        let deleteNestedBranchMismatch: JSON = ["p": ["nested"], "od": ["name": "not-inner"]]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedBranchMismatch], to: original))
    }

    func testJSON0ObjectReplace() throws {
        let original: JSON = ["name": "outter", "nested": ["name": "inner"]]

        let replaceSimple: JSON = ["p": ["name"], "od": "outter", "oi": "new-outter"]
        let result1 = try JSON0Transformer.apply([replaceSimple], to: original)
        XCTAssertEqual(result1, JSON(["name": "new-outter", "nested": ["name": "inner"]]))

        let insertSimpleMismatch: JSON = ["p": ["name"], "od": "non-exist", "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertSimpleMismatch], to: original))

        let replaceInner: JSON = ["p": ["nested", "name"], "od": "inner", "oi": "new-inner"]
        let result2 = try JSON0Transformer.apply([replaceInner], to: original)
        XCTAssertEqual(result2, JSON(["name": "outter", "nested": ["name": "new-inner"]]))

        let insertNestedMismatch: JSON = ["p": ["nested", "name"], "od": "non-exist", "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedMismatch], to: original))

        let replaceBranch: JSON = ["p": ["nested"], "od": ["name": "inner"], "oi": "new-branch"]
        let result3 = try JSON0Transformer.apply([replaceBranch], to: original)
        XCTAssertEqual(result3, JSON(["name": "outter", "nested": "new-branch"]))
    }

    func testTEXT0Insert() throws {
        let original = JSON("ABCD")

        let insertSingle: JSON = ["p": 1, "i": "X"]
        let result1 = try TEXT0Transformer.apply([insertSingle], to: original)
        XCTAssertEqual(result1.stringValue, "AXBCD")

        let insertMultiple: JSON = ["p": 1, "i": "XYZ"]
        let result2 = try TEXT0Transformer.apply([insertMultiple], to: original)
        XCTAssertEqual(result2.stringValue, "AXYZBCD")

        let insertStart: JSON = ["p": 0, "i": "XYZ"]
        let result3 = try TEXT0Transformer.apply([insertStart], to: original)
        XCTAssertEqual(result3.stringValue, "XYZABCD")

        let insertEnd: JSON = ["p": 4, "i": "XYZ"]
        let result4 = try TEXT0Transformer.apply([insertEnd], to: original)
        XCTAssertEqual(result4.stringValue, "ABCDXYZ")

        let insertOverflow: JSON = ["p": 5, "i": "XYZ"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([insertOverflow], to: original))
    }

    func testTEXT0Delete() throws {
        let original = JSON("ABCDE")

        let deleteSingle: JSON = ["p": 1, "d": "B"]
        let result1 = try TEXT0Transformer.apply([deleteSingle], to: original)
        XCTAssertEqual(result1.stringValue, "ACDE")

        let deleteMultiple: JSON = ["p": 1, "d": "BCD"]
        let result2 = try TEXT0Transformer.apply([deleteMultiple], to: original)
        XCTAssertEqual(result2.stringValue, "AE")

        let deleteStart: JSON = ["p": 0, "d": "ABC"]
        let result3 = try TEXT0Transformer.apply([deleteStart], to: original)
        XCTAssertEqual(result3.stringValue, "DE")

        let deleteEnd: JSON = ["p": 2, "d": "CDE"]
        let result4 = try TEXT0Transformer.apply([deleteEnd], to: original)
        XCTAssertEqual(result4.stringValue, "AB")

        let deleteOverflow: JSON = ["p": 2, "d": "BCDE"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([deleteOverflow], to: original))

        let deleteMismatch: JSON = ["p": 2, "d": "XX"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([deleteMismatch], to: original))
    }

    static var allTests = [
        ("testJSON0ObjectInsert", testJSON0ObjectInsert),
        ("testJSON0ObjectDelete", testJSON0ObjectDelete),
        ("testJSON0ObjectReplace", testJSON0ObjectReplace),
        ("testTEXT0Insert", testTEXT0Insert),
        ("testTEXT0Delete", testTEXT0Delete),
    ]
}
