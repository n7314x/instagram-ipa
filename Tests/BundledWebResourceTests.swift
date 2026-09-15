import Foundation
import XCTest
@testable import Instagram

final class BundledWebResourceTests: XCTestCase {
    func testApplicationBundleContainsEveryWebResource() {
        for fileName in InstagramWebResourceManifest.allFileNames {
            let fileURL = URL(fileURLWithPath: fileName)
            let resourceURL = Bundle.main.url(
                forResource: fileURL.deletingPathExtension().lastPathComponent,
                withExtension: fileURL.pathExtension,
                subdirectory: nil
            )
            XCTAssertNotNil(resourceURL, "Missing app resource: \(fileName)")
        }
    }
}
