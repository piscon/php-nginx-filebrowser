FROM webdevops/php-nginx:8.4

# 安装 filebrowser
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8080

# 新增一个 supervisord 配置，专门管 filebrowser
COPY supervisord-filebrowser.conf /opt/docker/etc/supervisor.d/filebrowser.conf
