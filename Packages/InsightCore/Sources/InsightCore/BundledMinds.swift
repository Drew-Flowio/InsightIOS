import Foundation

public enum BundledMinds {
    public static let floridaCoastalDemoResource = "florida-coastal-demo"

    public static func floridaCoastalDemoData() throws -> Data {
        guard
            let url = Bundle.module.url(forResource: floridaCoastalDemoResource, withExtension: "ogpack"),
            let data = try? Data(contentsOf: url)
        else {
            throw Error.missingBundledMind(floridaCoastalDemoResource)
        }
        return data
    }

    public static func floridaCoastalDemoVolume() throws -> KnowledgeVolume {
        try OGPackParser.parse(data: floridaCoastalDemoData())
    }

    public enum Error: Swift.Error, Equatable {
        case missingBundledMind(String)
    }
}
