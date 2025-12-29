

# php-nginx-filebrowser

基于 `webdevops/php-nginx:8.4` 的 PHP + Nginx 镜像，集成 FileBrowser 文件管理器，并通过 supervisord 统一管理。

## 快速开始

## 直接拉取已经构建的 Docker 镜像

> Docker Hub 镜像：`piscon/php-nginx-filebrowser`  
> https://hub.docker.com/r/piscon/php-nginx-filebrowser


## 自己构建

```bash
# 在项目根目录构建镜像（包含 Dockerfile 和 supervisord-filebrowser.conf）
docker build -t php-nginx-filebrowser .

# 启动容器
docker run -d \
  --name php-nginx-filebrowser \
  -p 8080:8080 \
  -v /path/to/app:/app \
  php-nginx-filebrowser
```

- 在浏览器访问：`http://<host>:8080` 打开 FileBrowser 界面。
- `/path/to/app` 为需要通过 FileBrowser 管理的目录，对应容器内 `/app`。

## 镜像结构

```Dockerfile
FROM webdevops/php-nginx:8.4

# 安装 filebrowser
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8080

# supervisord 管理 filebrowser
COPY supervisord-filebrowser.conf /opt/docker/etc/supervisor.d/filebrowser.conf
```

- 继承 `webdevops/php-nginx:8.4`，保留其 PHP-FPM + Nginx 环境和目录结构。
- 使用官方 `get.sh` 脚本安装 FileBrowser，可执行文件位于 `/usr/local/bin/filebrowser`。
- 暴露 `8080` 端口作为 FileBrowser 的 HTTP 服务端口。

## FileBrowser 运行配置

`supervisord-filebrowser.conf`：

```ini
[program:filebrowser]
command=/usr/local/bin/filebrowser -r /app -p 8080 -a 0.0.0.0 --database /tmp/filebrowser.db
autostart=true
autorestart=true
user=application
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

- `-r /app`：将根目录设为 `/app`，仅管理该目录下的文件。
- `-p 8080 -a 0.0.0.0`：监听 8080 端口并绑定到所有网卡，供外部访问。  
- `--database /tmp/filebrowser.db`：数据库文件位于 `/tmp/filebrowser.db`，存放在容器临时目录中（默认不持久化）。
- `autostart=true` / `autorestart=true`：随容器启动并在异常退出时自动重启。  
- `user=application`：以非 root 用户运行，与基础镜像保持一致。
- 日志重定向到 `/dev/stdout` 和 `/dev/stderr`，便于通过 `docker logs` 查看。

## 管理员账号与日志

使用一个全新的数据库路径首次启动时，FileBrowser 会初始化数据库并创建管理员账号 `admin`，密码为随机生成的强密码。

- 初始化时日志会输出一条类似信息：  
  ```text
  2025/12/29 00:13:22 User 'admin' initialized with randomly generated password: qxyS3DSTb3Gf1ikX
  ```
- 可以通过如下命令从容器日志中获取密码：  

  ```bash
  docker logs php-nginx-filebrowser | grep -i "initialized with randomly generated password"
  ```

- 只要数据库所在路径不持久化（例如使用默认的 `/tmp/filebrowser.db`），容器重启或镜像重建后，之前的 FileBrowser 配置和账号信息都会丢失，但挂载目录中的实际文件不会受影响。

## FileBrowser 配置数据持久化

默认数据库路径位于 `/tmp/filebrowser.db`，容器重启后内容会丢失。
如需持久化账号和配置，可以改用持久化目录：

1. 修改 `supervisord-filebrowser.conf` 中的命令，例如：

   ```ini
   command=/usr/local/bin/filebrowser -r /app -p 8080 -a 0.0.0.0 --database /srv/filebrowser/filebrowser.db
   ```

2. 启动容器时挂载数据卷：

   ```bash
   docker run -d \
     --name php-nginx-filebrowser \
     -p 8080:8080 \
     -v /path/to/app:/app \
     -v /path/to/db:/srv/filebrowser \
     php-nginx-filebrowser
   ```

这样数据库会保存到宿主机 `/path/to/db/filebrowser.db` 中，重建容器也不会丢失 FileBrowser 的用户和配置。

## PHP / Nginx 相关参数

本镜像只扩展了 FileBrowser，其余 PHP 与 Nginx 行为与 `webdevops/php-nginx` 保持一致，可通过环境变量进行配置。

- **WEB_DOCUMENT_ROOT**  
  - 指定 Nginx/PHP 的 Web 根目录，默认值为 `/app`。
  - 本镜像中 FileBrowser 也使用 `/app` 作为根目录（`-r /app`），默认情况下两者一致。  
  - 如需将 PHP 应用放在子目录（例如 `/app/public`），可以在启动容器时设置：  
    ```bash
    -e WEB_DOCUMENT_ROOT=/app/public
    ```

- **WEB_DOCUMENT_INDEX**  
  - 指定 Nginx 的默认首页文件名，默认值为 `index.php`。
  - 对 `/` 的访问会被重写到该文件，例如 `/index.php`。  
  - 如果 PHP 应用首页不叫 `index.php`，可以设置：  
    ```bash
    -e WEB_DOCUMENT_INDEX=public/index.php
    ```

如果需要进一步修改 PHP、Nginx 的配置（如上传大小、额外 vhost、PHP-FPM 参数等），请参考 `webdevops/php-nginx` 官方文档中的环境变量和配置挂载说明，不建议在本镜像中直接修改基础文件。

## 其余参考

- `webdevops/php-nginx` 文档：  
  https://dockerfile.readthedocs.io/en/latest/content/DockerImages/dockerfiles/php-nginx.html
- FileBrowser 文档：  
  https://filebrowser.readthedocs.io/en/latest
