{% set qubes_master_key_fpr = '427F11FD0FAA4B080123F01CDDFA1A3E36879494' %}
{% set commands_keyring = '/home/user/.config/qubes-builder-github/trusted-keys-for-commands.gpg' %}

{% set env = grains['id']|replace('build-','') %}
{% set builders_list = salt['pillar.get']('build-infra:build-envs:' + env + ':builders-list').keys() %}
{% set last_builder_dir = builders_list|last %}

/usr/local/etc/qubes-rpc/qubesbuilder.CopyTemplateBack:
  file.symlink:
    - target: {{ last_builder_dir }}/rpc-services/qubesbuilder.CopyTemplateBack
    - force: True
    - mode: 0775
    - makedirs: True

/usr/local/etc/qubes-rpc/qubesbuilder.TriggerBuild:
  file.symlink:
    - target: {{ last_builder_dir }}/qubes-src/builder-github/rpc-services/qubesbuilder.TriggerBuild
    - force: True
    - mode: 0755
    - makedirs: True

/usr/local/etc/qubes-rpc/qubesbuilder.ProcessGithubCommand:
  file.symlink:
    - target: {{ last_builder_dir }}/qubes-src/builder-github/rpc-services/qubesbuilder.ProcessGithubCommand
    - force: True
    - mode: 0755
    - makedirs: True

/usr/local/lib/qubes-builder-github:
  file.symlink:
    - target: {{ last_builder_dir }}/qubes-src/builder-github/lib
    - force: True
    - mode: 0755
    - makedirs: True

/home/user/.config/qubes-builder-github/builders.list:
  file.managed:
    - mode: 0644
    - user: user
    - contents: |
{%- for builder in builders_list %}
        r{{ salt['pillar.get']('build-infra:build-envs:'+ env + ':builders-list:' + builder + ':release') }}={{ builder }}
{%- endfor %}
    - makedirs: True

/rw/config/gpg-split-domain:
  file.managed:
    - contents:
      - {{ grains['id']|replace('build-', 'keys-') }}
    - mode: 0644
    - user: user

/home/user/.rpmmacros:
  file.managed:
    - source: salt://build-infra/rpmmacros
    - mode: 0644
    - user: user
    - group: user

/home/user/qubes-master-key.asc:
  file.managed:
    - source: salt://build-infra/qubes-master-key.asc
    - user: user

# populate keys to ease qubes-builder verification
gpg --import /home/user/qubes-master-key.asc:
  cmd.run:
    - runas: user
    - onchange:
      - file: /home/user/qubes-master-key.asc

{{qubes_master_key_fpr}}:
  gpg.present:
    - user: user

echo {{qubes_master_key_fpr}}:6 | gpg --import-ownertrust && gpg --check-trustdb:
  cmd.run:
    - runas: user
    - require:
      - gpg: {{qubes_master_key_fpr}}

/home/user/qubes-developers-keys.asc:
  file.managed:
    - source: salt://build-infra/qubes-builder/qubes-developers-keys.asc
    - user: user

gpg --import /home/user/qubes-developers-keys.asc:
  cmd.run:
    - runas: user
    - onchange:
      - file: /home/user/qubes-developers-keys.asc

/home/user/builder-github.conf:
  file.managed:
    - source: salt://build-infra/builder-github.conf
    - template: jinja
    - user: user
    - mode: 0600

/home/user/github-notify-state:
  file.directory:
    - makedirs: True
    - user: user
    - mode: 0755

/home/user/trusted-keys-for-commands.asc:
  file.managed:
    - contents_pillar: build-infra:commands_public_keys
    - user: user
    - mode: 0644

/usr/local/bin/builder-cleanup:
  file.managed:
    - source: salt://build-infra/builder-cleanup
    - mode: 0755

/home/user/.config/systemd/user/builder-cleanup.service:
  file.managed:
    - source: salt://build-infra/builder-cleanup.service
    - mode: 0644
    - user: user
    - makedirs: true

/home/user/.config/systemd/user/builder-cleanup.timer:
  file.managed:
    - source: salt://build-infra/builder-cleanup.timer
    - mode: 0644
    - user: user
    - makedirs: true

/home/user/.config/systemd/user/timers.target.wants/builder-cleanup.timer:
  file.symlink:
    - target: ../builder-cleanup.timer
    - force: True
    - mode: 0755
    - makedirs: True

/home/user/.config/systemd/user/upload-release-status.service:
  file.managed:
    - source: salt://build-infra/upload-release-status.service
    - mode: 0644
    - user: user
    - makedirs: true
    - template: jinja
    - context:
        builder_dir: {{last_builder_dir}}

