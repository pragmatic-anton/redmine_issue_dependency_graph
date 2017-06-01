DepGraphLogger = Logger.new(Rails.root.join('log/deps.log'))
#DepGraphLogger.debug "RELATION: all_issues_item[#{id.to_i}]"

class IssueDependencyGraphController < ApplicationController
	unloadable

	before_filter :find_issue_by_id, :authorize, :only => [:issue_graph]
	before_filter :authorize, :except => [:issue_graph]
	helper :issues

	def find_issue_by_id
		DepGraphLogger.info "RELATION: find_issue_by_id()"
		if params["issue_id"] then
			@issue = Issue.find(params[:issue_id])
		end
	rescue ActiveRecord::RecordNotFound
		render_404
	end

	def issue_graph()
	DepGraphLogger.info "RELATION: #{@issue}"
	DepGraphLogger.info "RELATION: Params: #{params}"

	all_issues = {}

	if params["issue_id"] then
		all_issues[@issue.id.to_i] = Issue.find(@issue.id.to_i)
	else
		params["issues"].each do |id|
		all_issues[id.to_i] = Issue.find(id.to_i)
		end
	end

	relevant_issues = []
	relations = []

	allowed_types = {}

	if Setting.plugin_redmine_issue_dependency_graph["show_relates"] then allowed_types['relates'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_duplicates"] then allowed_types['duplicates'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_duplicated"] then allowed_types['duplicated'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_blocks"] then allowed_types['blocks'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_blocked"] then allowed_types['blocked'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_follows"] then allowed_types['follows'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_precedes"] then allowed_types['precedes'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_copied_to"] then allowed_types['copied_to'] = true end
	if Setting.plugin_redmine_issue_dependency_graph["show_copied_from"] then allowed_types['copied_from'] = true end


	IssueRelation.all.each do |ir|
		if all_issues[ir.issue_from_id] and all_issues[ir.issue_to_id] and allowed_types[ir.relation_type]
			relations << { :from => ir.issue_from_id, :to => ir.issue_to_id, :type => ir.relation_type }
			relevant_issues << all_issues[ir.issue_from_id]
			relevant_issues << all_issues[ir.issue_to_id]
		end
	end

	if Setting.plugin_redmine_issue_dependency_graph["show_child"] then
			all_issues.values.each do |i|
				if i.parent_id and all_issues[i.id] and all_issues[i.parent_id]
					relations << { :from => i.parent_id, :to => i.id, :type => 'child' }
					relevant_issues << all_issues[i.id]
					relevant_issues << all_issues[i.parent_id]
				end
			end
	end
		DepGraphLogger.info "RELATION: relevant_issues: #{relevant_issues}"
		DepGraphLogger.info "RELATION: relations: #{relations}"

		render_graph(relevant_issues, relations)
	end


	private
	def render_graph(issues, relations)
		png = nil

		IO.popen("unflatten | dot -Tpng", "r+") do |io|
			io.binmode
			io.puts "digraph redmine {"

            io.puts "subgraph cluster_01 { label = \"Ticketbeziehungen:\""

			issues.uniq.each do |i|
				colour = i.closed? ? 'grey' : 'black'
                state = IssueStatus.find(Issue.find(i.id).status_id).name
                percent = Issue.find(i.id).done_ratio.to_s
				io.puts "#{i.id} [label=\"{ #{i.tracker.name}: ##{i.id} | #{state}, #{percent}% done | #{render_title(i)}\n}\" shape=Mrecord, fontcolor=#{colour}]"
			end

			relations.each do |ir|
				io.puts case ir[:type]
					when 'blocks'   then "#{ir[:to]} -> #{ir[:from]} [style=solid,  color=red dir=back]"
                    when 'child'    then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=gray dir=back]"
					when 'precedes' then "#{ir[:from]} -> #{ir[:to]} [style=solid,  color=black dir=from]"
					when 'relates'  then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=black dir=none]"
                    when 'duplicates' then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=blue dir=from]"
                    when 'duplicated' then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=blue dir=back]"
                    when 'copied_to' then "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=from]"
                    when 'copied_from' then "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=back]"
					else "#{ir[:from]} -> #{ir[:to]} [style=bold, color=pink]"
				end
			end
            io.puts "}"

            #make the Graph Key:
            io.puts "subgraph cluster_02 {
                    label = \"Legende:\"
                    Vater [label=\"{ Ticket| Task\n}\" shape=Mrecord, fontcolor=black]
                    Kind [label=\"{ Ticket| Subtask\n}\" shape=Mrecord, fontcolor=black]
                    Vorgaenger [label=\"{ Ticket| geht vor\n}\" shape=Mrecord, fontcolor=black]
                    Nachfolger [label=\"{ Ticket| folgt\n}\" shape=Mrecord, fontcolor=black]
                    Blockierer [label=\"{ Ticket| blockiert\n}\" shape=Mrecord, fontcolor=black]
                    Blockierter [label=\"{ Ticket| wird\\ngeblockt\n}\" shape=Mrecord, fontcolor=black]
                    Duplikator [label=\"{ Ticket| dupliziert\n}\" shape=Mrecord, fontcolor=black]
                    Duplizierter [label=\"{ Ticket| Original\n}\" shape=Mrecord, fontcolor=black]
                    Kopierer [label=\"{ Ticket| kopiert\n}\" shape=Mrecord, fontcolor=black]
                    Kopierter [label=\"{ Ticket| Original\n}\" shape=Mrecord, fontcolor=black]
                    beziehung1 [label=\"{ Ticket| hat\\nbeziehung\\nzu\n}\" shape=Mrecord, fontcolor=black]
                    beziehung2 [label=\"{ Ticket| hat\\nbeziehung\\nzu\n}\" shape=Mrecord, fontcolor=black]

                    Vater -> Kind [style=dotted, color=gray dir=back]
                    Vorgaenger -> Nachfolger [style=solid, color=black dir=from]
                    Blockierter -> Blockierer [style=solid, color=red, dir=back]
                    Duplikator -> Duplizierter [style=dotted, color=blue, dir=from]
                    Kopierer -> Kopierter [style=solid, color=blue, dir=from]
                    beziehung1 -> beziehung2 [style=dotted, color=black, dir=none]
                  }"

			io.puts "}"
			io.close_write
			png = io.read
		end
		send_data png, :type => 'image/png', :filename => 'graph.png', :disposition => 'inline'
	end

	def render_title(i)
		i.subject.chomp.gsub(/((?:[^ ]+ ){4})/, "\\1\\n").gsub('"', '\\"')
	end
end
