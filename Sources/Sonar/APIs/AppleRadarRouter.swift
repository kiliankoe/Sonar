import Alamofire
import Foundation

private let kRadarAppID = "77e2a60d4bdfa6b7311c854a56505800be3c24e3a27a670098ff61b69fc5214b"

typealias Components = (path: String, method: HTTPMethod, headers: [String: String],
                        data: Data?, parameters: [String: String])

/**
Apple's radar request router.

- Products:    The `Route` used to retrieve all available products
- Login:       The `Route` used to login an username/password pair..
- Create:      The `Route` used to create a new radar.
- ViewProblem: The main apple's radar page.
*/
enum AppleRadarRouter {
    case products(CSRF: String)
    case login(appleID: String, password: String)
    case create(radar: Radar, CSRF: String)
    case viewProblem

    fileprivate static let baseURL = URL(string: "https://bugreport.apple.com")!

    /// The request components including headers and parameters.
    var components: Components {
        switch self {
            case .viewProblem:
                return (path: "/problem/viewproblem", method: .get, headers: [:], data: nil, parameters: [:])

            case .login(let appleID, let password):
                let fullURL = "https://idmsa.apple.com/IDMSWebAuth/authenticate"
                let headers = ["Content-Type": "application/x-www-form-urlencoded"]
                return (path: fullURL, method: .post, headers: headers, data: nil, parameters: [
                    "appIdKey": kRadarAppID, "accNameLocked": "false", "rv": "3", "Env": "PROD",
                    "appleId": appleID, "accountPassword": password
                ])

            case .products(let CSRF):
                let headers = [
                    "X-Requested-With": "XMLHttpRequest",
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                    "csrftokencheck": CSRF,
                ]

                let timestamp = Int(NSDate().timeIntervalSince1970 * 100)
                return (path: "/developer/problem/getProductFullList", method: .get,
                        headers: headers, data: nil, parameters: ["_": String(timestamp)])

            case .create(let radar, let CSRF):
                let sizes = radar.attachments.map { String($0.size) } + [""]
                let JSON: [String: Any] = [
                    "problemTitle": radar.title,
                    "configIDPop": "",
                    "configTitlePop": "",
                    "configDescriptionPop": "",
                    "configurationText": radar.configuration,
                    "notes": radar.notes,
                    "configurationSplit": "Configuration:\r\n",
                    "configurationSplitValue": radar.configuration,
                    "workAroundText": "",
                    "descriptionText": radar.body,
                    "problemAreaTypeCode": radar.area.map { String($0.appleIdentifier) } ?? "",
                    "classificationCode": String(radar.classification.appleIdentifier),
                    "reproducibilityCode": String(radar.reproducibility.appleIdentifier),
                    "component": [
                        "ID": String(radar.product.appleIdentifier),
                        "compName": radar.product.name,
                    ],
                    "draftID": "",
                    "draftFlag": "0",
                    "versionBuild": radar.version,
                    "desctextvalidate": radar.body,
                    "stepstoreprvalidate": radar.steps,
                    "experesultsvalidate": radar.expected,
                    "actresultsvalidate": radar.actual,
                    "addnotesvalidate": radar.notes,
                    "hiddenFileSizeNew": radar.attachments.isEmpty ? "" : sizes,
                    "attachmentsValue": "\r\n\r\nAttachments:\r\n",
                    "configurationFileCheck": "",
                    "configurationFileFinal": "",
                    "csrftokencheck": CSRF,
                ]

                let body = try! JSONSerialization.data(withJSONObject: JSON, options: [])
                let headers = ["Referer": AppleRadarRouter.viewProblem.url.absoluteString]
                return (path: "/developer/problem/createNewDevUIProblem", method: .post, headers: headers,
                        data: body, parameters: [:])
        }
    }
}

extension AppleRadarRouter: URLRequestConvertible {
    /// The URL that will be used for the request.
    var url: URL {
        return self.urlRequest!.url!
    }

    /// The request representation of the route including parameters and HTTP method.
    func asURLRequest() -> URLRequest {
        let (path, method, headers, data, parameters) = self.components
        let fullURL: URL
        if let url = URL(string: path), url.host != nil {
            fullURL = url
        } else {
            fullURL = AppleRadarRouter.baseURL.appendingPathComponent(path)
        }

        var request = URLRequest(url: fullURL)
        request.httpMethod = method.rawValue
        request.httpBody = data

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if data == nil {
            return try! URLEncoding().encode(request, with: parameters)
        }

        return request
    }
}
