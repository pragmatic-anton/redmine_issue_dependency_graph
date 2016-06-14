class IssueDependencyGraphController < ApplicationController
	unloadable

	def issue_graph()
        all_issues = {}
        params["issues"].each do |id|
            all_issues[id.to_i] = Issue.find(id.to_i)
        end

		relevant_issues = []
		relations = []

        allowed_types = {}

        if Setting.plugin_redmine_issue_dependency_graph["show_relates"] then allowed_types['relates'] = true end
        if Setting.plugin_redmine_issue_dependency_graph["show_dublicates"] then allowed_types['dublicates'] = true end
        if Setting.plugin_redmine_issue_dependency_graph["show_dublicated"] then allowed_types['dublicated'] = true end
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

     	render_graph(relevant_issues, relations)
	end


	private
	def render_graph(issues, relations)
		png = nil

		IO.popen("unflatten | dot -Tpng", "r+") do |io|
			io.binmode
			io.puts "digraph redmine {"

			issues.uniq.each do |i|
				colour = i.closed? ? 'grey' : 'black'
				io.puts "#{i.id} [label=\"{<f0> #{i.tracker.name}: ##{i.id}|<f1> #{render_title(i)}\n}\" shape=Mrecord, fontcolor=#{colour}]"
			end

			relations.each do |ir|
				io.puts case ir[:type]
					when 'blocks'   then "#{ir[:to]} -> #{ir[:from]} [style=solid,  color=red dir=back]"
					when 'precedes' then "#{ir[:to]} -> #{ir[:from]} [style=solid,  color=blue dir=back]"
					when 'relates'  then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=blue dir=none]"
					when 'follows'  then "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=blue dir=none]"
					else "#{ir[:from]} -> #{ir[:to]} [style=bold, color=pink]"
				end
			end
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
