#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

// MARK: - Credentials
public struct JenkinsCredentials: Sendable {
    public let username: String
    public let password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// MARK: - Errors
public enum JenkinsAPIError: Error, Sendable {
    case httpError(Int)
    case noData
    case decodingError(Error)
    case invalidURL
    case buildNotFound
    case jobNotFound
    case invalidPath(String)
    case invalidPattern(String)
}

// MARK: - Build Status
public enum BuildStatus: String, Codable, Sendable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case unstable = "UNSTABLE"
    case aborted = "ABORTED"
    case notBuilt = "NOT_BUILT"
    case building // Special case for running builds
    
    public var isRunning: Bool {
        self == .building
    }
    
    public var isSuccess: Bool {
        self == .success
    }
    
    public var isFailure: Bool {
        self == .failure || self == .unstable || self == .aborted
    }
}

// MARK: - Data Models
public struct Job: Codable, Sendable {
    public let name: String
    public let url: String
    public let description: String?
    public let buildable: Bool?
    public let builds: [BuildReference]?
    public let lastBuild: BuildReference?
    public let lastCompletedBuild: BuildReference?
    public let lastFailedBuild: BuildReference?
    public let lastSuccessfulBuild: BuildReference?
    public let lastStableBuild: BuildReference?
    public let lastUnstableBuild: BuildReference?
    public let lastUnsuccessfulBuild: BuildReference?
    public let nextBuildNumber: Int?
    public let color: String? // Jenkins color coding (e.g., "blue", "red", "yellow")
    public let jobs: [JobSummary]? // Child jobs for folder-type jobs
    
    // MARK: - Computed Properties
    public var nextBuildNumberValue: Int { nextBuildNumber ?? 1 }
    public var buildableValue: Bool { buildable ?? false }
    
    // MARK: - Build References
    public var lastBuildNumber: Int? { lastBuild?.number }
    public var lastCompletedBuildNumber: Int? { lastCompletedBuild?.number }
    public var lastSuccessfulBuildNumber: Int? { lastSuccessfulBuild?.number }
    public var lastFailedBuildNumber: Int? { lastFailedBuild?.number }
    
    // MARK: - Status
    public var isHealthy: Bool {
        color?.contains("blue") == true || color?.contains("green") == true
    }
    
    public var isFailing: Bool {
        color?.contains("red") == true
    }
    
    public var isBuilding: Bool {
        color?.contains("anime") == true || color?.contains("building") == true
    }
    
    // MARK: - Build History
    public var buildReferences: [BuildReference] { builds ?? [] }
    public var buildNumbers: [Int] { buildReferences.map { $0.number } }
    
    // MARK: - Child Jobs (for folder-type jobs)
    public var childJobs: [JobSummary] { jobs ?? [] }
    public var hasChildJobs: Bool { !childJobs.isEmpty }
}

public struct BuildReference: Codable, Sendable {
    public let number: Int
    public let url: String
}

public struct JenkinsOverview: Codable, Sendable {
    public let jobs: [JobSummary]
    public let description: String?
    public let nodeName: String?
    public let nodeDescription: String?
    public let numExecutors: Int?
    public let mode: String?
}

public struct JobSummary: Codable, Sendable {
    public let name: String
    public let url: String
    public let color: String?
    public let buildable: Bool?
    public let description: String?
    
    // Helper properties
    public var isHealthy: Bool {
        color?.contains("blue") == true || color?.contains("green") == true
    }
    
    public var isFailing: Bool {
        color?.contains("red") == true
    }
    
    public var isBuilding: Bool {
        color?.contains("anime") == true || color?.contains("building") == true
    }
}

public struct Build: Codable, Sendable {
    public let number: Int
    public let url: String
    public let displayName: String
    public let fullDisplayName: String
    public let description: String?
    public let building: Bool
    public let result: String?
    public let timestamp: Int64
    public let duration: Int64
    public let estimatedDuration: Int64?
    public let builtOn: String?
    public let changeSet: ChangeSet?
    public let actions: [BuildAction]
    
    public var status: BuildStatus {
        if building {
            return .building
        }
        guard let result = result else {
            return .building
        }
        return BuildStatus(rawValue: result) ?? .notBuilt
    }
    
    public var startTime: Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
    }
    
    public var durationTimeInterval: TimeInterval {
        Double(duration) / 1000.0
    }
    
    // MARK: - Status Helpers
    public var isRunning: Bool { building }
    public var isSuccess: Bool { status.isSuccess }
    public var isFailure: Bool { status.isFailure }
    
    // MARK: - Timing
    public var estimatedDurationTimeInterval: TimeInterval? {
        guard let estimated = estimatedDuration else { return nil }
        return Double(estimated) / 1000.0
    }
    
    // MARK: - Changes
    public var hasChanges: Bool { 
        changeSet?.items.isEmpty == false
    }
    
    // MARK: - Parameters
    public var buildParameters: [String: String] {
        var params: [String: String] = [:]
        for action in actions {
            if let parameters = action.parameters {
                for param in parameters {
                    if let name = param.name, let value = param.stringValue {
                        params[name] = value
                    }
                }
            }
        }
        return params
    }
    
    // MARK: - Causes
    public var buildCauses: [BuildCause] {
        actions.compactMap { $0.causes }.flatMap { $0 }
    }
    
    public var triggeredByUser: Bool {
        buildCauses.contains { $0.userId != nil }
    }
    
    public var upstreamBuild: (project: String, build: Int)? {
        guard let cause = buildCauses.first(where: { $0.upstreamProject != nil }),
              let project = cause.upstreamProject,
              let buildNumber = cause.upstreamBuild else {
            return nil
        }
        return (project, buildNumber)
    }
}

