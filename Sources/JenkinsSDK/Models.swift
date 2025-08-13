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
    case building  // Special case for running builds

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
    public var name: String
    public var url: String
    public var description: String?
    public var buildable: Bool?
    public var builds: [BuildReference]?
    public var lastBuild: BuildReference?
    public var lastCompletedBuild: BuildReference?
    public var lastFailedBuild: BuildReference?
    public var lastSuccessfulBuild: BuildReference?
    public var lastStableBuild: BuildReference?
    public var lastUnstableBuild: BuildReference?
    public var lastUnsuccessfulBuild: BuildReference?
    public var nextBuildNumber: Int?
    public var color: String?  // Jenkins color coding (e.g., "blue", "red", "yellow")
    public var jobs: [JobSummary]?  // Child jobs for folder-type jobs

    public init(
        name: String,
        url: String,
        description: String? = nil,
        buildable: Bool? = nil,
        builds: [BuildReference]? = nil,
        lastBuild: BuildReference? = nil,
        lastCompletedBuild: BuildReference? = nil,
        lastFailedBuild: BuildReference? = nil,
        lastSuccessfulBuild: BuildReference? = nil,
        lastStableBuild: BuildReference? = nil,
        lastUnstableBuild: BuildReference? = nil,
        lastUnsuccessfulBuild: BuildReference? = nil,
        nextBuildNumber: Int? = nil,
        color: String? = nil,
        jobs: [JobSummary]? = nil
    ) {
        self.name = name
        self.url = url
        self.description = description
        self.buildable = buildable
        self.builds = builds
        self.lastBuild = lastBuild
        self.lastCompletedBuild = lastCompletedBuild
        self.lastFailedBuild = lastFailedBuild
        self.lastSuccessfulBuild = lastSuccessfulBuild
        self.lastStableBuild = lastStableBuild
        self.lastUnstableBuild = lastUnstableBuild
        self.lastUnsuccessfulBuild = lastUnsuccessfulBuild
        self.nextBuildNumber = nextBuildNumber
        self.color = color
        self.jobs = jobs
    }

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
    public var number: Int
    public var url: String

    public init(number: Int, url: String) {
        self.number = number
        self.url = url
    }
}

public struct JenkinsOverview: Codable, Sendable {
    public var version: String?
    public var jobs: [JobSummary]
    public var description: String?
    public var nodeName: String?
    public var nodeDescription: String?
    public var numExecutors: Int?
    public var mode: String?

    public init(
        jobs: [JobSummary],
        version: String? = nil,
        description: String? = nil,
        nodeName: String? = nil,
        nodeDescription: String? = nil,
        numExecutors: Int? = nil,
        mode: String? = nil
    ) {
        self.jobs = jobs
        self.version = version
        self.description = description
        self.nodeName = nodeName
        self.nodeDescription = nodeDescription
        self.numExecutors = numExecutors
        self.mode = mode
    }
}

public struct JobSummary: Codable, Sendable {
    public var name: String
    public var url: String
    public var color: String?
    public var buildable: Bool?
    public var description: String?

    public init(
        name: String,
        url: String,
        color: String? = nil,
        buildable: Bool? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.url = url
        self.color = color
        self.buildable = buildable
        self.description = description
    }

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
    public var number: Int
    public var url: String
    public var displayName: String
    public var fullDisplayName: String
    public var description: String?
    public var building: Bool
    public var result: String?
    public var timestamp: Int64
    public var duration: Int64
    public var estimatedDuration: Int64?
    public var builtOn: String?
    public var changeSet: ChangeSet?
    public var actions: [BuildAction]

    public init(
        number: Int,
        url: String,
        displayName: String,
        fullDisplayName: String,
        building: Bool,
        timestamp: Int64,
        duration: Int64,
        actions: [BuildAction],
        description: String? = nil,
        result: String? = nil,
        estimatedDuration: Int64? = nil,
        builtOn: String? = nil,
        changeSet: ChangeSet? = nil
    ) {
        self.number = number
        self.url = url
        self.displayName = displayName
        self.fullDisplayName = fullDisplayName
        self.description = description
        self.building = building
        self.result = result
        self.timestamp = timestamp
        self.duration = duration
        self.estimatedDuration = estimatedDuration
        self.builtOn = builtOn
        self.changeSet = changeSet
        self.actions = actions
    }

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
            let buildNumber = cause.upstreamBuild
        else {
            return nil
        }
        return (project, buildNumber)
    }
}

public struct ChangeSet: Codable, Sendable {
    public var items: [ChangeSetItem]
    public var kind: String?

    public init(items: [ChangeSetItem], kind: String? = nil) {
        self.items = items
        self.kind = kind
    }
}

