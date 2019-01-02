DEPGRAPHLOGGER = Logger.new(Rails.root.join('log/deps.log'))
# DepGraphLogger.debug "RELATION: all_issues_item[#{id.to_i}]"

class IssueDependencyGraphController < ApplicationController
  unloadable

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

    render_graph(relevant_issues, relations)
  end

  private

  def render_graph(issues, relations)
    graph_output = nil

    IO.popen('unflatten | dot -Tsvg', 'r+') do |io|
      io.binmode
      io.puts 'digraph redmine {'

      io.puts 'subgraph cluster_01 { label = "Issue dependencies:"'

      issues.uniq.each do |i|
        colour = i.closed? ? 'grey' : 'black'
        state = IssueStatus.find(Issue.find(i.id).status_id).name
        percent = Issue.find(i.id).done_ratio.to_s
        io.puts "#{i.id} [label=\"{ #{i.tracker.name}: ##{i.id} | #{state}, #{percent}% done | #{render_title(i)}\n}\" shape=Mrecord, fontcolor=#{colour}]"
      end

      relations.each do |ir|
        io.puts case ir[:type]
                when 'blocks'   then "#{ir[:from]} -> #{ir[:to]} [style=solid,  color=red dir=back]"
                when 'child'    then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=gray dir=back]"
                when 'precedes' then "#{ir[:from]} -> #{ir[:to]} [style=solid,  color=black dir=from]"
                when 'relates'  then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=black dir=none]"
                when 'duplicates' then "#{ir[:to]} -> #{ir[:from]} [style=dotted, color=blue dir=back]"
                when 'duplicated' then "#{ir[:to]} -> #{ir[:from]} [style=dotted, color=blue dir=from]"
                when 'copied_to' then "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=from]"
                when 'copied_from' then "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=back]"
                else "#{ir[:from]} -> #{ir[:to]} [style=bold, color=pink]"
        end
      end
      io.puts '}'

      # make the Graph Key:
      io.puts "subgraph cluster_02 {
              label = \"Caption:\"
              Parent [label=\"{ Issue| Task\n}\" shape=Mrecord, fontcolor=black]
              Child [label=\"{ Issue| Subtask\n}\" shape=Mrecord, fontcolor=black]
              Predecessor [label=\"{ Issue| Precedes\n}\" shape=Mrecord, fontcolor=black]
              Successor [label=\"{ Issue| Follows\n}\" shape=Mrecord, fontcolor=black]
              Blocker [label=\"{ Issue| Blocks\n}\" shape=Mrecord, fontcolor=black]
              Blocked [label=\"{ Issue| Blocked by\n}\" shape=Mrecord, fontcolor=black]
              Duplicator [label=\"{ Issue| Has duplicate\n}\" shape=Mrecord, fontcolor=black]
              Duplicate [label=\"{ Issue| Is duplicate of\n}\" shape=Mrecord, fontcolor=black]
              Copier [label=\"{ Issue| Copied to\n}\" shape=Mrecord, fontcolor=black]
              Copied [label=\"{ Issue| Copied from\n}\" shape=Mrecord, fontcolor=black]
              Relationship1 [label=\"{ Issue| Related to\n}\" shape=Mrecord, fontcolor=black]
              Relationship2 [label=\"{ Issue| Related to\n}\" shape=Mrecord, fontcolor=black]

              Parent -> Child [style=dotted, color=gray dir=back]
              Predecessor -> Successor [style=solid, color=black dir=from]
              Blocker -> Blocked [style=solid, color=red, dir=back]
              Duplicator -> Duplicate [style=dotted, color=blue, dir=back]
              Copier -> Copied [style=solid, color=blue, dir=from]
              Relationship1 -> Relationship2 [style=dotted, color=black, dir=none]
            }"

      io.puts '}'
      io.close_write
      graph_output = io.read
    end
    send_data graph_output, type: 'image/svg+xml', filename: 'graph.svg', disposition: 'inline'
  end

  def render_title(i)
    i.subject.chomp.gsub(/((?:[^ ]+ ){4})/, '\\1\\n').gsub('"', '\\"')
  end
end
