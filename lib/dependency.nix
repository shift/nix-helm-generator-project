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

      # Build graph based on dependency order
      # Assume dependencies are listed in deployment order
      buildGraph = deps:
        let
          # Create a map of chart positions
          depOrder = lib.map (dep: dep.name) deps;
          positions = lib.listToAttrs (
            lib.imap0 (i: name: { name = name; value = i; }) depOrder
          );

          # For each chart, add dependencies on all previous charts
          addDeps = lib.foldl (acc: dep:
            let
              depName = dep.name;
              condition = dep.condition or "true";
              position = positions.${depName} or 0;
              # All charts before this one in the list are dependencies
              prevDeps = lib.take position depOrder;
            in
            lib.foldl (graphAcc: prevDep:
              graphAcc // {
                # Add to current chart's dependsOn
                ${depName} = graphAcc.${depName} // {
                  dependsOn = graphAcc.${depName}.dependsOn ++ [{
                    name = prevDep;
                    condition = condition;
                  }];
                };
                # Add to previous chart's dependedBy
                ${prevDep} = graphAcc.${prevDep} // {
                  dependedBy = graphAcc.${prevDep}.dependedBy ++ [{
                    name = depName;
                    condition = condition;
                  }];
                };
              }
            ) acc prevDeps
          ) initGraph deps;
        in addDeps;

    in buildGraph dependencies;

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
        condition = dep.condition;
        # Handle conditions like "service1.enabled"
        parts = lib.splitString "." condition;
        enabled = if lib.length parts == 2
          then let
            chartName = lib.head parts;
            prop = lib.last parts;
            chartValues = values.${chartName} or {};
          in chartValues.${prop} or true
          else values.${condition} or true;
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