public struct ChangeSetItem: Codable, Sendable {
    public var commitId: String?
    public var timestamp: Int64?
    public var date: String?
    public var msg: String?
    public var author: Author?
    public var affectedPaths: [String]?
    public var paths: [ChangePath]?

    public init(
        commitId: String? = nil,
        timestamp: Int64? = nil,
        date: String? = nil,
        msg: String? = nil,
        author: Author? = nil,
        affectedPaths: [String]? = nil,
        paths: [ChangePath]? = nil
    ) {
        self.commitId = commitId
        self.timestamp = timestamp
        self.date = date
        self.msg = msg
        self.author = author
        self.affectedPaths = affectedPaths
        self.paths = paths
    }
}

public struct Author: Codable, Sendable {
    public var absoluteUrl: String?
    public var fullName: String?

    public init(absoluteUrl: String? = nil, fullName: String? = nil) {
        self.absoluteUrl = absoluteUrl
        self.fullName = fullName
    }
}

public struct ChangePath: Codable, Sendable {
    public var editType: String?
    public var file: String?

    public init(editType: String? = nil, file: String? = nil) {
        self.editType = editType
        self.file = file
    }
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
        parameters = try container.decodeIfPresent(
            [BuildParameter].self,
            forKey: DynamicCodingKeys(stringValue: "parameters")!
        )

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
    public var _class: String?
    public var shortDescription: String?
    public var upstreamBuild: Int?
    public var upstreamProject: String?
    public var upstreamUrl: String?
    public var userId: String?
    public var userName: String?

    public init(
        _class: String? = nil,
        shortDescription: String? = nil,
        upstreamBuild: Int? = nil,
        upstreamProject: String? = nil,
        upstreamUrl: String? = nil,
        userId: String? = nil,
        userName: String? = nil
    ) {
        self._class = _class
        self.shortDescription = shortDescription
        self.upstreamBuild = upstreamBuild
        self.upstreamProject = upstreamProject
        self.upstreamUrl = upstreamUrl
        self.userId = userId
        self.userName = userName
    }
}

public struct BuildParameter: Codable, Sendable {
    public var _class: String?
    public var name: String?
    public var value: AnyCodable?

    public init(_class: String? = nil, name: String? = nil, value: AnyCodable? = nil) {
        self._class = _class
        self.name = name
        self.value = value
    }

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
    public var items: [QueueItem]

    public init(items: [QueueItem]) {
        self.items = items
    }
}

public struct QueueItem: Codable, Sendable {
    public var id: Int
    public var task: QueueTask
    public var stuck: Bool
    public var actions: [QueueAction]?
    public var buildable: Bool
    public var params: String?
    public var why: String?
    public var blocked: Bool?
    public var buildableStartMilliseconds: Int64?
    public var inQueueSince: Int64?
    public var url: String?
    public var executable: QueueExecutable?

    public init(
        id: Int,
        task: QueueTask,
        stuck: Bool,
        buildable: Bool,
        actions: [QueueAction]? = nil,
        params: String? = nil,
        why: String? = nil,
        blocked: Bool? = nil,
        buildableStartMilliseconds: Int64? = nil,
        inQueueSince: Int64? = nil,
        url: String? = nil,
        executable: QueueExecutable? = nil
    ) {
        self.id = id
        self.task = task
        self.stuck = stuck
        self.actions = actions
        self.buildable = buildable
        self.params = params
        self.why = why
        self.blocked = blocked
        self.buildableStartMilliseconds = buildableStartMilliseconds
        self.inQueueSince = inQueueSince
        self.url = url
        self.executable = executable
    }

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
    public var name: String
    public var url: String
    public var color: String?

    public init(name: String, url: String, color: String? = nil) {
        self.name = name
        self.url = url
        self.color = color
    }
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
        parameters = try container.decodeIfPresent(
            [BuildParameter].self,
            forKey: DynamicCodingKeys(stringValue: "parameters")!
        )

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
    public var number: Int
    public var url: String

    public init(number: Int, url: String) {
        self.number = number
        self.url = url
    }
}

// MARK: - Test Report Models
public struct TestReport: Codable, Sendable {
    public var _class: String?
    public var testActions: [TestAction]?
    public var duration: Double
    public var empty: Bool?
    public var failCount: Int
    public var passCount: Int
    public var skipCount: Int
    public var suites: [TestSuite]

    public init(
        duration: Double,
        failCount: Int,
        passCount: Int,
        skipCount: Int,
        suites: [TestSuite],
        _class: String? = nil,
        testActions: [TestAction]? = nil,
        empty: Bool? = nil
    ) {
        self.duration = duration
        self.failCount = failCount
        self.passCount = passCount
        self.skipCount = skipCount
        self.suites = suites
        self._class = _class
        self.testActions = testActions
        self.empty = empty
    }

