

#if !swift(>=3.0)
  typealias Collection = CollectionType
  
#endif


class BlockContext {
  class var contextKey: String { return "block_context" }
  
  var blocks: [String:BlockNode]
  
  init(blocks: [String:BlockNode]) {
    self.blocks = blocks
  }
  
  func pop(blockName: String) -> BlockNode? {
    #if !swift(>=3.0)
      return blocks.removeValueForKey(blockName)
    #else
      return blocks.removeValue(forKey:blockName)
    #endif
  }
}


extension Collection {
  #if !swift(>=3.0)
  func any(closure: Generator.Element -> Bool) -> Generator.Element? {
    for element in self {
      if closure(element) {
      return element
      }
    }
  
    return nil
  }
  #else
  func any(closure: Iterator.Element -> Bool) -> Iterator.Element? {
    for element in self {
      if closure(element) {
        return element
      }
    }
    
    return nil
  }
  #endif
}


class ExtendsNode : NodeType {
  let templateName: Variable
  let blocks: [String:BlockNode]
  
  class func parse(parser: TokenParser, token: Token) throws -> NodeType {
    let bits = token.components()
    
    guard bits.count == 2 else {
      throw TemplateSyntaxError("'extends' takes one argument, the template file to be extended")
    }
    
    let parsedNodes = try parser.parse()
    guard (parsedNodes.any { $0 is ExtendsNode }) == nil else {
      throw TemplateSyntaxError("'extends' cannot appear more than once in the same template")
    }
    
    let blockNodes = parsedNodes.filter { node in node is BlockNode }
    
    let nodes = blockNodes.reduce([String:BlockNode]()) { (accumulator, node:NodeType) -> [String:BlockNode] in
      let node = (node as! BlockNode)
      var dict = accumulator
      dict[node.name] = node
      return dict
    }
    
    return ExtendsNode(templateName: Variable(bits[1]), blocks: nodes)
  }
  
  init(templateName: Variable, blocks: [String: BlockNode]) {
    self.templateName = templateName
    self.blocks = blocks
  }
  
  func render(context: Context) throws -> String {
    guard let loader = context["loader"] as? TemplateLoader else {
      throw TemplateSyntaxError("Template loader not in context")
    }
    
    guard let templateName = try self.templateName.resolve(context: context) as? String else {
      throw TemplateSyntaxError("'\(self.templateName)' could not be resolved as a string")
    }
    
    guard let template = loader.loadTemplate(name: templateName) else {
      #if !swift(>=3.0)
        let paths:String = loader.paths.map { $0.description }.joinWithSeparator(", ")
      #else
        let paths:String = loader.paths.map { $0.description }.joined(separator:", ")
      #endif
      throw TemplateSyntaxError("'\(templateName)' template not found in \(paths)")
    }
    
    let blockContext = BlockContext(blocks: blocks)
    return try context.push(dictionary: [BlockContext.contextKey: blockContext]) {
      return try template.render(context: context)
    }
  }
}


class BlockNode : NodeType {
  let name: String
  let nodes: [NodeType]
  
  class func parse(parser: TokenParser, token: Token) throws -> NodeType {
    let bits = token.components()
    
    guard bits.count == 2 else {
      throw TemplateSyntaxError("'block' tag takes one argument, the template file to be included")
    }
    
    let blockName = bits[1]
    let nodes = try parser.parse(until: until(tags: ["endblock"]))
    parser.nextToken()
    return BlockNode(name:blockName, nodes:nodes)
  }
  
  init(name: String, nodes: [NodeType]) {
    self.name = name
    self.nodes = nodes
  }
  
  func render(context: Context) throws -> String {
    if let blockContext = context[BlockContext.contextKey] as? BlockContext, node = blockContext.pop(blockName: name) {
      return try node.render(context: context)
    }
    
    return try renderNodes(nodes: nodes, context)
  }
}
