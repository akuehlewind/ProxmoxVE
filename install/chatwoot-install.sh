#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Adrian Kühlewind (akuehlewind)
# License: MIT | https://github.com/akuehlewind/ProxmoxVE/raw/main/LICENSE
# Source: https://www.chatwoot.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing base dependencies"
$STD apt-get install -y --no-install-recommends \
  curl gnupg2 git build-essential libpq-dev \
  libvips libvips-dev imagemagick libimage-exiftool-perl
msg_ok "Installed base dependencies"

msg_info "Installing PostgreSQL, Redis and Ruby"
$STD apt-get install -y postgresql postgresql-contrib redis-server ruby-full
msg_ok "Installed PostgreSQL, Redis and Ruby"

msg_info "Installing Node.js and Yarn"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
$STD apt-get install -y nodejs
$STD npm install -g yarn
msg_ok "Installed Node.js and Yarn"

msg_info "Creating chatwoot user"
useradd -m -s /bin/bash chatwoot
echo "chatwoot:chatwoot" | chpasswd
msg_ok "Created user and set default password"

msg_info "Installing rbenv and Ruby 3.4.4"
su - chatwoot -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
su - chatwoot -c "git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build"
su - chatwoot -c "echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.bashrc"
su - chatwoot -c "echo 'eval \"\$(rbenv init -)\"' >> ~/.bashrc"
su - chatwoot -c "bash -lc 'rbenv install 3.4.4 && rbenv global 3.4.4'"
su - chatwoot -c "bash -lc 'gem install bundler --no-document'"
msg_ok "Installed Ruby 3.4.4 with rbenv and bundler"

msg_info "Cloning Chatwoot"
su - chatwoot -c "git clone https://github.com/chatwoot/chatwoot.git"
msg_ok "Cloned Chatwoot"

msg_info "Running Chatwoot setup (may take a while)"
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
ExecStart=/usr/bin/foreman start
Restart=always

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

echo -e "\n${YW}🔑 Login credentials:${CL}"
echo -e "${TAB}Username: ${GN}chatwoot${CL}"
echo -e "${TAB}Password: ${GN}chatwoot${CL}"
echo -e "${INFO}${YW} Access Chatwoot using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