    // Computed properties
    public var totalCount: Int {
        passCount + failCount + skipCount
    }

    public var hasFailures: Bool {
        failCount > 0
    }

    public var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(passCount) / Double(totalCount)
    }

    public var isEmpty: Bool {
        empty ?? false
    }
}

public struct TestSuite: Codable, Sendable {
    public var name: String
    public var duration: Double?
    public var id: String?
    public var timestamp: String?
    public var cases: [TestCase]
    public var stderr: String?
    public var stdout: String?
    public var enclosingBlockNames: [String]?
    public var enclosingBlocks: [String]?
    public var nodeId: String?
    public var properties: TestProperties?

    public init(
        name: String,
        cases: [TestCase],
        duration: Double? = nil,
        id: String? = nil,
        timestamp: String? = nil,
        stderr: String? = nil,
        stdout: String? = nil,
        enclosingBlockNames: [String]? = nil,
        enclosingBlocks: [String]? = nil,
        nodeId: String? = nil,
        properties: TestProperties? = nil
    ) {
        self.name = name
        self.cases = cases
        self.duration = duration
        self.id = id
        self.timestamp = timestamp
        self.stderr = stderr
        self.stdout = stdout
        self.enclosingBlockNames = enclosingBlockNames
        self.enclosingBlocks = enclosingBlocks
        self.nodeId = nodeId
        self.properties = properties
    }

    // Computed properties
    public var failedCount: Int {
        cases.filter { $0.isFailed }.count
    }

    public var passedCount: Int {
        cases.filter { $0.isPassed }.count
    }

    public var skippedCount: Int {
        cases.filter { $0.isSkipped }.count
    }
}

public struct TestCase: Codable, Sendable {
    public var testActions: [TestAction]?
    public var age: Int
    public var className: String
    public var duration: Double
    public var errorDetails: String?
    public var errorStackTrace: String?
    public var failedSince: Int
    public var name: String
    public var properties: TestProperties?
    public var skipped: Bool
    public var skippedMessage: String?
    public var status: TestStatus
    public var stderr: String?
    public var stdout: String?

    public init(
        age: Int,
        className: String,
        duration: Double,
        failedSince: Int,
        name: String,
        skipped: Bool,
        status: TestStatus,
        testActions: [TestAction]? = nil,
        errorDetails: String? = nil,
        errorStackTrace: String? = nil,
        properties: TestProperties? = nil,
        skippedMessage: String? = nil,
        stderr: String? = nil,
        stdout: String? = nil
    ) {
        self.age = age
        self.className = className
        self.duration = duration
        self.failedSince = failedSince
        self.name = name
        self.skipped = skipped
        self.status = status
        self.testActions = testActions
        self.errorDetails = errorDetails
        self.errorStackTrace = errorStackTrace
        self.properties = properties
        self.skippedMessage = skippedMessage
        self.stderr = stderr
        self.stdout = stdout
    }

    // Computed properties
    public var isPassed: Bool {
        status == .passed
    }

    public var isFailed: Bool {
        status == .failed || status == .regression
    }

    public var isSkipped: Bool {
        status == .skipped || skipped
    }

    public var fullName: String {
        "\(className).\(name)"
    }
}

public struct TestStatus: RawRepresentable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Known values
    public static var passed: Self { .init(rawValue: "PASSED") }
    public static var failed: Self { .init(rawValue: "FAILED") }
    public static var skipped: Self { .init(rawValue: "SKIPPED") }
    public static var fixed: Self { .init(rawValue: "FIXED") }
    public static var regression: Self { .init(rawValue: "REGRESSION") }
}

extension TestStatus: Equatable {}

// MARK: - Supporting Test Report Types
public struct TestAction: Codable, Sendable {
    // Jenkins test actions can be very dynamic, using AnyCodable for flexibility
    private let data: [String: AnyCodable]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var data: [String: AnyCodable] = [:]
        for key in container.allKeys {
            data[key.stringValue] = try container.decodeIfPresent(AnyCodable.self, forKey: key)
        }
        self.data = data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in data {
            try container.encodeIfPresent(value, forKey: DynamicCodingKeys(stringValue: key)!)
        }
    }
}

public struct TestProperties: Codable, Sendable {
    // Jenkins test properties can be very dynamic, using AnyCodable for flexibility
    private let data: [String: AnyCodable]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var data: [String: AnyCodable] = [:]
        for key in container.allKeys {
            data[key.stringValue] = try container.decodeIfPresent(AnyCodable.self, forKey: key)
        }
        self.data = data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in data {
            try container.encodeIfPresent(value, forKey: DynamicCodingKeys(stringValue: key)!)
        }
    }
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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
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
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