/home/user/.config/systemd/user/upload-release-status.timer:
  file.managed:
    - source: salt://build-infra/upload-release-status.timer
    - mode: 0644
    - user: user
    - makedirs: true

/home/user/.config/systemd/user/timers.target.wants/upload-release-status.timer:
  file.symlink:
    - target: ../upload-release-status.timer
    - force: True
    - mode: 0755
    - makedirs: True

commands-keyring:
  cmd.run:
    - name: rm -f {{ commands_keyring }}; LC_ALL=C.utf8 gpg2 --dearmor > {{ commands_keyring }} < /home/user/trusted-keys-for-commands.asc
    - runas: user
    - onchange:
      - file: /home/user/trusted-keys-for-commands.asc

/home/user/.ssh/config:
  file.managed:
    - user: user
    - contents: |
{% for host, config in salt['pillar.get']('build-infra:remote-hosts', {}).items() %}
        Host {{host}}
          HostName {{host}}
          User {{config.ssh_user}}
{% endfor %}
    - mode: 0755
    - makedirs: True

{% for host, config in salt['pillar.get']('build-infra:remote-hosts', {}).items() %}
{{host}}:
  ssh_known_hosts.present:
    - user: user
    - enc: ssh-rsa
    - key: {{config.ssh_host_key}}
    - hash_known_hosts: False
{% endfor %}

github.com:
  ssh_known_hosts.present:
    - user: user
    - enc: ssh-rsa
    - key: AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
    - hash_known_hosts: False

{% if salt['pillar.get']('build-infra:mirror_ssh_key') %}
/home/user/.ssh/id_rsa:
  file.managed:
    - contents_pillar: build-infra:mirror_ssh_key
    - mode: 600
    - user: user
    - group: user
    - makedirs: True
    - dir_mode: 700
{% endif %}

{% for builder in builders_list %}
{% set config_baseurl = salt['pillar.get']('build-infra:build-envs:' + env + ':builders-list:' + builder + ':config:repository:baseurl', 'https://github.com/QubesOS/qubes-') %}
{% set config_repo = salt['pillar.get']('build-infra:build-envs:' + env + ':builders-list:' + builder + ':config:repository:component', 'release-configs') %}
{% set config_file = salt['pillar.get']('build-infra:build-envs:' + env + ':builders-list:' + builder + ':config:file') %}
{% set keys =  salt['pillar.get']('build-infra:build-envs:' + env + ':builders-list:' + builder + ':keys', []) %}

{{builder}}-get:
  git.latest:
    - name : https://github.com/QubesOS/qubes-builder
    - target: {{ builder }}
    - user: user

{{builder}}-check:
  cmd.run:
    - name: git verify-tag --raw "$(git describe)" 2>&1 >/dev/null | grep '^\[GNUPG:\] TRUST_FULLY'
    - cwd: {{ builder }}
    - runas: user
    - require:
      - git: {{builder}}-get
      - gpg: {{qubes_master_key_fpr}}

{{builder}}-init:
  cmd.run:
    - name: "BUILDERCONF= GIT_URL_builder=https://github.com/QubesOS/qubes-builder COMPONENTS=builder make get-sources"
    - cwd: {{ builder }}
    - runas: user
    - require:
      - cmd: {{builder}}-check

{% for key in keys %}
{{builder}}-{{key}}-import:
  cmd.run:
    - name:  export GNUPGHOME="$(make get-var GET_VAR=KEYRING_DIR_GIT)"; gpg --import {{builder}}/keys/{{key}}.asc || exit 1; echo '{{key}}:6:' | gpg --import-ownertrust
    - cwd: {{ builder }}
    - runas: user
    - require:
      - cmd: {{builder}}-init
{% endfor %}

{{builder}}-configs:
  cmd.run:
    - name: "BUILDERCONF= COMPONENTS={{ config_repo }} GIT_URL_{{ config_repo|replace('-', '_') }}={{ config_baseurl }}{{ config_repo }} make get-sources"
    - cwd: {{ builder }}
    - runas: user
    - require:
      - cmd: {{builder}}-check

{% if config_file %}
{{ builder }}/builder.conf:
  file.symlink:
    - target: {{ builder }}/qubes-src/{{ config_repo }}/{{ config_file }}
    - force: True
    - mode: 0775
    - makedirs: True
    - require:
      - cmd: {{builder}}-configs

{{builder}}-get-sources:
  cmd.run:
    - name: "make get-sources"
    - cwd: {{ builder }}
    - runas: user
    - require:
      - file: {{ builder }}/builder.conf
{% endif %}
{% endfor %}
