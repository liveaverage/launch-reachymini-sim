# Jupyter Lab Configuration for Reachy Mini Simulation Container
# Purpose: Configure Jupyter for easy demo access (no token/password)

c = get_config()  # noqa: F821

# Server settings
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True

# Disable authentication for demo ease
# WARNING: Only use in controlled/demo environments
c.ServerApp.token = ''
c.ServerApp.password = ''

# Allow connections from any origin (for remote access)
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True

# Disable XSRF for simpler API access
c.ServerApp.disable_check_xsrf = True

# Working directory
c.ServerApp.root_dir = '/workspace'

# Terminal settings
c.ServerApp.terminals_enabled = True

