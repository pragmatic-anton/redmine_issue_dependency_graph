# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
# resources :watchers do
#   member do
#     get 'preview_watchers'
#   end
# end
match 'issue_graph', :to => 'issue_dependency_graph#issue_graph', :as => 'issue_graph', :via => :get
