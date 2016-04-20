public class Namespace {
  public typealias TagParser = (TokenParser, Token) throws -> NodeType
  
  var tags = [String: TagParser]()
  var filters = [String: Filter]()
  
  public init() {
    registerDefaultTags()
    registerDefaultFilters()
  }
  
  private func registerDefaultTags() {
    registerTag(name: "for", parser: ForNode.parse)
    registerTag(name: "if", parser: IfNode.parse)
    registerTag(name: "ifnot", parser: IfNode.parse_ifnot)
    #if !os(Linux)
      registerTag(name: "now", parser: NowNode.parse)
    #endif
    registerTag(name: "include", parser: IncludeNode.parse)
    registerTag(name: "extends", parser: ExtendsNode.parse)
    registerTag(name: "block", parser: BlockNode.parse)
  }
  
  private func registerDefaultFilters() {
    registerFilter(name: "capitalize", filter: capitalise)
    registerFilter(name: "uppercase", filter: uppercase)
    registerFilter(name: "lowercase", filter: lowercase)
  }
  
  /// Registers a new template tag
  public func registerTag(name: String, parser: TagParser) {
    tags[name] = parser
  }
  
  /// Registers a simple template tag with a name and a handler
  public func registerSimpleTag(name: String, handler: Context throws -> String) {
    registerTag(name: name, parser: { parser, token in
      return SimpleNode(handler: handler)
    })
  }
  
  /// Registers a template filter with the given name
  public func registerFilter(name: String, filter: Filter) {
    filters[name] = filter
  }
}
