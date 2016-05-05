import Foundation


class FilterExpression : Resolvable {
  let filters: [Filter]
  let variable: Variable
  
  init(token: String, parser: TokenParser) throws {
    #if !swift(>=3.0)
      let bits = token.characters.split("|").map({ String($0).trim(" ") })
    #else
      let bits = token.characters.split(separator:"|").map({ String($0).trim(character: " ") })
    #endif
    if bits.isEmpty {
      filters = []
      variable = Variable("")
      throw TemplateSyntaxError("Variable tags must include at least 1 argument")
    }
    
    variable = Variable(bits[0])
    let filterBits = bits[1 ..< bits.endIndex]
    
    do {
      filters = try filterBits.map { try parser.findFilter(name: $0) }
    } catch {
      filters = []
      throw error
    }
  }
  
  func resolve(context: Context) throws -> Any? {
    let result = try variable.resolve(context: context)
    
    return try filters.reduce(result) { x, y in
      return try y(x)
    }
  }
}

/// A structure used to represent a template variable, and to resolve it in a given context.
public struct Variable : Equatable, Resolvable {
  public let variable: String
  
  /// Create a variable with a string representing the variable
  public init(_ variable: String) {
    self.variable = variable
  }
  
  private func lookup() -> [String] {
    #if !swift(>=3.0)
      return variable.characters.split(".").map(String.init)
    #else
      return variable.characters.split(separator:".").map(String.init)
    #endif
  }
  
  /// Resolve the variable in the given context
  public func resolve(context: Context) throws -> Any? {
    var current: Any? = context
    
    if (variable.hasPrefix("'") && variable.hasSuffix("'")) || (variable.hasPrefix("\"") && variable.hasSuffix("\"")) {
      // String literal
      return variable[variable.index(after: variable.startIndex)..<variable.index(before: variable.endIndex)]
    }
    
    for bit in lookup() {
      current = normalize(current: current)
      
      if let context = current as? Context {
        current = context[bit]
      } else if let dictionary = current as? [String: Any] {
        current = dictionary[bit]
      } else if let array = current as? [Any] {
        if let index = Int(bit) {
          current = array[index]
        } else if bit == "first" {
          current = array.first
        } else if bit == "last" {
          current = array.last
        } else if bit == "count" {
          current = array.count
        }
      } else if let object = current as? NSObject {  // NSKeyValueCoding
        #if os(Linux)
          return nil
        #else
          #if !swift(>=3.0)
            current = object.valueForKey(bit)
          #else
            current = object.value(forKey:bit)
          #endif
        #endif
      } else {
        return nil
      }
    }
    
    return normalize(current: current)
  }
}

public func ==(lhs: Variable, rhs: Variable) -> Bool {
  return lhs.variable == rhs.variable
}


func normalize(current: Any?) -> Any? {
  if let current = current as? Normalizable {
    return current.normalize()
  }
  
  return current
}

protocol Normalizable {
  func normalize() -> Any?
}

extension Array : Normalizable {
  func normalize() -> Any? {
    return map { $0 as Any }
  }
}

extension NSArray : Normalizable {
  func normalize() -> Any? {
    return map { $0 as Any }
  }
}

extension Dictionary : Normalizable {
  func normalize() -> Any? {
    var dictionary: [String: Any] = [:]
    
    for (key, value) in self {
      if let key = key as? String {
        dictionary[key] = Stencil.normalize(current: value)
      } else if let key = key as? CustomStringConvertible {
        dictionary[key.description] = Stencil.normalize(current: value)
      }
    }
    
    return dictionary
  }
}
