import XCTest
@testable import ShareKit

final class ShareKitTests: XCTestCase {
    func testJSON0ObjectInsert() throws {
        let original: AnyCodable = ["x": 100, "nested": ["y": 200]]

        let insertSimple: AnyCodable = ["p": ["name"], "oi": "outter"]
        let result1 = try JSON0Transformer.apply([insertSimple], to: original)
        let expected1: AnyCodable = ["name": "outter", "x": 100, "nested": ["y": 200]]
        XCTAssertEqual(result1, expected1)

        let insertSimpleNonEmpty: AnyCodable = ["p": ["x"], "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertSimpleNonEmpty], to: original))

        let insertNestedInner: AnyCodable = ["p": ["nested", "name"], "oi": "inner"]
        let result2 = try JSON0Transformer.apply([insertNestedInner], to: original)
        let expected2: AnyCodable = ["x": 100, "nested": ["name": "inner", "y": 200]]
        XCTAssertEqual(result2, expected2)

        let insertNestedNonEmpty: AnyCodable = ["p": ["nested", "y"], "oi": 200]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedNonEmpty], to: original))

        let insertNestedBranch: AnyCodable = ["p": ["newbranch"], "oi": ["name": "inner"]]
        let result3 = try JSON0Transformer.apply([insertNestedBranch], to: original)
        let expected3: AnyCodable = ["x": 100, "nested": ["y": 200], "newbranch": ["name": "inner"]]
        XCTAssertEqual(result3, expected3)

        let insertNestedBranchNonEmpty: AnyCodable = ["p": ["nested"], "oi": []]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedBranchNonEmpty], to: original))
    }

    func testJSON0ObjectDelete() throws {
        let original: AnyCodable = ["name": "outter", "nested": ["name": "inner"]]

        let deleteSimple: AnyCodable = ["p": ["name"], "od": "outter"]
        let result1 = try JSON0Transformer.apply([deleteSimple], to: original)
        let expected1: AnyCodable = ["nested": ["name": "inner"]]
        XCTAssertEqual(result1, expected1)

        let deleteSimpleMismatch: AnyCodable = ["p": ["name"], "od": "not-outter"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteSimpleMismatch], to: original))

        let deleteNestedInner: AnyCodable = ["p": ["nested", "name"], "od": "inner"]
        let result2 = try JSON0Transformer.apply([deleteNestedInner], to: original)
        let expected2: AnyCodable = ["name": "outter", "nested": [:]]
        XCTAssertEqual(result2, expected2)

        let deleteNestedMismatch: AnyCodable = ["p": ["nested", "name"], "od": "not-inner"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedMismatch], to: original))

        let deleteNestedBranch: AnyCodable = ["p": ["nested"], "od": ["name": "inner"]]
        let result3 = try JSON0Transformer.apply([deleteNestedBranch], to: original)
        let expected3: AnyCodable = ["name": "outter"]
        XCTAssertEqual(result3, expected3)

        let deleteNestedBranchMismatch: AnyCodable = ["p": ["nested"], "od": ["name": "not-inner"]]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedBranchMismatch], to: original))
    }

    func testJSON0ObjectReplace() throws {
        let original: AnyCodable = ["name": "outter", "nested": ["name": "inner"]]

        let replaceSimple: AnyCodable = ["p": ["name"], "od": "outter", "oi": "new-outter"]
        let result1 = try JSON0Transformer.apply([replaceSimple], to: original)
        let expected1: AnyCodable = ["name": "new-outter", "nested": ["name": "inner"]]
        XCTAssertEqual(result1, expected1)

        let insertSimpleMismatch: AnyCodable = ["p": ["name"], "od": "non-exist", "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertSimpleMismatch], to: original))

        let replaceInner: AnyCodable = ["p": ["nested", "name"], "od": "inner", "oi": "new-inner"]
        let result2 = try JSON0Transformer.apply([replaceInner], to: original)
        let expected2: AnyCodable = ["name": "outter", "nested": ["name": "new-inner"]]
        XCTAssertEqual(result2, expected2)

        let insertNestedMismatch: AnyCodable = ["p": ["nested", "name"], "od": "non-exist", "oi": 100]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedMismatch], to: original))

        let replaceBranch: AnyCodable = ["p": ["nested"], "od": ["name": "inner"], "oi": "new-branch"]
        let result3 = try JSON0Transformer.apply([replaceBranch], to: original)
        let expected3: AnyCodable = ["name": "outter", "nested": "new-branch"]
        XCTAssertEqual(result3, expected3)
    }

    func testJSON0ListInsert() throws {
        let original: AnyCodable = ["x": [100, 200], "nested": ["y": ["sam", "iam"]]]

        let insertSimple: AnyCodable = ["p": ["x", 2], "li": 150]
        let result1 = try JSON0Transformer.apply([insertSimple], to: original)
        let expected1: AnyCodable = ["x": [100, 200, 150], "nested": ["y": ["sam", "iam"]]]
        XCTAssertEqual(result1, expected1)

        let insertNoPath: AnyCodable = ["p": ["no-path"], "li": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNoPath], to: original))

        let insertNoIndex: AnyCodable = ["p": ["x"], "li": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNoIndex], to: original))

        let insertOutRange: AnyCodable = ["p": ["x", 3], "li": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertOutRange], to: original))

        let insertInvalidIndex: AnyCodable = ["p": ["x", -1], "li": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertInvalidIndex], to: original))

        let insertNested: AnyCodable = ["p": ["nested", "y", 1], "li": "ham"]
        let result2 = try JSON0Transformer.apply([insertNested], to: original)
        let expected2: AnyCodable = ["x": [100, 200], "nested": ["y": ["sam", "ham", "iam"]]]
        XCTAssertEqual(result2, expected2)

        let insertNestedNoIndex: AnyCodable = ["p": ["nested", "y"], "li": "ham"]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedNoIndex], to: original))

        let insertNestedOutRange: AnyCodable = ["p": ["nested", "y", 3], "li": "ham"]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedOutRange], to: original))

        let insertNestedInvalidIndex: AnyCodable = ["p": ["nested", "y", -1], "li": "ham"]
        XCTAssertThrowsError(try JSON0Transformer.apply([insertNestedInvalidIndex], to: original))
    }

    func testJSON0ListDelete() throws {
        let original: AnyCodable = ["x": [100, 200], "nested": ["y": ["sam", "iam"]]]

        let deleteSimple: AnyCodable = ["p": ["x", 1], "ld": 200]
        let result1 = try JSON0Transformer.apply([deleteSimple], to: original)
        let expected1: AnyCodable = ["x": [100], "nested": ["y": ["sam", "iam"]]]
        XCTAssertEqual(result1, expected1)

        let deleteMismatch: AnyCodable = ["p": ["x", 1], "ld": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteMismatch], to: original))

        let deleteNoPath: AnyCodable = ["p": ["no-path"], "ld": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNoPath], to: original))

        let deleteNoIndex: AnyCodable = ["p": ["x"], "ld": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNoIndex], to: original))

        let deleteOutRange: AnyCodable = ["p": ["x", 3], "ld": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteOutRange], to: original))

        let deleteInvalidIndex: AnyCodable = ["p": ["x", -1], "ld": 300]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteInvalidIndex], to: original))

        let deleteNested: AnyCodable = ["p": ["nested", "y", 1], "ld": "iam"]
        let result2 = try JSON0Transformer.apply([deleteNested], to: original)
        let expected2: AnyCodable = ["x": [100, 200], "nested": ["y": ["sam"]]]
        XCTAssertEqual(result2, expected2)

        let deleteNestedMismatch: AnyCodable = ["p": ["nested", "y", 1], "ld": "mismatch"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedMismatch], to: original))

        let deleteNestedNoPath: AnyCodable = ["p": ["nested", "no-path"], "ld": "iam"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedNoPath], to: original))

        let deleteNestedNoIndex: AnyCodable = ["p": ["nested", "y"], "ld": "iam"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedNoIndex], to: original))

        let deleteNestedOutRange: AnyCodable = ["p": ["nested", "y", 3], "ld": "iam"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedOutRange], to: original))

        let deleteNestedInvalidIndex: AnyCodable = ["p": ["nested", "y", -1], "ld": "iam"]
        XCTAssertThrowsError(try JSON0Transformer.apply([deleteNestedInvalidIndex], to: original))
    }

    func testJSON0Subtype() throws {
        let original: AnyCodable = ["x": "green eggs ham", "nested": ["y": "iam"]]

        let subtypeAdd: AnyCodable = ["t": "text0", "p": ["x"], "o": [["p": 10, "i": " and"]]]
        let result1 = try JSON0Transformer.apply([subtypeAdd], to: original)
        let expected1: AnyCodable = ["x": "green eggs and ham", "nested": ["y": "iam"]]
        XCTAssertEqual(result1, expected1)

        let subtypeNestedAdd: AnyCodable = ["t": "text0", "p": ["nested", "y"], "o": [["p": 0, "i": "sam "]]]
        let result2 = try JSON0Transformer.apply([subtypeNestedAdd], to: original)
        let expected2: AnyCodable = ["x": "green eggs ham", "nested": ["y": "sam iam"]]
        XCTAssertEqual(result2, expected2)
    }

    func testTEXT0Insert() throws {
        let original = AnyCodable("ABCD")

        let insertSingle: AnyCodable = ["p": 1, "i": "X"]
        let result1 = try TEXT0Transformer.apply([insertSingle], to: original)
        let expected1: AnyCodable = "AXBCD"
        XCTAssertEqual(result1, expected1)

        let insertMultiple: AnyCodable = ["p": 1, "i": "XYZ"]
        let result2 = try TEXT0Transformer.apply([insertMultiple], to: original)
        let expected2: AnyCodable = "AXYZBCD"
        XCTAssertEqual(result2, expected2)

        let insertStart: AnyCodable = ["p": 0, "i": "XYZ"]
        let result3 = try TEXT0Transformer.apply([insertStart], to: original)
        let expected3: AnyCodable = "XYZABCD"
        XCTAssertEqual(result3, expected3)

        let insertEnd: AnyCodable = ["p": 4, "i": "XYZ"]
        let result4 = try TEXT0Transformer.apply([insertEnd], to: original)
        let expected4: AnyCodable = "ABCDXYZ"
        XCTAssertEqual(result4, expected4)

        let insertOverflow: AnyCodable = ["p": 5, "i": "XYZ"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([insertOverflow], to: original))

        let insertNoIndex: AnyCodable = ["p": "1", "i": "XYZ"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([insertNoIndex], to: original))
    }

    func testTEXT0Delete() throws {
        let original = AnyCodable("ABCDE")

        let deleteSingle: AnyCodable = ["p": 1, "d": "B"]
        let result1 = try TEXT0Transformer.apply([deleteSingle], to: original)
        let expected1: AnyCodable = "ACDE"
        XCTAssertEqual(result1, expected1)

        let deleteMultiple: AnyCodable = ["p": 1, "d": "BCD"]
        let result2 = try TEXT0Transformer.apply([deleteMultiple], to: original)
        let expected2: AnyCodable = "AE"
        XCTAssertEqual(result2, expected2)

        let deleteStart: AnyCodable = ["p": 0, "d": "ABC"]
        let result3 = try TEXT0Transformer.apply([deleteStart], to: original)
        let expected3: AnyCodable = "DE"
        XCTAssertEqual(result3, expected3)

        let deleteEnd: AnyCodable = ["p": 2, "d": "CDE"]
        let result4 = try TEXT0Transformer.apply([deleteEnd], to: original)
        let expected4: AnyCodable = "AB"
        XCTAssertEqual(result4, expected4)

        let deleteOverflow: AnyCodable = ["p": 2, "d": "BCDE"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([deleteOverflow], to: original))

        let deleteMismatch: AnyCodable = ["p": 2, "d": "XX"]
        XCTAssertThrowsError(try TEXT0Transformer.apply([deleteMismatch], to: original))
    }

    static var allTests = [
        ("testJSON0ObjectInsert", testJSON0ObjectInsert),
        ("testJSON0ObjectDelete", testJSON0ObjectDelete),
        ("testJSON0ObjectReplace", testJSON0ObjectReplace),
        ("testJSON0ListInsert", testJSON0ListInsert),
        ("testJSON0ListDelete", testJSON0ListDelete),
        ("testTEXT0Insert", testTEXT0Insert),
        ("testTEXT0Delete", testTEXT0Delete),
    ]
}
