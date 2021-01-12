import Foundation

public enum AnyCodableKey {
    case index(Int)
    case member(String)
}

public protocol AnyCodableSubscriptType: Codable {
    var anyCodableKey: AnyCodableKey { get }
}

extension Int: AnyCodableSubscriptType {
    public var anyCodableKey: AnyCodableKey {
        return AnyCodableKey.index(self)
    }
}

extension String: AnyCodableSubscriptType {
    public var anyCodableKey: AnyCodableKey {
        return AnyCodableKey.member(self)
    }
}

public enum AnyCodable {
    case string(String)
    case int(Int)
    case decimal(Decimal)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null
    case undefined

    public init(_ object: Any?) {
        switch object {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let decimal as Decimal:
            self = .decimal(decimal)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [AnyCodable]:
            self = .array(array)
        case let array as [Any]:
            let wrappedArray = array.map { AnyCodable($0) }
            self = .array(wrappedArray)
        case let dictionary as [String: AnyCodable]:
            self = .dictionary(dictionary)
        case let dictionary as [String: Any]:
            let tuples = dictionary.map { ($0, AnyCodable($1)) }
            let wrappedDictionary = Dictionary(uniqueKeysWithValues: tuples)
            self = .dictionary(wrappedDictionary)
        case _ as NSNull, nil:
            self = .null
        default:
            self = .undefined
        }
    }

    private subscript(index index: Int) -> AnyCodable {
        get {
            guard case .array(let array) = self, index < array.count else {
                return .undefined
            }
            return array[index]
        }
        set {
            switch self {
            case .array(var array):
                if index < array.count {
                    array[index] = newValue
                } else {
                    array.append(newValue)
                }
                self = .array(array)
            case .undefined, .null:
                self = .array([newValue])
            default:
                break
            }
        }
    }

    private subscript(member member: String) -> AnyCodable {
        get {
            guard case .dictionary(let dictionary) = self, let child = dictionary[member] else {
                return .undefined
            }
            return child
        }
        set {
            switch self {
            case .dictionary(var dictionary):
                dictionary[member] = newValue
                self = .dictionary(dictionary)
            case .null, .undefined:
                self = .dictionary([member: newValue])
            default:
                break
            }
        }
    }

    private subscript(sub sub: AnyCodableSubscriptType) -> AnyCodable {
        get {
            switch sub.anyCodableKey {
            case .index(let index):
                return self[index: index]
            case .member(let member):
                return self[member: member]
            }
        }
        set {
            switch sub.anyCodableKey {
            case .index(let index):
                self[index: index] = newValue
            case .member(let member):
                self[member: member] = newValue
            }
        }
    }

    public subscript(path: [AnyCodableSubscriptType]) -> AnyCodable {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0: self = newValue
            case 1: self[sub:path[0]] = newValue
            default:
                var aPath = path
                aPath.remove(at: 0)
                var nextCodable = self[sub: path[0]]
                nextCodable[aPath] = newValue
                self[sub: path[0]] = nextCodable
            }
        }
    }

    public subscript(path: AnyCodableSubscriptType...) -> AnyCodable {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

extension AnyCodable: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let decimal = try? container.decode(Decimal.self) {
            self.init(decimal)
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.init(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        case .decimal(let decimal):
            try container.encode(decimal)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .null:
            try container.encodeNil()
        case .undefined:
            break
        }
    }
}

extension AnyCodable {
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(AnyCodable.self, from: data)
    }

    public var data: Data? {
        return try? JSONEncoder().encode(self)
    }
}

extension AnyCodable: Equatable {}

extension AnyCodable {
    public var string: String? {
        guard case .string(let string) = self else {
            return nil
        }
        return string
    }

    public var int: Int? {
        guard case .int(let int) = self else {
            return nil
        }
        return int
    }

    public var decimal: Decimal? {
        guard case .decimal(let decimal) = self else {
            return nil
        }
        return decimal
    }

    public var double: Double? {
        guard let decimal = self.decimal else {
            return nil
        }
        return Double(truncating: decimal as NSNumber)
    }

    public var array: [AnyCodable]? {
        guard case .array(let array) = self else {
            return nil
        }
        return array
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self.init(Decimal(value))
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = elements.reduce(into: [String: Any](), { $0[$1.0] = AnyCodable($1.1) })
        self.init(dictionary)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}
