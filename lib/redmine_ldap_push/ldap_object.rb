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
  class LdapObject
    # RDN attribute, used for identifying the ldap entry
    attr_accessor :rdnAttribute
    # id attribute mapped to the redmine object's id
    attr_accessor :idAttribute
    # member attribute for group objects (Group, Projects, ...)
    attr_accessor :memberAttribute
    # LDAP static attributes (eg objectclass...)
    attr_accessor :static_attributes 
    # LDAP dynamic attributes
    attr_accessor :attributes 
    def to_s; "[:#{self.class},id:#{id}]" end
  end
end