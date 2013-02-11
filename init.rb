#    This file is part of redmine_ldap_push.
#
#    redmine_ldap_push is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    redmine_ldap_push is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with redmine_ldap_push.  If not, see <http://www.gnu.org/licenses/>.

require 'redmine'

Redmine::Plugin.register :redmine_ldap_push do
  name 'Redmine - Ldap Push'
  author 'Antoine Lecouey'
  author_url 'mailto:Antoine Lecouey <antoine.lecouey@gmail.com>?subject=redmine_ldap_push'
  description 'Push Redmine users/groups/projects memberships to a ldap server'
  version '0.0.1'
  requires_redmine :version_or_higher => '2.0.0'
  url ''
  
  #settings :default =>  HashWithIndefferentAccess.new(), :partial => 'settings/ldap_push_settings'
  settings :default => {  'ldap_active' => 'false',
                          'ldap_url' => 'http://localhost:389', 
                          'ldap_use_tls' => 'false',
                          'ldap_base' => 'dc=localhost',
                          'ldap_user' => 'cn=admin,dc=localhost',
                          'ldap_password' => '',
                          'ldap_users_base_dn' => 'ou=users',
                          'ldap_groups_base_dn' => 'ou=groups',
                          'ldap_projects_base_dn' => 'ou=projects',
                           }, :partial => 'settings/ldap_push_settings'
end


RedmineApp::Application.config.after_initialize do
  require 'project'
  # Settings
  #unless SettingsHelper.include? RedmineLdapPush::RedmineExt::SettingsHelperPatch
  #  SettingsHelper.send(:include, RedmineLdapPush::RedmineExt::SettingsHelperPatch)
  #end

  # User events
  unless User.include? RedmineLdapPush::RedmineExt::UserPatch
    User.send(:include, RedmineLdapPush::RedmineExt::UserPatch)
  end
  
  # Group events
  unless Group.include? RedmineLdapPush::RedmineExt::GroupPatch
    Group.send(:include, RedmineLdapPush::RedmineExt::GroupPatch)
  end
  
  # Project events (only create/update/delete)
  unless Project.include? RedmineLdapPush::RedmineExt::ProjectPatch
    Project.send(:include, RedmineLdapPush::RedmineExt::ProjectPatch)
  end
  
  # Project membership events
  unless Member.include? RedmineLdapPush::RedmineExt::MemberPatch
    Member.send(:include, RedmineLdapPush::RedmineExt::MemberPatch)
  end
  # TODO : try to sync roles...
  #unless Role.include? RedmineLdapPush::RedmineExt::RolePatch
  #  Role.send(:include, RedmineLdapPush::RedmineExt::RolePatch)
  #end
  
end

