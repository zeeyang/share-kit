// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "share-kit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(name: "ShareKit", targets: ["ShareKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.1.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "ShareKit", dependencies: [
            .product(name: "WebSocketKit", package: "websocket-kit"),
            .product(name: "SwiftyJSON", package: "SwiftyJSON"),
        ]),
        .testTarget(name: "ShareKitTests", dependencies: [
            .target(name: "ShareKit"),
        ]),
    ]
)
