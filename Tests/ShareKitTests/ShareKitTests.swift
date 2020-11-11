import XCTest
import SwiftyJSON
@testable import ShareKit

final class ShareKitTests: XCTestCase {
    func testTEXT0() throws {
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

    static var allTests = [
        ("testTEXT0", testTEXT0),
    ]
}
