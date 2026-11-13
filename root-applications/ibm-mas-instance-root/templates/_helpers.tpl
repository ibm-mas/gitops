{{- /*
Returns the ArgoCD sync-wave for one step of a MAS application's "block".

Each MAS application is deployed as a contiguous block, in this order:
  pdb     -> primary Db2 database (non-sdb instance)
  jdbc    -> in-cluster Db2 JDBC config (JdbcCfg) of the app, so it exists before the app install
  install -> MAS application install
  config  -> MAS application workspace config (e.g. ManageWorkspace)
  sdb     -> standby Db2 database (sdb instance)
Blocks are ordered: manage, facilities, monitor/iot, health, assist, visualinspection, optimizer, predict.
Addons config (551) and RBAC / post-sync jobs (600) run after all blocks.

Block base waves (pdb = base, jdbc = base+1, install = base+2, config = base+3, sdb = base+4):
  manage 500 (its pdb stays at 120 so it is ready ahead of the suite and workspaces),
  facilities 505, monitor/iot 510 then 515, health 520, assist 525, visualinspection 530,
  optimizer 535, predict 540

Monitor/iot keep the channel-aware order used on main: when the Monitor or IoT channel is >= 9.2,
Monitor goes first (510) and IoT second (515), otherwise IoT first (510) and Monitor second (515).

Arguments (dict): root = chart root context ($), app = mas app id, step = pdb|jdbc|install|config|sdb
For an app without a block: pdb returns 120, sdb returns 549 and jdbc/install/config return nothing.
*/}}
{{- define "ibm-mas-instance-root.syncwave" -}}
{{- $app := .app | default "" -}}
{{- $monitorFirst := false -}}
{{- range $cfg := list .root.Values.ibm_suite_app_monitor_install .root.Values.ibm_suite_app_iot_install -}}
  {{- if and $cfg $cfg.mas_app_channel -}}
    {{- $version := regexFind `^[0-9]+\.[0-9]+` ($cfg.mas_app_channel | toString) -}}
    {{- if $version -}}
      {{- $parts := splitList "." $version -}}
      {{- $major := index $parts 0 | int -}}
      {{- $minor := index $parts 1 | int -}}
      {{- if or (gt $major 9) (and (eq $major 9) (ge $minor 2)) -}}
        {{- $monitorFirst = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $bases := dict "manage" 500 "facilities" 505 "health" 520 "assist" 525 "visualinspection" 530 "optimizer" 535 "predict" 540 -}}
{{- if $monitorFirst -}}
  {{- $_ := set $bases "monitor" 510 -}}
  {{- $_ := set $bases "iot" 515 -}}
{{- else -}}
  {{- $_ := set $bases "iot" 510 -}}
  {{- $_ := set $bases "monitor" 515 -}}
{{- end -}}
{{- $offsets := dict "pdb" 0 "jdbc" 1 "install" 2 "config" 3 "sdb" 4 -}}
{{- if and (eq $app "manage") (eq .step "pdb") -}}
120
{{- else if hasKey $bases $app -}}
{{ add (get $bases $app) (get $offsets .step) }}
{{- else if eq .step "pdb" -}}
120
{{- else if eq .step "sdb" -}}
549
{{- end -}}
{{- end -}}
