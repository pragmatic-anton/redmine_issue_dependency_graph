module GraphHelper

  def render_issue_node(i, highlight)
    colour = i.closed? ? 'grey' : 'black'
    state = IssueStatus.find(Issue.find(i.id).status_id).name
    percent = Issue.find(i.id).done_ratio.to_s
    n = "#{i.id} [label=\"{ ##{i.id}  #{render_title(i)} | #{i.tracker.name}, #{state}, #{percent}% done \n}\" shape=Mrecord fontcolor=#{colour}  "
    n += " color=cyan "  if highlight.include? i.id
    n += "href=\"/issues/#{i.id}\""
    n += "]"
  end

  def render_title(i)
    i.subject
        .chomp
        .gsub(/((?:[^ ]+ ){4})/, '\\1\\n') # split by 4 words
        .gsub('"', '\\"')
  end

  def render_relation(ir)
    case ir[:type]
    when 'blocks' then
      "#{ir[:from]} -> #{ir[:to]} [style=solid,  color=red dir=back]"
    when 'child' then
      "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=gray dir=back]"
    when 'precedes' then
      "#{ir[:from]} -> #{ir[:to]} [style=solid,  color=black dir=from]"
    when 'relates' then
      "#{ir[:from]} -> #{ir[:to]} [style=dotted, color=black dir=none]"
    when 'duplicates' then
      "#{ir[:to]} -> #{ir[:from]} [style=dotted, color=blue dir=back]"
    when 'duplicated' then
      "#{ir[:to]} -> #{ir[:from]} [style=dotted, color=blue dir=from]"
    when 'copied_to' then
      "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=from]"
    when 'copied_from' then
      "#{ir[:from]} -> #{ir[:to]} [style=solid, color=blue dir=back]"
    else
      "#{ir[:from]} -> #{ir[:to]} [style=bold, color=pink]"
    end
  end

end