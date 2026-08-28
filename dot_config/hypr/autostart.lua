-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Login session layout: browser on 1, herdr on 2, focus left on 2.
-- The `[workspace N ...]` prefix is an exec rule, matched on the spawned pid,
-- and survives the uwsm-app wrapper that o.launch() adds. `silent` places the
-- window without pulling focus; the terminal omits it so it ends up focused.
o.exec_on_start("[workspace 1 silent] " .. o.launch("chromium"))
o.exec_on_start("[workspace 2] " .. o.launch("foot herdr"))
