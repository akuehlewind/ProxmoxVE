#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Adrian Kühlewind (akuehlewind)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.chatwoot.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing dependencies"
$STD apt-get install -y --no-install-recommends \
  curl \
  gnupg2 \
  git \
  build-essential \
  libpq-dev \
  libvips \
  libvips-dev \
  imagemagick \
  libimage-exiftool-perl
msg_ok "Installed base dependencies"

msg_info "Installing PostgreSQL, Redis and Ruby"
$STD apt-get install -y \
  postgresql \
  postgresql-contrib \
  redis-server \
  ruby-full
msg_ok "Installed PostgreSQL, Redis, Ruby"

msg_info "Installing Node.js and Yarn"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
$STD apt-get install -y nodejs
$STD npm install -g yarn
msg_ok "Installed Node.js and Yarn"

msg_info "Creating chatwoot user with password"
useradd -m -s /bin/bash chatwoot
echo "chatwoot:chatwoot" | chpasswd
msg_ok "Created user and set default password"

msg_info "Installing rbenv and Ruby 3.4.4 for chatwoot user"
su - chatwoot -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
su - chatwoot -c "git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build"
su - chatwoot -c "bash -lc 'rbenv install 3.4.4 && rbenv global 3.4.4 && gem install bundler'"
msg_ok "Installed Ruby 3.4.4 and Bundler"

msg_info "Cloning Chatwoot repo"
su - chatwoot -c "git clone https://github.com/chatwoot/chatwoot.git"
msg_ok "Cloned Chatwoot repo"

msg_info "Running Chatwoot setup (this may take a while)"
su - chatwoot -c "bash -lc 'cd ~/chatwoot && bundle install && yarn install && bundle exec rake db:setup'"
msg_ok "Chatwoot setup completed"

msg_info "Creating Chatwoot systemd service"
cat <<EOF >/etc/systemd/system/chatwoot.service
[Unit]
Description=Chatwoot Server
After=network.target

[Service]
Type=simple
User=chatwoot
WorkingDirectory=/home/chatwoot/chatwoot
ExecStart=/home/chatwoot/.rbenv/shims/foreman start
Restart=always
Environment=RAILS_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now chatwoot
msg_ok "Created and started Chatwoot service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
