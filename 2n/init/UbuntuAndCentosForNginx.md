您提出了两个非常好的问题。让我来逐一回答：

1. Ubuntu 下 NGINX 的 HTTPS 配置位置：

在 Ubuntu 系统中，Certbot 通常不会直接修改主 nginx.conf 文件。相反，它会在 /etc/nginx/sites-available/ 目录下创建或修改特定站点的配置文件。这些配置文件通常以域名命名（例如：example.com）。

HTTPS 的配置（包括证书位置）会被写入这些站点特定的配置文件中。然后，这些配置文件会通过符号链接连接到 /etc/nginx/sites-enabled/ 目录。

nginx.conf 文件通过以下指令包含这些配置：

```
include /etc/nginx/sites-enabled/*;
```

这行通常位于 nginx.conf 的 http {} 块内。

要查看特定站点的 HTTPS 配置，您可以查看 /etc/nginx/sites-available/ 目录下对应的配置文件。

2. 在 Ubuntu 中恢复 HTTP 配置：

虽然 Ubuntu 没有 nginx.conf.default 文件，但您可以通过以下步骤恢复到 HTTP 配置：

a. 备份当前配置：
```
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
```

b. 删除或重命名 /etc/nginx/sites-enabled/ 目录下的 HTTPS 配置文件：
```
sudo rm /etc/nginx/sites-enabled/your_domain_name
```
或
```
sudo mv /etc/nginx/sites-enabled/your_domain_name /etc/nginx/sites-enabled/your_domain_name.https
```

c. 如果您在 /etc/nginx/sites-available/ 目录下有原始的 HTTP 配置，可以重新启用它：
```
sudo ln -s /etc/nginx/sites-available/your_domain_name /etc/nginx/sites-enabled/
```

d. 编辑站点配置文件（/etc/nginx/sites-available/your_domain_name），删除所有与 HTTPS 相关的配置。

e. 测试配置文件是否有语法错误：
```
sudo nginx -t
```

f. 如果测试通过，重新加载 NGINX：
```
sudo systemctl reload nginx
```

这样就可以恢复到 HTTP 配置。记得在恢复 HTTP 配置后，更新任何可能依赖于 HTTPS 的应用程序设置。

通过这些步骤，您应该能够在 Ubuntu 系统中管理 NGINX 的 HTTPS 配置，并在需要时恢复到 HTTP 配置。