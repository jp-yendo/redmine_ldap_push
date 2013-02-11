# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get "/redmine_ldap_push/check" => "redmine_ldap_push#check"
get "/redmine_ldap_push/save" => "redmine_ldap_push#save"
