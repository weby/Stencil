public class ForNode : NodeType {
  let variable:Variable
  let loopVariable:String
  let nodes:[NodeType]
  let emptyNodes: [NodeType]
  
  public class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    
    guard components.count == 4 && components[2] == "in" else {
      throw TemplateSyntaxError("'for' statements should use the following 'for x in y' `\(token.contents)`.")
    }
    
    let loopVariable = components[1]
    let variable = components[3]
    
    var emptyNodes = [NodeType]()
    
    let forNodes = try parser.parse(until: until(tags: ["endfor", "empty"]))
    
    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endfor` was not found.")
    }
    
    if token.contents == "empty" {
      emptyNodes = try parser.parse(until: until(tags: ["endfor"]))
      parser.nextToken()
    }
    
    return ForNode(variable: variable, loopVariable: loopVariable, nodes: forNodes, emptyNodes:emptyNodes)
  }
  
  public init(variable:String, loopVariable:String, nodes:[NodeType], emptyNodes:[NodeType]) {
    self.variable = Variable(variable)
    self.loopVariable = loopVariable
    self.nodes = nodes
    self.emptyNodes = emptyNodes
  }
  
  public func render(context: Context) throws -> String {
    let values = try variable.resolve(context: context)
    
    if let values = values as? [Any] where values.count > 0 {
      let count = values.count
      #if !swift(>=3.0)
        return try values.enumerate().map { index, item in
        let forContext: [String: Any] = [
        "first": index == 0,
        "last": index == (count - 1),
        "counter": index + 1,
        ]
        
        return try context.push([loopVariable: item, "forloop": forContext]) {
        try renderNodes(nodes, context)
        }
        }.joinWithSeparator("")
      #else
        return try values.enumerated().map { index, item in
          let forContext: [String: Any] = [
                                            "first": index == 0,
                                            "last": index == (count - 1),
                                            "counter": index + 1,
                                            ]
          
          return try context.push(dictionary: [loopVariable: item, "forloop": forContext]) {
            try renderNodes(nodes: nodes, context)
          }
          }.joined(separator:"")
      #endif
    }
    
    return try context.push {
      try renderNodes(nodes: emptyNodes, context)
    }
  }
}
