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
  # LDAP helper for remine's Project Model class
  class LdapProject < LdapObject
    @@static_attributes = {
      :objectclass => ["top", "posixGroup", "uidObject"],
    }
    @@rdnAttribute = :cn
    @@idAttribute = :gidnumber
    @@memberAttribute = :memberuid
    def initialize(project)
      @rdn = "#{project.name}"
      @attributes = {
        :gidnumber => "#{project.id}",
        :uid => "#{project.identifier}"
      }
      if !project.description.empty?
        @attributes[:description] = "#{project.description}"
      end
    end
    def rdnAttribute; @@rdnAttribute end
    def self.rdnAttribute; @@rdnAttribute end
    def idAttribute; @@idAttribute end
    def self.idAttribute; @@idAttribute end
    def rdn; @rdn end
    def id; @attributes[@@idAttribute] end
    def memberAttribute; @@memberAttribute end
    def self.memberAttribute; @@memberAttribute end
    def static_attributes; @@static_attributes end
    def attributes; @attributes end
  end
end