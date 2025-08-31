{ lib }:

let
  # Dependency validation and analysis
  validateDependency = dep:
    let
      required = ["name"];
      missing = lib.filter (field: !dep ? ${field}) required;
    in
    if missing != []
    then throw "Dependency missing required fields: ${lib.concatStringsSep ", " missing}"
    else dep;

  # Build dependency graph from chart configurations
  buildDependencyGraph = charts: dependencies:
    let
      # Initialize graph with all charts
      initGraph = lib.mapAttrs (name: _: {
        name = name;
        dependsOn = [];
        dependedBy = [];
      }) charts;

      # Add dependencies
      addDeps = graph: deps:
        lib.foldl (acc: dep:
          let
            validatedDep = validateDependency dep;
            depName = validatedDep.name;
            condition = validatedDep.condition or "true";
          in
          if !acc ? ${depName}
          then throw "Dependency '${depName}' references non-existent chart"
          else acc // {
            ${depName} = acc.${depName} // {
              dependedBy = acc.${depName}.dependedBy ++ [validatedDep];
            };
          } // {
            # Add reverse dependency
            ${validatedDep.dependsOn or "unknown"} = acc.${validatedDep.dependsOn or "unknown"} // {
              dependsOn = acc.${validatedDep.dependsOn or "unknown"}.dependsOn ++ [{
                name = depName;
                condition = condition;
              }];
            };
          }
        ) graph deps;

    in addDeps initGraph dependencies;

  # Detect circular dependencies
  detectCircularDependencies = graph:
    let
      # DFS to detect cycles
      dfs = (visited: recStack: node:
        if lib.elem node recStack
        then throw "Circular dependency detected involving: ${lib.concatStringsSep " -> " (recStack ++ [node])}"
        else if lib.elem node visited
        then visited
        else let
          newRecStack = recStack ++ [node];
          neighbors = lib.map (dep: dep.name) (graph.${node}.dependsOn or []);
          newVisited = lib.foldl (acc: neighbor:
            dfs acc newRecStack neighbor
          ) (visited ++ [node]) neighbors;
        in newVisited
      );

      allNodes = lib.attrNames graph;
    in
    lib.foldl (acc: node: dfs acc [] node) [] allNodes;

  # Topological sort with cycle detection
  topologicalSort = graph:
    let
      # Kahn's algorithm
      kahnSort = (queue: visited: result:
        if queue == []
        then result
        else let
          current = lib.head queue;
          remainingQueue = lib.tail queue;

          # Find nodes that only depend on visited nodes
          candidates = lib.filter (node:
            let deps = graph.${node}.dependsOn or [];
            in lib.all (dep: lib.elem dep.name visited) deps
          ) (lib.attrNames graph);

          newQueue = remainingQueue ++ lib.filter (c: !lib.elem c visited) candidates;
          newVisited = visited ++ [current];
          newResult = result ++ [current];
        in kahnSort newQueue newVisited newResult
      );

      # Start with nodes that have no dependencies
      startNodes = lib.filter (node:
        let deps = graph.${node}.dependsOn or [];
        in deps == []
      ) (lib.attrNames graph);

    in
    if startNodes == []
    then throw "No charts without dependencies found - possible circular dependency"
    else kahnSort startNodes [] [];

  # Evaluate conditional dependencies
  evaluateConditions = dependencies: values:
    lib.filter (dep:
      if dep ? condition
      then let
        # Simple condition evaluation (can be extended)
        condition = dep.condition;
        enabled = values.${condition} or false;
      in enabled
      else true  # No condition means always enabled
    ) dependencies;

  # Resolve all dependencies for a multi-chart configuration
  resolveAllDependencies = charts: dependencies: values:
    let
      # Evaluate conditional dependencies
      activeDeps = evaluateConditions dependencies values;

      # Build graph
      graph = buildDependencyGraph charts activeDeps;

      # Detect cycles
      _ = detectCircularDependencies graph;

      # Sort topologically
      sorted = topologicalSort graph;

    in {
      graph = graph;
      sorted = sorted;
      activeDependencies = activeDeps;
    };

in
{
  inherit
    validateDependency
    buildDependencyGraph
    detectCircularDependencies
    topologicalSort
    evaluateConditions
    resolveAllDependencies;
}