public struct ChangeSet: Codable, Sendable {
    public let items: [ChangeSetItem]
    public let kind: String?
}

public struct ChangeSetItem: Codable, Sendable {
    public let commitId: String?
    public let timestamp: Int64?
    public let date: String?
    public let msg: String?
    public let author: Author?
    public let affectedPaths: [String]?
    public let paths: [ChangePath]?
}

public struct Author: Codable, Sendable {
    public let absoluteUrl: String?
    public let fullName: String?
}

public struct ChangePath: Codable, Sendable {
    public let editType: String?
    public let file: String?
}

public struct BuildAction: Codable, Sendable {
    // Jenkins actions are very dynamic, so we use a flexible approach
    // Common fields that might be present:
    public let _class: String?
    public let causes: [BuildCause]?
    public let parameters: [BuildParameter]?
    
    // Allow any additional fields
    private let additionalProperties: [String: AnyCodable]?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        _class = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "_class")!)
        causes = try container.decodeIfPresent([BuildCause].self, forKey: DynamicCodingKeys(stringValue: "causes")!)
        parameters = try container.decodeIfPresent([BuildParameter].self, forKey: DynamicCodingKeys(stringValue: "parameters")!)
        
        // Store any additional properties
        var additional: [String: AnyCodable] = [:]
        for key in container.allKeys {
            if !["_class", "causes", "parameters"].contains(key.stringValue) {
                additional[key.stringValue] = try container.decodeIfPresent(AnyCodable.self, forKey: key)
            }
        }
        additionalProperties = additional.isEmpty ? nil : additional
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        
        try container.encodeIfPresent(_class, forKey: DynamicCodingKeys(stringValue: "_class")!)
        try container.encodeIfPresent(causes, forKey: DynamicCodingKeys(stringValue: "causes")!)
        try container.encodeIfPresent(parameters, forKey: DynamicCodingKeys(stringValue: "parameters")!)
        
        if let additional = additionalProperties {
            for (key, value) in additional {
                try container.encodeIfPresent(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
    }
}

public struct BuildCause: Codable, Sendable {
    public let _class: String?
    public let shortDescription: String?
    public let upstreamBuild: Int?
    public let upstreamProject: String?
    public let upstreamUrl: String?
    public let userId: String?
    public let userName: String?
}

public struct BuildParameter: Codable, Sendable {
    public let _class: String?
    public let name: String?
    public let value: AnyCodable?
    
    // Convenience getter to get string value
    public var stringValue: String? {
        switch value?.value {
        case let str as String:
            return str
        case let bool as Bool:
            return String(bool)
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        default:
            return nil
        }
    }
}

// MARK: - Helper Types
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Queue Models
public struct QueueInfo: Codable, Sendable {
    public let items: [QueueItem]
}

public struct QueueItem: Codable, Sendable {
    public let id: Int
    public let task: QueueTask
    public let stuck: Bool
    public let actions: [QueueAction]?
    public let buildable: Bool
    public let params: String?
    public let why: String?
    public let blocked: Bool?
    public let buildableStartMilliseconds: Int64?
    public let inQueueSince: Int64?
    public let url: String?
    public let executable: QueueExecutable?
    
    public var inQueueSinceDate: Date? {
        guard let inQueueSince = inQueueSince else { return nil }
        return Date(timeIntervalSince1970: Double(inQueueSince) / 1000.0)
    }
    
    public var buildableStartDate: Date? {
        guard let buildableStartMilliseconds = buildableStartMilliseconds else { return nil }
        return Date(timeIntervalSince1970: Double(buildableStartMilliseconds) / 1000.0)
    }
}

public struct QueueTask: Codable, Sendable {
    public let name: String
    public let url: String
    public let color: String?
}

public struct QueueAction: Codable, Sendable {
    public let _class: String?
    public let causes: [BuildCause]?
    public let parameters: [BuildParameter]?
    
    private let additionalProperties: [String: AnyCodable]?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        _class = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "_class")!)
        causes = try container.decodeIfPresent([BuildCause].self, forKey: DynamicCodingKeys(stringValue: "causes")!)
        parameters = try container.decodeIfPresent([BuildParameter].self, forKey: DynamicCodingKeys(stringValue: "parameters")!)
        
        var additional: [String: AnyCodable] = [:]
        for key in container.allKeys {
            if !["_class", "causes", "parameters"].contains(key.stringValue) {
                additional[key.stringValue] = try container.decodeIfPresent(AnyCodable.self, forKey: key)
            }
        }
        additionalProperties = additional.isEmpty ? nil : additional
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        
        try container.encodeIfPresent(_class, forKey: DynamicCodingKeys(stringValue: "_class")!)
        try container.encodeIfPresent(causes, forKey: DynamicCodingKeys(stringValue: "causes")!)
        try container.encodeIfPresent(parameters, forKey: DynamicCodingKeys(stringValue: "parameters")!)
        
        if let additional = additionalProperties {
            for (key, value) in additional {
                try container.encodeIfPresent(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
    }
}

public struct QueueExecutable: Codable, Sendable {
    public let number: Int
    public let url: String
}

public struct AnyCodable: Codable, Sendable {
    let value: any Sendable
    
    init<T: Sendable>(_ value: T?) {
        self.value = value ?? ()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [any Sendable]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: any Sendable]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}