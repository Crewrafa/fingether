// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fingether",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Fingether", targets: ["Fingether"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "Fingether",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Spendly"
        )
    ]
)
