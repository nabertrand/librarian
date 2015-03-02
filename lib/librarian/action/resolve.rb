require "librarian/resolver"
require "librarian/spec_change_set"
require "librarian/action/base"
require "librarian/action/persist_resolution_mixin"

module Librarian
  module Action
    class Resolve < Base
      include PersistResolutionMixin

      def run
        if force? || !lockfile_path.exist?
          spec = specfile.read
          manifests = []
        else
          lock = lockfile.read
          spec = specfile.read(lock.sources)
          changes = spec_change_set(spec, lock)
          if changes.same?
            debug { "The specfile is unchanged: nothing to do." }
            return
          end
          manifests = changes.analyze
        end

        dupes = spec.dependencies.group_by{ |e| e.name }.select { |k, v| v.size > 1 }
        dupes = Hash[dupes] if dupes.is_a? Array # Ruby 1.8 support
        unless dupes.empty?
          raise Error, "Duplicated dependencies: #{dupes.values.flatten.map {|d| {d.name => d.source.to_s} }}"
        end

        resolution = resolver.resolve(spec, manifests)
        persist_resolution(resolution)
      end

    private

      def force?
        options[:force]
      end

      def resolver
        Resolver.new(environment)
      end

      def spec_change_set(spec, lock)
        SpecChangeSet.new(environment, spec, lock)
      end

    end
  end
end
