require 'redmine'

require_dependency 'issue_dependency_graph/hooks'

Redmine::Plugin.register :redmine_issue_dependency_graph do
  name 'Redmine Issue Dependency Graph Plugin'
  author 'Robin Schmidtke, based on work by Jean-Phillippe Lang (redmine issue #2448), forked from Github user mpalmer'
  version '0.0.2'

  settings default: { empty: true }, partial: 'settings/dependency_graph_settings'
end
