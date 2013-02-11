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

module RedmineLdapPush
  class LdapPushService
    @@enabled = false
    
    def self.loadSettings
      settings = Setting.plugin_redmine_ldap_push
      @@enabled = settings['ldap_active'] == 'on'
      return unless @@enabled
      url = settings['ldap_url']
      ldap_base = settings['ldap_base']
      user = settings['ldap_user']
      password = settings['ldap_password']
      tls = settings['ldap_user_tls'] == 'on'
      users_base = settings['ldap_users_base']
      groups_base = settings['ldap_groups_base']
      projects_base = settings['ldap_projects_base']
      @@ldapRepository = LdapRepository.new(url, ldap_base, user, password, tls, users_base, groups_base, projects_base)
      if !@@ldapRepository.test_connection
        Rails.logger.error "[RLP] LDAP connection problem, check your settings"
        Rails.logger.error "[RLP] disabling plugin redmine ldap push!"
      @@enabled = true
      end

    end

    self.loadSettings

    def self.ldapRepository
      @@ldapRepository
    end

    def self.enabled
      @@enabled
    end

    def self.test_connection
      begin
        @@ldapRepository.test_connection
        return 0
      rescue Exception => e
      return e.message
      end
    end

    #################
    # User services #
    #################
    def self.sync_all_users
      # get a set of user ids, omitting empty logins (anonymous user)
      redmineUsers = User.all(:conditions => "login <> ''")
      # get a set of user logins stored in the LDAP server
      ldapUsers = ldapRepository.getAllUserIds

      # update every redmine user...
      for user in redmineUsers
        if ldapUsers.include?(user.id.to_s)
          puts "  - updating user [#{user.login}]"
          self.ldapRepository.updateUser(user)
          ldapUsers.delete(user.id.to_s)
        else
          puts "  - creating user [#{user.login}]"
          self.ldapRepository.createUser(user)
        end      
      end
      # remove ldap users that weren't updated...
      for id in ldapUsers
        dn = self.ldapRepository.findDnById(:ldapObjectClass => RedmineLdapPush::LdapUser, :id => id)
        puts "  - removing entry [#{dn}]"
        self.ldapRepository.deleteByDn(dn)
      end
    end

    def self.user_created(user)
      return unless @@enabled
      Rails.logger.info "[RLP] user_created:#{user.login} id:#{user.id}"
      self.ldapRepository.createUser(user)
    end

    def self.user_saved(user)
      return unless @@enabled
      Rails.logger.info "[RLP] user_saved:#{user.login} id:#{user.id}"
      self.ldapRepository.updateUser(user)
    end

    def self.user_destroyed(user)
      return unless @@enabled
      Rails.logger.info "[RLP] user_destroyed:#{user.login} id:#{user.id}"
      self.ldapRepository.deleteUser(user)
    end

    def self.user_password_updated(user, password)
      return unless @@enabled
      Rails.logger.info "[RLP] user_password_updated:#{user.login} id:#{user.id}"
      self.ldapRepository.updateUserPassword(user, password)
    end

    ##################
    # Group services #
    ##################
    def self.sync_all_groups
      redmineGroups = Group.all
      ldapGroups = ldapRepository.getAllGroupIds

      for group in redmineGroups
        puts "  - updating group [#{group.name}]"
        self.ldapRepository.deleteGroup(group)
        self.ldapRepository.createGroup(group)
        if group.users.count > 0
          print_and_flush "    - adding users: "
          for user in group.users
            print_and_flush "#{user.login} "
            self.ldapRepository.addUserInGroup(user, group)
          end
          puts ""
        end
        ldapGroups.delete(group.id.to_s)
      end
      
      for id in ldapGroups
        dn = self.ldapRepository.findDnById(:ldapObjectClass => RedmineLdapPush::LdapGroup, :id => id)
        puts "  - removing entry [#{dn}]"
        self.ldapRepository.deleteByDn(dn)
      end
    end

    def self.user_added_in_group(user, group)
      return unless @@enabled
      Rails.logger.info "[RLP] user [#{user.login}] added in group [#{group.name} id:#{group.id}]"
      self.ldapRepository.addUserInGroup(user, group)
    end

    def self.user_removed_from_group(user, group)
      return unless @@enabled
      Rails.logger.info "[RLP] user [#{user.login}] removed from group [#{group.name} id:#{group.id}]"
      self.ldapRepository.removeUserFromGroup(user, group)
    end

    def self.group_created(group)
      return unless @@enabled
      Rails.logger.info "[RLP] group_created:#{group.name} id:#{group.id}"
      self.ldapRepository.createGroup(group)
    end

    def self.group_saved(group)
      return unless @@enabled
      Rails.logger.info "[RLP] group_saved:#{group.name} id:#{group.id}"
      self.ldapRepository.updateGroup(group)
    end

    def self.group_destroyed(group)
      return unless @@enabled
      Rails.logger.info "[RLP] group_destroyed:#{group.name} id:#{group.id}"
      self.ldapRepository.deleteGroup(group)
    end

    ####################
    # Project services #
    ####################
    def self.sync_all_projects
      redmineProjects = Project.all
      ldapProjects = ldapRepository.getAllProjectIds
      for project in redmineProjects
        puts "  - updating project [#{project.identifier}]"
        self.ldapRepository.deleteProject(project)
        self.ldapRepository.createProject(project)
        if project.members.count > 0
          print_and_flush "    - adding users: " unless project.members.count == 0
          for member in project.members
            print_and_flush "#{member.user.login} "
            self.ldapRepository.addUserInProject(member.user, project)
          end
          puts ""
        end
        ldapProjects.delete(project.id.to_s)
      end
      
      for id in ldapProjects
        dn = self.ldapRepository.findDnById(:ldapObjectClass => RedmineLdapPush::LdapProject, :id => id)
        puts "  - removing entry [#{dn}]"
        self.ldapRepository.deleteByDn(dn)
      end
    end

    def self.project_created(project)
      return unless @@enabled
      Rails.logger.info "[RLP] project_created:#{project.name} id:#{project.id}"
      self.ldapRepository.createProject(project)
    end

    def self.project_saved(project)
      return unless @@enabled
      Rails.logger.info "[RLP] project_saved:#{project.name} id:#{project.id}"
      self.ldapRepository.updateProject(project)
    end

    def self.project_destroyed(project)
      return unless @@enabled
      Rails.logger.info "[RLP] project_destroyed:#{project.name} id:#{project.id}"
      self.ldapRepository.deleteProject(project)
    end

    ###############
    # Role events #
    ###############
    def self.role_created(role)
      return unless @@enabled
      Rails.logger.info "[RLP] role_created:#{role.name} id:#{role.id}"
    end

    def self.role_saved(role)
      return unless @@enabled
      Rails.logger.info "[RLP] role_saved:#{role.name} id:#{role.id}"
    end

    def self.role_destroyed(role)
      return unless @@enabled
      Rails.logger.info "[RLP] role_destroyed:#{role.name} id:#{role.id}"
    end

    #################
    # Member events #
    #################
    def self.member_created(member)
      return unless @@enabled
      Rails.logger.info "[RLP] member_created:#{member.name} id:#{member.id}"
      user = User.find(member.user_id)
      project = Project.find(member.project_id)
      self.ldapRepository.addUserInProject(user, project) unless user == nil || project == nil
    end

    def self.member_saved(member)
      return unless @@enabled
      Rails.logger.info "[RLP] member_saved:#{member.name} id:#{member.id}"
      user = User.find(member.user_id)
      project = Project.find(member.project_id)
      self.ldapRepository.addUserInProject(user, project) unless user == nil || project == nil
    end

    def self.member_destroyed(member)
      return unless @@enabled
      Rails.logger.info "[RLP] member_destroyed:#{member.name} id:#{member.id}"
      user = User.find(member.user_id)
      project = Project.find(member.project_id)
      self.ldapRepository.removeUserFromProject(user, project) unless user == nil || project == nil
    end

    def self.print_and_flush(str)
      print str
      $stdout.flush
    end

  end

end