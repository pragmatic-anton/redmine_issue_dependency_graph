require 'redmine'

require_dependency 'issue_dependency_graph/hooks'

Redmine::Plugin.register :redmine_issue_dependency_graph do
  name 'Redmine Issue Dependency Graph Plugin'
  author 'Enguerran P for PopUp House, based on work by Jean-Phillippe Lang (redmine issue #2448), forked from Github user tpip (Robin Schmidtke), forked itself from Github user mpalmer'
  url 'https://github.com/popup-house/redmine_issue_dependency_graph'
  version '0.1.0'

  settings default: { empty: true }, partial: 'settings/dependency_graph_settings'
end
