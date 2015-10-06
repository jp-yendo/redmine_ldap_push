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
  module RedmineExt
    module GroupPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        
        base.class_eval do 
          after_create :rlp_group_created
          after_save :rlp_group_saved
          after_destroy :rlp_group_destroyed
          
          alias_method_chain :user_added, :redmine_ldap_push
          alias_method_chain :user_removed, :redmine_ldap_push
          
        end
      end

      module InstanceMethods
        
        def user_added_with_redmine_ldap_push(user)
          Rails.logger.debug "[RLP] [GroupPatch] User [#{user.login}] added to group [#{self.name}]"
          user_added_without_redmine_ldap_push(user)
          LdapPushService.user_added_in_group(user, self)
        end
        
        def user_removed_with_redmine_ldap_push(user)
          Rails.logger.info "[RLP] [GroupPatch] User [#{user.login}] removed from group [#{self.name}]"
          user_removed_without_redmine_ldap_push(user)
          LdapPushService.user_removed_from_group(user, self)
        end
        
        def rlp_group_created
          Rails.logger.info "[RLP] [GroupPatch] Group [#{self.name}] created"
          LdapPushService.group_created(self)
        end
        
        def rlp_group_saved
          Rails.logger.info "[RLP] [GroupPatch] Group [#{self.name}] saved"
          LdapPushService.group_saved(self)          
        end
        
        def rlp_group_destroyed
          Rails.logger.info "[RLP] [GroupPatch] Group [#{self.name}] destroyed"
          LdapPushService.group_destroyed(self)
        end
        
      end      
    end
  end
end