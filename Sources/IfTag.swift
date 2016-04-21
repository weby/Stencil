public class IfNode : NodeType {
  public let variable:Variable
  public let trueNodes:[NodeType]
  public let falseNodes:[NodeType]

  public class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    guard components.count == 2 else {
      throw TemplateSyntaxError("'if' statements should use the following 'if condition' `\(token.contents)`.")
    }
    let variable = components[1]
    var trueNodes = [NodeType]()
    var falseNodes = [NodeType]()

    trueNodes = try parser.parse(until: until(tags: ["endif", "else"]))

    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endif` was not found.")
    }

    if token.contents == "else" {
      falseNodes = try parser.parse(until: until(tags: ["endif"]))
      parser.nextToken()
    }

    return IfNode(variable: variable, trueNodes: trueNodes, falseNodes: falseNodes)
  }

  public class func parse_ifnot(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    guard components.count == 2 else {
      throw TemplateSyntaxError("'ifnot' statements should use the following 'if condition' `\(token.contents)`.")
    }
    let variable = components[1]
    var trueNodes = [NodeType]()
    var falseNodes = [NodeType]()

    falseNodes = try parser.parse(until: until(tags: ["endif", "else"]))

    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endif` was not found.")
    }

    if token.contents == "else" {
      trueNodes = try parser.parse(until: until(tags: ["endif"]))
      parser.nextToken()
    }

    return IfNode(variable: variable, trueNodes: trueNodes, falseNodes: falseNodes)
  }

  public init(variable:String, trueNodes:[NodeType], falseNodes:[NodeType]) {
    self.variable = Variable(variable)
    self.trueNodes = trueNodes
    self.falseNodes = falseNodes
  }

  public func render(context: Context) throws -> String {
    let result = try variable.resolve(context: context)
    var truthy = false

    if let result = result as? [Any] {
      truthy = !result.isEmpty
    } else if let result = result as? [String:Any] {
      truthy = !result.isEmpty
    } else if result != nil {
      truthy = true
    }

    return try context.push {
      if truthy {
        return try renderNodes(nodes: trueNodes, context)
      } else {
        return try renderNodes(nodes: falseNodes, context)
      }
    }
  }
}
