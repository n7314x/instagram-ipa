import Foundation
import XCTest
@testable import Instagram

final class SessionRoutingTests: XCTestCase {
    func testFreshLaunchWithoutSessionCookieUsesLoginRoute() {
        let decision = InstagramSessionRouting.launchDecision(hasSessionCookie: false)

        XCTAssertEqual(decision.sessionState, .loggedOut)
        XCTAssertEqual(decision.initialHomeURL, InstagramSessionRouting.loginURL)
        XCTAssertEqual(decision.initialHomeURL.path, "/accounts/login/")
    }

    func testLaunchWithSessionCookieUsesAuthenticatedHomeRoute() {
        let decision = InstagramSessionRouting.launchDecision(hasSessionCookie: true)

        XCTAssertEqual(decision.sessionState, .authenticated)
        XCTAssertEqual(decision.initialHomeURL, InstagramSessionRouting.homeURL)
    }

    func testAuthenticationFlowRoutesAreNotReloadedBackToLogin() {
        let routes = [
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/emailsignup/",
            "https://www.instagram.com/accounts/password/reset/",
            "https://www.instagram.com/accounts/two_factor/",
            "https://www.instagram.com/challenge/123/",
            "https://www.instagram.com/checkpoint/"
        ]

        for route in routes {
            XCTAssertTrue(
                InstagramSessionRouting.isAuthenticationFlowURL(URL(string: route)),
                "Expected authentication flow route: \(route)"
            )
        }
        XCTAssertFalse(
            InstagramSessionRouting.isAuthenticationFlowURL(InstagramSessionRouting.homeURL)
        )
    }

    func testInstagramAppDeepLinksAreRecognizedWithoutBlockingWebRoutes() {
        XCTAssertTrue(InstagramNavigationDelegate.isInstagramAppOpeningURL(
            URL(string: "instagram://user?username=example")!
        ))
        XCTAssertTrue(InstagramNavigationDelegate.isInstagramAppOpeningURL(
            URL(string: "https://apps.apple.com/app/instagram/id389801252")!
        ))
        XCTAssertFalse(InstagramNavigationDelegate.isInstagramAppOpeningURL(
            URL(string: "https://www.instagram.com/accounts/login/")!
        ))
    }
}
