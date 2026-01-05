# frozen_string_literal: true

module Scrub
  class TableConfig
    attr_reader :name, :columns

    def initialize(name)
      @name = name.to_s
      @columns = {}
    end

    def column(name, type = nil, **options)
      if type
        options[:type] = type
      end
      @columns[name.to_s] = ColumnConfig.new(name, **options)
    end

    # Returns columns sorted by dependency order
    def sorted_columns
      tsort_hash = {}
      @columns.each do |name, config|
        tsort_hash[name] = config.dependencies & @columns.keys
      end

      # Simple topological sort
      sorted = []
      visited = {}
      recursion_stack = {}

      visit = lambda do |node|
        return if visited[node]
        raise "Circular dependency detected: #{node}" if recursion_stack[node]

        recursion_stack[node] = true
        (tsort_hash[node] || []).each do |dep|
          visit.call(dep)
        end
        visited[node] = true
        recursion_stack[node] = false
        sorted << node
      end

      @columns.keys.each do |node|
        visit.call(node)
      end

      sorted.map { |name| @columns[name] }
    end
  end
end
