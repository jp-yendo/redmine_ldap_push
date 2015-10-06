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
    module ProjectPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        
        base.class_eval do 
          after_create :rlp_project_created
          after_save :rlp_project_saved
          after_destroy :rlp_project_destroyed
        end
      end

      module InstanceMethods
        
        def rlp_project_created
          LdapPushService.project_created(self)
        end
        
        def rlp_project_saved
          LdapPushService.project_saved(self)          
        end
        
        def rlp_project_destroyed
          LdapPushService.project_destroyed(self)
        end
        
      end      
    end
  end
end