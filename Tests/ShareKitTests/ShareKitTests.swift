import XCTest
import SwiftyJSON
@testable import ShareKit

final class ShareKitTests: XCTestCase {
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
        ("testTEXT0Insert", testTEXT0Insert),
        ("testTEXT0Delete", testTEXT0Delete),
    ]
}
