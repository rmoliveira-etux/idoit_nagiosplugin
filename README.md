# idoit_nagiosplugin
nagios plugin for tenant licenses monitoring
As of right now, it's specific for multi-tenant setups; maybe in the future it can be smarter and detect single or multi-tenant setups, and act accordingly.
supports i-doit PRO 1.15.2

CONFIGURATION:
- get your idoit main database (typically  idoit_system)
- create a read-only user for all of idoit's databases on MySQL
- define parameters accordingly

