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
    module UserPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        #base.send(:include, ClassMethods)
        
        base.class_eval do 
          alias_method_chain :check_password?, :redmine_ldap_push
          #alias_method_chain :try_to_login, :redmine_ldap_push
          
          after_create :rlp_user_created
          after_save :rlp_user_saved
          after_destroy :rlp_user_destroyed
        end
      end

      module ClassMethods
        
        def self.try_to_login_with_redmine_ldap_push(login, password)
          # regular login
          user = self.try_to_login_without_redmine_ldap_push(login, password)
          # if login was successful, sync the password while it's in clear text
          if user != nil
            LdapPushService.update_user_password(user, password)
          end
          return user
        end
        
      end


      module InstanceMethods
        
        def check_password_with_redmine_ldap_push?(clear_password)
          passwordOk = check_password_without_redmine_ldap_push?(clear_password)
          if passwordOk
            LdapPushService.user_password_updated(self, clear_password)
          end
          return passwordOk
        end
        
        def rlp_user_created
          LdapPushService.user_created(self)
        end
        
        def rlp_user_saved
          LdapPushService.user_saved(self)          
        end
        
        def rlp_user_destroyed
          LdapPushService.user_destroyed(self)
        end
        
      end      
    end
  end
end