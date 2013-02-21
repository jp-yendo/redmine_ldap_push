Redmine LDAP Push
=================

The plugin tracks changes affecting users, groups or projects and propagates it simultaneously to a Ldap server. 
This « enslaved » Ldap server can thus be used for authentication purpose (auth. centralization, SSO) while managing 
the user's roles and project memberships with Redmine.

Usage
-----
Open the configuration from the Administration > Plugins page.

 * Active : check it to enable the synchronization
 * Ldap base : your LDAP base tree (e.g. dc=localhost)
 * User TLS? : check it to secure the communication between Redmine and LDAP
 * User DN : user's distinguished name used by the plugin to write in the LDAP, generally something like cn=admin,(your ldap base)
 * Password : the user's password
 * Ldap users base DN : the tree base in which the users will be stored, relative to the LDAP base
 * Ldap groups base DN : the tree base in which the groups will be stored, relative to the LDAP base
 * Ldap projects base DN : the tree base in which the projects will be stored, relative to the LDAP base

Warning : the plugin has only been tested with OpenLDAP!

LDAP synchronization
--------------------

__User synchronization__:

Each time a user is created, updated or deleted, the modification is propagated to the configured LDAP server.
In LDAP, users are stored as inetOrgPerson and posixAccount objects and distinguished by their UID attribute. 
Here are the current mappings between Redmine fields and the LDAP attributes of an user :

<table>
  <tr><td>login</td><td>UID</td></tr>
  <tr><td>first name</td><td>givenName</td></tr>
  <tr><td>last name</td><td>SN</td></tr>
  <tr><td>email</td><td>mail</td></tr>
  <tr><td>password</td><td>userPassword [stored in Secure SHA]</td></tr>
  <tr><td>internal id</td><td>uidNumber [stored for sync. purposes]</td></tr>
</table>

__Group synchronization__:

Groups inherit from posixGroup and are distinguished by their CN attribute :

<table>
  <tr><td>name</td><td>CN</td></tr>
  <tr><td>members</td><td>memberUid [containing user's full DNs]</td></tr>
  <tr><td>internal id</td><td>gidNumber</td></tr>
</table>

__Project synchronization__:

Projects inherit from posixGroup and uidObject and are distinguished by their `CN` attribute :

<table>
  <tr><td>name</td><td>CN</td></tr>
  <tr><td>identifier</td><td>UID</td></tr>
  <tr><td>description</td><td>description</td></tr>
  <tr><td>members</td><td>memberUid</td></tr>
  <tr><td>internal id</td><td>gidNumber</td></tr>
</table>

