import Foundation

@main struct StorefrontLinkTests {
    static func main() {
        for value in ["storefrontdemo://open", "STOREFRONTDEMO://OPEN", "storefrontdemo://open/"] {
            precondition(StorefrontLink.accepts(URL(string: value)!))
        }
        for value in ["https://open", "storefrontdemo://other", "storefrontdemo:open",
                      "storefrontdemo://open/profile", "storefrontdemo://open?token=anything",
                      "storefrontdemo://open#home", "storefrontdemo://user@open", "storefrontdemo://open:443"] {
            precondition(!StorefrontLink.accepts(URL(string: value)!))
        }
        print("Storefront route validation passed")
    }
}
