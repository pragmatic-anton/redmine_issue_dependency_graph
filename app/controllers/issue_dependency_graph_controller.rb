DEPGRAPHLOGGER = Logger.new(Rails.root.join('log/deps.log'))
# DepGraphLogger.debug "RELATION: all_issues_item[#{id.to_i}]"

class IssueDependencyGraphController < ApplicationController
  add_template_helper GraphHelper

  before_action :find_issue_by_id, :authorize, only: [:issue_graph]
  before_action :authorize, except: [:issue_graph]
  helper :issues

  def find_issue_by_id
    DEPGRAPHLOGGER.info 'RELATION: find_issue_by_id()'
    @issue = Issue.find(params[:issue_id]) if params['issue_id']
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def issue_graph
    DEPGRAPHLOGGER.info "RELATION: #{@issue}"
    DEPGRAPHLOGGER.info "RELATION: Params: #{params}"

    all_issues = {}

    if params['issue_id']
      all_issues[@issue.id.to_i] = Issue.find(@issue.id.to_i)
    else
      params['issues'].each do |id|
        all_issues[id.to_i] = Issue.find(id.to_i)
      end
    end

    relevant_issues = []
    relations = []

    allowed_types = {}

    if Setting.plugin_redmine_issue_dependency_graph['show_relates'] then allowed_types['relates'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_duplicates'] then allowed_types['duplicates'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_duplicated'] then allowed_types['duplicated'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_blocks'] then allowed_types['blocks'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_blocked'] then allowed_types['blocked'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_follows'] then allowed_types['follows'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_precedes'] then allowed_types['precedes'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_copied_to'] then allowed_types['copied_to'] = true end
    if Setting.plugin_redmine_issue_dependency_graph['show_copied_from'] then allowed_types['copied_from'] = true end

    IssueRelation.all.each do |ir|
      next unless all_issues[ir.issue_from_id] && all_issues[ir.issue_to_id] && allowed_types[ir.relation_type]

      relations << { from: ir.issue_from_id, to: ir.issue_to_id, type: ir.relation_type }
      relevant_issues << all_issues[ir.issue_from_id]
      relevant_issues << all_issues[ir.issue_to_id]
    end

    if Setting.plugin_redmine_issue_dependency_graph['show_child']
      all_issues.values.each do |i|
        next unless i.parent_id && all_issues[i.id] && all_issues[i.parent_id]

        relations << { from: i.parent_id, to: i.id, type: 'child' }
        relevant_issues << all_issues[i.id]
        relevant_issues << all_issues[i.parent_id]
      end
    end
    DEPGRAPHLOGGER.info "RELATION: relevant_issues: #{relevant_issues}"
    DEPGRAPHLOGGER.info "RELATION: relations: #{relations}"

    render_graph(render_dot_to_string(relevant_issues, relations))
  end

  private

  def render_dot_to_string(issues, relations)
    render_to_string "graph/digraph", layout: false, :formats => [:text], :locals => {:issues => issues, :relations => relations}
  end

  def render_graph(dot_code)
    graph_output = nil
    IO.popen('unflatten | dot -Tsvg ', 'r+') do |io|
      io.binmode
      io.puts dot_code
      io.close_write
      graph_output = io.read
    end
    send_data graph_output, type: 'image/svg+xml', filename: 'graph.svg', disposition: 'inline'
  end

end
